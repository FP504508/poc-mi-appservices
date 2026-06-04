<script setup>
import { ref } from 'vue'
import ResultPanel from './components/ResultPanel.vue'

const loading  = ref(false)
const result   = ref(null)
const fetchErr = ref(null)

const callBackend = async () => {
  loading.value  = true
  result.value   = null
  fetchErr.value = null
  try {
    const res  = await fetch('/api/call-backend')
    const data = await res.json()
    result.value = { ...data, httpStatusCode: res.status }
  } catch (err) {
    fetchErr.value = err.message || 'Error inesperado'
  } finally {
    loading.value = false
  }
}

const reset = () => {
  result.value   = null
  fetchErr.value = null
}
</script>

<template>
  <div :style="S.page">
    <header :style="S.header">
      <span :style="S.icon">🚫</span>
      <h1 :style="S.title">Frontend Vue.js — Identidad rechazada en Capa 3</h1>
      <p :style="S.subtitle">Demostración de rechazo por appid diferente al autorizado</p>
      <span :style="S.badge">Escenario B — Capa 3</span>
    </header>

    <div :style="S.card">
      <p :style="S.description">
        Este frontend <strong>SÍ tiene el App Role "Frontend.Call" asignado</strong>
        (Capa 2 ✅), pero su Managed Identity tiene un <em>appid diferente</em>
        al del frontend React que el backend espera.
        El backend rechazará la llamada en la <strong>Capa 3</strong> (appid no autorizado).
      </p>

      <button
        :style="loading ? { ...S.btn, ...S.btnDisabled } : S.btn"
        :disabled="loading"
        @click="callBackend"
      >
        🚫 {{ loading ? 'Llamando...' : 'Intentar llamar al backend' }}
      </button>
    </div>

    <div v-if="result || fetchErr" :style="S.resultWrap">
      <ResultPanel :data="result" :fetchError="fetchErr" @reset="reset" />
    </div>
  </div>
</template>

<script>
// Inyectar keyframes una sola vez
if (typeof document !== 'undefined' && !document.getElementById('vue-poc-kf')) {
  const el = document.createElement('style')
  el.id = 'vue-poc-kf'
  el.textContent = '@keyframes fadein{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}'
  document.head.appendChild(el)
}

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
    lineHeight: '1',
    display: 'block',
    marginBottom: '20px',
  },
  title: {
    margin: '0 0 10px',
    fontSize: 'clamp(1.6rem, 4vw, 2.4rem)',
    fontWeight: 800,
    color: '#c0392b',
    letterSpacing: '-0.5px',
    lineHeight: '1.2',
  },
  subtitle: {
    margin: '0 0 18px',
    fontSize: '1.1rem',
    color: '#555',
    fontWeight: 400,
  },
  badge: {
    display: 'inline-block',
    backgroundColor: '#e74c3c',
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
    boxShadow: '0 8px 40px rgba(231,76,60,0.12)',
    border: '1px solid #fad7d4',
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
    backgroundColor: '#e74c3c',
    color: '#ffffff',
    fontFamily: 'system-ui, sans-serif',
    fontSize: '1.1rem',
    fontWeight: 700,
    cursor: 'pointer',
    boxShadow: '0 4px 20px rgba(231,76,60,0.35)',
    letterSpacing: '0.2px',
  },
  btnDisabled: {
    backgroundColor: '#a0aec0',
    cursor: 'not-allowed',
    boxShadow: 'none',
  },
  resultWrap: {
    width: '100%',
    maxWidth: '860px',
    marginTop: '44px',
    animation: 'fadein 0.5s ease',
  },
}
export default { data: () => ({ S }) }
</script>
