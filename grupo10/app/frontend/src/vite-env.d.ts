/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_MODE: 'full' | 'bd'
}
interface ImportMeta {
  readonly env: ImportMetaEnv
}