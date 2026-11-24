/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { formatarColunaConsulta } from '@/lib/apresentacao'
import type { ConsultaEstrategicaResponse } from '../types/comercio.types'
import { SkeletonBlock } from './SkeletonBlock'
import { formatarCelulaConsulta } from './StatusBadge'

const ANALISES_GERENCIAIS = [
  { numero: 5, titulo: 'Lojas com todas as formas de pagamento' },
  { numero: 6, titulo: 'Frete acima do repasse' },
  { numero: 7, titulo: 'Pedidos > R$ 100 com avaliação baixa' },
  { numero: 8, titulo: 'Entregues com avaliação pendente' },
  { numero: 9, titulo: 'Pedido concluído de maior valor' },
  { numero: 10, titulo: 'Clientes em múltiplos meios de pagamento' },
  { numero: 11, titulo: 'Concluídos > R$ 250 e avaliação' },
  { numero: 12, titulo: 'Repasse líquido > R$ 15 mil' },
]

interface ConsultasEstrategicasSectionProps {
  consultaAtiva: ConsultaEstrategicaResponse | null
  carregando: boolean
  onSelecionarConsulta: (numero: number) => void
}

export function ConsultasEstrategicasSection({
  consultaAtiva,
  carregando,
  onSelecionarConsulta,
}: ConsultasEstrategicasSectionProps) {
  return (
    <section className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {ANALISES_GERENCIAIS.map((c) => {
          const ativa = consultaAtiva?.numero === c.numero
          return (
            <button
              key={c.numero}
              type="button"
              aria-pressed={ativa}
              onClick={() => onSelecionarConsulta(c.numero)}
              className={`rounded-full px-3.5 py-1.5 text-xs font-semibold transition-colors ${
                ativa
                  ? 'bg-brand-lime text-brand-dark'
                  : 'border border-surface-bg bg-surface text-brand-dark hover:border-brand-outline'
              }`}
            >
              {c.titulo}
            </button>
          )
        })}
      </div>

      {carregando && !consultaAtiva ? (
        <div className="rounded-2xl border border-surface-bg bg-surface p-6">
          <SkeletonBlock linhas={4} label="Carregando análise..." />
        </div>
      ) : consultaAtiva ? (
        <div className="overflow-x-auto rounded-2xl border border-surface-bg bg-surface p-6">
          <h3 className="font-display text-xl font-semibold text-brand-dark">
            {consultaAtiva.titulo}
          </h3>
          <p className="mt-1 text-xs text-text-default">{consultaAtiva.descricao}</p>

          {carregando ? (
            <SkeletonBlock linhas={4} label="Atualizando resultado..." />
          ) : consultaAtiva.linhas.length === 0 ? (
            <p role="status" className="mt-4 text-sm text-text-default">
              Nenhum registro encontrado para esta análise.
            </p>
          ) : (
            <table className="mt-4 w-full border-collapse text-left text-sm">
              <thead>
                <tr className="border-b border-surface-bg text-xs font-semibold uppercase text-text-default">
                  {consultaAtiva.colunas.map((col) => (
                    <th key={col} className="py-2.5 pr-4">
                      {formatarColunaConsulta(col)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-surface-bg">
                {consultaAtiva.linhas.map((linha, idx) => (
                  <tr key={idx} className="hover:bg-surface-bg/30">
                    {consultaAtiva.colunas.map((col) => (
                      <td key={col} className="py-2.5 pr-4 tabular-nums text-brand-dark">
                        {formatarCelulaConsulta(col, linha[col])}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      ) : null}
    </section>
  )
}
