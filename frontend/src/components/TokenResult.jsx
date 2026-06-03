const styles = {
  wrapper: {
    marginTop: '24px',
    display: 'grid',
    gap: '16px'
  },
  section: {
    backgroundColor: '#ffffff',
    border: '1px solid #e5e7eb',
    borderRadius: '10px',
    padding: '16px'
  },
  securitySection: {
    backgroundColor: '#dcfce7',
    borderRadius: '10px',
    padding: '16px'
  },
  heading: {
    marginTop: 0,
    marginBottom: '12px'
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '8px'
  },
  check: {
    color: '#15803d',
    fontWeight: 700
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse'
  },
  th: {
    textAlign: 'left',
    borderBottom: '1px solid #e5e7eb',
    padding: '8px',
    backgroundColor: '#f9fafb'
  },
  td: {
    borderBottom: '1px solid #e5e7eb',
    padding: '8px',
    wordBreak: 'break-word'
  },
  mono: {
    fontFamily: 'Consolas, Monaco, monospace',
    backgroundColor: '#f3f4f6',
    padding: '10px',
    borderRadius: '8px',
    wordBreak: 'break-all'
  }
}

function asString(value) {
  if (Array.isArray(value)) {
    return value.join(', ')
  }
  if (value === null || value === undefined) {
    return '-'
  }
  return String(value)
}

function TokenResult({ data }) {
  const backend = data.backendResponse || {}

  return (
    <div style={styles.wrapper}>
      <section style={styles.securitySection}>
        <h3 style={styles.heading}>Sección 1 — Capas de seguridad verificadas</h3>
        <div style={styles.row}>
          <span style={styles.check}>✓</span>
          <span>Capa 1: JWT firmado por Entra ID — firma, issuer y audience validados</span>
        </div>
        <div style={styles.row}>
          <span style={styles.check}>✓</span>
          <span>Capa 2: App Role <strong>Frontend.Call</strong> presente en el token</span>
        </div>
        <div style={styles.row}>
          <span style={styles.check}>✓</span>
          <span>Capa 3: <strong>appid</strong> coincide con la Managed Identity del frontend</span>
        </div>
      </section>

      <section style={styles.section}>
        <h3 style={styles.heading}>Sección 2 — Claims del token</h3>
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Label</th>
              <th style={styles.th}>Valor</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style={styles.td}>callerAppId</td>
              <td style={styles.td}>{asString(backend.callerAppId)}</td>
            </tr>
            <tr>
              <td style={styles.td}>audience</td>
              <td style={styles.td}>{asString(backend.audience)}</td>
            </tr>
            <tr>
              <td style={styles.td}>issuer</td>
              <td style={styles.td}>{asString(backend.issuer)}</td>
            </tr>
            <tr>
              <td style={styles.td}>expiraEn</td>
              <td style={styles.td}>{asString(backend.expiraEn)}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section style={styles.section}>
        <h3 style={styles.heading}>Sección 3 — Token JWT preview</h3>
        <div style={styles.mono}>{asString(data.tokenPreview)}...</div>
        <p>Timestamp de expiración: {asString(data.tokenExpiresAt)}</p>
      </section>
    </div>
  )
}

export default TokenResult
