/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01
 */
import axios from 'axios'
import { api } from '@/lib/api'
import type { Perfil, PerfilRequest, PessoaResumo } from '../types/identidade.types'

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

/** Converte o erro do Axios no contrato de erro da API (GlobalExceptionHandler). */
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

export const identidadeApi = {
  listarPessoas: async (busca: string) =>
    (await api.get<PessoaResumo[]>('/identidade/pessoas', { params: busca ? { busca } : undefined })).data,

  buscarPerfil: async (idPessoa: number) =>
    (await api.get<Perfil>(`/identidade/pessoas/${idPessoa}`)).data,

  criarPerfil: async (payload: PerfilRequest) =>
    (await api.post<Perfil>('/identidade/pessoas', payload)).data,

  atualizarPerfil: async (idPessoa: number, payload: PerfilRequest) =>
    (await api.put<Perfil>(`/identidade/pessoas/${idPessoa}`, payload)).data,
}
