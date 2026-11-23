/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística (RF05)
 */
import { Link, useLocation, useParams } from 'react-router-dom'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { SkeletonBlock } from '@/features/comercio/components/SkeletonBlock'
import { StatusBadge, formatarDataHora, formatarIdPedido } from '@/features/comercio/components/StatusBadge'
import { MENSAGEM_ID_INVALIDO, useRastreioPedido } from '../hooks/useRastreioPedido'
import { statusEntregaRastreioSchema, statusPedidoSchema } from '../schemas/logistica.schemas'
import type { EventoRastreio, RastreioPedidoResponse } from '../types/rastreio.types'
import { botaoSecundarioClass, secaoPainelClass, statusEntregaInfo } from './painel.styles'

const badgeClass = 'inline-flex rounded-full px-3 py-1 text-xs font-semibold'
const alertaClass = 'rounded-2xl border border-state-error/50 bg-surface px-4 py-3 text-sm text-brand-dark'

function StatusRastreio({ tipo, status }: Pick<EventoRastreio, 'tipo' | 'status'>) {
  if (tipo === 'PEDIDO') {
    if (status === 'recusado') {
      return (
        <span className={`${badgeClass} border border-state-cancelled/40 bg-state-cancelled/15 text-brand-pit`}>
          Recusado
        </span>
      )
    }
    const statusPedido = statusPedidoSchema.options.find((valor) => valor === status)
    if (statusPedido) return <StatusBadge status={statusPedido} />
  } else {
    const statusEntrega = statusEntregaRastreioSchema.options.find((valor) => valor === status)
    if (statusEntrega) {
      const { rotulo, classes } = statusEntregaInfo[statusEntrega]
      return <span className={`${badgeClass} ${classes}`}>{rotulo}</span>
    }
  }

  return <span className={`${badgeClass} bg-surface-bg text-text-default`}>Status não reconhecido</span>
}

function DataHora({ valor }: { valor: string }) {
  return Number.isFinite(Date.parse(valor))
    ? <time dateTime={valor}>{formatarDataHora(valor)}</time>
    : <span>Data e hora não informadas</span>
}

function ResumoRastreio({ dados }: { dados: RastreioPedidoResponse }) {
  const { entrega, nomeLoja, statusPedido } = dados

  return (
    <section aria-labelledby="rastreio-resumo" className={secaoPainelClass}>
      <div>
        <h3 id="rastreio-resumo" className="text-2xl">Situação atual</h3>
        <p className="wrap-break-word text-sm">Loja: <strong className="text-brand-dark">{nomeLoja}</strong></p>
      </div>
      <dl className="grid gap-4 sm:grid-cols-3">
        <div className="space-y-1">
          <dt className="text-sm font-semibold text-brand-dark">Status do pedido</dt>
          <dd><StatusRastreio tipo="PEDIDO" status={statusPedido} /></dd>
        </div>
        <div className="space-y-1">
          <dt className="text-sm font-semibold text-brand-dark">Status da entrega</dt>
          <dd className="text-sm">
            {entrega ? <StatusRastreio tipo="ENTREGA" status={entrega.status} /> : 'Nenhuma entrega vinculada ao pedido.'}
          </dd>
        </div>
        {entrega && (
          <div className="space-y-1">
            <dt className="text-sm font-semibold text-brand-dark">Previsão de entrega</dt>
            <dd className="text-sm tabular-nums"><DataHora valor={entrega.previsaoEntrega} /></dd>
          </div>
        )}
      </dl>
    </section>
  )
}

