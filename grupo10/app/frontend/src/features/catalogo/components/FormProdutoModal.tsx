/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Catálogo
 */
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { produtoSchema, type ProdutoFormValues } from '../schemas/catalogo.schemas'
import type { CategoriaResponse, ProdutoCatalogoResponse } from '../types/catalogo.types'

interface FormProdutoModalProps {
  aberto: boolean
  onFechar: () => void
  onSalvar: (valores: ProdutoFormValues) => Promise<void>
  produtoParaEditar?: ProdutoCatalogoResponse | null
  categoriasDisponiveis: CategoriaResponse[]
  salvando: boolean
}

export function FormProdutoModal({
  aberto,
  onFechar,
  onSalvar,
  produtoParaEditar,
  categoriasDisponiveis,
  salvando,
}: FormProdutoModalProps) {
  const isEdicao = !!produtoParaEditar

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors },
  } = useForm<ProdutoFormValues>({
    resolver: zodResolver(produtoSchema),
    defaultValues: {
      nome: '',
      descricao: '',
      preco: 0,
      categoriasIds: [],
    },
  })

  const categoriasSelecionadas = watch('categoriasIds') || []

  useEffect(() => {
    if (produtoParaEditar) {
      reset({
        nome: produtoParaEditar.nome,
        descricao: produtoParaEditar.descricao || '',
        preco: produtoParaEditar.preco,
        categoriasIds: produtoParaEditar.categorias.map((c) => c.idCategoria),
      })
    } else {
      reset({
        nome: '',
        descricao: '',
        preco: '' as unknown as number,
        categoriasIds: categoriasDisponiveis.length > 0 ? [categoriasDisponiveis[0].idCategoria] : [],
      })
    }
  }, [produtoParaEditar, categoriasDisponiveis, reset])

  if (!aberto) return null

  const toggleCategoria = (idCat: number) => {
    const jaSelecionada = categoriasSelecionadas.includes(idCat)
    if (jaSelecionada) {
      setValue(
        'categoriasIds',
        categoriasSelecionadas.filter((id) => id !== idCat),
        { shouldValidate: true }
      )
    } else {
      setValue('categoriasIds', [...categoriasSelecionadas, idCat], {
        shouldValidate: true,
      })
    }
  }

  const onSubmit = async (data: ProdutoFormValues) => {
    await onSalvar(data)
    onFechar()
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-xs"
      role="dialog"
      aria-modal="true"
    >
      <div className="w-full max-w-lg rounded-2xl bg-surface p-6 shadow-hover transition-all">
        <div className="flex items-center justify-between border-b border-surface-bg pb-3">
          <h3 className="font-display text-lg font-semibold text-brand-dark">
            {isEdicao ? 'Editar Produto do Catálogo' : 'Novo Produto do Catálogo'}
          </h3>
          <button
            type="button"
            onClick={onFechar}
            className="rounded-full p-1 text-text-default hover:bg-surface-bg hover:text-brand-dark"
          >
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="mt-4 space-y-4">
          <div>
            <label htmlFor="prod-nome" className="block text-xs font-semibold text-brand-dark">
              Nome do Produto *
            </label>
            <input
              id="prod-nome"
              type="text"
              placeholder="Ex: X-Salada Especial, Pizza Média..."
              {...register('nome')}
              className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
            />
            {errors.nome && (
              <p className="mt-1 text-xs text-state-error">{errors.nome.message}</p>
            )}
          </div>

          <div>
            <label htmlFor="prod-desc" className="block text-xs font-semibold text-brand-dark">
              Descrição (opcional)
            </label>
            <textarea
              id="prod-desc"
              rows={2}
              placeholder="Ingredientes, porção, detalhes..."
              {...register('descricao')}
              className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
            />
            {errors.descricao && (
              <p className="mt-1 text-xs text-state-error">{errors.descricao.message}</p>
            )}
          </div>

          <div>
            <label htmlFor="prod-preco" className="block text-xs font-semibold text-brand-dark">
              Preço Unitário (R$) * — <span className="text-[11px] font-normal text-text-default">RN09: maior que zero</span>
            </label>
            <input
              id="prod-preco"
              type="number"
              step="0.01"
              min="0.01"
              placeholder="0.00"
              {...register('preco', { valueAsNumber: true })}
              className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
            />
            {errors.preco && (
              <p className="mt-1 text-xs text-state-error">{errors.preco.message}</p>
            )}
          </div>

          <div>
            <label className="block text-xs font-semibold text-brand-dark">
              Categorias * — <span className="text-[11px] font-normal text-text-default">RR18: selecione ao menos uma</span>
            </label>
            {categoriasDisponiveis.length === 0 ? (
              <p className="mt-1 rounded-xl bg-state-pending/10 p-2 text-xs text-brand-pit">
                Nenhuma categoria cadastrada. Crie uma categoria na aba correspondente antes de cadastrar produtos.
              </p>
            ) : (
              <div className="mt-2 flex flex-wrap gap-2">
                {categoriasDisponiveis.map((cat) => {
                  const ativa = categoriasSelecionadas.includes(cat.idCategoria)
                  return (
                    <button
                      key={cat.idCategoria}
                      type="button"
                      onClick={() => toggleCategoria(cat.idCategoria)}
                      className={`rounded-full px-3 py-1 text-xs font-medium transition-all ${
                        ativa
                          ? 'bg-brand-lime text-brand-dark border border-brand-green/40 shadow-xs'
                          : 'bg-surface-bg/70 text-text-default hover:bg-surface-bg border border-transparent'
                      }`}
                    >
                      {ativa ? '✓ ' : '+ '}
                      {cat.nome}
                    </button>
                  )
                })}
              </div>
            )}
            {errors.categoriasIds && (
              <p className="mt-1 text-xs text-state-error">{errors.categoriasIds.message}</p>
            )}
          </div>

          <div className="flex items-center justify-end gap-3 border-t border-surface-bg pt-4">
            <button
              type="button"
              onClick={onFechar}
              disabled={salvando}
              className="rounded-full px-4 py-2 text-xs font-semibold text-text-default hover:bg-surface-bg"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={salvando || categoriasDisponiveis.length === 0}
              className="rounded-full bg-brand-lime px-6 py-2 text-xs font-semibold text-brand-dark shadow-low transition-all hover:bg-brand-green/30 disabled:opacity-50"
            >
              {salvando ? 'Salvando...' : isEdicao ? 'Salvar Alterações' : 'Cadastrar Produto'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
