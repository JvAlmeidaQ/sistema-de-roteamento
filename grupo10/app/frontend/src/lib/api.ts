import axios from 'axios'

export const api = axios.create({ baseURL: '/api' })

api.interceptors.request.use((config) => {
  const userId = sessionStorage.getItem('userId')
  if (userId) config.headers['X-User-Id'] = userId
  return config
})