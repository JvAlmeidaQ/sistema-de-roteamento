/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Catálogo
 */
import axios from 'axios'
import { api } from '@/lib/api'
import type {
  AtualizarLojaRequest,
  CategoriaResponse,
  CriarCategoriaRequest,
  CriarProdutoRequest,
  LojaResponse,
  ProdutoCatalogoResponse,
  StatusFuncionamento,
  AtualizarProdutoRequest,
} from '../types/catalogo.types'

interface ApiErrorPayload {
  status?: number
  error?: string
  message?: string
  sqlState?: string | null
  details?: string[]
}

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

export const catalogoApi = {
  obterMinhaLoja: async () =>
    (await api.get<LojaResponse>('/catalogo/lojas/minha-loja')).data,

  buscarLojaPorId: async (idLoja: number) =>
    (await api.get<LojaResponse>(`/catalogo/lojas/${idLoja}`)).data,

  atualizarStatusLoja: async (idLoja: number, statusFuncionamento: StatusFuncionamento) =>
    (
      await api.patch<LojaResponse>(`/catalogo/lojas/${idLoja}/status`, {
        statusFuncionamento,
      })
    ).data,

  atualizarDadosLoja: async (idLoja: number, payload: AtualizarLojaRequest) =>
    (await api.put<LojaResponse>(`/catalogo/lojas/${idLoja}`, payload)).data,

  listarCategorias: async (idLoja: number) =>
    (await api.get<CategoriaResponse[]>(`/catalogo/lojas/${idLoja}/categorias`)).data,

  criarCategoria: async (idLoja: number, payload: CriarCategoriaRequest) =>
    (await api.post<CategoriaResponse>(`/catalogo/lojas/${idLoja}/categorias`, payload)).data,

  excluirCategoria: async (idLoja: number, idCategoria: number) => {
    await api.delete(`/catalogo/lojas/${idLoja}/categorias/${idCategoria}`)
  },

  listarProdutos: async (
    idLoja: number,
    params?: { idCategoria?: number; ativo?: boolean }
  ) =>
    (
      await api.get<ProdutoCatalogoResponse[]>(`/catalogo/lojas/${idLoja}/produtos`, {
        params,
      })
    ).data,

  buscarProdutoPorId: async (idLoja: number, idProduto: number) =>
    (await api.get<ProdutoCatalogoResponse>(`/catalogo/lojas/${idLoja}/produtos/${idProduto}`)).data,

  criarProduto: async (idLoja: number, payload: CriarProdutoRequest) =>
    (await api.post<ProdutoCatalogoResponse>(`/catalogo/lojas/${idLoja}/produtos`, payload)).data,

  atualizarProduto: async (
    idLoja: number,
    idProduto: number,
    payload: AtualizarProdutoRequest
  ) =>
    (
      await api.put<ProdutoCatalogoResponse>(
        `/catalogo/lojas/${idLoja}/produtos/${idProduto}`,
        payload
      )
    ).data,

  atualizarAtivoProduto: async (idLoja: number, idProduto: number, ativo: boolean) =>
    (
      await api.patch<ProdutoCatalogoResponse>(
        `/catalogo/lojas/${idLoja}/produtos/${idProduto}/ativo`,
        { ativo }
      )
    ).data,
}
