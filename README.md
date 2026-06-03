# poc-mi-appservices
POC — Comunicación segura Frontend ↔ Backend via Managed Identity + Entra ID

## 2. Descripción

Esta POC demuestra:

- Comunicación segura service-to-service sin secretos ni contraseñas en el código.
- El frontend obtiene un token JWT de Microsoft Entra ID usando su Managed Identity.
- El backend Spring Boot valida el token automáticamente con Azure AD Starter.
- Ambos servicios se despliegan como contenedores Docker en Azure App Service.
- Un solo App Service Plan compartido (B1 Linux) para frontend y backend.

## 3. Arquitectura

```text
Frontend (React + Express)          Microsoft Entra ID
	App Service Container       →     emite JWT firmado
	Managed Identity            ←
				│
				│  Authorization: Bearer <token>
				▼
Backend (Spring Boot Java 21)
	App Service Container
	Valida JWT automáticamente
```

## 4. Stack tecnológico

| Componente | Tecnología |
|---|---|
| Frontend UI | React 18 + Vite 5 |
| Frontend servidor | Node 20 + Express 4 |
| Backend | Java 21 + Spring Boot 3.3 + Spring Security |
| Validación JWT | spring-cloud-azure-starter-active-directory 5.17 |
| Identidad | Azure Managed Identity (System-assigned) |
| Autorización | Microsoft Entra ID (OAuth 2.0 Client Credentials) |
| Contenedores | Docker (multi-stage build) |
| Registry | Azure Container Registry (Basic) |
| Infraestructura | Azure App Service (Linux B1, plan compartido) |
| Despliegue | Azure CLI + bash |

## 5. Estructura del repositorio

```text
poc-mi-appservices/
├── backend/                        # Proyecto Spring Boot (Java 21)
│   ├── src/main/java/.../
│   │   ├── config/SecurityConfig   # Protege endpoints con JWT de Entra ID
│   │   └── controller/Hello...     # Endpoint /api/hello protegido
│   ├── src/main/resources/
│   │   └── application.yml         # Config: client-id y app-id-uri
│   ├── pom.xml
│   └── Dockerfile                  # Multi-stage: maven:21 → temurin:21-jre
├── frontend/                       # Proyecto React + Express (Node 20)
│   ├── src/                        # Componentes React
│   ├── server/index.js             # Express: obtiene token MI y llama backend
│   ├── package.json
│   ├── vite.config.js
│   └── Dockerfile                  # Multi-stage: node:20 build + runtime
├── deploy.sh                       # Despliega todo en Azure (13 pasos)
├── .gitignore
└── README.md
```

## 6. Requisitos previos

- Azure CLI >= 2.60
- Docker Desktop en ejecución
- Node.js >= 20
- Java >= 21
- Maven >= 3.9
- Cuenta Azure con créditos (Entra ID Free incluido)
- Git

## 7. Cómo desplegar

```bash
# 1. Clonar el repo
git clone https://github.com/<tu-usuario>/poc-mi-appservices.git
cd poc-mi-appservices

# 2. Iniciar sesión en Azure
az login

# 3. Ejecutar el script (tarda ~10-15 min, Maven es lo más lento)
bash deploy.sh
```

Al terminar, el script imprime las URLs y comandos de verificación.

## 8. Verificación de la POC

```bash
# Debe devolver JSON con los claims del token → comunicación segura OK
curl https://<frontend>.azurewebsites.net/api/call-backend

# Debe devolver HTTP 401 → el backend rechaza llamadas sin token
curl https://<backend>.azurewebsites.net/api/hello

# Health checks públicos (sin token)
curl https://<frontend>.azurewebsites.net/health
curl https://<backend>.azurewebsites.net/health
```

Ejemplo de respuesta JSON exitosa:

```json
{
	"backendResponse": {
		"mensaje": "✅ Comunicación segura verificada — 3 capas OK",
		"callerAppId": "11111111-2222-3333-4444-555555555555",
		"audience": ["api://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"],
		"issuer": "https://sts.windows.net/<tenant-id>/",
		"expiraEn": "3592s"
	},
	"tokenPreview": "eyJ0eXAiOiJKV1QiLCJub25jZSI6Ii0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0",
	"tokenExpiresAt": "2026-06-03T20:17:01.000Z"
}
```

## 9. Recursos creados en Azure

| Recurso | Nombre | Costo aprox. |
|---|---|---|
| Resource Group | rg-poc-mi-appservices | $0 |
| Container Registry | acrpocmi{RANDOM} | ~$5/mes |
| App Service Plan B1 | plan-poc-mi-appservices | ~$13/mes |
| App Service Frontend | frontend-poc-{RANDOM} | incluido en plan |
| App Service Backend | backend-poc-{RANDOM} | incluido en plan |
| App Registration | backend-poc-api-{RANDOM} | $0 (Entra ID Free) |
| Managed Identity | system-assigned al frontend | $0 |

## 10. Cómo limpiar

```bash
# Elimina TODOS los recursos de Azure de esta POC
az group delete --name rg-poc-mi-appservices --yes --no-wait
```

Advertencia: esta operación es irreversible.

## 11. Decisiones de diseño

- Por qué Express junto a React: la Managed Identity solo existe en el proceso servidor del contenedor. El browser no tiene acceso a IDENTITY_ENDPOINT ni IDENTITY_HEADER.
- Por qué un solo App Service Plan: para una POC se optimiza costo y simplicidad. En producción se recomienda separar planes por aislamiento y escalado independiente.
- Por qué no hay secretos en el código: Managed Identity elimina el uso de client secrets, passwords y connection strings embebidos.
- Por qué JWT de Entra ID y no JWT propio: Azure emite y firma el token, y Spring Security valida firma/issuer/audience automáticamente con JWKS.
- Por qué 3 capas de seguridad y no solo 1: Capa 1 (Entra ID) bloquea tokens falsos y de otros tenants; Capa 2 (App Role) bloquea identidades de tu tenant sin permiso explícito; Capa 3 (appid) garantiza que solo el frontend específico puede llamar al backend, aunque otra app tuviera el rol asignado por error.

## 12. Referencias

- https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
- https://learn.microsoft.com/azure/developer/java/spring-framework/spring-security-support
- https://learn.microsoft.com/entra/fundamentals/whatis

## Anexo — Matriz de acceso al backend

Con las 3 capas de seguridad implementadas, este es el comportamiento
esperado según el tipo de caller:

| Caller | Capa que bloquea | Resultado |
|---|---|---|
| Frontend propio (MI con App Role asignado) | Pasa las 3 capas | ✅ 200 OK |
| Postman sin token | Capa 1 — Spring Security | ❌ 401 |
| Postman con token válido pero sin App Role | Capa 2 — App Role ausente | ❌ 403 |
| Otra app del mismo tenant con App Role asignado por error | Capa 3 — appid distinto | ❌ 403 |
| App en la misma red / VNet sin token | Capa 1 — sin JWT | ❌ 401 |
| App de otro tenant | Capa 1 — issuer inválido | ❌ 401 |

### Nota sobre restricción de red

Las 3 capas controlan **identidad**, no red. El backend sigue siendo una URL
pública HTTPS. Cualquiera puede intentar llamarlo, pero sin el JWT correcto
siempre recibirá 401 o 403.

Si en producción se requiere restricción de red adicional, se necesitaría:
- **VNet Integration** — el backend solo acepta tráfico desde una red privada
- **Access Restrictions** — whitelist de IPs o subnets en el App Service

Para esta POC, las 3 capas de identidad son el estándar recomendado
por Microsoft para comunicación service-to-service en Azure.
