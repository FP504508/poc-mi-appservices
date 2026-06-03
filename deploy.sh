#!/usr/bin/env bash
set -euo pipefail

RG="rg-poc-mi-appservices"
LOCATION="eastus"
PLAN="plan-poc-mi-appservices"  # UN SOLO plan compartido para frontend y backend
SUFFIX=$RANDOM
FRONTEND_APP="frontend-poc-$SUFFIX"
BACKEND_APP="backend-poc-$SUFFIX"
ACR_NAME="acrpocmi$SUFFIX"

BACKEND_IMAGE="$ACR_NAME.azurecr.io/backend:latest"
FRONTEND_IMAGE="$ACR_NAME.azurecr.io/frontend:latest"

ROLE_ID="11111111-1111-1111-1111-111111111111"

printf "\n[1/13] Crear Resource Group\n"
az group create --name "$RG" --location "$LOCATION" -o none

printf "\n[2/13] Crear Azure Container Registry (Basic, admin-enabled)\n"
az acr create --resource-group "$RG" --name "$ACR_NAME" --sku Basic --admin-enabled true -o none

printf "\n[3/13] az acr login + docker build backend + docker push\n"
az acr login --name "$ACR_NAME" -o none
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RG" --query loginServer -o tsv)
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

docker build -t "$BACKEND_IMAGE" ./backend
docker push "$BACKEND_IMAGE"

printf "\n[4/13] docker build frontend + docker push\n"
docker build -t "$FRONTEND_IMAGE" ./frontend
docker push "$FRONTEND_IMAGE"

printf "\n[5/13] Crear UN SOLO App Service Plan (Linux, SKU B1)\n"
az appservice plan create --name "$PLAN" --resource-group "$RG" --is-linux --sku B1 -o none

printf "\n[6/13] Registrar backend en Entra ID\n"
BACKEND_CLIENT_ID=$(az ad app create --display-name "backend-poc-api-$SUFFIX" --query appId -o tsv)
APP_ID_URI="api://$BACKEND_CLIENT_ID"
az ad app update --id "$BACKEND_CLIENT_ID" --identifier-uris "$APP_ID_URI" -o none
TENANT_ID=$(az account show --query tenantId -o tsv)

printf "\n[7/13] Crear App Service del BACKEND\n"
az webapp create --name "$BACKEND_APP" --resource-group "$RG" --plan "$PLAN" --deployment-container-image-name "$BACKEND_IMAGE" -o none
az webapp config container set --name "$BACKEND_APP" --resource-group "$RG" \
  --docker-custom-image-name "$BACKEND_IMAGE" \
  --docker-registry-server-url "https://$ACR_LOGIN_SERVER" \
  --docker-registry-server-user "$ACR_USER" \
  --docker-registry-server-password "$ACR_PASS" -o none
az webapp config appsettings set --name "$BACKEND_APP" --resource-group "$RG" \
  --settings AZURE_CLIENT_ID="$BACKEND_CLIENT_ID" AZURE_APP_ID_URI="$APP_ID_URI" -o none

printf "\n[8/13] Crear App Service del FRONTEND\n"
az webapp create --name "$FRONTEND_APP" --resource-group "$RG" --plan "$PLAN" --deployment-container-image-name "$FRONTEND_IMAGE" -o none
az webapp config container set --name "$FRONTEND_APP" --resource-group "$RG" \
  --docker-custom-image-name "$FRONTEND_IMAGE" \
  --docker-registry-server-url "https://$ACR_LOGIN_SERVER" \
  --docker-registry-server-user "$ACR_USER" \
  --docker-registry-server-password "$ACR_PASS" -o none
BACKEND_URL="https://$BACKEND_APP.azurewebsites.net"
BACKEND_SCOPE="$APP_ID_URI/.default"
az webapp config appsettings set --name "$FRONTEND_APP" --resource-group "$RG" \
  --settings BACKEND_URL="$BACKEND_URL" BACKEND_SCOPE="$BACKEND_SCOPE" -o none

