/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — RF05 (rastreio passo a passo de Pedido e Entrega)
 */
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Link, useSearchParams } from 'react-router-dom'
import { useHistoricoEntrega, useRastreioPedido } from '../hooks/useAuditoria'
import { buscaRastreioSchema, type BuscaRastreioFormValues } from '../schemas/auditoria.schemas'
import { LinhaTempoAuditoria, type ItemTimeline } from './LinhaTempoAuditoria'

const inputClass =
  'mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline focus-visible:ring-2 focus-visible:ring-brand-outline/30'

type AbaPedido = 'unificada' | 'comercial'

export default function AuditoriaRastreioPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const tipoInicial = searchParams.get('tipo') === 'entrega' ? 'entrega' : 'pedido'
  const idInicial = searchParams.get('id') ?? ''

  const [consultaAtiva, setConsultaAtiva] = useState<{ tipo: 'pedido' | 'entrega'; id: number } | null>(() => {
    const num = Number(idInicial)
    return Number.isSafeInteger(num) && num > 0 ? { tipo: tipoInicial, id: num } : null
  })
  const [abaPedido, setAbaPedido] = useState<AbaPedido>('unificada')

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<BuscaRastreioFormValues>({
    resolver: zodResolver(buscaRastreioSchema),
    defaultValues: { tipo: tipoInicial, id: idInicial },
  })

  const idPedidoAtivo = consultaAtiva?.tipo === 'pedido' ? consultaAtiva.id : null
  const idEntregaAtiva = consultaAtiva?.tipo === 'entrega' ? consultaAtiva.id : null

  const rastreioPedido = useRastreioPedido(idPedidoAtivo)
  const rastreioEntrega = useHistoricoEntrega(idEntregaAtiva)

  const onSubmit = (valores: BuscaRastreioFormValues) => {
    const id = Number(valores.id)
    setConsultaAtiva({ tipo: valores.tipo, id })
    setSearchParams({ tipo: valores.tipo, id: String(id) })
  }

  const carregando = idPedidoAtivo ? rastreioPedido.carregando : rastreioEntrega.carregando
  const erro = idPedidoAtivo ? rastreioPedido.erro : rastreioEntrega.erro

  const itensTimeline: ItemTimeline[] = (() => {
    if (idPedidoAtivo) {
      if (abaPedido === 'unificada') {
        return rastreioPedido.linhaTempo.map((ev, i) => ({
          chave: `${ev.dominioEvento}-${ev.statusEvento}-${ev.dataHora}-${i}`,
          dominio: ev.dominioEvento,
          status: ev.statusEvento,
          dataHora: ev.dataHora,
        }))
      }
      return rastreioPedido.historicoComercial.map((ev, i) => ({
        chave: `COMERCIAL-${ev.status}-${ev.dataHora}-${i}`,
        dominio: 'COMERCIAL',
        status: ev.status,
        dataHora: ev.dataHora,
      }))
    }
    if (idEntregaAtiva) {
      return rastreioEntrega.eventos.map((ev, i) => ({
        chave: `LOGISTICO-${ev.status}-${ev.dataHora}-${i}`,
        dominio: 'LOGISTICO',
        status: ev.status,
        dataHora: ev.dataHora,
      }))
    }
    return []
  })()

  const resumoPedido = rastreioPedido.linhaTempo[0]

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="space-y-1">
          <p className="text-xs font-semibold text-text-default">Auditoria · RF05 / RN04 / RN08</p>
          <h2 className="text-3xl">Rastreamento e Histórico</h2>
          <p className="text-sm text-text-default">
            Consulte a trilha cronológica imutável de um pedido (comercial + logística) ou de uma entrega.
          </p>
        </div>
        <Link
          to="/auditoria/sla"
          className="rounded-full bg-brand-lime px-5 py-2 text-sm font-semibold text-brand-dark shadow-low transition-colors hover:bg-brand-green/40"
        >
          Painel de SLA de Entregas →
        </Link>
      </header>

      <section className="rounded-3xl bg-surface p-6 shadow-low">
        <form onSubmit={handleSubmit(onSubmit)} noValidate className="grid gap-4 md:grid-cols-12 md:items-end">
          <div className="md:col-span-4">
            <label htmlFor="rastreio-tipo" className="block text-xs font-semibold text-brand-dark">
              Tipo de consulta
            </label>
            <select id="rastreio-tipo" {...register('tipo')} className={inputClass}>
              <option value="pedido">Pedido (Linha do tempo unificada)</option>
              <option value="entrega">Entrega (Histórico logístico)</option>
            </select>
          </div>

          <div className="md:col-span-5">
            <label htmlFor="rastreio-id" className="block text-xs font-semibold text-brand-dark">
              Identificador (ID) *
            </label>
            <input
              id="rastreio-id"
              inputMode="numeric"
              placeholder="Ex.: 101"
              {...register('id')}
              className={inputClass}
            />
            {errors.id && (
              <p role="alert" className="mt-1 text-xs text-state-error">
                {errors.id.message}
              </p>
            )}
          </div>

          <div className="md:col-span-3">
            <button
              type="submit"
              className="w-full rounded-full bg-brand-lime px-5 py-2.5 text-sm font-semibold text-brand-dark shadow-low transition-colors hover:bg-brand-green/40"
            >
              Consultar trilha
            </button>
          </div>
        </form>
      </section>

      {carregando && (
        <div className="space-y-3" role="status" aria-label="Carregando histórico de auditoria">
          <div className="h-20 animate-pulse rounded-3xl bg-surface" />
          <div className="h-48 animate-pulse rounded-3xl bg-surface" />
        </div>
      )}

      {!carregando && erro && (
        <p role="alert" className="rounded-2xl bg-state-error/10 px-4 py-3 text-sm text-state-error">
          {erro.status === 404
            ? `${consultaAtiva?.tipo === 'pedido' ? 'Pedido' : 'Entrega'} #${consultaAtiva?.id} não encontrado(a).`
            : erro.mensagem}
        </p>
      )}

      {!carregando && !erro && consultaAtiva && (
        <section className="space-y-5 rounded-3xl bg-surface p-6 shadow-low">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-surface-bg pb-4">
            <div>
              <h3 className="text-lg">
                {consultaAtiva.tipo === 'pedido'
                  ? `Pedido #${consultaAtiva.id}`
                  : `Entrega #${consultaAtiva.id}`}
              </h3>
              {resumoPedido && consultaAtiva.tipo === 'pedido' && (
                <p className="text-xs text-text-default tabular-nums">
                  Loja #{resumoPedido.idLoja} · Cliente #{resumoPedido.idCliente}
                </p>
              )}
            </div>

            {consultaAtiva.tipo === 'pedido' && (
              <div className="flex gap-2" role="tablist" aria-label="Visão do histórico do pedido">
                <button
                  type="button"
                  role="tab"
                  aria-selected={abaPedido === 'unificada'}
                  onClick={() => setAbaPedido('unificada')}
                  className={`rounded-full px-4 py-1.5 text-xs font-semibold transition-colors ${
                    abaPedido === 'unificada'
                      ? 'bg-brand-lime text-brand-dark'
                      : 'border border-surface-bg text-text-default hover:bg-surface-bg/50'
                  }`}
                >
                  Linha do tempo unificada ({rastreioPedido.linhaTempo.length})
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={abaPedido === 'comercial'}
                  onClick={() => setAbaPedido('comercial')}
                  className={`rounded-full px-4 py-1.5 text-xs font-semibold transition-colors ${
                    abaPedido === 'comercial'
                      ? 'bg-brand-lime text-brand-dark'
                      : 'border border-surface-bg text-text-default hover:bg-surface-bg/50'
                  }`}
                >
                  Apenas comercial ({rastreioPedido.historicoComercial.length})
                </button>
              </div>
            )}
          </div>

          <LinhaTempoAuditoria itens={itensTimeline} />
        </section>
      )}
    </div>
  )
}