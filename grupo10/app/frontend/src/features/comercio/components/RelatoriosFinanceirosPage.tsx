/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { useEffect, useState } from 'react'
import { StarRating } from '@/components/StarRating'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { formatarStatusPedido, limparNomeLoja } from '@/lib/apresentacao'
import { useRelatoriosFinanceiros } from '../hooks/useRelatoriosFinanceiros'
import { ConsultasEstrategicasSection } from './ConsultasEstrategicasSection'
import { SkeletonBlock } from './SkeletonBlock'
import { StatusBadge, formatarDataHora, formatarIdPedido, formatarMoeda } from './StatusBadge'
import { VisaoResumoFinanceiroTable } from './VisaoResumoFinanceiroTable'

export function RelatoriosFinanceirosPage() {
  const { usuarioAtual, papelAtivo } = useSessaoUsuario()
  const {
    resumoLojas,
    lojas,
    relatorio,
    consultaAtiva,
    carregando,
    erro,
    buscarRelatorioParametrizado,
    carregarConsulta,
  } = useRelatoriosFinanceiros(usuarioAtual, papelAtivo)

  const ehAdmin = papelAtivo === 'admin'
  const [aba, setAba] = useState<'visao' | 'parametrizado' | 'consultas'>(
    ehAdmin ? 'visao' : 'parametrizado',
  )
  const [idLojaFiltro, setIdLojaFiltro] = useState<number>(usuarioAtual?.idLoja ?? 0)
  const [statusFiltro, setStatusFiltro] = useState<string>('concluido')
  const [dataInicio, setDataInicio] = useState<string>('')
  const [dataFim, setDataFim] = useState<string>('')

  useEffect(() => {
    if (papelAtivo === 'lojista' && usuarioAtual?.idLoja) {
      setIdLojaFiltro(usuarioAtual.idLoja)
      setAba((atual) => (atual === 'visao' ? 'parametrizado' : atual))
      void buscarRelatorioParametrizado(usuarioAtual.idLoja, {
        status: statusFiltro,
        dataInicio,
        dataFim,
      })
    } else if (papelAtivo === 'admin' && lojas[0] && idLojaFiltro === 0) {
      setIdLojaFiltro(lojas[0].idLoja)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [papelAtivo, usuarioAtual?.idLoja, lojas])

  const resumoMinhaLoja = !ehAdmin ? resumoLojas[0] ?? null : null
  const nomeLojaTitulo =
    limparNomeLoja(usuarioAtual?.nomeLoja) ||
    limparNomeLoja(resumoMinhaLoja?.nomeLoja) ||
    'Minha loja'

  const tituloPrincipal = ehAdmin
    ? 'Painel financeiro consolidado'
    : `Relatórios — ${nomeLojaTitulo}`

  const subtituloPrincipal = ehAdmin
    ? 'Visão consolidada de faturamento, repasses e análises gerenciais da plataforma.'
    : 'Acompanhe o desempenho financeiro, pedidos por período e análises da sua loja.'

  const aplicarFiltros = () => {
    const idAlvo = ehAdmin ? idLojaFiltro : (usuarioAtual?.idLoja ?? idLojaFiltro)
    if (!idAlvo) return
    void buscarRelatorioParametrizado(idAlvo, {
      status: statusFiltro,
      dataInicio,
      dataFim,
    })
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="font-display text-3xl font-semibold text-brand-dark">
            {tituloPrincipal}
          </h2>
          <p className="mt-1 text-sm text-text-default">{subtituloPrincipal}</p>
        </div>

        <div role="tablist" aria-label="Seções de relatórios" className="flex flex-wrap gap-2">
          {ehAdmin && (
            <button
              type="button"
              role="tab"
              aria-selected={aba === 'visao'}
              onClick={() => setAba('visao')}
              className={`rounded-full px-4 py-2 text-xs font-semibold transition-colors ${
                aba === 'visao'
                  ? 'bg-brand-lime text-brand-dark'
                  : 'border border-brand-dark bg-surface text-brand-dark hover:bg-surface-bg/50'
              }`}
            >
              Visão consolidada
            </button>
          )}
          <button
            type="button"
            role="tab"
            aria-selected={aba === 'parametrizado'}
            onClick={() => {
              setAba('parametrizado')
              if (!relatorio) aplicarFiltros()
            }}
            className={`rounded-full px-4 py-2 text-xs font-semibold transition-colors ${
              aba === 'parametrizado'
                ? 'bg-brand-lime text-brand-dark'
                : 'border border-brand-dark bg-surface text-brand-dark hover:bg-surface-bg/50'
            }`}
          >
            Pedidos por período
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={aba === 'consultas'}
            onClick={() => {
              setAba('consultas')
              if (!consultaAtiva) carregarConsulta(5)
            }}
            className={`rounded-full px-4 py-2 text-xs font-semibold transition-colors ${
              aba === 'consultas'
                ? 'bg-brand-lime text-brand-dark'
                : 'border border-brand-dark bg-surface text-brand-dark hover:bg-surface-bg/50'
            }`}
          >
            {ehAdmin ? 'Análises gerenciais' : 'Análises da loja'}
          </button>
        </div>
      </div>

      {!ehAdmin && resumoMinhaLoja && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl border border-surface-bg bg-surface p-5">
            <p className="text-xs font-semibold text-text-default">Faturamento bruto</p>
            <p className="mt-1 font-display text-2xl font-semibold tabular-nums text-brand-dark">
              {formatarMoeda(resumoMinhaLoja.faturamentoBruto)}
            </p>
          </div>
          <div className="rounded-2xl border border-surface-bg bg-surface p-5">
            <p className="text-xs font-semibold text-text-default">Repasse da loja</p>
            <p className="mt-1 font-display text-2xl font-semibold tabular-nums text-brand-outline">
              {formatarMoeda(resumoMinhaLoja.repasseTotalLoja)}
            </p>
          </div>
          <div className="rounded-2xl border border-surface-bg bg-surface p-5">
            <p className="text-xs font-semibold text-text-default">Pedidos concluídos</p>
            <p className="mt-1 font-display text-2xl font-semibold tabular-nums text-brand-dark">
              {resumoMinhaLoja.pedidosConcluidos}
            </p>
          </div>
          <div className="rounded-2xl border border-surface-bg bg-surface p-5">
            <p className="text-xs font-semibold text-text-default">Avaliação média</p>
            <div className="mt-2">
              {resumoMinhaLoja.mediaAvaliacaoLoja != null ? (
                <StarRating nota={Number(resumoMinhaLoja.mediaAvaliacaoLoja)} tamanho="md" rotulo="Avaliação média da loja" />
              ) : (
                <span className="text-sm text-text-default">Sem avaliações</span>
              )}
            </div>
          </div>
        </div>
      )}

      {erro && (
        <div
          role="alert"
          className="rounded-2xl border border-state-error/40 bg-state-error/10 px-4 py-3 text-sm font-medium text-state-error"
        >
          {erro}
        </div>
      )}

      {ehAdmin && aba === 'visao' && (
        <VisaoResumoFinanceiroTable resumoLojas={resumoLojas} carregando={carregando} />
      )}

      {aba === 'parametrizado' && (
        <section className="space-y-5">
          <div className="flex flex-wrap items-end gap-4 rounded-2xl border border-surface-bg bg-surface p-6">
            {ehAdmin && (
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
                      {limparNomeLoja(l.nome)}
                    </option>
                  ))}
                </select>
              </div>
            )}
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
                <option value="em_preparacao">Em preparação</option>
                <option value="pronto">Pronto para entrega</option>
                <option value="concluido">Concluído</option>
                <option value="recusado">Recusado</option>
              </select>
            </div>
            <div>
              <label
                htmlFor="relatorio-data-inicio"
                className="block text-xs font-semibold text-brand-dark"
              >
                Data inicial
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
                Data final
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
              onClick={aplicarFiltros}
              disabled={carregando}
              className="rounded-full bg-brand-lime px-5 py-2.5 text-sm font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80 disabled:opacity-50"
            >
              {carregando ? 'Consultando...' : 'Aplicar filtros'}
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
                  <p className="text-xs font-semibold text-text-default">Pedidos encontrados</p>
                  <p className="mt-1 font-display text-3xl font-semibold tabular-nums text-brand-dark">
                    {relatorio.totalPedidosFiltrados}
                  </p>
                </div>
                <div className="rounded-2xl border border-surface-bg bg-surface p-5">
                  <p className="text-xs font-semibold text-text-default">Faturamento no período</p>
                  <p className="mt-1 font-display text-3xl font-semibold tabular-nums text-brand-outline">
                    {formatarMoeda(relatorio.faturamentoFiltrado)}
                  </p>
                </div>
                <div className="rounded-2xl border border-surface-bg bg-surface p-5">
                  <p className="text-xs font-semibold text-text-default">Ticket médio</p>
                  <p className="mt-1 font-display text-3xl font-semibold tabular-nums text-brand-dark">
                    {formatarMoeda(relatorio.ticketMedioFiltrado)}
                  </p>
                </div>
              </div>

              <div className="overflow-x-auto rounded-2xl border border-surface-bg bg-surface p-6">
                <h4 className="font-display text-lg font-semibold text-brand-dark">
                  Pedidos recentes — {limparNomeLoja(relatorio.nomeLoja)}
                  {statusFiltro ? ` (${formatarStatusPedido(statusFiltro)})` : ''}
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
                        <th className="py-2.5 text-right">Valor total</th>
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
