/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01
 */
import axios from 'axios'
import { api } from '@/lib/api'
import type { UsuarioSessao } from '@/features/comercio/types/comercio.types'
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

export interface DisponibilidadeCadastro {
  emailDisponivel: boolean
  cpfDisponivel: boolean
}

/** Converte o erro do Axios no contrato de erro da API. */
export function lerErroApi(erro: unknown): ErroApi {
  if (axios.isAxiosError(erro)) {
    const data = erro.response?.data as ApiErrorPayload | undefined
    return {
      status: data?.status ?? erro.response?.status ?? null,
      mensagem: data?.message ?? 'Não foi possível comunicar com o servidor. Tente novamente.',
      detalhes: data?.details ?? [],
    }
  }
  return { status: null, mensagem: 'Erro inesperado. Tente novamente.', detalhes: [] }
}

export const autenticacaoApi = {
  verificarDisponibilidade: async (params: { email?: string; cpf?: string }) =>
    (await api.get<DisponibilidadeCadastro>('/identidade/autenticacao/disponibilidade', { params })).data,

  entrar: async (identificador: string) =>
    (await api.post<UsuarioSessao>('/identidade/autenticacao/entrar', { identificador })).data,

  obterSessao: async () =>
    (await api.get<UsuarioSessao>('/identidade/autenticacao/sessao')).data,
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
