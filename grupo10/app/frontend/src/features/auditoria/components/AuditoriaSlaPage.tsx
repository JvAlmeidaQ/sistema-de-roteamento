/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — RF10 (painel de SLA e pontualidade de entregas)
 */
import { useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Link } from 'react-router-dom'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { formatarCodigoPedido, formatarCodigoRota, limparNomeLoja } from '@/lib/apresentacao'
import { useSlaEntregas } from '../hooks/useAuditoria'
import { filtroSlaSchema, type FiltroSlaFormValues } from '../schemas/auditoria.schemas'
import type { FiltroSlaEntregas } from '../types/auditoria.types'
import { formatarDataHora, SlaBadge } from './AuditoriaBadges'

const inputClass =
  'mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline focus-visible:ring-2 focus-visible:ring-brand-outline/30'

export default function AuditoriaSlaPage() {
  const { papelAtivo } = useSessaoUsuario()
  const [filtrosAplicados, setFiltrosAplicados] = useState<FiltroSlaEntregas>({})
  const { itens, carregando, erro } = useSlaEntregas(filtrosAplicados)
  const mostrarFiltroLoja = papelAtivo === 'admin'

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<FiltroSlaFormValues>({
    resolver: zodResolver(filtroSlaSchema),
    defaultValues: { idLoja: '', inicio: '', fim: '', apenasAtrasadas: false },
  })

  const onSubmit = (valores: FiltroSlaFormValues) => {
    setFiltrosAplicados({
      idLoja: valores.idLoja ? Number(valores.idLoja) : undefined,
      apenasAtrasadas: valores.apenasAtrasadas,
      inicio: valores.inicio ? new Date(valores.inicio).toISOString() : undefined,
      fim: valores.fim ? new Date(valores.fim).toISOString() : undefined,
    })
  }

  const limparFiltros = () => {
    reset({ idLoja: '', inicio: '', fim: '', apenasAtrasadas: false })
    setFiltrosAplicados({})
  }

  const metricas = useMemo(() => {
    const total = itens.length
    const atrasadas = itens.filter((i) => i.atrasada).length
    const taxaPontualidade = total > 0 ? ((total - atrasadas) / total) * 100 : 0
    const desvioMedio = total > 0 ? itens.reduce((acc, i) => acc + i.desvioMinutos, 0) / total : 0
    return { total, atrasadas, taxaPontualidade, desvioMedio }
  }, [itens])

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div className="space-y-1">
          <Link to="/auditoria" className="text-sm font-semibold text-brand-outline hover:underline">
            ← Rastreamento e Histórico
          </Link>
          <h2 className="text-3xl">
            {papelAtivo === 'entregador' ? 'Meu SLA de Entregas' : 'Auditoria de SLA de Entregas'}
          </h2>
          <p className="text-sm text-text-default">
            {papelAtivo === 'entregador'
              ? 'Acompanhe a pontualidade e eventuais atrasos das suas entregas concluídas.'
              : 'Comparação entre a previsão contratada e o horário real de entrega.'}
          </p>
        </div>
      </header>

      {/* Filtros contextuais */}
      <section className="rounded-2xl border border-surface-bg bg-surface p-6 shadow-low">
        <form onSubmit={handleSubmit(onSubmit)} noValidate className="space-y-4">
          <div className={`grid gap-4 ${mostrarFiltroLoja ? 'md:grid-cols-3' : 'md:grid-cols-2'}`}>
            {mostrarFiltroLoja && (
              <div>
                <label htmlFor="sla-loja" className="block text-xs font-semibold text-brand-dark">
                  ID da Loja (opcional)
                </label>
                <input id="sla-loja" inputMode="numeric" placeholder="Todas" {...register('idLoja')} className={inputClass} />
                {errors.idLoja && <p role="alert" className="mt-1 text-xs text-state-error">{errors.idLoja.message}</p>}
              </div>
            )}

            <div>
              <label htmlFor="sla-inicio" className="block text-xs font-semibold text-brand-dark">
                Início do período
              </label>
              <input id="sla-inicio" type="datetime-local" {...register('inicio')} className={inputClass} />
            </div>

            <div>
              <label htmlFor="sla-fim" className="block text-xs font-semibold text-brand-dark">
                Fim do período
              </label>
              <input id="sla-fim" type="datetime-local" {...register('fim')} className={inputClass} />
              {errors.fim && <p role="alert" className="mt-1 text-xs text-state-error">{errors.fim.message}</p>}
            </div>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
            <label className="flex cursor-pointer items-center gap-2 text-sm font-semibold text-brand-dark">
              <input type="checkbox" {...register('apenasAtrasadas')} className="accent-brand-green" />
              Exibir apenas entregas atrasadas
            </label>

            <div className="flex gap-2">
              <button
                type="button"
                onClick={limparFiltros}
                className="rounded-full border border-brand-outline px-4 py-2 text-xs font-semibold text-brand-outline hover:bg-brand-lime/20"
              >
                Limpar filtros
              </button>
              <button
                type="submit"
                className="rounded-full bg-brand-lime px-5 py-2 text-xs font-semibold text-brand-dark shadow-low hover:bg-brand-green/40"
              >
                Aplicar filtros
              </button>
            </div>
          </div>
        </form>
      </section>

      {/* Cards de resumo */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-2xl border border-surface-bg bg-surface p-5 shadow-low">
          <p className="text-xs font-semibold text-text-default">Entregas auditadas</p>
          <p className="mt-1 text-2xl font-bold tabular-nums text-brand-dark">{metricas.total}</p>
        </div>
        <div className="rounded-2xl border border-surface-bg bg-surface p-5 shadow-low">
          <p className="text-xs font-semibold text-text-default">Entregas atrasadas</p>
          <p className="mt-1 text-2xl font-bold tabular-nums text-state-error">{metricas.atrasadas}</p>
        </div>
        <div className="rounded-2xl border border-surface-bg bg-surface p-5 shadow-low">
          <p className="text-xs font-semibold text-text-default">Pontualidade (SLA)</p>
          <p className="mt-1 text-2xl font-bold tabular-nums text-brand-dark">
            {metricas.taxaPontualidade.toFixed(1)}%
          </p>
        </div>
        <div className="rounded-2xl border border-surface-bg bg-surface p-5 shadow-low">
          <p className="text-xs font-semibold text-text-default">Desvio médio</p>
          <p className="mt-1 text-2xl font-bold tabular-nums text-brand-dark">
            {metricas.desvioMedio > 0 ? '+' : ''}
            {metricas.desvioMedio.toFixed(1)} min
          </p>
        </div>
      </div>

      {/* Tabela de resultados */}
      <section className="overflow-hidden rounded-2xl border border-surface-bg bg-surface shadow-low">
        {carregando ? (
          <div className="p-6" role="status" aria-label="Carregando relatório de SLA">
            <div className="h-48 animate-pulse rounded-2xl bg-surface-bg/60 motion-reduce:animate-none" />
          </div>
        ) : erro ? (
          <p role="alert" className="m-6 rounded-2xl bg-state-error/10 px-4 py-3 text-sm text-state-error">
            {erro.status === 403
              ? 'Você não tem permissão para consultar este relatório de SLA.'
              : erro.mensagem}
          </p>
        ) : itens.length === 0 ? (
          <p className="p-6 text-sm text-text-default">Nenhuma entrega encontrada para os filtros selecionados.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[680px] text-left text-sm">
              <caption className="sr-only">Relatório de SLA e pontualidade das entregas</caption>
              <thead className="border-b border-surface-bg bg-surface-bg/40 text-xs font-semibold text-brand-dark">
                <tr>
                  <th scope="col" className="px-5 py-3">Pedido / Entrega</th>
                  <th scope="col" className="px-5 py-3">Loja</th>
                  <th scope="col" className="px-5 py-3">Previsão</th>
                  <th scope="col" className="px-5 py-3">Entregue em</th>
                  <th scope="col" className="px-5 py-3">SLA</th>
                  <th scope="col" className="px-5 py-3 text-right">Rastreio</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-surface-bg">
                {itens.map((item) => (
                  <tr key={item.idEntrega} className="hover:bg-surface-bg/20">
                    <td className="px-5 py-3 tabular-nums">
                      <span className="font-semibold text-brand-dark">{formatarCodigoPedido(item.idPedido)}</span>
                      <span className="block text-xs text-text-default">
                        Entrega {item.idEntrega}
                        {item.idRota ? ` · ${formatarCodigoRota(item.idRota)}` : ''}
                      </span>
                    </td>
                    <td className="px-5 py-3">
                      <span className="font-semibold text-brand-dark">{limparNomeLoja(item.nomeLoja)}</span>
                      <span className="block text-xs text-text-default tabular-nums">Loja {item.idLoja}</span>
                    </td>
                    <td className="px-5 py-3 text-xs tabular-nums">{formatarDataHora(item.previsaoEntrega)}</td>
                    <td className="px-5 py-3 text-xs tabular-nums">{formatarDataHora(item.entregueEm)}</td>
                    <td className="px-5 py-3">
                      <SlaBadge atrasada={item.atrasada} desvioMinutos={item.desvioMinutos} />
                    </td>
                    <td className="px-5 py-3 text-right">
                      <Link
                        to={`/auditoria?tipo=pedido&id=${item.idPedido}`}
                        className="text-xs font-semibold text-brand-outline hover:underline"
                      >
                        Ver linha do tempo →
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  )
}