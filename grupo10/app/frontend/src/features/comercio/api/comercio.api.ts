/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import axios from 'axios'
import { api } from '@/lib/api'
import type {
  ApiErrorPayload,
  AvaliacaoResponse,
  ConsultaEstrategicaResponse,
  DivisaoPagamentoResponse,
  EnderecoEntregaCliente,
  LojaCheckout,
  PedidoResponse,
  RelatorioPedidosLoja,
  ResumoFinanceiroLoja,
  UsuarioSessao,
} from '../types/comercio.types'
import type { AvaliacaoFormValues, CriarPedidoFormValues } from '../schemas/comercio.schemas'

export function extrairMensagemErro(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as ApiErrorPayload | undefined
    if (data?.message) {
      const details = data.details?.length ? ` (${data.details.join('; ')})` : ''
      return `${data.message}${details}`
    }
    return 'Não foi possível concluir a solicitação. Tente novamente.'
  }
  if (err instanceof Error) return err.message
  return 'Erro inesperado ao comunicar com o servidor.'
}

// Endpoints estritamente de leitura (GET) para popular o fluxo de checkout e sessão
export const checkoutApi = {
  listarUsuariosSessao: async () =>
    (await api.get<UsuarioSessao[]>('/comercio/checkout/usuarios')).data,
  listarLojasCheckout: async () =>
    (await api.get<LojaCheckout[]>('/comercio/checkout/lojas')).data,
  listarEnderecosEntregaCliente: async (idCliente: number) =>
    (await api.get<EnderecoEntregaCliente[]>(`/comercio/checkout/clientes/${idCliente}/enderecos`))
      .data,
}

export const pedidosApi = {
  criar: async (payload: CriarPedidoFormValues) =>
    (await api.post<PedidoResponse>('/pedidos', payload)).data,

  listar: async (params?: {
    idLoja?: number
    idCliente?: number
    status?: string
    limit?: number
  }) => (await api.get<PedidoResponse[]>('/pedidos', { params })).data,

  buscarPorId: async (idPedido: number) =>
    (await api.get<PedidoResponse>(`/pedidos/${idPedido}`)).data,

  atualizarStatus: async (idPedido: number, novoStatus: string) =>
    (await api.patch<PedidoResponse>(`/pedidos/${idPedido}/status`, { novoStatus })).data,

  calcularDivisaoPagamento: async (idPedido: number) =>
    (await api.post<DivisaoPagamentoResponse>(`/pedidos/${idPedido}/divisao-pagamento`)).data,

  avaliarLoja: async (idPedido: number, payload: AvaliacaoFormValues) =>
    (await api.post<AvaliacaoResponse>(`/pedidos/${idPedido}/avaliacoes/loja`, payload)).data,

  avaliarEntregador: async (idPedido: number, payload: AvaliacaoFormValues) =>
    (await api.post<AvaliacaoResponse>(`/pedidos/${idPedido}/avaliacoes/entregador`, payload)).data,
}

export const financeiroApi = {
  resumoLojas: async (idLoja?: number) =>
    (
      await api.get<ResumoFinanceiroLoja[]>('/comercio/lojas/resumo-financeiro', {
        params: idLoja ? { idLoja } : undefined,
      })
    ).data,

  relatorioLoja: async (
    idLoja: number,
    params?: { status?: string; dataInicio?: string; dataFim?: string; limit?: number },
  ) => (await api.get<RelatorioPedidosLoja>(`/comercio/lojas/${idLoja}/relatorio`, { params })).data,

  consultaEstrategica: async (numero: number) =>
    (await api.get<ConsultaEstrategicaResponse>(`/comercio/consultas/${numero}`)).data,
}
