/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Comércio e Finanças
 */
import type { AvaliacaoFormValues } from '../schemas/comercio.schemas'
import type { PedidoResponse } from '../types/comercio.types'
import { AvaliacaoPedidoForm } from './AvaliacaoPedidoForm'
import { StatusBadge, formatarDataHora, formatarIdPedido, formatarMoeda } from './StatusBadge'

interface DetalhesPedidoPanelProps {
  pedido: PedidoResponse | null
  onTransicionar: (idPedido: number, novoStatus: string) => void
  onCalcularSplit: (idPedido: number) => void
  onEnviarAvaliacao: (
    alvo: 'loja' | 'entregador',
    idPedido: number,
    valores: AvaliacaoFormValues,
  ) => Promise<void>
}

export function DetalhesPedidoPanel({
  pedido,
  onTransicionar,
  onCalcularSplit,
  onEnviarAvaliacao,
}: DetalhesPedidoPanelProps) {
  if (!pedido) {
    return (
      <aside className="rounded-2xl border border-surface-bg bg-surface p-6">
        <p className="text-sm text-text-default">
          Selecione um pedido na tabela ao lado para acompanhar detalhes, avançar status, calcular
          o split financeiro ou avaliar.
        </p>
      </aside>
    )
  }

  return (
    <aside className="space-y-4 rounded-2xl border border-surface-bg bg-surface p-6">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="font-display text-xl font-semibold text-brand-dark">
            {formatarIdPedido(pedido.idPedido)}
          </h3>
          <p className="text-xs text-text-default">
            {formatarDataHora(pedido.dataPedido)} · {pedido.formaPagamento}
          </p>
        </div>
        <StatusBadge status={pedido.status} />
      </div>

      <div className="space-y-1 rounded-2xl bg-surface-bg/50 p-3 text-xs">
        <p>
          <strong>Loja:</strong> {pedido.nomeLoja}
        </p>
        <p>
          <strong>Cliente:</strong> {pedido.nomeCliente}
        </p>
        <p>
          <strong>Endereço:</strong> {pedido.resumoEndereco}
        </p>
        {pedido.statusEntrega && (
          <p>
            <strong>Entrega (Logística):</strong> {pedido.statusEntrega}
          </p>
        )}
      </div>

      <div>
        <h4 className="text-xs font-semibold uppercase text-text-default">Itens</h4>
        <ul className="mt-1 divide-y divide-surface-bg text-xs">
          {pedido.itens.map((item) => (
            <li key={item.idProduto} className="flex justify-between py-1.5">
              <span>
                {item.quantidade}x {item.nomeProduto}
              </span>
              <span className="font-semibold text-brand-dark">
                {formatarMoeda(item.subtotalItem)}
              </span>
            </li>
          ))}
        </ul>
      </div>

      {/* Transições da máquina de estados (RF03 / RF06 / RR06) */}
      <div className="flex flex-wrap gap-2 border-t border-surface-bg pt-3">
        {pedido.status === 'solicitado' && (
          <>
            <button
              type="button"
              onClick={() => onTransicionar(pedido.idPedido, 'aceito')}
              className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark"
            >
              Aceitar Pedido (Lojista)
            </button>
            <button
              type="button"
              onClick={() => onTransicionar(pedido.idPedido, 'recusado')}
              className="rounded-full border border-state-error px-4 py-1.5 text-xs font-semibold text-state-error"
            >
              Recusar
            </button>
          </>
        )}

        {pedido.status === 'aceito' && (
          <button
            type="button"
            onClick={() => onTransicionar(pedido.idPedido, 'pago')}
            className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark"
          >
            Confirmar Pagamento (Cliente)
          </button>
        )}

        {pedido.status === 'pago' && (
          <button
            type="button"
            onClick={() => onTransicionar(pedido.idPedido, 'em_preparacao')}
            className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark"
          >
            Iniciar Preparo (Lojista)
          </button>
        )}

        {pedido.status === 'em_preparacao' && (
          <button
            type="button"
            onClick={() => onTransicionar(pedido.idPedido, 'pronto')}
            className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark"
          >
            Marcar como Pronto (Lojista)
          </button>
        )}

        {pedido.status === 'pronto' && (
          <p className="text-xs text-text-default">
            Entrega gerada (RN12). Aguardando conclusão pelo subdomínio de Logística para liberar
            split financeiro e avaliações (RN13/RR08).
          </p>
        )}
      </div>

      {/* Divisão de Pagamento (RF09 / RN05) */}
      <div className="space-y-2 border-t border-surface-bg pt-3">
        <div className="flex items-center justify-between gap-2">
          <h4 className="font-display text-sm font-semibold text-brand-dark">
            Divisão Financeira (RF09 / RN05)
          </h4>
          {pedido.status !== 'concluido' && (
            <span className="rounded-full bg-state-pending/15 px-2.5 py-0.5 text-[11px] font-semibold text-brand-pit">
              Requer concluído (RN13)
            </span>
          )}
        </div>

        {pedido.divisaoPagamento ? (
          <div className="space-y-1 rounded-2xl bg-state-success/10 p-3 text-xs">
            <div className="flex justify-between">
              <span>Parcela Loja (85% subtotal)</span>
              <strong>{formatarMoeda(pedido.divisaoPagamento.parcelaLoja)}</strong>
            </div>
            <div className="flex justify-between">
              <span>Comissão Entregador (frete)</span>
              <strong>{formatarMoeda(pedido.divisaoPagamento.comissaoEntregador)}</strong>
            </div>
            <div className="flex justify-between">
              <span>Taxa Plataforma</span>
              <strong>{formatarMoeda(pedido.divisaoPagamento.taxaPlataforma)}</strong>
            </div>
            <div className="flex justify-between border-t border-state-success/25 pt-1 text-brand-dark">
              <span>Total Split (RN05)</span>
              <strong>{formatarMoeda(pedido.divisaoPagamento.valorTotal)}</strong>
            </div>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => onCalcularSplit(pedido.idPedido)}
            className="w-full rounded-full border border-brand-dark px-4 py-2 text-xs font-semibold text-brand-dark transition-colors hover:bg-brand-lime"
          >
            Calcular & Registrar Split (RF09)
          </button>
        )}
      </div>

      {/* Avaliações Pós-Entrega (RF08 / RN06 / RN13) */}
      <div className="space-y-3 border-t border-surface-bg pt-3">
        <h4 className="font-display text-sm font-semibold text-brand-dark">
          Avaliações Pós-Entrega (RF08 / RN06 / RN13)
        </h4>

        {pedido.avaliacaoLoja ? (
          <div className="rounded-2xl bg-surface-bg/50 p-3 text-xs">
            <strong>Loja:</strong> {pedido.avaliacaoLoja.nota}/5 ★ —{' '}
            {pedido.avaliacaoLoja.comentario ?? 'Sem comentário'}
          </div>
        ) : (
          <AvaliacaoPedidoForm alvo="loja" idPedido={pedido.idPedido} onEnviar={onEnviarAvaliacao} />
        )}

        {pedido.avaliacaoEntregador ? (
          <div className="rounded-2xl bg-surface-bg/50 p-3 text-xs">
            <strong>Entregador:</strong> {pedido.avaliacaoEntregador.nota}/5 ★ —{' '}
            {pedido.avaliacaoEntregador.comentario ?? 'Sem comentário'}
          </div>
        ) : (
          <AvaliacaoPedidoForm
            alvo="entregador"
            idPedido={pedido.idPedido}
            onEnviar={onEnviarAvaliacao}
          />
        )}
      </div>
    </aside>
  )
}
