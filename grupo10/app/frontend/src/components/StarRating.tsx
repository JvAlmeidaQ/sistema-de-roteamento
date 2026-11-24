/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Componente padronizado de avaliação por estrelas.
 */
import { Star } from 'lucide-react'

interface StarRatingProps {
  nota: number
  interativo?: boolean
  onChange?: (nota: number) => void
  rotulo?: string
  tamanho?: 'sm' | 'md'
}

export function StarRating({
  nota,
  interativo = false,
  onChange,
  rotulo = 'Avaliação',
  tamanho = 'sm',
}: StarRatingProps) {
  const iconSize = tamanho === 'sm' ? 'h-4 w-4' : 'h-5 w-5'

  if (!interativo) {
    return (
      <span
        className="inline-flex items-center gap-0.5 text-brand-dark"
        aria-label={`${rotulo}: ${nota} de 5 estrelas`}
      >
        {[1, 2, 3, 4, 5].map((estrela) => (
          <Star
            key={estrela}
            className={`${iconSize} ${
              estrela <= Math.round(nota)
                ? 'fill-state-pending text-state-pending'
                : 'text-surface-bg'
            }`}
            aria-hidden="true"
          />
        ))}
        <span className="ml-1 text-xs font-semibold tabular-nums text-brand-dark">
          {Number.isInteger(nota) ? `${nota}/5` : nota.toFixed(1)}
        </span>
      </span>
    )
  }

  return (
    <div role="radiogroup" aria-label={rotulo} className="inline-flex items-center gap-1">
      {[1, 2, 3, 4, 5].map((estrela) => {
        const ativa = estrela <= nota
        return (
          <button
            key={estrela}
            type="button"
            role="radio"
            aria-checked={nota === estrela}
            aria-label={`${estrela} ${estrela === 1 ? 'estrela' : 'estrelas'}`}
            onClick={() => onChange?.(estrela)}
            className="rounded-md p-1 transition-transform hover:scale-110 focus-visible:outline-2 focus-visible:outline-brand-outline"
          >
            <Star
              className={`${iconSize} ${
                ativa ? 'fill-state-pending text-state-pending' : 'text-text-default/40'
              }`}
              aria-hidden="true"
            />
          </button>
        )
      })}
    </div>
  )
}
