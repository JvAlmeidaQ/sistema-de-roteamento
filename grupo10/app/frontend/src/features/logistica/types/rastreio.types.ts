/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística (RF05)
 */
import type { z } from 'zod'
import type { rastreioPedidoSchema } from '../schemas/logistica.schemas'

export type RastreioPedidoResponse = z.infer<typeof rastreioPedidoSchema>
export type EventoRastreio = RastreioPedidoResponse['eventos'][number]
export type StatusEntregaRastreio = NonNullable<RastreioPedidoResponse['entrega']>['status']
