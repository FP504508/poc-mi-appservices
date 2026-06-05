#!/usr/bin/env bash
# =============================================================================
# deploy-vue.sh — Despliega el frontend Vue (Escenario B — Capa 3)
#
# PREREQUISITO: La imagen frontend-vue:latest debe estar publicada en el ACR
#               antes de ejecutar este script. El workflow de GitHub Actions
#               .github/workflows/build-and-push.yml se encarga de construirla.
#
# PREREQUISITO: deploy.sh debe haberse ejecutado antes — este script reutiliza
#               el Resource Group, ACR, App Service Plan y App Registration
#               del backend que ese script creó.
#
# Uso: bash deploy-vue.sh
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Variables fijas
# ---------------------------------------------------------------------------
RG="rg-poc-mi-appservices"
PLAN="plan-poc-mi-appservices"
VUE_APP="app-frontend-vue-poc-mi"
ROLE_ID="11111111-1111-1111-1111-111111111111"

# ---------------------------------------------------------------------------
# Detección automática de recursos existentes
# ---------------------------------------------------------------------------
ACR_NAME=$(az acr list --resource-group "$RG" --query "[0].name" -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" \
  --query "passwords[0].value" -o tsv)
VUE_IMAGE="$ACR_LOGIN_SERVER/poc-mi-frontend-vue:latest"

BACKEND_CLIENT_ID=$(az ad app list \
  --filter "startswith(displayName,'backend-poc-api')" \
  --query "[0].appId" -o tsv)
APP_ID_URI="api://$BACKEND_CLIENT_ID"
BACKEND_SCOPE="$APP_ID_URI/.default"

BACKEND_URL="https://$(az webapp list --resource-group "$RG" \
  --query "[?contains(name,'backend')].defaultHostName" -o tsv)"

BACKEND_SP_ID=$(az ad sp show \
  --id "$BACKEND_CLIENT_ID" --query id -o tsv)

# ---------------------------------------------------------------------------
# Verificación previa — abortar si falta algún recurso
# ---------------------------------------------------------------------------
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Verificando recursos previos..."
echo "═══════════════════════════════════════════════════"

if ! az group show --name "$RG" -o none 2>/dev/null; then
  echo "  ❌ Resource Group '$RG' no existe."
  echo "     Ejecuta primero: bash deploy.sh"
  exit 1
fi
echo "  ✅ Resource Group '$RG' existe"

if [[ -z "$ACR_NAME" ]]; then
  echo "  ❌ No se encontró ningún ACR en '$RG'."
  echo "     Ejecuta primero: bash deploy.sh"
  exit 1
fi
echo "  ✅ ACR '$ACR_NAME' existe"

if ! az acr repository show --name "$ACR_NAME" \
    --repository "poc-mi-frontend-vue" -o none 2>/dev/null; then
  echo "  ❌ La imagen poc-mi-frontend-vue:latest no existe en el ACR."
  echo "     Ejecuta primero el workflow de GitHub Actions: build-and-push.yml"
  exit 1
fi
echo "  ✅ Imagen poc-mi-frontend-vue:latest disponible en el ACR"

if ! az appservice plan show --name "$PLAN" \
    --resource-group "$RG" -o none 2>/dev/null; then
  echo "  ❌ App Service Plan '$PLAN' no existe."
  echo "     Ejecuta primero: bash deploy.sh"
  exit 1
fi
echo "  ✅ App Service Plan '$PLAN' existe"

if [[ -z "$BACKEND_CLIENT_ID" ]]; then
  echo "  ❌ No se encontró App Registration del backend (backend-poc-api)."
  echo "     Ejecuta primero: bash deploy.sh"
  exit 1
fi
echo "  ✅ App Registration del backend encontrada (appId: $BACKEND_CLIENT_ID)"

echo ""

# ---------------------------------------------------------------------------
# Pasos
# ---------------------------------------------------------------------------

echo ""
echo "[1/5] Crear App Service del frontend Vue"
echo "      Qué hace: Crea un nuevo App Service para el Vue en el mismo"
echo "                plan compartido existente usando la imagen del ACR"
echo "                que ya construyó GitHub Actions"
echo "      Por qué:  Comparte el plan con React y backend para no"
echo "                generar costos adicionales en la POC"
echo ""
az webapp create \
  --name "$VUE_APP" \
  --resource-group "$RG" \
  --plan "$PLAN" \
  --deployment-container-image-name "$VUE_IMAGE" \
  -o none

az webapp config container set \
  --name "$VUE_APP" \
  --resource-group "$RG" \
  --container-image-name "$VUE_IMAGE" \
  --container-registry-url "https://$ACR_LOGIN_SERVER" \
  --container-registry-user "$ACR_USER" \
  --container-registry-password "$ACR_PASS" \
  -o none

echo ""
echo "[2/5] Configurar variables de entorno del Vue"
echo "      Qué hace: Inyecta BACKEND_URL y BACKEND_SCOPE"
echo "      Por qué:  El servidor Express del Vue las necesita para"
echo "                saber a dónde llamar y qué audience usar"
echo ""
az webapp config appsettings set \
  --name "$VUE_APP" \
  --resource-group "$RG" \
  --settings \
    BACKEND_URL="$BACKEND_URL" \
    BACKEND_SCOPE="$BACKEND_SCOPE" \
  -o none

echo ""
echo "[3/5] Habilitar Managed Identity en el frontend Vue"
echo "      Qué hace: Asigna una System-assigned Managed Identity al Vue"
echo "                y captura su clientId — será diferente al del React"
echo "      Por qué:  El Vue necesita su propia identidad única en Entra ID"
echo "                para solicitar tokens JWT"
echo ""
az webapp identity assign \
  --name "$VUE_APP" \
  --resource-group "$RG" \
  -o none

VUE_PRINCIPAL_ID=$(az webapp identity show \
  --name "$VUE_APP" \
  --resource-group "$RG" \
  --query principalId -o tsv)

VUE_MI_CLIENT_ID=$(az webapp identity show \
  --name "$VUE_APP" \
  --resource-group "$RG" \
  --query clientId -o tsv)

echo ""
echo "[4/5] Asignar App Role 'Frontend.Call' al Vue"
echo "      Qué hace: Asigna el mismo App Role que tiene el React"
echo "                a la Managed Identity del Vue"
echo "      Por qué:  Escenario B — el Vue tiene el rol correcto pero"
echo "                la Capa 3 (appid) lo bloqueará porque su clientId"
echo "                es diferente al FRONTEND_MI_CLIENT_ID del backend"
echo ""
az rest \
  --method POST \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$BACKEND_SP_ID/appRoleAssignedTo" \
  --headers "Content-Type=application/json" \
  --body "{\"principalId\":\"$VUE_PRINCIPAL_ID\",\"resourceId\":\"$BACKEND_SP_ID\",\"appRoleId\":\"$ROLE_ID\"}" \
  -o none

echo ""
echo "[5/5] Resumen final"
echo ""

cat <<EOF
╔══════════════════════════════════════════════════════════════════╗
║  ✅ Frontend Vue desplegado — Escenario B listo                  ║
╠══════════════════════════════════════════════════════════════════╣
║  URL Frontend Vue   : https://$VUE_APP.azurewebsites.net       ║
║  Managed Identity Vue clientId: $VUE_MI_CLIENT_ID              ║
╠══════════════════════════════════════════════════════════════════╣
║  Para la demo — abrir ambas URLs en el browser:                 ║
║                                                                  ║
║  React (autorizado)  → presionar botón → ✅ verde               ║
║  Vue   (bloqueado)   → presionar botón → ❌ rojo Capa 3         ║
╠══════════════════════════════════════════════════════════════════╣
║  Verificar que el Vue está vivo:                                 ║
║  curl https://$VUE_APP.azurewebsites.net/health                ║
╠══════════════════════════════════════════════════════════════════╣
║  ⚠️  Espera 2-3 minutos para que el contenedor arranque         ║
╚══════════════════════════════════════════════════════════════════╝
EOF
