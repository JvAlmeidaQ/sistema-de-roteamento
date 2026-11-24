/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Catálogo (RF07)
 */
import type { StatusFuncionamento } from '../types/catalogo.types'

interface StatusFuncionamentoToggleProps {
  status: StatusFuncionamento
  onToggle: (novoStatus: StatusFuncionamento) => void
  disabled?: boolean
}

export function StatusFuncionamentoToggle({
  status,
  onToggle,
  disabled = false,
}: StatusFuncionamentoToggleProps) {
  const isAberta = status === 'aberta'

  return (
    <div className="flex items-center gap-3">
      <span
        className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold ${
          isAberta
            ? 'bg-state-success/15 text-brand-dark border border-state-success/30'
            : 'bg-state-cancelled/15 text-state-error border border-state-cancelled/30'
        }`}
      >
        <span
          className={`mr-1.5 h-2 w-2 rounded-full ${
            isAberta ? 'bg-state-success' : 'bg-state-error'
          }`}
        />
        {isAberta ? 'Loja Aberta' : 'Loja Fechada'}
      </span>

      <button
        type="button"
        disabled={disabled}
        onClick={() => onToggle(isAberta ? 'fechada' : 'aberta')}
        className={`rounded-full px-4 py-1.5 text-xs font-semibold transition-all ${
          isAberta
            ? 'border border-state-error/40 bg-surface text-state-error hover:bg-state-error/10'
            : 'bg-brand-lime text-brand-dark hover:bg-brand-green/30'
        } disabled:opacity-50 disabled:cursor-not-allowed`}
        title="Alternar status de funcionamento (RF07)"
      >
        {disabled
          ? 'Atualizando...'
          : isAberta
            ? 'Fechar Loja (RF07)'
            : 'Abrir Loja (RF07)'}
      </button>
    </div>
  )
}
