import { useState } from 'react'
import TokenResult from './components/TokenResult'

const styles = {
  page: {
    minHeight: '100vh',
    backgroundColor: '#f5f7fb',
    fontFamily: 'Segoe UI, Tahoma, sans-serif',
    color: '#1f2937',
    padding: '32px 16px'
  },
  container: {
    maxWidth: '920px',
    margin: '0 auto',
    backgroundColor: '#ffffff',
    borderRadius: '12px',
    boxShadow: '0 8px 24px rgba(0, 0, 0, 0.08)',
    padding: '24px'
  },
  title: {
    marginTop: 0,
    marginBottom: '8px'
  },
  subtitle: {
    marginTop: 0,
    marginBottom: '20px',
    color: '#4b5563'
  },
  button: {
    padding: '12px 18px',
    borderRadius: '8px',
    border: 'none',
    backgroundColor: '#0f766e',
    color: '#ffffff',
    fontWeight: 600,
    cursor: 'pointer'
  },
  buttonDisabled: {
    backgroundColor: '#9ca3af',
    cursor: 'not-allowed'
  },
  errorBox: {
    marginTop: '16px',
    backgroundColor: '#fee2e2',
    color: '#991b1b',
    border: '1px solid #fecaca',
    borderRadius: '8px',
    padding: '12px'
  }
}

function App() {
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState(null)
  const [error, setError] = useState(null)

  const callBackend = async () => {
    setLoading(true)
    setError(null)
    setResult(null)

    try {
      const response = await fetch('/api/call-backend')
      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || 'Error al llamar al backend')
      }

      setResult(data)
    } catch (err) {
      setError(err.message || 'Error inesperado')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.page}>
      <div style={styles.container}>
        <h1 style={styles.title}>POC Frontend → Backend con Managed Identity</h1>
        <p style={styles.subtitle}>
          El servidor Express del frontend obtiene un JWT con Managed Identity y llama al backend protegido.
        </p>

        <button
          type="button"
          onClick={callBackend}
          disabled={loading}
          style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
        >
          {loading ? '⏳ Obteniendo token...' : 'Llamar backend seguro'}
        </button>

        {error && <div style={styles.errorBox}>{error}</div>}

        {result && <TokenResult data={result} />}
      </div>
    </div>
  )
}

export default App
