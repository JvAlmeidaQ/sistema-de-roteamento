/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import type { StatusEntregaRastreio } from '../types/rastreio.types'

export const statusEntregaInfo: Record<StatusEntregaRastreio, { rotulo: string; classes: string }> = {
  aguardando_entregador: { rotulo: 'Aguardando entregador', classes: 'bg-state-pending/15 text-brand-pit' },
  aceita: { rotulo: 'Aceita · Aguardando retirada', classes: 'bg-state-pending/15 text-brand-pit' },
  a_caminho: { rotulo: 'A caminho', classes: 'bg-state-progress/15 text-brand-dark' },
  entregue: { rotulo: 'Entregue', classes: 'bg-state-success/15 text-brand-dark' },
}

export const linkRastreioClass = 'inline-flex min-h-11 items-center rounded-sm text-sm font-semibold text-brand-dark underline underline-offset-4 hover:text-brand-outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-outline'

export const secaoPainelClass = 'min-w-0 space-y-4 rounded-2xl border border-surface-bg bg-surface p-4 sm:p-6'

const botaoClasseBase =
  'inline-flex min-h-11 items-center justify-center rounded-full px-4 py-2 text-sm font-semibold leading-tight text-brand-dark focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-outline motion-safe:transition-colors disabled:cursor-not-allowed disabled:opacity-60'

export const botaoPrimarioClass = `${botaoClasseBase} bg-brand-lime enabled:hover:bg-brand-lime/75 enabled:active:bg-brand-pulp/60`
export const botaoSecundarioClass = `${botaoClasseBase} border border-brand-dark bg-surface enabled:hover:bg-surface-bg/50 enabled:active:bg-surface-bg`
