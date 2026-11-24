/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import { Link } from 'react-router-dom'
import { formatarDataHora, formatarIdPedido } from '@/features/comercio/components/StatusBadge'
import { formatarCodigoRota, limparNomeLoja } from '@/lib/apresentacao'
import type { AcaoEntrega } from '../hooks/usePainelEntregador'
import type { EntregaDaRota, RotaAtual } from '../types/logistica.types'
import { botaoPrimarioClass, linkRastreioClass, secaoPainelClass, statusEntregaInfo } from './painel.styles'

const TRANSICOES = {
  aceita: { rotulo: 'Registrar retirada', pendente: 'Registrando retirada…', status: 'a_caminho' },
  a_caminho: { rotulo: 'Finalizar', pendente: 'Finalizando…', status: 'entregue' },
  entregue: null,
} as const

interface ControlesEntrega {
  ocupado: boolean
  acaoPendente: AcaoEntrega | null
  onAcao: (acao: AcaoEntrega) => void
}

function EntregaCard({
  entrega,
  ocupado,
  acaoPendente,
  onAcao,
}: ControlesEntrega & { entrega: EntregaDaRota }) {
  const pedido = formatarIdPedido(entrega.idPedido)
  const status = statusEntregaInfo[entrega.status]
  const transicao = TRANSICOES[entrega.status]
  const pendente = acaoPendente?.idEntrega === entrega.idEntrega
  const detalhesDestino = [
    ['Complemento', entrega.complementoEntrega],
    ['Referência', entrega.referenciaEntrega],
    ['Observação', entrega.observacaoEntrega],
  ] as const

  return (
    <li className="min-w-0 space-y-4 rounded-2xl border border-surface-bg p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <h4 className="text-xl">{pedido}</h4>
          <p className="wrap-break-word text-sm">{limparNomeLoja(entrega.nomeLoja)}</p>
          <Link
            to={`/rastreio/${entrega.idPedido}`}
            state={{ origemRastreio: 'painel-entregador' }}
            aria-label={`Ver rastreio de ${pedido}`}
            className={linkRastreioClass}
          >
            Ver rastreio
          </Link>
        </div>
        <div className="flex flex-wrap gap-2">
          <span className={`rounded-full px-3 py-1 text-xs font-semibold ${status.classes}`}>
            {status.rotulo}
          </span>
          {entrega.atrasada && (
            <span className="rounded-full bg-state-error/10 px-3 py-1 text-xs font-semibold text-brand-pit">
              Em atraso
            </span>
          )}
        </div>
      </div>

      <dl className="space-y-3 wrap-break-word text-sm">
        <div>
          <dt className="font-semibold text-brand-dark">Coleta</dt>
          <dd>{entrega.enderecoColeta}</dd>
        </div>
        <div>
          <dt className="font-semibold text-brand-dark">Destino</dt>
          <dd>{entrega.enderecoEntrega}</dd>
        </div>
        {detalhesDestino.map(([rotulo, valor]) => valor && (
          <div key={rotulo}>
            <dt className="font-semibold text-brand-dark">{rotulo}</dt>
            <dd className="whitespace-pre-wrap">{valor}</dd>
          </div>
        ))}
        <div>
          <dt className="font-semibold text-brand-dark">Previsão de entrega</dt>
          <dd><time dateTime={entrega.previsaoEntrega}>{formatarDataHora(entrega.previsaoEntrega)}</time></dd>
        </div>
      </dl>

      {transicao && (
        <button
          type="button"
          disabled={ocupado}
          aria-label={`${pendente ? transicao.pendente : transicao.rotulo} · Pedido ${pedido}`}
          onClick={() => onAcao({
            idEntrega: entrega.idEntrega,
            idPedido: entrega.idPedido,
            tipo: transicao.status,
          })}
          className={`${botaoPrimarioClass} w-full sm:w-auto`}
        >
          {pendente ? transicao.pendente : transicao.rotulo}
        </button>
      )}
    </li>
  )
}

export function RotaAtualSection({ rota, ...controles }: ControlesEntrega & { rota: RotaAtual | null }) {
  return (
    <section aria-labelledby="logistica-rota-atual" className={secaoPainelClass}>
      <div>
        <h3 id="logistica-rota-atual" className="text-2xl">Rota atual</h3>
        {rota && (
          <p className="text-sm">
            {formatarCodigoRota(rota.idRota)} · Aberta em{' '}
            <time dateTime={rota.criadaEm}>{formatarDataHora(rota.criadaEm)}</time>
            {' · '}{rota.totalEntregas} de 2 entregas vinculadas
          </p>
        )}
      </div>

      {rota ? (
        <>
          <dl className="grid grid-cols-3 gap-2 sm:gap-4">
            {[
              ['Vagas livres', rota.vagas],
              ['Ativas', rota.entregasAtivas],
              ['Em atraso', rota.entregasAtrasadas],
            ].map(([rotulo, valor]) => (
              <div key={rotulo} className="rounded-xl bg-surface-bg/50 px-2 py-3 text-center sm:px-4">
                <dt className="text-xs font-semibold text-brand-dark sm:text-sm">{rotulo}</dt>
                <dd className="font-display text-2xl tabular-nums sm:text-3xl">{valor}</dd>
              </div>
            ))}
          </dl>
          <ul role="list" aria-label="Entregas da rota atual" className="grid gap-4 md:grid-cols-2">
            {rota.entregas.map((entrega) => (
              <EntregaCard key={entrega.idEntrega} entrega={entrega} {...controles} />
            ))}
          </ul>
        </>
      ) : (
        <p className="rounded-xl bg-surface-bg/50 p-4 text-sm">
          Você não tem uma rota aberta. Assuma uma entrega da fila para abrir uma rota.
        </p>
      )}
      <p className="border-t border-surface-bg pt-4 text-xs text-text-default">
        Limite de 2 entregas por rota até a finalização das entregas ativas.
      </p>
    </section>
  )
}
