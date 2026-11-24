/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Contexto global de sessão autenticada e papel ativo do usuário.
 */
import { isAxiosError } from 'axios'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { ZodError } from 'zod'
import { checkoutApi } from '@/features/comercio/api/comercio.api'
import type { UsuarioSessao } from '@/features/comercio/types/comercio.types'
import { autenticacaoApi } from '@/features/identidade/api/identidade.api'

export type PapelAtivo = 'cliente' | 'entregador' | 'lojista' | 'admin'

export function papeisDoUsuario(usuario: UsuarioSessao | null): PapelAtivo[] {
  if (!usuario) return []
  const lista: PapelAtivo[] = []
  if (usuario.perfilCliente) lista.push('cliente')
  if (usuario.perfilEntregador) lista.push('entregador')
  if (usuario.perfilLojista) lista.push('lojista')
  if (usuario.administrador) lista.push('admin')
  return lista
}

export function rotaInicialPorPapel(papel: PapelAtivo | null): string {
  switch (papel) {
    case 'entregador':
      return '/painel-entregador'
    case 'lojista':
      return '/catalogo'
    case 'admin':
      return '/relatorios'
    case 'cliente':
    default:
      return '/'
  }
}

export const ROTULO_PAPEL: Record<PapelAtivo, string> = {
  cliente: 'Cliente',
  entregador: 'Entregador',
  lojista: 'Lojista',
  admin: 'Administrador',
}

interface SessaoUsuarioContextValue {
  usuarios: UsuarioSessao[]
  usuarioAtual: UsuarioSessao | null
  papelAtivo: PapelAtivo | null
  papeisDisponiveis: PapelAtivo[]
  selecionarPapel: (papel: PapelAtivo) => void
  entrar: (identificador: string) => Promise<UsuarioSessao>
  entrarComSessao: (sessao: UsuarioSessao) => void
  sair: () => void
  recarregarSessao: () => Promise<void>
  carregandoUsuarios: boolean
  errosUsuarios: string[]
}

const SessaoUsuarioContext = createContext<SessaoUsuarioContextValue | null>(null)

function mensagemErroLista(erro: unknown) {
  const prefixo = 'Não foi possível carregar as contas cadastradas.'
  const mensagemDominio = isAxiosError<{ message?: unknown }>(erro)
    ? erro.response?.data?.message
    : undefined

  if (typeof mensagemDominio === 'string' && mensagemDominio.trim()) return `${prefixo} ${mensagemDominio}`
  if (erro instanceof ZodError) return `${prefixo} Recarregue a página.`
  return `${prefixo} Recarregue a página para tentar novamente.`
}

function resolverPapelInicial(usuario: UsuarioSessao): PapelAtivo | null {
  const disponiveis = papeisDoUsuario(usuario)
  if (disponiveis.length === 0) return null
  const salvo = sessionStorage.getItem('activeRole') as PapelAtivo | null
  if (salvo && disponiveis.includes(salvo)) return salvo
  return disponiveis[0]
}

export function SessaoUsuarioProvider({ children }: { children: ReactNode }) {
  const [usuarios, setUsuarios] = useState<UsuarioSessao[]>([])
  const [usuarioAtual, setUsuarioAtual] = useState<UsuarioSessao | null>(null)
  const [papelAtivo, setPapelAtivo] = useState<PapelAtivo | null>(null)
  const [carregandoUsuarios, setCarregandoUsuarios] = useState(true)
  const [errosUsuarios, setErrosUsuarios] = useState<string[]>([])

  const aplicarSessao = useCallback((sessao: UsuarioSessao) => {
    sessionStorage.setItem('userId', String(sessao.idPessoa))
    const papel = resolverPapelInicial(sessao)
    if (papel) {
      sessionStorage.setItem('activeRole', papel)
    } else {
      sessionStorage.removeItem('activeRole')
    }
    setUsuarioAtual(sessao)
    setPapelAtivo(papel)
  }, [])

  useEffect(() => {
    let ativo = true
    const salvoId = sessionStorage.getItem('userId')

    void Promise.allSettled([
      checkoutApi.listarUsuariosSessao(),
      salvoId ? autenticacaoApi.obterSessao() : Promise.resolve(null),
    ]).then(([listaResp, sessaoResp]) => {
      if (!ativo) return
      const erros: string[] = []
      let lista: UsuarioSessao[] = []

      if (listaResp.status === 'rejected') {
        erros.push(mensagemErroLista(listaResp.reason))
      } else if (Array.isArray(listaResp.value)) {
        lista = listaResp.value
      }

      if (sessaoResp.status === 'fulfilled' && sessaoResp.value) {
        aplicarSessao(sessaoResp.value)
      } else if (salvoId) {
        const encontrado = lista.find((u) => String(u.idPessoa) === salvoId)
        if (encontrado) {
          aplicarSessao(encontrado)
        } else {
          sessionStorage.removeItem('userId')
          sessionStorage.removeItem('activeRole')
        }
      }

      setUsuarios(lista)
      setErrosUsuarios(erros)
      setCarregandoUsuarios(false)
    })

    return () => {
      ativo = false
    }
  }, [aplicarSessao])

  const papeisDisponiveis = useMemo(() => papeisDoUsuario(usuarioAtual), [usuarioAtual])

  const selecionarPapel = useCallback(
    (papel: PapelAtivo) => {
      if (!usuarioAtual || !papeisDoUsuario(usuarioAtual).includes(papel)) return
      sessionStorage.setItem('activeRole', papel)
      setPapelAtivo(papel)
    },
    [usuarioAtual],
  )

  const entrar = useCallback(
    async (identificador: string) => {
      const sessao = await autenticacaoApi.entrar(identificador)
      aplicarSessao(sessao)
      return sessao
    },
    [aplicarSessao],
  )

  const entrarComSessao = useCallback(
    (sessao: UsuarioSessao) => {
      aplicarSessao(sessao)
    },
    [aplicarSessao],
  )

  const sair = useCallback(() => {
    sessionStorage.removeItem('userId')
    sessionStorage.removeItem('activeRole')
    setUsuarioAtual(null)
    setPapelAtivo(null)
  }, [])

  const recarregarSessao = useCallback(async () => {
    const salvoId = sessionStorage.getItem('userId')
    if (!salvoId) return
    const sessao = await autenticacaoApi.obterSessao()
    aplicarSessao(sessao)
  }, [aplicarSessao])

  return (
    <SessaoUsuarioContext.Provider
      value={{
        usuarios,
        usuarioAtual,
        papelAtivo,
        papeisDisponiveis,
        selecionarPapel,
        entrar,
        entrarComSessao,
        sair,
        recarregarSessao,
        carregandoUsuarios,
        errosUsuarios,
      }}
    >
      {children}
    </SessaoUsuarioContext.Provider>
  )
}

export function useSessaoUsuario() {
  const ctx = useContext(SessaoUsuarioContext)
  if (!ctx) throw new Error('useSessaoUsuario deve ser usado dentro de SessaoUsuarioProvider.')
  return ctx
}
