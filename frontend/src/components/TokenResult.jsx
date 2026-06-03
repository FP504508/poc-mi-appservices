import { useState } from 'react'

const LAYERS = [
  {
    n: 1,
    title: 'JWT firmado por Entra ID',
    desc:  'Firma, issuer y audience validados contra el App Registration del backend',
  },
  {
    n: 2,
    title: 'App Role "Frontend.Call"',
    desc:  'El claim roles del token confirma que el frontend tiene permiso explícito',
  },
  {
    n: 3,
    title: 'Managed Identity verificada',
    desc:  'appid del token coincide con el clientId de la Managed Identity del frontend',
  },
]

const CLAIMS = [
  ['callerAppId', 'callerAppId'],
  ['audience',   'audience'],
  ['issuer',     'issuer'],
  ['expiraEn',   'expiraEn'],
]

const S = {
  wrapper: {
    display: 'grid',
    gap: '20px',
    animation: 'fadein 0.5s ease',
  },
  banner: {
    backgroundColor: '#107c10',
    borderRadius: '16px',
    padding: '32px',
    textAlign: 'center',
    color: '#fff',
  },
  bannerIcon: {
    fontSize: '56px',
    display: 'block',
    marginBottom: '10px',
  },
  bannerTitle: {
    margin: 0,
    fontSize: 'clamp(1.3rem, 3vw, 1.8rem)',
    fontWeight: 700,
  },
  layersRow: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
    gap: '16px',
  },
  layerCard: {
    backgroundColor: '#fff',
    border: '1px solid #e5e7eb',
    borderRadius: '14px',
    padding: '22px',
    display: 'flex',
    flexDirection: 'column',
    gap: '10px',
    boxShadow: '0 2px 10px rgba(0,0,0,0.06)',
  },
  badge: {
    width: '38px',
    height: '38px',
    borderRadius: '50%',
    backgroundColor: '#0078d4',
    color: '#fff',
    fontWeight: 800,
    fontSize: '1.05rem',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  layerTitle: {
    margin: 0,
    fontWeight: 700,
    fontSize: '0.95rem',
    color: '#111',
  },
  layerDesc: {
    margin: 0,
    fontSize: '0.85rem',
    color: '#555',
    lineHeight: '1.5',
  },
  claimsCard: {
    backgroundColor: '#fff',
    border: '1px solid #e5e7eb',
    borderRadius: '14px',
    overflow: 'hidden',
  },
  claimsHeader: {
    backgroundColor: '#f3f3f3',
    padding: '13px 22px',
    fontWeight: 700,
    fontSize: '0.88rem',
    color: '#333',
    borderBottom: '1px solid #e5e7eb',
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
  },
  th: {
    textAlign: 'left',
    padding: '10px 22px',
    backgroundColor: '#fafafa',
    color: '#6b7280',
    fontSize: '0.78rem',
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
    borderBottom: '1px solid #e5e7eb',
  },
  tdLabel: {
    padding: '13px 22px',
    borderBottom: '1px solid #f3f3f3',
    fontSize: '0.88rem',
    fontWeight: 600,
    color: '#374151',
    whiteSpace: 'nowrap',
    width: '140px',
  },
  td: {
    padding: '13px 22px',
    borderBottom: '1px solid #f3f3f3',
    fontSize: '0.88rem',
    color: '#1f2937',
    wordBreak: 'break-all',
  },
  jwtCard: {
    backgroundColor: '#fff',
    border: '1px solid #e5e7eb',
    borderRadius: '14px',
    overflow: 'hidden',
  },
  jwtToggle: {
    width: '100%',
    background: 'none',
    border: 'none',
    borderBottom: '1px solid #e5e7eb',
    padding: '15px 22px',
    textAlign: 'left',
    fontFamily: 'system-ui, sans-serif',
    fontSize: '0.92rem',
    fontWeight: 700,
    color: '#0078d4',
    cursor: 'pointer',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#f9fafb',
  },
  jwtBody: {
    backgroundColor: '#1e1e1e',
    padding: '22px 24px',
    fontFamily: 'Consolas, Monaco, "Courier New", monospace',
    fontSize: '0.8rem',
    color: '#9cdcfe',
    wordBreak: 'break-all',
    lineHeight: '1.7',
    whiteSpace: 'pre-wrap',
  },
  resetBtn: {
    display: 'block',
    margin: '8px auto 0',
    padding: '14px 32px',
    backgroundColor: '#fff',
    border: '2px solid #0078d4',
    borderRadius: '12px',
    color: '#0078d4',
    fontFamily: 'system-ui, sans-serif',
    fontSize: '1rem',
    fontWeight: 700,
    cursor: 'pointer',
  },
}

function asString(value) {
  if (Array.isArray(value)) return value.join(', ')
  if (value === null || value === undefined) return '—'
  return String(value)
}

export default function TokenResult({ data, onReset }) {
  const [jwtOpen, setJwtOpen] = useState(false)
  const backend = data.backendResponse || {}

  return (
    <div style={S.wrapper}>
      {/* Success banner */}
      <div style={S.banner}>
        <span style={S.bannerIcon}>✅</span>
        <h2 style={S.bannerTitle}>Comunicación segura verificada</h2>
      </div>

      {/* 3 security layer cards */}
      <div style={S.layersRow}>
        {LAYERS.map(({ n, title, desc }) => (
          <div key={n} style={S.layerCard}>
            <div style={S.badge}>{n}</div>
            <p style={S.layerTitle}>{title}</p>
            <p style={S.layerDesc}>{desc}</p>
          </div>
        ))}
      </div>

      {/* Claims table */}
      <div style={S.claimsCard}>
        <div style={S.claimsHeader}>Claims del token JWT</div>
        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Campo</th>
              <th style={S.th}>Valor</th>
            </tr>
          </thead>
          <tbody>
            {CLAIMS.map(([label, key]) => (
              <tr key={label}>
                <td style={S.tdLabel}>{label}</td>
                <td style={S.td}>{asString(backend[key])}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Collapsible JWT preview */}
      <div style={S.jwtCard}>
        <button
          type="button"
          style={S.jwtToggle}
          onClick={() => setJwtOpen(o => !o)}
        >
          <span>🔑 Ver token JWT</span>
          <span>{jwtOpen ? '▲' : '▼'}</span>
        </button>
        {jwtOpen && (
          <div style={S.jwtBody}>{asString(data.tokenPreview)}...</div>
        )}
      </div>

      {/* Reset */}
      <button type="button" style={S.resetBtn} onClick={onReset}>
        🔄 Volver a verificar
      </button>
    </div>
  )
}
