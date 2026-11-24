/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças (disponível em VITE_APP_MODE=bd e full)
 */
import { Minus, Plus } from 'lucide-react'
import type { UseFormReturn } from 'react-hook-form'
import { limparNomeProduto } from '@/lib/apresentacao'
import type { CriarPedidoFormValues } from '../schemas/comercio.schemas'
import type { EnderecoEntregaCliente, ProdutoCheckout } from '../types/comercio.types'
import { formatarMoeda } from './StatusBadge'

interface CarrinhoCheckoutAsideProps {
  form: UseFormReturn<CriarPedidoFormValues>
  itensCarrinho: { produto: ProdutoCheckout; quantidade: number }[]
  enderecos: EnderecoEntregaCliente[]
  carregandoEnderecos: boolean
  lojaFechada: boolean
  subtotal: number
  taxaEntrega: number
  taxaServico: number
  valorTotal: number
  enviando: boolean
  onAlterarQuantidade: (idProduto: number, delta: number) => void
  onSubmit: () => void
}

export function CarrinhoCheckoutAside({
  form,
  itensCarrinho,
  enderecos,
  carregandoEnderecos,
  lojaFechada,
  subtotal,
  taxaEntrega,
  taxaServico,
  valorTotal,
  enviando,
  onAlterarQuantidade,
  onSubmit,
}: CarrinhoCheckoutAsideProps) {
  const {
    register,
    formState: { errors },
  } = form

  return (
    <aside className="flex flex-col justify-between space-y-5 rounded-2xl border border-surface-bg bg-surface p-6">
      <form onSubmit={onSubmit} className="space-y-4" noValidate>
        <h3 className="font-display text-xl font-semibold text-brand-dark">Resumo do Pedido</h3>

        {lojaFechada && (
          <div
            role="status"
            aria-live="polite"
            className="rounded-2xl border border-state-pending/50 bg-state-pending/15 px-3 py-2 text-xs font-medium text-brand-pit"
          >
            Esta loja está fechada no momento e não aceita novos pedidos.
          </div>
        )}

        {itensCarrinho.length === 0 ? (
          <p className="rounded-2xl bg-surface-bg/50 p-4 text-center text-xs text-text-default">
            Nenhum item adicionado. Selecione produtos da loja ao lado.
          </p>
        ) : (
          <ul className="divide-y divide-surface-bg">
            {itensCarrinho.map((item) => (
              <li
                key={item.produto.idProduto}
                className="flex items-center justify-between gap-2 py-2.5 text-sm"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold text-brand-dark">
                    {limparNomeProduto(item.produto.nome)}
                  </p>
                  <p className="text-xs text-text-default">
                    {formatarMoeda(item.produto.preco)} un.
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    aria-label={`Diminuir quantidade de ${limparNomeProduto(item.produto.nome)}`}
                    onClick={() => onAlterarQuantidade(item.produto.idProduto, -1)}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-surface-bg font-semibold text-brand-dark hover:bg-surface-bg"
                  >
                    <Minus className="h-3.5 w-3.5" aria-hidden="true" />
                  </button>
                  <span className="w-5 text-center font-semibold text-brand-dark">
                    {item.quantidade}
                  </span>
                  <button
                    type="button"
                    aria-label={`Aumentar quantidade de ${limparNomeProduto(item.produto.nome)}`}
                    onClick={() => onAlterarQuantidade(item.produto.idProduto, 1)}
                    className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-surface-bg font-semibold text-brand-dark hover:bg-surface-bg"
                  >
                    <Plus className="h-3.5 w-3.5" aria-hidden="true" />
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
        {errors.itens?.message && (
          <p className="text-xs font-medium text-state-error">{errors.itens.message}</p>
        )}

        <div>
          <label htmlFor="select-endereco" className="block text-xs font-semibold text-brand-dark">
            Endereço de entrega
          </label>
          <select
            id="select-endereco"
            disabled={carregandoEnderecos}
            {...register('idEndereco', { valueAsNumber: true })}
            className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-xs font-medium text-brand-dark outline-none focus:border-brand-outline"
          >
            {enderecos.length === 0 && <option value={0}>Nenhum endereço disponível</option>}
            {enderecos.map((end) => (
              <option key={end.idEndereco} value={end.idEndereco}>
                {end.apelido ? `${end.apelido}: ` : ''}
                {end.logradouro}, {end.numero} — {end.bairro}
              </option>
            ))}
          </select>
          {errors.idEndereco?.message && (
            <p className="mt-1 text-xs font-medium text-state-error">
              {errors.idEndereco.message}
            </p>
          )}
        </div>

        <div>
          <label htmlFor="select-pagto" className="block text-xs font-semibold text-brand-dark">
            Forma de Pagamento
          </label>
          <select
            id="select-pagto"
            {...register('formaPagamento')}
            className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-xs font-medium text-brand-dark outline-none focus:border-brand-outline"
          >
            <option value="pix">Pix</option>
            <option value="cartao_credito">Cartão de Crédito</option>
            <option value="cartao_debito">Cartão de Débito</option>
            <option value="dinheiro">Dinheiro</option>
          </select>
        </div>

        <div>
          <label htmlFor="obs-entrega" className="block text-xs font-semibold text-brand-dark">
            Observação de Entrega
          </label>
          <input
            id="obs-entrega"
            type="text"
            maxLength={255}
            placeholder="Ex.: Deixar na portaria"
            {...register('observacaoEntrega')}
            className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-xs text-brand-dark outline-none focus:border-brand-outline"
          />
          {errors.observacaoEntrega?.message && (
            <p className="mt-1 text-xs font-medium text-state-error">
              {errors.observacaoEntrega.message}
            </p>
          )}
        </div>

        <div className="space-y-3 border-t border-surface-bg pt-4">
          <div className="space-y-1 text-xs">
            <div className="flex justify-between">
              <span>Subtotal</span>
              <span className="font-semibold text-brand-dark">{formatarMoeda(subtotal)}</span>
            </div>
            <div className="flex justify-between">
              <span>Taxa de entrega</span>
              <span className="font-semibold text-brand-dark">{formatarMoeda(taxaEntrega)}</span>
            </div>
            <div className="flex justify-between">
              <span>Taxa de serviço</span>
              <span className="font-semibold text-brand-dark">{formatarMoeda(taxaServico)}</span>
            </div>
            <div className="flex justify-between border-t border-surface-bg pt-2 text-sm font-semibold text-brand-dark">
              <span>Total</span>
              <span>{formatarMoeda(valorTotal)}</span>
            </div>
          </div>

          <button
            type="submit"
            disabled={enviando || lojaFechada}
            className="min-h-11 w-full rounded-full bg-brand-lime px-5 py-3 text-sm font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {enviando ? 'Enviando pedido...' : 'Confirmar pedido'}
          </button>
        </div>
      </form>
    </aside>
  )
}
