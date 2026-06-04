<script setup>
defineProps({
  data:       { type: Object,  default: null },
  fetchError: { type: String,  default: null },
})
defineEmits(['reset'])
</script>

<template>
  <div :style="S.wrapper">

    <!-- 403 / acceso denegado -->
    <template v-if="data && data.accesoDenegado">
      <div :style="S.deniedBanner">
        <span :style="S.bannerIcon">❌</span>
        <h2 :style="S.bannerTitle">Acceso denegado por el backend</h2>
      </div>

      <div :style="S.deniedCard">
        <div :style="S.row">
          <span :style="S.label">Motivo</span>
          <span :style="S.value">{{ data.motivo }}</span>
        </div>
        <div :style="S.row">
          <span :style="S.label">Capa bloqueada</span>
          <span :style="{ ...S.value, ...S.capaBadge }">{{ data.capa }}</span>
        </div>
        <div :style="S.row">
          <span :style="S.label">HTTP Status</span>
          <span :style="{ ...S.value, ...S.httpBadge }">{{ data.httpStatus }}</span>
        </div>
      </div>

      <!-- Capas de seguridad -->
      <div :style="S.sectionHeader">Resultado por capa de seguridad</div>
      <div :style="S.layersCard">
        <div :style="S.layerRow">
          <span :style="S.layerOk">✅</span>
          <div>
            <span :style="S.layerTitle">Capa 1 — JWT válido de Entra ID</span>
            <span :style="S.layerDesc">Firma, issuer y audience verificados correctamente</span>
          </div>
        </div>
        <div :style="S.layerRow">
          <span :style="S.layerOk">✅</span>
          <div>
            <span :style="S.layerTitle">Capa 2 — App Role "Frontend.Call"</span>
            <span :style="S.layerDesc">El rol está presente en el token de esta identidad</span>
          </div>
        </div>
        <div :style="{ ...S.layerRow, ...S.layerRowLast }">
          <span :style="S.layerFail">❌</span>
          <div>
            <span :style="{ ...S.layerTitle, color: '#c0392b' }">Capa 3 — appid autorizado</span>
            <span :style="S.layerDesc">El appid no coincide con el del frontend React esperado</span>
          </div>
        </div>
      </div>

      <!-- Comparación de identidades -->
      <div :style="S.sectionHeader">Comparación de identidades</div>
      <div :style="S.identityCard">
        <div :style="S.idRow">
          <span :style="S.idLabel">❌ Mi appId (Vue)</span>
          <span :style="{ ...S.idValue, ...S.idValueBad }">{{ data.miAppId || '—' }}</span>
        </div>
        <div :style="{ ...S.idRow, borderBottom: 'none' }">
          <span :style="S.idLabel">✅ appId esperado (React)</span>
          <span :style="{ ...S.idValue, ...S.idValueOk }">{{ data.appIdEsperado || '—' }}</span>
        </div>
      </div>

      <div :style="S.successNote">
        ✅ Esto demuestra que las 3 capas de seguridad funcionan correctamente
      </div>
    </template>

    <!-- Error inesperado de red/server -->
    <template v-else-if="fetchError || (data && data.error)">
      <div :style="S.warnBanner">
        <span :style="S.bannerIcon">⚠️</span>
        <h2 :style="S.bannerTitle">Error inesperado</h2>
      </div>
      <div :style="S.warnCard">
        <p :style="S.warnText">{{ fetchError || data.error }}</p>
        <p v-if="data && data.ayuda" :style="S.warnHelp">{{ data.ayuda }}</p>
      </div>
    </template>

    <!-- 200 OK — no debería ocurrir -->
    <template v-else-if="data">
      <div :style="S.okBanner">
        <span :style="S.bannerIcon">✅</span>
        <h2 :style="S.bannerTitle">Respuesta 200 — inesperado</h2>
      </div>
      <div :style="S.okCard">
        <p :style="S.warnText">
          El backend respondió 200. Verifica que esta Managed Identity
          realmente no tenga el App Role asignado.
        </p>
        <pre :style="S.pre">{{ JSON.stringify(data, null, 2) }}</pre>
      </div>
    </template>

    <button :style="S.resetBtn" @click="$emit('reset')">
      🔄 Volver a intentar
    </button>
  </div>
</template>

