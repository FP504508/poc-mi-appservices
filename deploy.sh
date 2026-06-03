#!/usr/bin/env bash
set -euo pipefail

RG="rg-poc-mi-appservices"
LOCATION="mexicocentral"
PLAN="plan-poc-mi-appservices"  # UN SOLO plan compartido para frontend y backend
FRONTEND_APP="app-frontend-poc-mi"
BACKEND_APP="app-backend-poc-mi"
ACR_NAME="acrpocmiappservices"

BACKEND_IMAGE="$ACR_NAME.azurecr.io/poc-mi-backend:latest"
FRONTEND_IMAGE="$ACR_NAME.azurecr.io/poc-mi-frontend:latest"

ROLE_ID="11111111-1111-1111-1111-111111111111"

echo ""
echo "[1/13] Crear Resource Group"
echo "       Qué hace: Crea el Resource Group 'rg-poc-mi-appservices' en México Central"
echo "       Por qué:  Es el contenedor lógico de todos los recursos Azure de esta POC."
echo "                 Borrar este grupo al final elimina todo de una vez."
echo ""
az group create --name "$RG" --location "$LOCATION" -o none

echo ""
echo "[2/13] Crear Azure Container Registry (Basic, admin-enabled)"
echo "       Qué hace: Crea el Azure Container Registry (ACR) para guardar las imágenes Docker"
echo "       Por qué:  Azure App Service no puede usar imágenes locales, necesita"
echo "                 descargarlas desde un registry. El ACR es el registry privado de Azure."
echo ""
az acr create --resource-group "$RG" --name "$ACR_NAME" --sku Basic --admin-enabled true -o none

echo ""
echo "[3/13] Construir y subir imagen backend al ACR"
echo "       Qué hace: Hace docker build de la imagen del backend y la sube al ACR"
echo "       Por qué:  La suscripción no permite ACR Tasks, por lo que el build se"
echo "                 ejecuta localmente con Docker y se empuja al registry con push."
echo ""
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RG" --query loginServer -o tsv)
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)
az acr login --name "$ACR_NAME"
docker build -t "$BACKEND_IMAGE" ./backend
docker push "$BACKEND_IMAGE"

echo ""
echo "[4/13] Construir y subir imagen frontend al ACR"
echo "       Qué hace: Hace docker build de la imagen del frontend y la sube al ACR"
echo "       Por qué:  Igual que el paso anterior pero para el frontend React + Express."
echo "                 El Dockerfile hace dos etapas: build de React con Vite y"
echo "                 runtime con Node + Express."
echo ""
docker build -t "$FRONTEND_IMAGE" ./frontend
docker push "$FRONTEND_IMAGE"

echo ""
echo "[5/13] Crear App Service Plan compartido (Linux, SKU B1)"
echo "       Qué hace: Crea UN SOLO App Service Plan B1 Linux compartido"
echo "       Por qué:  El Plan es la infraestructura subyacente (VM). Compartirlo"
echo "                 entre frontend y backend reduce el costo de la POC a ~\$13/mes"
echo "                 en lugar de ~\$26/mes con dos planes separados."
echo ""
az appservice plan create --name "$PLAN" --resource-group "$RG" --is-linux --sku B1 -o none

echo ""
echo "[6/13] Registrar backend en Entra ID"
echo "       Qué hace: Registra el backend en Microsoft Entra ID como App Registration"
echo "       Por qué:  Para que Entra ID sepa que el backend es un recurso protegido"
echo "                 con un audience definido (api://<client-id>). Sin esto el"
echo "                 backend no puede validar tokens JWT."
echo ""
BACKEND_CLIENT_ID=$(az ad app create --display-name "backend-poc-api" --query appId -o tsv)
APP_ID_URI="api://$BACKEND_CLIENT_ID"
az ad app update --id "$BACKEND_CLIENT_ID" --identifier-uris "$APP_ID_URI" -o none
TENANT_ID=$(az account show --query tenantId -o tsv)

echo ""
echo "[7/13] Crear App Service del BACKEND"
echo "       Qué hace: Crea el App Service del backend y configura sus variables de entorno"
echo "       Por qué:  Despliega el contenedor Spring Boot. Las variables AZURE_CLIENT_ID"
echo "                 y AZURE_APP_ID_URI le dicen al backend cómo validar los tokens"
echo "                 de Entra ID (Capa 1 de seguridad)."
echo ""
az webapp create --name "$BACKEND_APP" --resource-group "$RG" --plan "$PLAN" --deployment-container-image-name "$BACKEND_IMAGE" -o none
az webapp config container set --name "$BACKEND_APP" --resource-group "$RG" \
  --docker-custom-image-name "$BACKEND_IMAGE" \
  --docker-registry-server-url "https://$ACR_LOGIN_SERVER" \
  --docker-registry-server-user "$ACR_USER" \
  --docker-registry-server-password "$ACR_PASS" -o none
