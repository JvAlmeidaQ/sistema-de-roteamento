/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { MapPin } from 'lucide-react'
import { Link } from 'react-router-dom'
import { StarRating } from '@/components/StarRating'
import type { PapelAtivo } from '@/context/SessaoUsuarioContext'
import {
  formatarFormaPagamento,
  formatarStatusEntrega,
  limparNomeLoja,
  limparNomeProduto,
} from '@/lib/apresentacao'
import type { AvaliacaoFormValues } from '../schemas/comercio.schemas'
import type { PedidoResponse } from '../types/comercio.types'
import { AvaliacaoPedidoForm } from './AvaliacaoPedidoForm'
import { StatusBadge, formatarDataHora, formatarIdPedido, formatarMoeda } from './StatusBadge'

interface DetalhesPedidoPanelProps {
  pedido: PedidoResponse | null
  papelAtivo: PapelAtivo | null
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
  papelAtivo,
  onTransicionar,
  onCalcularSplit,
  onEnviarAvaliacao,
}: DetalhesPedidoPanelProps) {
  if (!pedido) {
    return (
      <aside className="rounded-2xl border border-surface-bg bg-surface p-6">
        <p className="text-sm text-text-default">
          Selecione um pedido ao lado para acompanhar os detalhes e realizar ações disponíveis.
        </p>
      </aside>
    )
  }

  const ehLojista = papelAtivo === 'lojista'
  const ehCliente = papelAtivo === 'cliente'

  return (
    <aside className="space-y-4 rounded-2xl border border-surface-bg bg-surface p-6">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="font-display text-xl font-semibold text-brand-dark">
            {formatarIdPedido(pedido.idPedido)}
          </h3>
          <p className="text-xs text-text-default">
            {formatarDataHora(pedido.dataPedido)} · {formatarFormaPagamento(pedido.formaPagamento)}
          </p>
        </div>
        <StatusBadge status={pedido.status} />
      </div>

      <Link
        to={`/rastreio/${pedido.idPedido}`}
        className="inline-flex min-h-11 items-center gap-1.5 rounded-sm text-sm font-semibold text-brand-outline underline underline-offset-4 hover:text-brand-dark focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-outline"
      >
        <MapPin className="h-4 w-4" aria-hidden="true" />
        Acompanhar entrega
      </Link>

      <div className="space-y-1 rounded-2xl bg-surface-bg/50 p-3 text-xs">
        <p>
          <strong>Loja:</strong> {limparNomeLoja(pedido.nomeLoja)}
        </p>
        <p>
          <strong>Cliente:</strong> {pedido.nomeCliente}
        </p>
        <p>
          <strong>Endereço:</strong> {pedido.resumoEndereco}
        </p>
        {pedido.statusEntrega && (
          <p>
            <strong>Entrega:</strong> {formatarStatusEntrega(pedido.statusEntrega)}
          </p>
        )}
      </div>

      <div>
        <h4 className="text-xs font-semibold uppercase text-text-default">Itens</h4>
        <ul className="mt-1 divide-y divide-surface-bg text-xs">
          {pedido.itens.map((item) => (
            <li key={item.idProduto} className="flex justify-between py-1.5">
              <span>
                {item.quantidade}x {limparNomeProduto(item.nomeProduto)}
              </span>
              <span className="font-semibold text-brand-dark">
                {formatarMoeda(item.subtotalItem)}
              </span>
            </li>
          ))}
        </ul>
      </div>

      {/* Ações operacionais filtradas pelo papel ativo */}
      <div className="flex flex-wrap gap-2 border-t border-surface-bg pt-3">
        {ehLojista && pedido.status === 'solicitado' && (
          <>
            <button
              type="button"
              onClick={() => onTransicionar(pedido.idPedido, 'aceito')}
              className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80"
            >
              Aceitar pedido
            </button>
            <button
              type="button"
              onClick={() => onTransicionar(pedido.idPedido, 'recusado')}
              className="rounded-full border border-state-error px-4 py-1.5 text-xs font-semibold text-state-error transition-colors hover:bg-state-error/10"
            >
              Recusar
            </button>
          </>
        )}

        {ehCliente && pedido.status === 'aceito' && (
          <button
            type="button"
            onClick={() => onTransicionar(pedido.idPedido, 'pago')}
            className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80"
          >
            Confirmar pagamento
          </button>
        )}

        {ehLojista && pedido.status === 'pago' && (
          <button
            type="button"
            onClick={() => onTransicionar(pedido.idPedido, 'em_preparacao')}
            className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80"
          >
            Iniciar preparo
          </button>
        )}

        {ehLojista && pedido.status === 'em_preparacao' && (
          <button
            type="button"
            onClick={() => onTransicionar(pedido.idPedido, 'pronto')}
            className="rounded-full bg-brand-lime px-4 py-1.5 text-xs font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80"
          >
            Marcar como pronto
          </button>
        )}

        {pedido.status === 'pronto' && (
          <p className="text-xs text-text-default">
            Pedido pronto e aguardando entrega.
          </p>
        )}
      </div>

      {/* Divisão financeira exclusiva para visão do Lojista */}
      {ehLojista && (
        <div className="space-y-2 border-t border-surface-bg pt-3">
          <div className="flex items-center justify-between gap-2">
            <h4 className="font-display text-sm font-semibold text-brand-dark">
              Repasse financeiro
            </h4>
            {pedido.status !== 'concluido' && (
              <span className="rounded-full bg-state-pending/15 px-2.5 py-0.5 text-[11px] font-semibold text-brand-pit">
                Disponível após conclusão
              </span>
            )}
          </div>

          {pedido.divisaoPagamento ? (
            <div className="space-y-1 rounded-2xl bg-state-success/10 p-3 text-xs">
              <div className="flex justify-between">
                <span>Repasse da loja</span>
                <strong>{formatarMoeda(pedido.divisaoPagamento.parcelaLoja)}</strong>
              </div>
              <div className="flex justify-between">
                <span>Comissão do entregador</span>
                <strong>{formatarMoeda(pedido.divisaoPagamento.comissaoEntregador)}</strong>
              </div>
              <div className="flex justify-between">
                <span>Taxa da plataforma</span>
                <strong>{formatarMoeda(pedido.divisaoPagamento.taxaPlataforma)}</strong>
              </div>
              <div className="flex justify-between border-t border-state-success/25 pt-1 text-brand-dark">
                <span>Total</span>
                <strong>{formatarMoeda(pedido.divisaoPagamento.valorTotal)}</strong>
              </div>
            </div>
          ) : (
            <button
              type="button"
              disabled={pedido.status !== 'concluido'}
              onClick={() => onCalcularSplit(pedido.idPedido)}
              className="w-full rounded-full border border-brand-dark px-4 py-2 text-xs font-semibold text-brand-dark transition-colors hover:bg-brand-lime disabled:cursor-not-allowed disabled:opacity-40"
            >
              Calcular repasse
            </button>
          )}
        </div>
      )}

      {/* Avaliações pós-entrega */}
      {(ehCliente || pedido.avaliacaoLoja || pedido.avaliacaoEntregador) && (
        <div className="space-y-3 border-t border-surface-bg pt-3">
          <h4 className="font-display text-sm font-semibold text-brand-dark">
            Avaliações
          </h4>

          {pedido.avaliacaoLoja ? (
            <div className="space-y-1 rounded-2xl bg-surface-bg/50 p-3 text-xs">
              <div className="flex items-center justify-between">
                <strong>Loja</strong>
                <StarRating nota={pedido.avaliacaoLoja.nota} rotulo="Avaliação da loja" />
              </div>
              <p className="text-text-default">
                {pedido.avaliacaoLoja.comentario ?? 'Sem comentário'}
              </p>
            </div>
          ) : ehCliente && pedido.status === 'concluido' ? (
            <AvaliacaoPedidoForm alvo="loja" idPedido={pedido.idPedido} onEnviar={onEnviarAvaliacao} />
          ) : null}

          {pedido.avaliacaoEntregador ? (
            <div className="space-y-1 rounded-2xl bg-surface-bg/50 p-3 text-xs">
              <div className="flex items-center justify-between">
                <strong>Entregador</strong>
                <StarRating nota={pedido.avaliacaoEntregador.nota} rotulo="Avaliação do entregador" />
              </div>
              <p className="text-text-default">
                {pedido.avaliacaoEntregador.comentario ?? 'Sem comentário'}
              </p>
            </div>
          ) : ehCliente && pedido.status === 'concluido' ? (
            <AvaliacaoPedidoForm
              alvo="entregador"
              idPedido={pedido.idPedido}
              onEnviar={onEnviarAvaliacao}
            />
          ) : null}
        </div>
      )}
    </aside>
  )
}
