import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    //No Windows, o .pathname pode gerar um caminho com /C:/.... 
    // Se o alias @ falhar, use fileURLToPath(new URL('./src', import.meta.url)), importando fileURLToPath de node:url.
    alias: { '@': new URL('./src', import.meta.url).pathname },
  },
  server: {
    port: 5173,
    // em desenvolvimento, as chamadas /api vão para o Spring Boot
    proxy: { '/api': 'http://localhost:8080' },
  },
  build: { outDir: '../backend/src/main/resources/static', emptyOutDir: true },
})