az webapp config appsettings set --name "$BACKEND_APP" --resource-group "$RG" \
  --settings AZURE_CLIENT_ID="$BACKEND_CLIENT_ID" AZURE_APP_ID_URI="$APP_ID_URI" -o none

echo ""
echo "[8/13] Crear App Service del FRONTEND"
echo "       Qué hace: Crea el App Service del frontend y configura sus variables de entorno"
echo "       Por qué:  Despliega el contenedor React + Express. Las variables BACKEND_URL"
echo "                 y BACKEND_SCOPE le dicen al frontend a dónde llamar y qué"
echo "                 audience usar al pedir el token JWT a Entra ID."
echo ""
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

echo ""
echo "[9/13] Habilitar Managed Identity en el frontend"
echo "       Qué hace: Habilita la Managed Identity en el App Service del frontend"
echo "                 y captura su clientId para la Capa 3 de seguridad"
echo "       Por qué:  La Managed Identity es la identidad del frontend en Entra ID."
echo "                 No requiere secretos ni contraseñas — Azure la gestiona sola."
echo "                 El clientId se inyecta en el backend para verificar que solo"
echo "                 este frontend específico puede llamarlo (Capa 3)."
echo ""
az webapp identity assign --name "$FRONTEND_APP" --resource-group "$RG" -o none
FRONTEND_PRINCIPAL_ID=$(az webapp identity show --name "$FRONTEND_APP" --resource-group "$RG" --query principalId -o tsv)
FRONTEND_MI_CLIENT_ID=$(az webapp identity show --name "$FRONTEND_APP" --resource-group "$RG" --query clientId -o tsv)
az webapp config appsettings set --name "$BACKEND_APP" --resource-group "$RG" \
  --settings FRONTEND_MI_CLIENT_ID="$FRONTEND_MI_CLIENT_ID" -o none

echo ""
echo "[10/13] Crear Service Principal del backend"
echo "        Qué hace: Crea el Service Principal del backend en Entra ID"
echo "        Por qué:  El App Registration del paso [6/13] es solo el registro."
echo "                  El Service Principal es la identidad activa que puede"
echo "                  recibir asignaciones de roles y permisos."
echo ""
if ! az ad sp show --id "$BACKEND_CLIENT_ID" >/dev/null 2>&1; then
  az ad sp create --id "$BACKEND_CLIENT_ID" -o none
fi
BACKEND_SP_ID=$(az ad sp show --id "$BACKEND_CLIENT_ID" --query id -o tsv)

echo ""
echo "[11/13] Agregar App Role 'Frontend.Call' al backend"
echo "        Qué hace: Define el App Role 'Frontend.Call' en el backend"
echo "        Por qué:  El App Role es el permiso explícito que debe tener la"
echo "                  Managed Identity del frontend para llamar al backend."
echo "                  Sin este rol asignado, Entra ID no incluye el claim"
echo "                  'roles' en el token y el backend rechaza la llamada"
echo "                  con 403 (Capa 2 de seguridad)."
echo ""
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

echo ""
echo "[12/13] Asignar App Role a la Managed Identity del frontend"
echo "        Qué hace: Asigna el App Role 'Frontend.Call' a la Managed Identity del frontend"
echo "        Por qué:  Conecta la identidad del frontend con el permiso definido"
echo "                  en el paso anterior. A partir de aquí Entra ID incluirá"
echo "                  el rol en el token JWT y el backend lo aceptará."
echo "                  Esto completa las 3 capas de seguridad:"
echo "                  Capa 1: JWT válido de Entra ID (firma, issuer, audience)"
echo "                  Capa 2: App Role Frontend.Call presente"
echo "                  Capa 3: appid == Managed Identity del frontend"
echo ""
az rest \
  --method POST \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$BACKEND_SP_ID/appRoleAssignedTo" \
  --headers "Content-Type=application/json" \
  --body "{\"principalId\":\"$FRONTEND_PRINCIPAL_ID\",\"resourceId\":\"$BACKEND_SP_ID\",\"appRoleId\":\"$ROLE_ID\"}" -o none

echo ""
echo "[13/13] Imprimir resumen del despliegue"
echo "        Qué hace: Imprime el resumen con URLs y comandos de verificación"
echo "        Por qué:  Confirma que todo se creó correctamente y da los pasos"
echo "                  exactos para probar la comunicación segura."
echo ""

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
