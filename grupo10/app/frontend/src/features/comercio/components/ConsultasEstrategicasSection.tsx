/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças (disponível em VITE_APP_MODE=bd e full)
 */
import type { ConsultaEstrategicaResponse } from '../types/comercio.types'
import { SkeletonBlock } from './SkeletonBlock'
import { formatarCelulaConsulta } from './StatusBadge'

const CONSULTAS_COMERCIO = [
  { numero: 5, titulo: 'C5 · Lojas com todas as formas de pagamento' },
  { numero: 6, titulo: 'C6 · Comissão entregador > parcela loja' },
  { numero: 7, titulo: 'C7 · Pedidos > R$ 100 com nota <= 2' },
  { numero: 8, titulo: 'C8 · Entregues sem avaliação completa' },
  { numero: 9, titulo: 'C9 · Pedido concluído de maior valor' },
  { numero: 10, titulo: 'C10 · Clientes Pix/dinheiro e crédito' },
  { numero: 11, titulo: 'C11 · Concluídos > R$ 250 + avaliação' },
  { numero: 12, titulo: 'C12 · Lojas repasse líquido > R$ 15 mil' },
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
        {CONSULTAS_COMERCIO.map((c) => {
          const ativa = consultaAtiva?.numero === c.numero
          return (
            <button
              key={c.numero}
              type="button"
              aria-pressed={ativa}
              onClick={() => onSelecionarConsulta(c.numero)}
              className={`rounded-full px-3.5 py-1.5 text-xs font-semibold transition-colors ${
                ativa
                  ? 'bg-brand-dark text-white'
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
          <SkeletonBlock linhas={4} label="Executando consulta SQL..." />
        </div>
      ) : consultaAtiva ? (
        <div className="overflow-x-auto rounded-2xl border border-surface-bg bg-surface p-6">
          <h3 className="font-display text-xl font-semibold text-brand-dark">
            Consulta {consultaAtiva.numero}: {consultaAtiva.titulo}
          </h3>
          <p className="mt-1 text-xs text-text-default">{consultaAtiva.descricao}</p>

          {carregando ? (
            <SkeletonBlock linhas={4} label="Atualizando resultado da consulta..." />
          ) : consultaAtiva.linhas.length === 0 ? (
            <p role="status" className="mt-4 text-sm text-text-default">
              Nenhum registro retornado por esta consulta na base atual.
            </p>
          ) : (
            <table className="mt-4 w-full border-collapse text-left text-sm">
              <thead>
                <tr className="border-b border-surface-bg text-xs font-semibold uppercase text-text-default">
                  {consultaAtiva.colunas.map((col) => (
                    <th key={col} className="py-2.5 pr-4">
                      {col}
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
