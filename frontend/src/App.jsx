import { useState, useEffect } from 'react'
import TokenResult from './components/TokenResult'

const LOADING_STEPS = [
  '① Obteniendo token de Entra ID...',
  '② Llamando al backend Spring Boot...',
  '③ Validando 3 capas de seguridad...',
]

const S = {
  page: {
    minHeight: '100vh',
    backgroundColor: '#ffffff',
    fontFamily: 'system-ui, -apple-system, sans-serif',
    color: '#1f2937',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '56px 24px 80px',
  },
  header: {
    textAlign: 'center',
    marginBottom: '44px',
  },
  icon: {
    fontSize: '72px',
    lineHeight: 1,
    display: 'block',
    marginBottom: '20px',
  },
  title: {
    margin: '0 0 10px',
    fontSize: 'clamp(1.8rem, 4vw, 2.6rem)',
    fontWeight: 800,
    color: '#0078d4',
    letterSpacing: '-0.5px',
    lineHeight: 1.2,
  },
  subtitle: {
    margin: '0 0 18px',
    fontSize: '1.15rem',
    color: '#555',
    fontWeight: 400,
  },
  badge: {
    display: 'inline-block',
    backgroundColor: '#0078d4',
    color: '#fff',
    borderRadius: '999px',
    padding: '7px 20px',
    fontSize: '0.85rem',
    fontWeight: 600,
    letterSpacing: '0.4px',
  },
  card: {
    width: '100%',
    maxWidth: '680px',
    backgroundColor: '#fff',
    borderRadius: '20px',
    boxShadow: '0 8px 40px rgba(0,120,212,0.13)',
    border: '1px solid #dde8f5',
    padding: '44px 48px',
    textAlign: 'center',
  },
  description: {
    color: '#4b5563',
    fontSize: '1rem',
    lineHeight: '1.7',
    marginBottom: '36px',
  },
  btn: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '10px',
    padding: '16px 40px',
    borderRadius: '12px',
    border: 'none',
    backgroundColor: '#0078d4',
    color: '#ffffff',
    fontFamily: 'system-ui, sans-serif',
    fontSize: '1.1rem',
    fontWeight: 700,
    cursor: 'pointer',
    boxShadow: '0 4px 20px rgba(0,120,212,0.35)',
    letterSpacing: '0.2px',
  },
  btnDisabled: {
    backgroundColor: '#a0aec0',
    cursor: 'not-allowed',
    boxShadow: 'none',
  },
  loadingWrap: {
    marginTop: '32px',
    textAlign: 'left',
  },
  loadingStep: {
    fontSize: '0.95rem',
    color: '#0078d4',
    fontWeight: 600,
    marginBottom: '14px',
  },
  track: {
    height: '8px',
    backgroundColor: '#e5e7eb',
    borderRadius: '999px',
    overflow: 'hidden',
  },
  bar: {
    height: '100%',
    backgroundColor: '#0078d4',
    borderRadius: '999px',
    transition: 'width 0.9s cubic-bezier(0.4,0,0.2,1)',
  },
  errorCard: {
    marginTop: '28px',
    backgroundColor: '#fef2f2',
    border: '1px solid #fecaca',
    borderRadius: '14px',
    padding: '20px 24px',
    display: 'flex',
    alignItems: 'flex-start',
    gap: '14px',
    textAlign: 'left',
  },
  errorIcon: { fontSize: '26px', flexShrink: 0 },
  errorTitle: { fontWeight: 700, marginBottom: '4px', color: '#7f1d1d', fontSize: '0.95rem' },
  errorText:  { color: '#991b1b', fontSize: '0.9rem', lineHeight: '1.5' },
  resultWrap: {
    width: '100%',
    maxWidth: '900px',
    marginTop: '44px',
    animation: 'fadein 0.5s ease',
  },
}

export default function App() {
  const [loading, setLoading]       = useState(false)
  const [result,  setResult]        = useState(null)
  const [error,   setError]         = useState(null)
  const [step,    setStep]          = useState(0)

  useEffect(() => {
    const id = 'poc-kf'
    if (document.getElementById(id)) return
    const el = document.createElement('style')
    el.id = id
    el.textContent = '@keyframes fadein{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}'
    document.head.appendChild(el)
  }, [])

  useEffect(() => {
    if (!loading) { setStep(0); return }
    const id = setInterval(() => setStep(s => (s + 1) % LOADING_STEPS.length), 1500)
    return () => clearInterval(id)
  }, [loading])

  const callBackend = async () => {
    setLoading(true)
    setError(null)
    setResult(null)
    try {
      const res  = await fetch('/api/call-backend')
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Error al llamar al backend')
      setResult(data)
    } catch (err) {
      setError(err.message || 'Error inesperado')
    } finally {
      setLoading(false)
    }
  }

  const progressPct = loading ? ((step + 1) / LOADING_STEPS.length) * 100 : 0

  return (
    <div style={S.page}>
      <header style={S.header}>
        <span style={S.icon}>🛡️</span>
        <h1 style={S.title}>POC — Comunicación Segura en Azure</h1>
        <p style={S.subtitle}>Managed Identity + Microsoft Entra ID</p>
        <span style={S.badge}>Azure App Service · Spring Boot · React</span>
      </header>

      <div style={S.card}>
        <p style={S.description}>
          El frontend obtiene automáticamente un token JWT usando su Managed Identity
          y lo presenta al backend Spring Boot, que valida tres capas de seguridad
          independientes antes de responder.
        </p>

        <button
          type="button"
          onClick={callBackend}
          disabled={loading}
          style={{ ...S.btn, ...(loading ? S.btnDisabled : {}) }}
        >
          🔐 {loading ? 'Verificando...' : 'Verificar comunicación segura'}
        </button>

        {loading && (
          <div style={S.loadingWrap}>
            <p style={S.loadingStep}>{LOADING_STEPS[step]}</p>
            <div style={S.track}>
              <div style={{ ...S.bar, width: `${progressPct}%` }} />
            </div>
          </div>
        )}

        {error && (
          <div style={S.errorCard}>
            <span style={S.errorIcon}>⚠️</span>
            <div>
              <div style={S.errorTitle}>Error al verificar la comunicación</div>
              <div style={S.errorText}>{error}</div>
            </div>
          </div>
        )}
      </div>

      {result && (
        <div style={S.resultWrap}>
          <TokenResult data={result} onReset={() => setResult(null)} />
        </div>
      )}
    </div>
  )
}
