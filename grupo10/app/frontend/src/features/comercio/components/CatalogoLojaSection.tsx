/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças (disponível em VITE_APP_MODE=bd e full)
 */
import type { LojaCheckout, ProdutoCheckout } from '../types/comercio.types'
import { SkeletonBlock } from './SkeletonBlock'
import { formatarMoeda } from './StatusBadge'

interface CatalogoLojaSectionProps {
  lojas: LojaCheckout[]
  lojaAtual: LojaCheckout | null
  idLojaSelecionada: number
  carregandoLojas: boolean
  onTrocarLoja: (idLoja: number) => void
  onAdicionarProduto: (produto: ProdutoCheckout) => void
}

export function CatalogoLojaSection({
  lojas,
  lojaAtual,
  idLojaSelecionada,
  carregandoLojas,
  onTrocarLoja,
  onAdicionarProduto,
}: CatalogoLojaSectionProps) {
  return (
    <section className="space-y-4 rounded-2xl border border-surface-bg bg-surface p-6 lg:col-span-2">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <label htmlFor="select-loja" className="block text-xs font-semibold text-brand-dark">
            1. Escolha a Loja (RN01 — apenas lojas abertas aceitam pedidos)
          </label>
          <select
            id="select-loja"
            value={idLojaSelecionada || ''}
            onChange={(e) => onTrocarLoja(Number(e.target.value))}
            className="mt-1.5 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2.5 text-sm font-medium text-brand-dark outline-none focus:border-brand-outline sm:w-96"
          >
            {lojas.map((l) => (
              <option key={l.idLoja} value={l.idLoja}>
                {l.nome} — {l.statusFuncionamento === 'aberta' ? 'Aberta' : 'Fechada'} (Frete:{' '}
                {formatarMoeda(l.taxaEntrega)})
              </option>
            ))}
          </select>
        </div>

        {lojaAtual && (
          <span
            className={`rounded-full px-3 py-1 text-xs font-semibold ${
              lojaAtual.statusFuncionamento === 'aberta'
                ? 'bg-state-success/15 text-brand-dark'
                : 'bg-state-cancelled/15 text-state-error'
            }`}
          >
            {lojaAtual.statusFuncionamento === 'aberta' ? 'Loja Aberta' : 'Loja Fechada (RN01)'}
          </span>
        )}
      </div>

      <div className="pt-2">
        <h3 className="font-display text-lg font-semibold text-brand-dark">
          2. Produtos do Catálogo
        </h3>

        {carregandoLojas ? (
          <SkeletonBlock linhas={4} label="Carregando catálogo de produtos..." />
        ) : !lojaAtual || lojaAtual.produtos.length === 0 ? (
          <p className="mt-3 rounded-2xl bg-surface-bg/50 p-4 text-sm text-text-default">
            Nenhum produto disponível para a loja selecionada.
          </p>
        ) : (
          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
            {lojaAtual.produtos.map((produto) => (
              <div
                key={produto.idProduto}
                className="flex flex-col justify-between rounded-2xl border border-surface-bg p-4 transition-colors hover:border-brand-outline/50"
              >
                <div>
                  <div className="flex items-start justify-between gap-2">
                    <h4 className="font-display text-base font-semibold text-brand-dark">
                      {produto.nome}
                    </h4>
                    {!produto.ativo && (
                      <span className="rounded-full bg-state-cancelled/15 px-2.5 py-0.5 text-[11px] font-semibold text-state-error">
                        Inativo (RR04)
                      </span>
                    )}
                  </div>
                  {produto.descricao && (
                    <p className="mt-1 text-xs text-text-default">{produto.descricao}</p>
                  )}
                </div>

                <div className="mt-4 flex items-center justify-between">
                  <span className="text-base font-semibold text-brand-dark">
                    {formatarMoeda(produto.preco)}
                  </span>
                  <button
                    type="button"
                    onClick={() => onAdicionarProduto(produto)}
                    className="rounded-full border border-brand-dark px-4 py-1.5 text-xs font-semibold text-brand-dark transition-colors hover:border-brand-lime hover:bg-brand-lime"
                  >
                    + Adicionar
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </section>
  )
}
