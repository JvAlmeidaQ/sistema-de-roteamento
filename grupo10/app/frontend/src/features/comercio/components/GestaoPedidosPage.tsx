/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Comércio e Finanças
 */
import { RefreshCw } from 'lucide-react'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { limparNomeLoja } from '@/lib/apresentacao'
import { useGestaoPedidos } from '../hooks/useGestaoPedidos'
import { DetalhesPedidoPanel } from './DetalhesPedidoPanel'
import { SkeletonBlock } from './SkeletonBlock'
import { StatusBadge, formatarIdPedido, formatarMoeda } from './StatusBadge'

export function GestaoPedidosPage() {
  const { usuarioAtual, papelAtivo } = useSessaoUsuario()
  const {
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
  } = useGestaoPedidos(usuarioAtual, papelAtivo)

  const tituloPagina =
    papelAtivo === 'lojista'
      ? `Pedidos — ${limparNomeLoja(usuarioAtual?.nomeLoja) || 'Minha loja'}`
      : 'Meus pedidos'

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="font-display text-3xl font-semibold text-brand-dark">
            {tituloPagina}
          </h2>
          <p className="mt-1 text-sm text-text-default">
            {papelAtivo === 'lojista'
              ? 'Acompanhe os pedidos recebidos pela sua loja e atualize o andamento.'
              : 'Acompanhe seus pedidos, confirme pagamentos e avalie sua experiência.'}
          </p>
        </div>

        <div className="flex items-center gap-2">
          <label htmlFor="gestao-status-filtro" className="sr-only">
            Filtrar pedidos por status
          </label>
          <select
            id="gestao-status-filtro"
            value={statusFiltro}
            onChange={(e) => setStatusFiltro(e.target.value)}
            className="rounded-full border border-surface-bg bg-surface px-4 py-2 text-xs font-semibold text-brand-dark"
          >
            <option value="">Todos os status</option>
            <option value="solicitado">Solicitado</option>
            <option value="aceito">Aceito</option>
            <option value="pago">Pago</option>
            <option value="em_preparacao">Em preparação</option>
            <option value="pronto">Pronto para entrega</option>
            <option value="concluido">Concluído</option>
            <option value="recusado">Recusado</option>
          </select>
          <button
            type="button"
            onClick={carregarPedidos}
            className="inline-flex items-center gap-1.5 rounded-full border border-brand-dark bg-surface px-4 py-2 text-xs font-semibold text-brand-dark hover:bg-surface-bg/50"
          >
            <RefreshCw className="h-3.5 w-3.5" aria-hidden="true" />
            Atualizar
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

      {sucesso && (
        <div
          role="status"
          aria-live="polite"
          className="rounded-2xl border border-state-success/40 bg-state-success/10 px-4 py-3 text-sm font-medium text-brand-dark"
        >
          {sucesso}
        </div>
      )}

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <section className="overflow-x-auto rounded-2xl border border-surface-bg bg-surface p-6 lg:col-span-2">
          {carregando ? (
            <SkeletonBlock linhas={5} label="Carregando pedidos..." />
          ) : pedidos.length === 0 ? (
            <div role="status" className="space-y-3 py-8 text-center">
              <p className="text-sm text-text-default">
                Nenhum pedido encontrado para o filtro selecionado.
              </p>
              {statusFiltro && (
                <button
                  type="button"
                  onClick={() => setStatusFiltro('')}
                  className="rounded-full border border-brand-dark px-4 py-1.5 text-xs font-semibold text-brand-dark"
                >
                  Limpar filtro
                </button>
              )}
            </div>
          ) : (
            <table className="w-full border-collapse text-left text-sm">
              <thead>
                <tr className="border-b border-surface-bg text-xs font-semibold uppercase text-text-default">
                  <th className="py-2.5 pr-3">Pedido</th>
                  <th className="py-2.5 pr-3">Loja / Cliente</th>
                  <th className="py-2.5 pr-3">Status</th>
                  <th className="py-2.5 pr-3 text-right">Total</th>
                  <th className="py-2.5 text-right">Ação</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-surface-bg">
                {pedidos.map((pedido) => {
                  const selecionado = pedidoSelecionado?.idPedido === pedido.idPedido
                  return (
                    <tr
                      key={pedido.idPedido}
                      tabIndex={0}
                      aria-selected={selecionado}
                      onClick={() => setPedidoSelecionado(pedido)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault()
                          setPedidoSelecionado(pedido)
                        }
                      }}
                      className={`cursor-pointer transition-colors hover:bg-surface-bg/40 focus:outline-2 focus:outline-brand-outline ${
                        selecionado ? 'bg-brand-lime/15' : ''
                      }`}
                    >
                      <td className="py-3 pr-3 font-semibold text-brand-dark">
                        {formatarIdPedido(pedido.idPedido)}
                      </td>
                      <td className="py-3 pr-3">
                        <p className="font-semibold text-brand-dark">{limparNomeLoja(pedido.nomeLoja)}</p>
                        <p className="text-xs text-text-default">{pedido.nomeCliente}</p>
                      </td>
                      <td className="py-3 pr-3">
                        <StatusBadge status={pedido.status} />
                      </td>
                      <td className="py-3 pr-3 text-right font-semibold tabular-nums text-brand-dark">
                        {formatarMoeda(pedido.valorTotal)}
                      </td>
                      <td className="py-3 text-right">
                        <button
                          type="button"
                          aria-pressed={selecionado}
                          aria-label={`Ver detalhes do pedido ${formatarIdPedido(pedido.idPedido)}`}
                          onClick={(e) => {
                            e.stopPropagation()
                            setPedidoSelecionado(pedido)
                          }}
                          className="rounded-full border border-brand-dark px-3 py-1 text-xs font-semibold text-brand-dark"
                        >
                          Detalhes
                        </button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          )}
        </section>

        <DetalhesPedidoPanel
          pedido={pedidoSelecionado}
          papelAtivo={papelAtivo}
          onTransicionar={executarTransicao}
          onCalcularSplit={registrarSplit}
          onEnviarAvaliacao={enviarAvaliacao}
        />
      </div>
    </div>
  )
}
