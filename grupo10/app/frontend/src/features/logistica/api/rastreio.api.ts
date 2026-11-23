/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística (RF05)
 */
import { api } from '@/lib/api'
import { rastreioPedidoSchema } from '../schemas/logistica.schemas'

export async function buscarRastreioPedido(idPedido: number, signal: AbortSignal) {
  const { data } = await api.get<unknown>(`/logistica/pedidos/${idPedido}/rastreio`, {
    signal,
    // A URL é a mesma para contas diferentes e a atualização deve consultar o servidor.
    headers: { 'Cache-Control': 'no-cache, no-store' },
  })
  return rastreioPedidoSchema.parse(data)
}
