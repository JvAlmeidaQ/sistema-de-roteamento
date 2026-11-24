/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01
 */
import { useEffect, useState } from 'react'
import { identidadeApi, lerErroApi, type ErroApi } from '../api/identidade.api'
import type { Perfil, PessoaResumo } from '../types/identidade.types'

/** Busca de pessoas com atraso (debounce) para não consultar a cada tecla. */
export function usePessoas(busca: string) {
  const [pessoas, setPessoas] = useState<PessoaResumo[]>([])
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState<ErroApi | null>(null)

  useEffect(() => {
    let ativo = true
    setCarregando(true)
    const timer = window.setTimeout(() => {
      identidadeApi
        .listarPessoas(busca.trim())
        .then((dados) => {
          if (!ativo) return
          setPessoas(dados)
          setErro(null)
        })
        .catch((e: unknown) => ativo && setErro(lerErroApi(e)))
        .finally(() => ativo && setCarregando(false))
    }, 300)
    return () => {
      ativo = false
      window.clearTimeout(timer)
    }
  }, [busca])

  return { pessoas, carregando, erro }
}

/** Carrega o perfil completo de uma pessoa (idPessoa null = nada a carregar). */
export function usePerfil(idPessoa: number | null, idUsuarioSessao?: number | null) {
  const [perfil, setPerfil] = useState<Perfil | null>(null)
  const [carregando, setCarregando] = useState(idPessoa !== null)
  const [erro, setErro] = useState<ErroApi | null>(null)

  useEffect(() => {
    if (idPessoa === null) {
      setPerfil(null)
      setErro(null)
      setCarregando(false)
      return
    }
    let ativo = true
    setCarregando(true)
    setErro(null)
    identidadeApi
      .buscarPerfil(idPessoa)
      .then((dados) => ativo && setPerfil(dados))
      .catch((e: unknown) => {
        if (!ativo) return
        setPerfil(null)
        setErro(lerErroApi(e))
      })
      .finally(() => ativo && setCarregando(false))
    return () => {
      ativo = false
    }
  }, [idPessoa, idUsuarioSessao])

  return { perfil, carregando, erro }
}
