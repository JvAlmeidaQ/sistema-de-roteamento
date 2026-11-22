/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { checkoutApi } from '@/features/comercio/api/comercio.api'
import type { UsuarioSessao } from '@/features/comercio/types/comercio.types'

interface SessaoUsuarioContextValue {
  usuarios: UsuarioSessao[]
  usuarioAtual: UsuarioSessao | null
  selecionarUsuario: (idPessoa: number) => void
  carregandoUsuarios: boolean
}

const SessaoUsuarioContext = createContext<SessaoUsuarioContextValue | null>(null)

export function SessaoUsuarioProvider({ children }: { children: ReactNode }) {
  const [usuarios, setUsuarios] = useState<UsuarioSessao[]>([])
  const [usuarioAtual, setUsuarioAtual] = useState<UsuarioSessao | null>(null)
  const [carregandoUsuarios, setCarregandoUsuarios] = useState(true)

  useEffect(() => {
    let ativo = true
    checkoutApi
      .listarUsuariosSessao()
      .then((lista) => {
        if (!ativo) return
        setUsuarios(lista)
        const salvo = sessionStorage.getItem('userId')
        const encontrado = salvo ? lista.find((u) => String(u.idPessoa) === salvo) : undefined
        const inicial = encontrado ?? lista.find((u) => u.perfilCliente) ?? lista[0] ?? null
        if (inicial) {
          sessionStorage.setItem('userId', String(inicial.idPessoa))
          setUsuarioAtual(inicial)
        }
      })
      .finally(() => {
        if (ativo) setCarregandoUsuarios(false)
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
      value={{ usuarios, usuarioAtual, selecionarUsuario, carregandoUsuarios }}
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
