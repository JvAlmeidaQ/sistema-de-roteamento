/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { StarRating } from '@/components/StarRating'
import { limparNomeLoja } from '@/lib/apresentacao'
import type { ResumoFinanceiroLoja } from '../types/comercio.types'
import { SkeletonBlock } from './SkeletonBlock'
import { formatarMoeda } from './StatusBadge'

interface VisaoResumoFinanceiroTableProps {
  resumoLojas: ResumoFinanceiroLoja[]
  carregando: boolean
}

export function VisaoResumoFinanceiroTable({
  resumoLojas,
  carregando,
}: VisaoResumoFinanceiroTableProps) {
  return (
    <section className="overflow-x-auto rounded-2xl border border-surface-bg bg-surface p-6">
      <h3 className="font-display text-xl font-semibold text-brand-dark">
        Resumo financeiro por loja
      </h3>

      {carregando ? (
        <SkeletonBlock linhas={5} label="Carregando resumo financeiro das lojas..." />
      ) : resumoLojas.length === 0 ? (
        <p role="status" className="py-8 text-center text-sm text-text-default">
          Nenhum dado financeiro consolidado encontrado.
        </p>
      ) : (
        <table className="mt-4 w-full border-collapse text-left text-sm">
          <thead>
            <tr className="border-b border-surface-bg text-xs font-semibold uppercase text-text-default">
              <th className="py-3 pr-4">Loja</th>
              <th className="py-3 pr-4 text-right">Concluídos</th>
              <th className="py-3 pr-4 text-right">Faturamento bruto</th>
              <th className="py-3 pr-4 text-right">Repasse loja</th>
              <th className="py-3 pr-4 text-right">Comissão entreg.</th>
              <th className="py-3 pr-4 text-right">Receita plataforma</th>
              <th className="py-3 text-right">Avaliação</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-surface-bg">
            {resumoLojas.map((r) => (
              <tr key={r.idLoja} className="hover:bg-surface-bg/30">
                <td className="py-3 pr-4 font-semibold text-brand-dark">
                  {limparNomeLoja(r.nomeLoja)}
                </td>
                <td className="py-3 pr-4 text-right tabular-nums">{r.pedidosConcluidos}</td>
                <td className="py-3 pr-4 text-right font-medium tabular-nums">
                  {formatarMoeda(r.faturamentoBruto)}
                </td>
                <td className="py-3 pr-4 text-right font-semibold tabular-nums text-brand-outline">
                  {formatarMoeda(r.repasseTotalLoja)}
                </td>
                <td className="py-3 pr-4 text-right tabular-nums">
                  {formatarMoeda(r.totalComissaoEntregadores)}
                </td>
                <td className="py-3 pr-4 text-right tabular-nums">
                  {formatarMoeda(r.receitaPlataforma)}
                </td>
                <td className="py-3 text-right">
                  {r.mediaAvaliacaoLoja != null ? (
                    <StarRating nota={Number(r.mediaAvaliacaoLoja)} rotulo={`Média de ${limparNomeLoja(r.nomeLoja)}`} />
                  ) : (
                    '—'
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
