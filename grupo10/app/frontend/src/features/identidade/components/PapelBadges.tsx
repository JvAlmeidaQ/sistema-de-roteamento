/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — papéis sobrepostos de Pessoa (RR16)
 */
import { ROTULO_VEICULO } from '../utils/formatadores'

interface PapelBadgesProps {
  cliente: boolean
  lojista: boolean
  entregador: boolean
  tipoVeiculo?: string | null
}

const badge = 'inline-flex items-center rounded-full px-3 py-0.5 text-xs font-semibold'

export function PapelBadges({ cliente, lojista, entregador, tipoVeiculo }: PapelBadgesProps) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {cliente && <span className={`${badge} bg-brand-lime/40 text-brand-dark`}>Cliente</span>}
      {lojista && <span className={`${badge} bg-state-pending/20 text-brand-pit`}>Lojista</span>}
      {entregador && (
        <span className={`${badge} bg-brand-outline/15 text-brand-outline`}>
          Entregador{tipoVeiculo ? ` · ${ROTULO_VEICULO[tipoVeiculo] ?? tipoVeiculo}` : ''}
        </span>
      )}
      {!cliente && !lojista && !entregador && (
        <span className={`${badge} bg-state-error/10 text-state-error`}>Sem função</span>
      )}
    </div>
  )
}
