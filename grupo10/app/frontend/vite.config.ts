/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=bd | full (RNF02)
 */
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': decodeURIComponent(new URL('./src', import.meta.url).pathname) },
  },
  server: {
    port: 5173,
    // em desenvolvimento, as chamadas /api vão para o Spring Boot
    proxy: { '/api': 'http://localhost:8080' },
  },
  build: { outDir: '../backend/src/main/resources/static', emptyOutDir: true },
})