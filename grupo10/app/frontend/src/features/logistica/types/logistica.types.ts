/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import type { z } from 'zod'
import type { paginaSchema, painelLogisticaSchema } from '../schemas/logistica.schemas'

export type PainelLogistica = z.infer<typeof painelLogisticaSchema>
export type Pagina<T> = z.infer<ReturnType<typeof paginaSchema<T>>>
export type EntregaDisponivel = PainelLogistica['disponiveis']['itens'][number]
export type RotaResumo = PainelLogistica['encerradas']['itens'][number]
export type RotaAtual = NonNullable<PainelLogistica['rotaAtual']>
export type EntregaDaRota = RotaAtual['entregas'][number]
export type StatusEntrega = EntregaDaRota['status']
export type NovoStatusEntrega = Exclude<StatusEntrega, 'aceita'>

export interface PaginasPainel {
  paginaDisponiveis: number
  paginaEncerradas: number
}
