/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — API somente leitura (RF05, RF10, RN08, RR11)
 */
import axios from 'axios'
import { api } from '@/lib/api'
import type {
  FiltroSlaEntregas,
  HistoricoEntregaEvento,
  HistoricoPedidoEvento,
  LinhaTempoEvento,
  SlaEntregaItem,
} from '../types/auditoria.types'

interface ApiErrorPayload {
  status?: number
  message?: string
  details?: string[]
}

export interface ErroApi {
  status: number | null
  mensagem: string
  detalhes: string[]
}

export function lerErroApi(erro: unknown): ErroApi {
  if (axios.isAxiosError(erro)) {
    const data = erro.response?.data as ApiErrorPayload | undefined
    return {
      status: data?.status ?? erro.response?.status ?? null,
      mensagem: data?.message ?? 'Não foi possível comunicar com o servidor. Verifique se o backend está rodando.',
      detalhes: data?.details ?? [],
    }
  }
  return { status: null, mensagem: 'Erro inesperado. Tente novamente.', detalhes: [] }
}

export const auditoriaApi = {
  buscarHistoricoPedido: async (idPedido: number) =>
    (await api.get<HistoricoPedidoEvento[]>(`/auditoria/pedidos/${idPedido}/historico`)).data,

  buscarHistoricoEntrega: async (idEntrega: number) =>
    (await api.get<HistoricoEntregaEvento[]>(`/auditoria/entregas/${idEntrega}/historico`)).data,

  buscarLinhaTempoPedido: async (idPedido: number) =>
    (await api.get<LinhaTempoEvento[]>(`/auditoria/pedidos/${idPedido}/linha-tempo`)).data,

  consultarSlaEntregas: async (filtros: FiltroSlaEntregas) => {
    const params: Record<string, string | number | boolean> = {}
    if (filtros.idLoja) params.idLoja = filtros.idLoja
    if (filtros.apenasAtrasadas) params.apenasAtrasadas = true
    if (filtros.inicio) params.inicio = filtros.inicio
    if (filtros.fim) params.fim = filtros.fim

    return (await api.get<SlaEntregaItem[]>('/auditoria/sla/entregas', { params })).data
  },
}