/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística (RF05)
 */
import { isAxiosError } from 'axios'
import { useEffect, useState } from 'react'
import { ZodError } from 'zod'
import { buscarRastreioPedido } from '../api/rastreio.api'
import type { RastreioPedidoResponse } from '../types/rastreio.types'

export const MENSAGEM_ID_INVALIDO = 'Identificador do pedido inválido. Confira o link de rastreio.'

type EstadoRastreio =
  | { tipo: 'carregando' }
  | { tipo: 'sucesso'; dados: RastreioPedidoResponse }
  | { tipo: 'erro'; mensagem: string }

function mensagemErro(erro: unknown) {
  if (erro instanceof ZodError) {
    return 'O servidor retornou dados inválidos para o rastreio. Tente novamente em Atualizar rastreio.'
  }

  switch (isAxiosError(erro) ? erro.response?.status : undefined) {
    case 400:
      return MENSAGEM_ID_INVALIDO
    case 403:
      return 'A conta selecionada não tem permissão para consultar este rastreio. Confira a conta no menu de sessão.'
    case 404:
      return 'Pedido não encontrado. Confira o link de rastreio.'
    default:
      return 'Não foi possível carregar o rastreio. Tente novamente em Atualizar rastreio.'
  }
}

export function useRastreioPedido(idPedido: number) {
  const [estado, setEstado] = useState<EstadoRastreio>({ tipo: 'carregando' })
  const [revisao, setRevisao] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    const { signal } = controller

    async function carregar() {
      try {
        const dados = await buscarRastreioPedido(idPedido, signal)
        if (signal.aborted) return
        if (dados?.idPedido !== idPedido) throw new Error('Resposta de rastreio não corresponde ao pedido.')
        setEstado({ tipo: 'sucesso', dados })
      } catch (erro) {
        if (!signal.aborted) setEstado({ tipo: 'erro', mensagem: mensagemErro(erro) })
      }
    }

    void carregar()
    return () => controller.abort()
  }, [idPedido, revisao])

  function atualizar() {
    setEstado({ tipo: 'carregando' })
    setRevisao((atual) => atual + 1)
  }

  return { estado, atualizar }
}
