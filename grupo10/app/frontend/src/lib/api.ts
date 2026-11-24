/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=bd | full
 */
import axios from 'axios'

export const api = axios.create({ baseURL: '/api' })

api.interceptors.request.use((config) => {
  const userId = sessionStorage.getItem('userId')
  if (userId) config.headers['X-User-Id'] = userId
  const activeRole = sessionStorage.getItem('activeRole')
  if (activeRole) config.headers['X-Active-Role'] = activeRole
  return config
})