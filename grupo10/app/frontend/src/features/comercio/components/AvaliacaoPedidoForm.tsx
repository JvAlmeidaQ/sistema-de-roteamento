/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { zodResolver } from '@hookform/resolvers/zod'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { StarRating } from '@/components/StarRating'
import { type AvaliacaoFormValues, avaliacaoSchema } from '../schemas/comercio.schemas'

interface AvaliacaoPedidoFormProps {
  alvo: 'loja' | 'entregador'
  idPedido: number
  onEnviar: (alvo: 'loja' | 'entregador', idPedido: number, valores: AvaliacaoFormValues) => Promise<void>
}

export function AvaliacaoPedidoForm({ alvo, idPedido, onEnviar }: AvaliacaoPedidoFormProps) {
  const titulo = alvo === 'loja' ? 'Avaliar loja' : 'Avaliar entregador'
  const idComentario = `comentario-${alvo}-${idPedido}`

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<AvaliacaoFormValues>({
    resolver: zodResolver(avaliacaoSchema),
    defaultValues: { nota: 5, comentario: '' },
  })

  const notaAtual = watch('nota')

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
      className="space-y-2.5 rounded-2xl border border-surface-bg p-3 text-xs"
      noValidate
    >
      <div className="flex items-center justify-between gap-2">
        <p className="font-semibold text-brand-dark">{titulo}</p>
        <StarRating
          nota={notaAtual}
          interativo
          onChange={(n) => setValue('nota', n, { shouldValidate: true })}
          rotulo={`Nota para ${alvo}`}
        />
      </div>

      <div>
        <label htmlFor={idComentario} className="sr-only">
          Comentário para {alvo}
        </label>
        <input
          id={idComentario}
          type="text"
          placeholder="Comentário opcional"
          {...register('comentario')}
          className="w-full rounded-2xl border border-surface-bg bg-surface px-3 py-1.5 text-brand-dark outline-none focus:border-brand-outline"
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
        className="rounded-full bg-brand-lime px-3.5 py-1.5 font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80 disabled:opacity-50"
      >
        {isSubmitting ? 'Enviando...' : `Enviar avaliação`}
      </button>
    </form>
  )
}