function LinhaDoTempo({ eventos, historicoIncompleto }: Pick<RastreioPedidoResponse, 'eventos' | 'historicoIncompleto'>) {
  return (
    <section aria-labelledby="rastreio-historico" className={secaoPainelClass}>
      <h3 id="rastreio-historico" className="text-2xl">Linha do tempo</h3>
      {historicoIncompleto && (
        <p className="rounded-xl bg-state-pending/15 px-4 py-3 text-sm text-brand-pit">
          <strong>Histórico incompleto.</strong> A linha do tempo mostra apenas os eventos registrados.
        </p>
      )}
      {eventos.length === 0 ? (
        <p className="rounded-xl bg-surface-bg/50 p-4 text-sm">Nenhum evento registrado para este pedido.</p>
      ) : (
        <ol role="list" className="ms-2 space-y-3 border-s-2 border-surface-bg">
          {eventos.map((evento, indice) => (
            <li key={`${evento.tipo}-${evento.dataHora}-${indice}`} className="relative ps-5">
              <span aria-hidden="true" className="absolute -start-2 top-4 size-3.5 rounded-full border-2 border-surface bg-brand-outline" />
              <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2 rounded-xl bg-surface-bg/50 px-3 py-2 sm:px-4">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-sm font-semibold text-brand-dark">{evento.tipo === 'PEDIDO' ? 'Pedido' : 'Entrega'}</span>
                  <StatusRastreio tipo={evento.tipo} status={evento.status} />
                </div>
                <span className="text-sm tabular-nums"><DataHora valor={evento.dataHora} /></span>
              </div>
            </li>
          ))}
        </ol>
      )}
    </section>
  )
}

function RastreioDaSessao({ idPedido }: { idPedido: number }) {
  const { estado, atualizar } = useRastreioPedido(idPedido)
  const carregando = estado.tipo === 'carregando'

  return (
    <div className="space-y-4">
      <div className="flex sm:justify-end">
        <button type="button" disabled={carregando} onClick={atualizar} className={`${botaoSecundarioClass} w-full sm:w-auto`}>
          Atualizar rastreio
        </button>
      </div>
      {carregando && (
        <div className={secaoPainelClass}>
          <p role="status" className="text-sm">Carregando rastreio…</p>
          <div aria-hidden="true" className="motion-reduce:[&_*]:animate-none">
            <SkeletonBlock linhas={3} />
          </div>
        </div>
      )}
      {estado.tipo === 'erro' && <p role="alert" className={alertaClass}>{estado.mensagem}</p>}
      {estado.tipo === 'sucesso' && (
        <>
          <ResumoRastreio dados={estado.dados} />
          <LinhaDoTempo eventos={estado.dados.eventos} historicoIncompleto={estado.dados.historicoIncompleto} />
        </>
      )}
    </div>
  )
}

export default function RastreioPedido() {
  const { id } = useParams<'id'>()
  const { state } = useLocation()
  const { usuarioAtual, carregandoUsuarios } = useSessaoUsuario()
  const idPedido = Number(id)
  const idValido = /^\d+$/.test(id ?? '') && Number.isSafeInteger(idPedido) && idPedido > 0
  const veioDoPainel = state?.origemRastreio === 'painel-entregador'

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <Link replace to={veioDoPainel ? '/painel-entregador' : '/pedidos'} className={botaoSecundarioClass}>
        {veioDoPainel ? 'Voltar ao painel do entregador' : 'Voltar aos pedidos'}
      </Link>
      <header className="space-y-1">
        <p className="text-sm font-semibold uppercase tracking-wide text-brand-dark">Logística</p>
        <h2 className="text-3xl sm:text-4xl">Rastreio de pedido e entrega</h2>
        {idValido && <p className="font-semibold text-brand-dark">Pedido {formatarIdPedido(idPedido)}</p>}
      </header>

      {!idValido ? (
        <p role="alert" className={alertaClass}>{MENSAGEM_ID_INVALIDO}</p>
      ) : carregandoUsuarios ? (
        <p role="status" className={secaoPainelClass}>Carregando a sessão…</p>
      ) : usuarioAtual ? (
        // Remonta a consulta ao trocar o contexto para não renderizar dados anteriores, nem por um frame.
        <RastreioDaSessao key={`${usuarioAtual.idPessoa}:${idPedido}`} idPedido={idPedido} />
      ) : (
        <p role="status" className={secaoPainelClass}>Selecione uma conta no menu de sessão para consultar o rastreio.</p>
      )}
    </div>
  )
}
