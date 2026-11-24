/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { useEffect, useState } from 'react'
import type { PapelAtivo } from '@/context/SessaoUsuarioContext'
import { checkoutApi, extrairMensagemErro, financeiroApi } from '../api/comercio.api'
import type {
  ConsultaEstrategicaResponse,
  LojaCheckout,
  RelatorioPedidosLoja,
  ResumoFinanceiroLoja,
  UsuarioSessao,
} from '../types/comercio.types'

export function useRelatoriosFinanceiros(
  usuarioAtual: UsuarioSessao | null,
  papelAtivo: PapelAtivo | null,
) {
  const [resumoLojas, setResumoLojas] = useState<ResumoFinanceiroLoja[]>([])
  const [lojas, setLojas] = useState<LojaCheckout[]>([])
  const [relatorio, setRelatorio] = useState<RelatorioPedidosLoja | null>(null)
  const [consultaAtiva, setConsultaAtiva] = useState<ConsultaEstrategicaResponse | null>(null)
  const [carregando, setCarregando] = useState(false)
  const [erro, setErro] = useState<string | null>(null)

  useEffect(() => {
    if (!usuarioAtual || !papelAtivo) return
    let ativo = true
    setCarregando(true)
    setErro(null)
    setRelatorio(null)
    setConsultaAtiva(null)

    const idLojaEscopo = papelAtivo === 'lojista' ? usuarioAtual.idLoja ?? undefined : undefined

    Promise.all([
      financeiroApi.resumoLojas(idLojaEscopo),
      papelAtivo === 'admin' ? checkoutApi.listarLojasCheckout() : Promise.resolve([]),
    ])
      .then(([resumo, listaLojas]) => {
        if (!ativo) return
        setResumoLojas(resumo)
        setLojas(listaLojas)
      })
      .catch((e) => {
        if (ativo) setErro(extrairMensagemErro(e))
      })
      .finally(() => {
        if (ativo) setCarregando(false)
      })

    return () => {
      ativo = false
    }
  }, [usuarioAtual, papelAtivo])

  const buscarRelatorioParametrizado = async (
    idLoja: number,
    filtros: { status?: string; dataInicio?: string; dataFim?: string },
  ) => {
    setErro(null)
    setCarregando(true)
    try {
      const data = await financeiroApi.relatorioLoja(idLoja, {
        status: filtros.status || undefined,
        dataInicio: filtros.dataInicio ? `${filtros.dataInicio}T00:00:00Z` : undefined,
        dataFim: filtros.dataFim ? `${filtros.dataFim}T23:59:59Z` : undefined,
        limit: 25,
      })
      setRelatorio(data)
    } catch (e) {
      setErro(extrairMensagemErro(e))
    } finally {
      setCarregando(false)
    }
  }

  const carregarConsulta = async (numero: number) => {
    setErro(null)
    setCarregando(true)
    try {
      const resp = await financeiroApi.consultaEstrategica(numero)
      setConsultaAtiva(resp)
    } catch (e) {
      setErro(extrairMensagemErro(e))
    } finally {
      setCarregando(false)
    }
  }

  return {
    resumoLojas,
    lojas,
    relatorio,
    consultaAtiva,
    carregando,
    erro,
    buscarRelatorioParametrizado,
    carregarConsulta,
  }
}
