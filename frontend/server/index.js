import express from 'express'
import path from 'path'
import { fileURLToPath } from 'url'
import { ManagedIdentityCredential } from '@azure/identity'

/**
 * Servidor Express dentro del contenedor del frontend.
 *
 * Por qué el token se obtiene aquí y no en el browser:
 * Azure inyecta dos variables de entorno en el proceso del contenedor:
 *   - IDENTITY_ENDPOINT: URL interna para pedir tokens
 *   - IDENTITY_HEADER:   header de seguridad para esa URL
 * Estas variables solo existen en el servidor, no en el browser.
 * ManagedIdentityCredential de @azure/identity las usa automáticamente.
 * El browser nunca ve el token completo, solo el resultado de la llamada.
 */
const credential = new ManagedIdentityCredential()

const app = express()
const port = process.env.PORT || 3000

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

app.use(express.json())
app.use(express.static(path.join(__dirname, '../dist')))

app.get('/health', (_req, res) => {
  res.json({ status: 'UP', service: 'frontend' })
})

app.get('/api/call-backend', async (_req, res) => {
  const backendUrl = process.env.BACKEND_URL
  const backendScope = process.env.BACKEND_SCOPE

  if (!backendUrl || !backendUrl.trim()) {
    return res.status(500).json({
      error: 'BACKEND_URL no está definido en el App Service del frontend'
    })
  }

  if (!backendScope || !backendScope.trim()) {
    return res.status(500).json({
      error: 'BACKEND_SCOPE no está definido en el App Service del frontend'
    })
  }

  try {
    const accessToken = await credential.getToken(backendScope)

    if (!accessToken || !accessToken.token) {
      throw new Error('No se pudo obtener un token válido desde Managed Identity')
    }

    const backendResponse = await fetch(`${backendUrl}/api/hello`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken.token}`
      }
    })

    if (backendResponse.status === 401) {
      return res.status(401).json({
        error: 'El backend rechazó el token. Verifica que el App Role esté asignado.'
      })
    }

    if (!backendResponse.ok) {
      const text = await backendResponse.text()
      return res.status(backendResponse.status).json({
        error: `Error al invocar backend: ${text}`
      })
    }

    const data = await backendResponse.json()

    return res.json({
      backendResponse: data,
      tokenPreview: accessToken.token.slice(0, 80),
      tokenExpiresAt: new Date(accessToken.expiresOnTimestamp).toISOString()
    })
  } catch (err) {
    return res.status(500).json({
      error: err.message,
      ayuda: 'La causa más común es que la Managed Identity no esté habilitada o no tenga permisos sobre el backend.'
    })
  }
})

app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, '../dist/index.html'))
})

app.listen(port, () => {
  console.log(`Frontend server running on port ${port}`)
})
