/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=bd | full (entregadores apenas em full)
 * Subdomínios: Comércio e Finanças, Logística
 */
import { isAxiosError } from 'axios'
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { ZodError } from 'zod'
import { checkoutApi } from '@/features/comercio/api/comercio.api'
import type { UsuarioSessao } from '@/features/comercio/types/comercio.types'

const isBd = import.meta.env.VITE_APP_MODE === 'bd'

interface SessaoUsuarioContextValue {
  usuarios: UsuarioSessao[]
  usuarioAtual: UsuarioSessao | null
  selecionarUsuario: (idPessoa: number) => void
  carregandoUsuarios: boolean
  errosUsuarios: string[]
}

const SessaoUsuarioContext = createContext<SessaoUsuarioContextValue | null>(null)

function mensagemErroLista(lista: string, erro: unknown) {
  const prefixo = `Não foi possível carregar ${lista}.`
  const mensagemDominio = isAxiosError<{ message?: unknown }>(erro)
    ? erro.response?.data?.message
    : undefined

  if (typeof mensagemDominio === 'string' && mensagemDominio.trim()) return `${prefixo} ${mensagemDominio}`
  if (erro instanceof ZodError) return `${prefixo} A resposta está fora do formato esperado. Recarregue a página.`
  return `${prefixo} Recarregue a página para tentar novamente.`
}

export function SessaoUsuarioProvider({ children }: { children: ReactNode }) {
  const [usuarios, setUsuarios] = useState<UsuarioSessao[]>([])
  const [usuarioAtual, setUsuarioAtual] = useState<UsuarioSessao | null>(null)
  const [carregandoUsuarios, setCarregandoUsuarios] = useState(true)
  const [errosUsuarios, setErrosUsuarios] = useState<string[]>([])

  useEffect(() => {
    let ativo = true
    void Promise.allSettled([
      checkoutApi.listarUsuariosSessao(),
      !isBd
        ? import('@/features/logistica/api/sessaoEntregadores.api')
            .then(({ listarEntregadoresSessao }) => listarEntregadoresSessao())
        : [],
    ]).then(([comercio, entregadores]) => {
      if (!ativo) return

      let lista: UsuarioSessao[] = []
      const erros: string[] = []
      if (comercio.status === 'rejected') {
        erros.push(mensagemErroLista('as contas de Comércio', comercio.reason))
      } else if (!Array.isArray(comercio.value) || comercio.value.some(
        (conta) => !conta || !Number.isSafeInteger(conta.idPessoa) || typeof conta.nome !== 'string',
      )) {
        erros.push('A resposta com as contas de Comércio está fora do formato esperado. Recarregue a página.')
      } else {
        lista = comercio.value
      }

      if (!isBd) {
        const porPessoa = new Map<number, UsuarioSessao>()
        for (const conta of lista) {
          // A seleção anterior considerava o primeiro registro para cada pessoa.
          if (!porPessoa.has(conta.idPessoa)) porPessoa.set(conta.idPessoa, conta)
        }
        if (entregadores.status === 'fulfilled') {
          for (const { idPessoa, nome } of entregadores.value) {
            const conta = porPessoa.get(idPessoa) ?? {
              idPessoa, nome, perfilCliente: false, perfilLojista: false, idLoja: null, nomeLoja: null,
            }
            porPessoa.set(idPessoa, { ...conta, perfilEntregador: true })
          }
        } else {
          erros.push(mensagemErroLista('a lista de entregadores', entregadores.reason))
        }
        lista = [...porPessoa.values()]
      }

      if (lista.length > 0) {
        const salvo = sessionStorage.getItem('userId')
        const encontrado = salvo ? lista.find((u) => String(u.idPessoa) === salvo) : undefined
        const inicial = encontrado ?? lista.find((u) => u.perfilCliente) ?? lista[0]
        sessionStorage.setItem('userId', String(inicial.idPessoa))
        setUsuarioAtual(inicial)
      }
      setUsuarios(lista)
      setErrosUsuarios(erros)
      setCarregandoUsuarios(false)
    })
    return () => {
      ativo = false
    }
  }, [])

  const selecionarUsuario = (idPessoa: number) => {
    const encontrado = usuarios.find((u) => u.idPessoa === idPessoa) ?? null
    if (encontrado) {
      sessionStorage.setItem('userId', String(encontrado.idPessoa))
      setUsuarioAtual(encontrado)
    }
  }

  return (
    <SessaoUsuarioContext.Provider
      value={{ usuarios, usuarioAtual, selecionarUsuario, carregandoUsuarios, errosUsuarios }}
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
