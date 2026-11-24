/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — badges semânticos de domínio e pontualidade (SLA)
 */
import { formatarStatusEntrega, formatarStatusPedido } from '@/lib/apresentacao'
import type { DominioEvento } from '../types/auditoria.types'

const badgeBase = 'inline-flex items-center rounded-full px-3 py-0.5 text-xs font-semibold'

export function formatarStatusAuditoria(status: string): string {
  const pedido = formatarStatusPedido(status)
  if (pedido !== status) return pedido
  const entrega = formatarStatusEntrega(status)
  if (entrega !== status) return entrega
  return status.replace(/_/g, ' ')
}

export function formatarDataHora(iso: string): string {
  const data = new Date(iso)
  if (Number.isNaN(data.getTime())) return iso
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(data)
}

export function DominioBadge({ dominio }: { dominio: DominioEvento }) {
  if (dominio === 'COMERCIAL') {
    return <span className={`${badgeBase} bg-brand-lime/40 text-brand-dark`}>Comercial</span>
  }
  return <span className={`${badgeBase} bg-brand-outline/15 text-brand-outline`}>Logístico</span>
}

export function SlaBadge({ atrasada, desvioMinutos }: { atrasada: boolean; desvioMinutos: number }) {
  const sinal = desvioMinutos > 0 ? '+' : ''
  const textoDesvio = `${sinal}${desvioMinutos.toFixed(1)} min`

  if (atrasada) {
    return (
      <span className={`${badgeBase} bg-state-error/10 text-state-error tabular-nums`}>
        Atrasada ({textoDesvio})
      </span>
    )
  }
  return (
    <span className={`${badgeBase} bg-state-success/15 text-brand-dark tabular-nums`}>
      No prazo ({textoDesvio})
    </span>
  )
}