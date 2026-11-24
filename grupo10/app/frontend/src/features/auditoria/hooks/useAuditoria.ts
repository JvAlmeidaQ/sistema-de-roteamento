/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — hooks de consulta de rastreio e SLA (RF05, RF10)
 */
import { useCallback, useEffect, useState } from 'react'
import { auditoriaApi, lerErroApi, type ErroApi } from '../api/auditoria.api'
import type {
  FiltroSlaEntregas,
  HistoricoEntregaEvento,
  HistoricoPedidoEvento,
  LinhaTempoEvento,
  SlaEntregaItem,
} from '../types/auditoria.types'

export function useRastreioPedido(idPedido: number | null) {
  const [linhaTempo, setLinhaTempo] = useState<LinhaTempoEvento[]>([])
  const [historicoComercial, setHistoricoComercial] = useState<HistoricoPedidoEvento[]>([])
  const [carregando, setCarregando] = useState(false)
  const [erro, setErro] = useState<ErroApi | null>(null)

  const recarregar = useCallback(async () => {
    if (!idPedido) {
      setLinhaTempo([])
      setHistoricoComercial([])
      setErro(null)
      return
    }
    setCarregando(true)
    setErro(null)
    try {
      const [unificada, comercial] = await Promise.all([
        auditoriaApi.buscarLinhaTempoPedido(idPedido),
        auditoriaApi.buscarHistoricoPedido(idPedido),
      ])
      setLinhaTempo(unificada)
      setHistoricoComercial(comercial)
    } catch (e) {
      setLinhaTempo([])
      setHistoricoComercial([])
      setErro(lerErroApi(e))
    } finally {
      setCarregando(false)
    }
  }, [idPedido])

  useEffect(() => {
    void recarregar()
  }, [recarregar])

  return { linhaTempo, historicoComercial, carregando, erro, recarregar }
}

export function useHistoricoEntrega(idEntrega: number | null) {
  const [eventos, setEventos] = useState<HistoricoEntregaEvento[]>([])
  const [carregando, setCarregando] = useState(false)
  const [erro, setErro] = useState<ErroApi | null>(null)

  const recarregar = useCallback(async () => {
    if (!idEntrega) {
      setEventos([])
      setErro(null)
      return
    }
    setCarregando(true)
    setErro(null)
    try {
      setEventos(await auditoriaApi.buscarHistoricoEntrega(idEntrega))
    } catch (e) {
      setEventos([])
      setErro(lerErroApi(e))
    } finally {
      setCarregando(false)
    }
  }, [idEntrega])

  useEffect(() => {
    void recarregar()
  }, [recarregar])

  return { eventos, carregando, erro, recarregar }
}

export function useSlaEntregas(filtros: FiltroSlaEntregas) {
  const [itens, setItens] = useState<SlaEntregaItem[]>([])
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState<ErroApi | null>(null)

  const { idLoja, apenasAtrasadas, inicio, fim } = filtros

  const recarregar = useCallback(async () => {
    setCarregando(true)
    setErro(null)
    try {
      const dados = await auditoriaApi.consultarSlaEntregas({
        idLoja,
        apenasAtrasadas,
        inicio,
        fim,
      })
      setItens(dados)
    } catch (e) {
      setItens([])
      setErro(lerErroApi(e))
    } finally {
      setCarregando(false)
    }
  }, [idLoja, apenasAtrasadas, inicio, fim])

  useEffect(() => {
    void recarregar()
  }, [recarregar])

  return { itens, carregando, erro, recarregar }
}