printf "\n[9/13] Habilitar Managed Identity en el frontend\n"
az webapp identity assign --name "$FRONTEND_APP" --resource-group "$RG" -o none
FRONTEND_PRINCIPAL_ID=$(az webapp identity show --name "$FRONTEND_APP" --resource-group "$RG" --query principalId -o tsv)
FRONTEND_MI_CLIENT_ID=$(az webapp identity show --name "$FRONTEND_APP" --resource-group "$RG" --query clientId -o tsv)
az webapp config appsettings set --name "$BACKEND_APP" --resource-group "$RG" \
  --settings FRONTEND_MI_CLIENT_ID="$FRONTEND_MI_CLIENT_ID" -o none

printf "\n[10/13] Crear Service Principal del backend si no existe\n"
if ! az ad sp show --id "$BACKEND_CLIENT_ID" >/dev/null 2>&1; then
  az ad sp create --id "$BACKEND_CLIENT_ID" -o none
fi
BACKEND_SP_ID=$(az ad sp show --id "$BACKEND_CLIENT_ID" --query id -o tsv)

printf "\n[11/13] Agregar App Role al App Registration del backend\n"
APP_OBJECT_ID=$(az ad app show --id "$BACKEND_CLIENT_ID" --query id -o tsv)
APP_ROLES='[
  {
    "allowedMemberTypes": ["Application"],
    "description": "Permite al frontend llamar al backend",
    "displayName": "Frontend.Call",
    "id": "11111111-1111-1111-1111-111111111111",
    "isEnabled": true,
    "origin": "Application",
    "value": "Frontend.Call"
  }
]'
az ad app update --id "$APP_OBJECT_ID" --app-roles "$APP_ROLES" -o none

printf "\n[12/13] Asignar el App Role a la Managed Identity del frontend\n"
az rest \
  --method POST \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$BACKEND_SP_ID/appRoleAssignedTo" \
  --headers "Content-Type=application/json" \
  --body "{\"principalId\":\"$FRONTEND_PRINCIPAL_ID\",\"resourceId\":\"$BACKEND_SP_ID\",\"appRoleId\":\"$ROLE_ID\"}" -o none

printf "\n[13/13] Imprimir resumen\n"

cat <<EOF
╔══════════════════════════════════════════════════════════════════╗
║  ✅ Despliegue completado                                        ║
╠══════════════════════════════════════════════════════════════════╣
║  Recursos creados en Azure:                                      ║
║    Resource Group : $RG                                          ║
║    Frontend       : https://$FRONTEND_APP.azurewebsites.net     ║
║    Backend        : https://$BACKEND_APP.azurewebsites.net      ║
║    ACR            : $ACR_LOGIN_SERVER                            ║
╠══════════════════════════════════════════════════════════════════╣
║  Para verificar la POC:                                          ║
║                                                                  ║
║  1. Abre el frontend en el browser y presiona el botón           ║
║     → debe mostrar los claims del token JWT ✅                   ║
║                                                                  ║
║  2. Verifica que el backend rechaza sin token (debe dar 401):    ║
║     curl https://$BACKEND_APP.azurewebsites.net/api/hello       ║
║                                                                  ║
║  3. Health checks públicos:                                      ║
║     curl https://$FRONTEND_APP.azurewebsites.net/health         ║
║     curl https://$BACKEND_APP.azurewebsites.net/health          ║
╠══════════════════════════════════════════════════════════════════╣
║  Para limpiar todos los recursos cuando termines:                ║
║    az group delete --name $RG --yes --no-wait                   ║
╠══════════════════════════════════════════════════════════════════╣
║  ⚠️  Espera 2-3 minutos para que los contenedores arranquen      ║
║      por primera vez tras el despliegue.                         ║
╚══════════════════════════════════════════════════════════════════╝
EOF
