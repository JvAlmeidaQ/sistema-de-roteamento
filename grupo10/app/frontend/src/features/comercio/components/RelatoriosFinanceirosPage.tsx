/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças (disponível em VITE_APP_MODE=bd e full)
 */
import { useEffect, useMemo, useState } from 'react'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { useRelatoriosFinanceiros } from '../hooks/useRelatoriosFinanceiros'
import { ConsultasEstrategicasSection } from './ConsultasEstrategicasSection'
import { SkeletonBlock } from './SkeletonBlock'
import { StatusBadge, formatarDataHora, formatarIdPedido, formatarMoeda } from './StatusBadge'
import { VisaoResumoFinanceiroTable } from './VisaoResumoFinanceiroTable'

export function RelatoriosFinanceirosPage() {
  const { usuarioAtual } = useSessaoUsuario()
  const {
    resumoLojas,
    lojas,
    relatorio,
    consultaAtiva,
    carregando,
    erro,
    buscarRelatorioParametrizado,
    carregarConsulta,
  } = useRelatoriosFinanceiros()

  const [aba, setAba] = useState<'visao' | 'parametrizado' | 'consultas'>('visao')
  const [idLojaFiltro, setIdLojaFiltro] = useState<number>(1)
  const [statusFiltro, setStatusFiltro] = useState<string>('concluido')
  const [dataInicio, setDataInicio] = useState<string>('')
  const [dataFim, setDataFim] = useState<string>('')

  useEffect(() => {
    if (usuarioAtual?.perfilLojista && usuarioAtual.idLoja) {
      setIdLojaFiltro(usuarioAtual.idLoja)
    } else if (lojas[0] && idLojaFiltro === 1) {
      setIdLojaFiltro(lojas[0].idLoja)
    }
  }, [usuarioAtual, lojas])

  const lojaSelecionada = useMemo(
    () => lojas.find((l) => l.idLoja === idLojaFiltro) ?? null,
    [lojas, idLojaFiltro],
  )

  const ehLojistaDono =
    Boolean(lojaSelecionada) && usuarioAtual?.idPessoa === lojaSelecionada?.idLojista

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="font-display text-3xl font-semibold text-brand-dark">
            Painel Financeiro & Consultas SQL (RF10)
          </h2>
          <p className="mt-1 text-sm text-text-default">
            Visão <code>vw_resumo_financeiro_loja</code>, relatório parametrizado por loja/período
            e consultas analíticas de Comércio e Finanças.
          </p>
        </div>

        <div role="tablist" aria-label="Seções de relatórios" className="flex flex-wrap gap-2">
          <button
            type="button"
            role="tab"
            aria-selected={aba === 'visao'}
            onClick={() => setAba('visao')}
            className={`rounded-full px-4 py-2 text-xs font-semibold ${
              aba === 'visao'
                ? 'bg-brand-lime text-brand-dark'
                : 'border border-brand-dark bg-surface text-brand-dark'
            }`}
          >
            Visão Financeira (View)
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={aba === 'parametrizado'}
            onClick={() => {
              setAba('parametrizado')
              if (!relatorio) {
                buscarRelatorioParametrizado(idLojaFiltro, {
                  status: statusFiltro,
                  dataInicio,
                  dataFim,
                })
              }
            }}
            className={`rounded-full px-4 py-2 text-xs font-semibold ${
              aba === 'parametrizado'
                ? 'bg-brand-lime text-brand-dark'
                : 'border border-brand-dark bg-surface text-brand-dark'
            }`}
          >
            Relatório Parametrizado (RF10)
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={aba === 'consultas'}
            onClick={() => {
              setAba('consultas')
              if (!consultaAtiva) carregarConsulta(5)
            }}
            className={`rounded-full px-4 py-2 text-xs font-semibold ${
              aba === 'consultas'
                ? 'bg-brand-lime text-brand-dark'
                : 'border border-brand-dark bg-surface text-brand-dark'
            }`}
          >
            Consultas SQL (C5–C12)
          </button>
        </div>
      </div>

      {erro && (
        <div
          role="alert"
          className="rounded-2xl border border-state-error/40 bg-state-error/10 px-4 py-3 text-sm font-medium text-state-error"
        >
          {erro}
        </div>
      )}

      {aba === 'visao' && (
        <VisaoResumoFinanceiroTable resumoLojas={resumoLojas} carregando={carregando} />
      )}

      {aba === 'parametrizado' && (
        <section className="space-y-5">

          <div className="flex flex-wrap items-end gap-4 rounded-2xl border border-surface-bg bg-surface p-6">
            <div>
              <label htmlFor="relatorio-loja" className="block text-xs font-semibold text-brand-dark">
                Loja
              </label>
              <select
                id="relatorio-loja"
                value={idLojaFiltro}
                onChange={(e) => setIdLojaFiltro(Number(e.target.value))}
                className="mt-1 rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-sm text-brand-dark"
              >
                {lojas.map((l) => (
                  <option key={l.idLoja} value={l.idLoja}>
                    #{l.idLoja} · {l.nome}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label
                htmlFor="relatorio-status"
                className="block text-xs font-semibold text-brand-dark"
              >
                Status
              </label>
              <select
                id="relatorio-status"
                value={statusFiltro}
                onChange={(e) => setStatusFiltro(e.target.value)}
                className="mt-1 rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-sm text-brand-dark"
              >
                <option value="">Todos</option>
                <option value="solicitado">Solicitado</option>
                <option value="aceito">Aceito</option>
                <option value="pago">Pago</option>
                <option value="em_preparacao">Em Preparação</option>
                <option value="pronto">Pronto</option>
                <option value="concluido">Concluído</option>
                <option value="recusado">Recusado</option>
              </select>
            </div>
            <div>
              <label
                htmlFor="relatorio-data-inicio"
                className="block text-xs font-semibold text-brand-dark"
              >
                Data Início
              </label>
              <input
                id="relatorio-data-inicio"
                type="date"
                value={dataInicio}
                onChange={(e) => setDataInicio(e.target.value)}
                className="mt-1 rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-sm text-brand-dark"
              />
            </div>
            <div>
              <label
                htmlFor="relatorio-data-fim"
                className="block text-xs font-semibold text-brand-dark"
              >
                Data Fim
              </label>
              <input
                id="relatorio-data-fim"
                type="date"
                value={dataFim}
                onChange={(e) => setDataFim(e.target.value)}
                className="mt-1 rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-sm text-brand-dark"
              />
            </div>
            <button
              type="button"
              onClick={() =>
                buscarRelatorioParametrizado(idLojaFiltro, {
                  status: statusFiltro,
                  dataInicio,
                  dataFim,
                })
              }
              disabled={carregando}
              className="rounded-full bg-brand-lime px-5 py-2.5 text-sm font-semibold text-brand-dark"
            >
              {carregando ? 'Consultando...' : 'Aplicar Filtros'}
            </button>
          </div>

          {carregando && !relatorio ? (
            <div className="rounded-2xl border border-surface-bg bg-surface p-6">
              <SkeletonBlock linhas={4} label="Carregando relatório da loja..." />
            </div>
          ) : relatorio ? (
            <>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div className="rounded-2xl border border-surface-bg bg-surface p-5">
                  <p className="text-xs font-semibold text-text-default">Pedidos Encontrados</p>
                  <p className="mt-1 font-display text-3xl font-semibold tabular-nums text-brand-dark">
                    {relatorio.totalPedidosFiltrados}
                  </p>
                </div>
                <div className="rounded-2xl border border-surface-bg bg-surface p-5">
                  <p className="text-xs font-semibold text-text-default">Faturamento Filtrado</p>
                  <p className="mt-1 font-display text-3xl font-semibold tabular-nums text-brand-outline">
                    {formatarMoeda(relatorio.faturamentoFiltrado)}
                  </p>
                </div>
                <div className="rounded-2xl border border-surface-bg bg-surface p-5">
                  <p className="text-xs font-semibold text-text-default">Ticket Médio</p>
                  <p className="mt-1 font-display text-3xl font-semibold tabular-nums text-brand-dark">
                    {formatarMoeda(relatorio.ticketMedioFiltrado)}
                  </p>
                </div>
              </div>

              <div className="overflow-x-auto rounded-2xl border border-surface-bg bg-surface p-6">
                <h4 className="font-display text-lg font-semibold text-brand-dark">
                  Últimos 25 pedidos filtrados — {relatorio.nomeLoja}
                </h4>
                {relatorio.pedidos.length === 0 ? (
                  <p role="status" className="py-6 text-center text-sm text-text-default">
                    Nenhum pedido encontrado para os filtros informados.
                  </p>
                ) : (
                  <table className="mt-3 w-full border-collapse text-left text-sm">
                    <thead>
                      <tr className="border-b border-surface-bg text-xs font-semibold uppercase text-text-default">
                        <th className="py-2.5 pr-4">Pedido</th>
                        <th className="py-2.5 pr-4">Cliente</th>
                        <th className="py-2.5 pr-4">Status</th>
                        <th className="py-2.5 pr-4">Data</th>
                        <th className="py-2.5 text-right">Valor Total</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-surface-bg">
                      {relatorio.pedidos.map((p) => (
                        <tr key={p.idPedido}>
                          <td className="py-2.5 pr-4 font-semibold text-brand-dark">
                            {formatarIdPedido(p.idPedido)}
                          </td>
                          <td className="py-2.5 pr-4">{p.nomeCliente}</td>
                          <td className="py-2.5 pr-4">
                            <StatusBadge status={p.status} />
                          </td>
                          <td className="py-2.5 pr-4">{formatarDataHora(p.dataPedido)}</td>
                          <td className="py-2.5 text-right font-semibold tabular-nums text-brand-dark">
                            {formatarMoeda(p.valorTotal)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            </>
          ) : null}
        </section>
      )}

      {aba === 'consultas' && (
        <ConsultasEstrategicasSection
          consultaAtiva={consultaAtiva}
          carregando={carregando}
          onSelecionarConsulta={carregarConsulta}
        />
      )}
    </div>
  )
}
