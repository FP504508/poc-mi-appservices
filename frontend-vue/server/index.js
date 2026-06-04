import express from 'express'
import path from 'path'
import { fileURLToPath } from 'url'
import { ManagedIdentityCredential } from '@azure/identity'

/**
 * Servidor Express dentro del contenedor del frontend Vue — Escenario B.
 *
 * Este frontend SÍ tiene el App Role "Frontend.Call" asignado (Capa 2 ✅),
 * pero su appid es diferente al del frontend React que el backend espera.
 * El backend rechazará con 403 en la Capa 3 (appid no autorizado).
 */
const credential = new ManagedIdentityCredential()

const app = express()
const port = process.env.PORT || 3000

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

app.use(express.json())
app.use(express.static(path.join(__dirname, '../dist')))

app.get('/health', (_req, res) => {
  res.json({ status: 'UP', service: 'frontend-vue' })
})

app.get('/api/call-backend', async (_req, res) => {
  const backendUrl   = process.env.BACKEND_URL
  const backendScope = process.env.BACKEND_SCOPE

  if (!backendUrl || !backendUrl.trim()) {
    return res.status(500).json({ error: 'BACKEND_URL no está definido en el App Service' })
  }

  if (!backendScope || !backendScope.trim()) {
    return res.status(500).json({ error: 'BACKEND_SCOPE no está definido en el App Service' })
  }

  try {
    const accessToken = await credential.getToken(backendScope)

    if (!accessToken || !accessToken.token) {
      throw new Error('No se pudo obtener un token válido desde Managed Identity')
    }

    const token = accessToken.token
    const payload = JSON.parse(
      Buffer.from(token.split('.')[1], 'base64').toString()
    )
    const miAppId = payload.appid

    const backendResponse = await fetch(`${backendUrl}/api/hello`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` }
    })

    if (backendResponse.status === 403) {
      return res.status(403).json({
        accesoDenegado: true,
        httpStatus: 403,
        capa: "Capa 3 — appid no autorizado",
        motivo: "El backend rechazó la llamada. Este frontend tiene el App Role asignado pero su Managed Identity no es la esperada por el backend.",
        miAppId
      })
    }

    if (backendResponse.status === 401) {
      return res.status(401).json({
        error: 'Token inválido o no reconocido. El backend rechazó con 401.'
      })
    }

    if (!backendResponse.ok) {
      const text = await backendResponse.text()
      return res.status(backendResponse.status).json({
        error: `Error inesperado del backend (${backendResponse.status}): ${text}`
      })
    }

    // No debería llegar aquí si la MI no tiene el rol asignado
    const data = await backendResponse.json()
    return res.json({
      backendResponse: data,
      tokenPreview: accessToken.token.slice(0, 80),
      tokenExpiresAt: new Date(accessToken.expiresOnTimestamp).toISOString()
    })
  } catch (err) {
    return res.status(500).json({
      error: err.message,
      ayuda: 'Verifica que la Managed Identity esté habilitada en este App Service.'
    })
  }
})

app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, '../dist/index.html'))
})

app.listen(port, () => {
  console.log(`Frontend Vue server running on port ${port}`)
})
