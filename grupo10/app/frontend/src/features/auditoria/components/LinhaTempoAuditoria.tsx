/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — visualização cronológica de eventos (RF05 / RN04)
 */
import type { DominioEvento } from '../types/auditoria.types'
import { DominioBadge, formatarDataHora, formatarStatusAuditoria } from './AuditoriaBadges'

export interface ItemTimeline {
  chave: string
  dominio: DominioEvento
  status: string
  dataHora: string
}

interface LinhaTempoAuditoriaProps {
  itens: ItemTimeline[]
  vazioMensagem?: string
}

export function LinhaTempoAuditoria({
  itens,
  vazioMensagem = 'Nenhum evento de auditoria registrado.',
}: LinhaTempoAuditoriaProps) {
  if (itens.length === 0) {
    return <p className="text-sm text-text-default">{vazioMensagem}</p>
  }

  return (
    <ol className="relative space-y-4 border-l-2 border-surface-bg pl-6">
      {itens.map((item, indice) => {
        const ultimo = indice === itens.length - 1
        return (
          <li key={item.chave} className="relative">
            <span
              aria-hidden="true"
              className={`absolute -left-[31px] top-1.5 h-3.5 w-3.5 rounded-full border-2 border-surface ${
                ultimo ? 'bg-brand-green' : 'bg-brand-outline/60'
              }`}
            />
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-surface-bg bg-surface p-4">
              <div className="space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <DominioBadge dominio={item.dominio} />
                  <span className="text-sm font-semibold text-brand-dark">
                    {formatarStatusAuditoria(item.status)}
                  </span>
                </div>
                <p className="text-xs text-text-default">
                  Etapa {indice + 1} de {itens.length} · Registro imutável (RN08)
                </p>
              </div>
              <time dateTime={item.dataHora} className="text-xs font-semibold tabular-nums text-brand-dark">
                {formatarDataHora(item.dataHora)}
              </time>
            </div>
          </li>
        )
      })}
    </ol>
  )
}