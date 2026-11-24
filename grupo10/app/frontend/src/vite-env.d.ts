/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=bd | full (RNF02)
 */
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_MODE: 'full' | 'bd'
}
interface ImportMeta {
  readonly env: ImportMetaEnv
}