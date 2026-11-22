/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Comércio e Finanças
 */
import { zodResolver } from '@hookform/resolvers/zod'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { type AvaliacaoFormValues, avaliacaoSchema } from '../schemas/comercio.schemas'

interface AvaliacaoPedidoFormProps {
  alvo: 'loja' | 'entregador'
  idPedido: number
  onEnviar: (alvo: 'loja' | 'entregador', idPedido: number, valores: AvaliacaoFormValues) => Promise<void>
}

export function AvaliacaoPedidoForm({ alvo, idPedido, onEnviar }: AvaliacaoPedidoFormProps) {
  const titulo = alvo === 'loja' ? 'Avaliar Loja' : 'Avaliar Entregador'
  const idNota = `nota-${alvo}-${idPedido}`
  const idComentario = `comentario-${alvo}-${idPedido}`

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<AvaliacaoFormValues>({
    resolver: zodResolver(avaliacaoSchema),
    defaultValues: { nota: 5, comentario: '' },
  })

  useEffect(() => {
    reset({ nota: 5, comentario: '' })
  }, [idPedido, reset])

  const submit = handleSubmit(async (valores) => {
    await onEnviar(alvo, idPedido, {
      nota: valores.nota,
      comentario: valores.comentario?.trim() || undefined,
    })
    reset({ nota: 5, comentario: '' })
  })

  return (
    <form
      onSubmit={submit}
      className="space-y-2 rounded-2xl border border-surface-bg p-3 text-xs"
      noValidate
    >
      <p className="font-semibold text-brand-dark">{titulo}</p>
      <div className="flex flex-wrap gap-2">
        <label htmlFor={idNota} className="sr-only">
          Nota para {alvo}
        </label>
        <select
          id={idNota}
          {...register('nota', { valueAsNumber: true })}
          className="rounded-2xl border border-surface-bg bg-surface px-3 py-1.5 text-brand-dark outline-none focus:border-brand-outline"
        >
          {[1, 2, 3, 4, 5].map((n) => (
            <option key={n} value={n}>
              {n} ★
            </option>
          ))}
        </select>

        <label htmlFor={idComentario} className="sr-only">
          Comentário para {alvo}
        </label>
        <input
          id={idComentario}
          type="text"
          placeholder="Comentário opcional"
          {...register('comentario')}
          className="min-w-0 flex-1 rounded-2xl border border-surface-bg bg-surface px-3 py-1.5 text-brand-dark outline-none focus:border-brand-outline"
        />
      </div>
      {errors.nota?.message && (
        <p className="font-medium text-state-error">{errors.nota.message}</p>
      )}
      {errors.comentario?.message && (
        <p className="font-medium text-state-error">{errors.comentario.message}</p>
      )}
      <button
        type="submit"
        disabled={isSubmitting}
        className="rounded-full bg-brand-lime px-3.5 py-1.5 font-semibold text-brand-dark transition-opacity hover:opacity-90 disabled:opacity-50"
      >
        {isSubmitting ? 'Enviando...' : `Enviar Avaliação (${alvo === 'loja' ? 'Loja' : 'Entregador'})`}
      </button>
    </form>
  )
}
