/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import { api } from '@/lib/api'
import { painelLogisticaSchema } from '../schemas/logistica.schemas'
import type { NovoStatusEntrega, PaginasPainel } from '../types/logistica.types'

export const logisticaApi = {
  buscarPainel: async (params: PaginasPainel, signal: AbortSignal) => {
    // A mesma URL pode retornar detalhes de entrega de contas diferentes.
    const { data } = await api.get<unknown>('/logistica/painel', {
      params,
      signal,
      headers: { 'Cache-Control': 'no-cache, no-store' },
    })
    return painelLogisticaSchema.parse(data)
  },

  assumir: async (idEntrega: number, signal: AbortSignal): Promise<void> => {
    await api.post<void>(`/logistica/entregas/${idEntrega}/assumir`, undefined, { signal })
  },

  atualizarStatus: async (
    idEntrega: number,
    novoStatus: NovoStatusEntrega,
    signal: AbortSignal,
  ): Promise<void> => {
    await api.patch<void>(`/logistica/entregas/${idEntrega}/status`, { novoStatus }, { signal })
  },
}
