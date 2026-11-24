/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — hooks de consulta de rastreio e SLA (RF05, RF10)
 */
import { useCallback, useEffect, useState } from 'react'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { auditoriaApi, lerErroApi, type ErroApi } from '../api/auditoria.api'
import type {
  FiltroSlaEntregas,
  HistoricoEntregaEvento,
  HistoricoPedidoEvento,
  LinhaTempoEvento,
  SlaEntregaItem,
} from '../types/auditoria.types'

export function useRastreioPedido(idPedido: number | null) {
  const { usuarioAtual, papelAtivo } = useSessaoUsuario()
  const [linhaTempo, setLinhaTempo] = useState<LinhaTempoEvento[]>([])
  const [historicoComercial, setHistoricoComercial] = useState<HistoricoPedidoEvento[]>([])
  const [carregando, setCarregando] = useState(false)
  const [erro, setErro] = useState<ErroApi | null>(null)

  const recarregar = useCallback(async () => {
    if (!idPedido || !usuarioAtual?.idPessoa) {
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
  }, [idPedido, usuarioAtual?.idPessoa, papelAtivo])

  useEffect(() => {
    void recarregar()
  }, [recarregar])

  return { linhaTempo, historicoComercial, carregando, erro, recarregar }
}

export function useHistoricoEntrega(idEntrega: number | null) {
  const { usuarioAtual, papelAtivo } = useSessaoUsuario()
  const [eventos, setEventos] = useState<HistoricoEntregaEvento[]>([])
  const [carregando, setCarregando] = useState(false)
  const [erro, setErro] = useState<ErroApi | null>(null)

  const recarregar = useCallback(async () => {
    if (!idEntrega || !usuarioAtual?.idPessoa) {
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
  }, [idEntrega, usuarioAtual?.idPessoa, papelAtivo])

  useEffect(() => {
    void recarregar()
  }, [recarregar])

  return { eventos, carregando, erro, recarregar }
}

export function useSlaEntregas(filtros: FiltroSlaEntregas) {
  const { usuarioAtual, papelAtivo } = useSessaoUsuario()
  const [itens, setItens] = useState<SlaEntregaItem[]>([])
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState<ErroApi | null>(null)

  const { idLoja, apenasAtrasadas, inicio, fim } = filtros

  const recarregar = useCallback(async () => {
    if (!usuarioAtual?.idPessoa || !papelAtivo) {
      setItens([])
      setCarregando(false)
      return
    }
    setItens([])
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
  }, [idLoja, apenasAtrasadas, inicio, fim, usuarioAtual?.idPessoa, papelAtivo])

  useEffect(() => {
    void recarregar()
  }, [recarregar])

  return { itens, carregando, erro, recarregar }
}