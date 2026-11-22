/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import type { StatusPedido } from '../types/comercio.types'

const STATUS_CONFIG: Record<StatusPedido, { label: string; classes: string }> = {
  solicitado: {
    label: 'Solicitado',
    classes: 'bg-state-pending/15 text-brand-pit border-state-pending/40',
  },
  aceito: {
    label: 'Aceito (Aguard. Pagto)',
    classes: 'bg-state-pending/15 text-brand-pit border-state-pending/40',
  },
  pago: {
    label: 'Pago',
    classes: 'bg-state-progress/15 text-brand-dark border-state-progress/40',
  },
  em_preparacao: {
    label: 'Em Preparação',
    classes: 'bg-state-progress/15 text-brand-dark border-state-progress/40',
  },
  pronto: {
    label: 'Pronto p/ Entrega',
    classes: 'bg-brand-pulp/20 text-brand-dark border-brand-pulp/50',
  },
  concluido: {
    label: 'Concluído',
    classes: 'bg-state-success/15 text-brand-dark border-state-success/40',
  },
  recusado: {
    label: 'Recusado',
    classes: 'bg-state-cancelled/15 text-state-error border-state-cancelled/40',
  },
}

export function StatusBadge({ status }: { status: StatusPedido }) {
  const cfg = STATUS_CONFIG[status] ?? {
    label: status,
    classes: 'bg-surface-bg text-text-default border-surface-bg',
  }
  return (
    <span
      className={`inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold ${cfg.classes}`}
    >
      {cfg.label}
    </span>
  )
}

export function formatarMoeda(valor: number | null | undefined): string {
  if (valor == null) return 'R$ 0,00'
  return valor.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
}

export function formatarData(iso: string | null | undefined): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

export function formatarDataHora(iso: string | null | undefined): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })
}

export function formatarIdPedido(id: number): string {
  return `#${String(id).padStart(6, '0')}`
}

export function formatarCelulaConsulta(coluna: string, valor: unknown): string {
  if (valor == null) return '—'
  const col = coluna.toLowerCase()
  if (col === 'id_pedido' && typeof valor === 'number') {
    return formatarIdPedido(valor)
  }
  if (
    typeof valor === 'number' &&
    (col.includes('valor') ||
      col.includes('faturamento') ||
      col.includes('repasse') ||
      col.includes('comissao') ||
      col.includes('parcela') ||
      col.includes('taxa') ||
      col.includes('ticket'))
  ) {
    return formatarMoeda(valor)
  }
  if (col.startsWith('data_') && typeof valor === 'string') {
    return formatarDataHora(valor)
  }
  return String(valor)
}
