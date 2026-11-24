/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — badges semânticos de domínio e pontualidade (SLA)
 */
import type { DominioEvento } from '../types/auditoria.types'

const badgeBase = 'inline-flex items-center rounded-full px-3 py-0.5 text-xs font-semibold'

const ROTULO_STATUS: Record<string, string> = {
  aguardando_aprovacao: 'Aguardando aprovação',
  aprovado: 'Aprovado',
  recusado: 'Recusado',
  em_preparacao: 'Em preparação',
  pronto: 'Pronto para retirada',
  cancelado: 'Cancelado',
  pendente: 'Pendente de coleta',
  a_caminho: 'A caminho',
  entregue: 'Entregue',
  falha_entrega: 'Falha na entrega',
}

export function formatarStatusAuditoria(status: string): string {
  return ROTULO_STATUS[status] ?? status.replace(/_/g, ' ')
}

export function formatarDataHora(iso: string): string {
  const data = new Date(iso)
  if (Number.isNaN(data.getTime())) return iso
  return new Intl.DateTimeFormat('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'medium',
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