<script>
const S = {
  wrapper: {
    display: 'grid',
    gap: '20px',
    animation: 'fadein 0.5s ease',
  },
  // --- denied ---
  deniedBanner: {
    backgroundColor: '#c0392b',
    borderRadius: '16px',
    padding: '32px',
    textAlign: 'center',
    color: '#fff',
  },
  deniedCard: {
    backgroundColor: '#fff',
    border: '1px solid #fad7d4',
    borderRadius: '14px',
    overflow: 'hidden',
  },
  row: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '16px',
    padding: '16px 24px',
    borderBottom: '1px solid #fef2f2',
  },
  label: {
    flexShrink: 0,
    width: '140px',
    fontWeight: 700,
    fontSize: '0.88rem',
    color: '#374151',
    paddingTop: '2px',
  },
  value: {
    fontSize: '0.92rem',
    color: '#1f2937',
    lineHeight: '1.5',
  },
  capaBadge: {
    display: 'inline-block',
    backgroundColor: '#fef3c7',
    color: '#92400e',
    borderRadius: '6px',
    padding: '3px 10px',
    fontWeight: 600,
    fontSize: '0.85rem',
  },
  httpBadge: {
    display: 'inline-block',
    backgroundColor: '#fee2e2',
    color: '#991b1b',
    borderRadius: '6px',
    padding: '3px 10px',
    fontWeight: 700,
    fontSize: '0.95rem',
  },
  successNote: {
    backgroundColor: '#f0fdf4',
    color: '#166534',
    fontWeight: 600,
    fontSize: '0.92rem',
    padding: '16px 24px',
    borderRadius: '0 0 14px 14px',
    borderTop: '1px solid #bbf7d0',
  },
  // --- layers ---
  sectionHeader: {
    fontSize: '0.78rem',
    fontWeight: 700,
    textTransform: 'uppercase',
    letterSpacing: '0.6px',
    color: '#6b7280',
    padding: '4px 2px',
  },
  layersCard: {
    backgroundColor: '#fff',
    border: '1px solid #e5e7eb',
    borderRadius: '14px',
    overflow: 'hidden',
  },
  layerRow: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '14px',
    padding: '14px 20px',
    borderBottom: '1px solid #f3f3f3',
  },
  layerRowLast: {
    borderBottom: 'none',
    backgroundColor: '#fff5f5',
  },
  layerOk:   { fontSize: '1.25rem', flexShrink: 0, paddingTop: '1px' },
  layerFail: { fontSize: '1.25rem', flexShrink: 0, paddingTop: '1px' },
  layerTitle: {
    display: 'block',
    fontWeight: 700,
    fontSize: '0.9rem',
    color: '#111',
    marginBottom: '2px',
  },
  layerDesc: {
    display: 'block',
    fontSize: '0.82rem',
    color: '#6b7280',
  },
  // --- identity comparison ---
  identityCard: {
    backgroundColor: '#fff',
    border: '1px solid #e5e7eb',
    borderRadius: '14px',
    overflow: 'hidden',
  },
  idRow: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '16px',
    padding: '14px 20px',
    borderBottom: '1px solid #f3f3f3',
  },
  idLabel: {
    flexShrink: 0,
    width: '200px',
    fontWeight: 700,
    fontSize: '0.88rem',
    color: '#374151',
    paddingTop: '2px',
  },
  idValue: {
    fontFamily: 'Consolas, Monaco, monospace',
    fontSize: '0.82rem',
    wordBreak: 'break-all',
    lineHeight: '1.5',
    padding: '3px 10px',
    borderRadius: '6px',
  },
  idValueBad: {
    backgroundColor: '#fee2e2',
    color: '#991b1b',
  },
  idValueOk: {
    backgroundColor: '#dcfce7',
    color: '#166534',
  },
  // --- warn ---
  warnBanner: {
    backgroundColor: '#d97706',
    borderRadius: '16px',
    padding: '32px',
    textAlign: 'center',
    color: '#fff',
  },
  warnCard: {
    backgroundColor: '#fff',
    border: '1px solid #fde68a',
    borderRadius: '14px',
    padding: '24px',
  },
  warnText: {
    color: '#92400e',
    fontSize: '0.95rem',
    lineHeight: '1.6',
    marginBottom: '8px',
  },
  warnHelp: {
    color: '#78350f',
    fontSize: '0.85rem',
    fontStyle: 'italic',
  },
  // --- ok (unexpected) ---
  okBanner: {
    backgroundColor: '#059669',
    borderRadius: '16px',
    padding: '32px',
    textAlign: 'center',
    color: '#fff',
  },
  okCard: {
    backgroundColor: '#fff',
    border: '1px solid #a7f3d0',
    borderRadius: '14px',
    padding: '24px',
  },
  pre: {
    marginTop: '12px',
    backgroundColor: '#1e1e1e',
    color: '#9cdcfe',
    fontFamily: 'Consolas, Monaco, monospace',
    fontSize: '0.78rem',
    padding: '16px',
    borderRadius: '10px',
    overflowX: 'auto',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-all',
  },
  // --- shared ---
  bannerIcon: {
    fontSize: '52px',
    display: 'block',
    marginBottom: '10px',
  },
  bannerTitle: {
    margin: 0,
    fontSize: 'clamp(1.2rem, 3vw, 1.7rem)',
    fontWeight: 700,
  },
  resetBtn: {
    display: 'block',
    margin: '8px auto 0',
    padding: '14px 32px',
    backgroundColor: '#fff',
    border: '2px solid #e74c3c',
    borderRadius: '12px',
    color: '#e74c3c',
    fontFamily: 'system-ui, sans-serif',
    fontSize: '1rem',
    fontWeight: 700,
    cursor: 'pointer',
  },
}
export default { data: () => ({ S }) }
</script>
