/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Comércio e Finanças
 */
import { useCallback, useEffect, useState } from 'react'
import type { PapelAtivo } from '@/context/SessaoUsuarioContext'
import { formatarCodigoPedido, formatarStatusPedido } from '@/lib/apresentacao'
import { extrairMensagemErro, pedidosApi } from '../api/comercio.api'
import type { AvaliacaoFormValues } from '../schemas/comercio.schemas'
import type { PedidoResponse, UsuarioSessao } from '../types/comercio.types'

export function useGestaoPedidos(
  usuarioAtual: UsuarioSessao | null,
  papelAtivo: PapelAtivo | null,
) {
  const [pedidos, setPedidos] = useState<PedidoResponse[]>([])
  const [pedidoSelecionado, setPedidoSelecionado] = useState<PedidoResponse | null>(null)
  const [statusFiltro, setStatusFiltro] = useState('')
  const [carregando, setCarregando] = useState(false)
  const [erro, setErro] = useState<string | null>(null)
  const [sucesso, setSucesso] = useState<string | null>(null)

  const carregarPedidos = useCallback(async () => {
    if (!usuarioAtual) return
    setCarregando(true)
    setErro(null)
    try {
      const params: { idLoja?: number; idCliente?: number; status?: string; limit: number } = {
        limit: 25,
      }
      if (papelAtivo === 'lojista' && usuarioAtual.idLoja) {
        params.idLoja = usuarioAtual.idLoja
      } else if (papelAtivo === 'cliente') {
        params.idCliente = usuarioAtual.idPessoa
      }
      if (statusFiltro) params.status = statusFiltro

      const lista = await pedidosApi.listar(params)
      setPedidos(lista)
      setPedidoSelecionado((anterior) =>
        anterior ? (lista.find((p) => p.idPedido === anterior.idPedido) ?? null) : null,
      )
    } catch (e) {
      setErro(extrairMensagemErro(e))
    } finally {
      setCarregando(false)
    }
  }, [usuarioAtual, papelAtivo, statusFiltro])

  useEffect(() => {
    carregarPedidos()
  }, [carregarPedidos])

  const executarTransicao = async (idPedido: number, novoStatus: string) => {
    setErro(null)
    setSucesso(null)
    try {
      const atualizado = await pedidosApi.atualizarStatus(idPedido, novoStatus)
      setPedidoSelecionado(atualizado)
      setPedidos((prev) => prev.map((p) => (p.idPedido === idPedido ? atualizado : p)))
      setSucesso(
        novoStatus === 'pronto'
          ? `${formatarCodigoPedido(idPedido)} marcado como pronto para entrega.`
          : `Status de ${formatarCodigoPedido(idPedido)} atualizado para ${formatarStatusPedido(novoStatus).toLowerCase()}.`,
      )
    } catch (e) {
      setErro(extrairMensagemErro(e))
    }
  }

  const registrarSplit = async (idPedido: number) => {
    setErro(null)
    setSucesso(null)
    try {
      const split = await pedidosApi.calcularDivisaoPagamento(idPedido)
      setSucesso(
        `Divisão financeira registrada: Loja R$ ${split.parcelaLoja.toFixed(2)}, Entregador R$ ${split.comissaoEntregador.toFixed(2)}, Plataforma R$ ${split.taxaPlataforma.toFixed(2)}.`,
      )
      const atualizado = await pedidosApi.buscarPorId(idPedido)
      setPedidoSelecionado(atualizado)
      setPedidos((prev) => prev.map((p) => (p.idPedido === idPedido ? atualizado : p)))
    } catch (e) {
      setErro(extrairMensagemErro(e))
    }
  }

  const enviarAvaliacao = async (
    alvo: 'loja' | 'entregador',
    idPedido: number,
    payload: AvaliacaoFormValues,
  ) => {
    setErro(null)
    setSucesso(null)
    try {
      if (alvo === 'loja') {
        await pedidosApi.avaliarLoja(idPedido, payload)
      } else {
        await pedidosApi.avaliarEntregador(idPedido, payload)
      }
      setSucesso(
        alvo === 'loja'
          ? 'Avaliação da loja enviada com sucesso.'
          : 'Avaliação do entregador enviada com sucesso.',
      )
      const atualizado = await pedidosApi.buscarPorId(idPedido)
      setPedidoSelecionado(atualizado)
      setPedidos((prev) => prev.map((p) => (p.idPedido === idPedido ? atualizado : p)))
    } catch (e) {
      setErro(extrairMensagemErro(e))
    }
  }

  return {
    pedidos,
    pedidoSelecionado,
    setPedidoSelecionado,
    statusFiltro,
    setStatusFiltro,
    carregando,
    erro,
    sucesso,
    carregarPedidos,
    executarTransicao,
    registrarSplit,
    enviarAvaliacao,
  }
}
