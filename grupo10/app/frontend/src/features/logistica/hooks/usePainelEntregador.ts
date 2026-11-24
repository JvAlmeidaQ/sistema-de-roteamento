/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import axios from 'axios'
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { ZodError } from 'zod'
import { extrairMensagemErro } from '@/features/comercio/api/comercio.api'
import { formatarIdPedido } from '@/features/comercio/components/StatusBadge'
import { logisticaApi } from '../api/logistica.api'
import type { NovoStatusEntrega, PaginasPainel, PainelLogistica } from '../types/logistica.types'

export interface AcaoEntrega {
  idEntrega: number
  idPedido: number
  tipo: 'assumir' | NovoStatusEntrega
}

const PAGINAS_INICIAIS: PaginasPainel = { paginaDisponiveis: 1, paginaEncerradas: 1 }
const ACAO_CONFIRMADA: Record<AcaoEntrega['tipo'], string> = {
  assumir: 'Entrega assumida',
  a_caminho: 'Retirada registrada',
  entregue: 'Entrega finalizada',
}

function statusHttp(erro: unknown) {
  return axios.isAxiosError(erro) ? erro.response?.status : undefined
}

export function usePainelEntregador() {
  const [painel, setPainel] = useState<PainelLogistica | null>(null)
  const [paginas, setPaginas] = useState(PAGINAS_INICIAIS)
  const [operacao, setOperacao] = useState<'carregar' | AcaoEntrega | null>('carregar')
  const [erro, setErro] = useState<string | null>(null)
  const [feedback, setFeedback] = useState<{ tipo: 'sucesso' | 'erro'; mensagem: string } | null>(null)
  const requisicao = useRef<AbortController | null>(null)

  const executar = useCallback(async (params: PaginasPainel, acao?: AcaoEntrega) => {
    if (requisicao.current) return
    const controller = new AbortController()
    const { signal } = controller
    requisicao.current = controller
    setOperacao(acao ?? 'carregar')
    setErro(null)
    setFeedback(null)

    let consulta = params
    try {
      if (acao) {
        try {
          if (acao.tipo === 'assumir') {
            await logisticaApi.assumir(acao.idEntrega, signal)
          } else {
            await logisticaApi.atualizarStatus(acao.idEntrega, acao.tipo, signal)
          }
          if (signal.aborted) return
          setFeedback({
            tipo: 'sucesso',
            mensagem: `${ACAO_CONFIRMADA[acao.tipo]} para o pedido ${formatarIdPedido(acao.idPedido)}.`,
          })
        } catch (e) {
          if (signal.aborted) return
          const status = statusHttp(e)
          if (status === 403) throw e
          const mudou = status === 404 || status === 409
          setFeedback({
            tipo: 'erro',
            mensagem: `${mudou ? 'A entrega ou a rota pode ter mudado. ' : ''}Não foi possível confirmar a ação. ${extrairMensagemErro(e)}`,
          })
        }
        // Mesmo após conflito ou falha de rede, o servidor pode ter um estado diferente do exibido.
        setOperacao('carregar')
      }

      let dados = await logisticaApi.buscarPainel(consulta, signal)
      if (signal.aborted) return
      const filaVazia = dados.disponiveis.pagina > 1 && dados.disponiveis.itens.length === 0
      const historicoVazio = dados.encerradas.pagina > 1 && dados.encerradas.itens.length === 0
      if (filaVazia || historicoVazio) {
        // Uma página pode sumir se as entregas forem assumidas enquanto o painel está aberto.
        consulta = {
          paginaDisponiveis: filaVazia ? 1 : dados.disponiveis.pagina,
          paginaEncerradas: historicoVazio ? 1 : dados.encerradas.pagina,
        }
        dados = await logisticaApi.buscarPainel(consulta, signal)
        if (signal.aborted) return
      }

      setPainel(dados)
      setPaginas({
        paginaDisponiveis: dados.disponiveis.pagina,
        paginaEncerradas: dados.encerradas.pagina,
      })
    } catch (e) {
      if (signal.aborted) return
      setPainel(null)
      setPaginas(consulta)
      if (statusHttp(e) === 403) {
        setErro('Você não tem permissão para acessar o painel de entregas.')
      } else if (e instanceof ZodError) {
        setErro('O servidor retornou dados inválidos para o painel. Tente novamente em Atualizar painel.')
      } else {
        setErro(`Não foi possível carregar o painel. Tente atualizar. ${extrairMensagemErro(e)}`)
      }
    } finally {
      if (!signal.aborted) {
        requisicao.current = null
        setOperacao(null)
      }
    }
  }, [])

  // O painel é remontado por conta. Cancela também a leitura pós-ação ao sair dessa sessão.
  useLayoutEffect(() => () => {
    requisicao.current?.abort()
    requisicao.current = null
  }, [])

  useEffect(() => {
    void executar(PAGINAS_INICIAIS)
  }, [executar])

  return {
    painel,
    ocupado: operacao !== null,
    acaoPendente: operacao === 'carregar' ? null : operacao,
    erro,
    feedback,
    atualizar: () => executar(paginas),
    paginar: (lista: keyof PaginasPainel, pagina: number) => executar({ ...paginas, [lista]: pagina }),
    executarAcao: (acao: AcaoEntrega) => executar(paginas, acao),
  }
}
