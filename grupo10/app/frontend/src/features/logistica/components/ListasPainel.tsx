/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import { Link } from 'react-router-dom'
import { formatarDataHora, formatarIdPedido } from '@/features/comercio/components/StatusBadge'
import type { AcaoEntrega } from '../hooks/usePainelEntregador'
import type { EntregaDisponivel, Pagina, RotaAtual, RotaResumo } from '../types/logistica.types'
import { botaoPrimarioClass, botaoSecundarioClass, linkRastreioClass, secaoPainelClass } from './painel.styles'

interface ListaPaginadaProps<T> {
  lista: Pagina<T>
  ocupado: boolean
  onPaginar: (pagina: number) => void
}

type PaginacaoProps = Omit<ListaPaginadaProps<unknown>, 'lista'> & {
  lista: Pick<Pagina<unknown>, 'pagina' | 'temProxima'>
  rotulo: string
}

function Paginacao({ lista: { pagina, temProxima }, ocupado, onPaginar, rotulo }: PaginacaoProps) {
  return (
    <nav aria-label={rotulo} className="flex flex-wrap items-center justify-between gap-2">
      <button
        type="button"
        disabled={ocupado || pagina <= 1}
        onClick={() => onPaginar(pagina - 1)}
        className={botaoSecundarioClass}
      >
        Anterior
      </button>
      <span role="status" className="text-sm tabular-nums">Página {pagina}</span>
      <button
        type="button"
        disabled={ocupado || !temProxima}
        onClick={() => onPaginar(pagina + 1)}
        className={botaoSecundarioClass}
      >
        Próxima
      </button>
    </nav>
  )
}

interface DisponiveisProps extends ListaPaginadaProps<EntregaDisponivel> {
  rota: RotaAtual | null
  idAssumindo?: number
  onAssumir: (acao: AcaoEntrega) => void
}

export function EntregasDisponiveisSection({ lista, ocupado, onPaginar, rota, idAssumindo, onAssumir }: DisponiveisProps) {
  const temAtraso = rota !== null && rota.entregasAtrasadas > 0
  const lotada = rota !== null && rota.vagas <= 0
  const bloqueada = temAtraso || lotada

  return (
    <section aria-labelledby="logistica-disponiveis" className={secaoPainelClass}>
      <div>
        <h3 id="logistica-disponiveis" className="text-2xl">Entregas disponíveis</h3>
        <p className="text-sm">O endereço completo só aparece após assumir a entrega.</p>
      </div>

      {bloqueada && (
        <div id="logistica-bloqueio" className="space-y-1 rounded-xl border border-state-pending/40 bg-state-pending/10 p-4 text-sm text-brand-pit">
          <p className="font-semibold">Não é possível assumir outra entrega agora.</p>
          {temAtraso && <p>Há entregas em atraso na sua rota. Finalize as atrasadas antes de assumir outra.</p>}
          {lotada && <p>A rota está lotada. As entregas concluídas ocupam vaga até o encerramento da rota.</p>}
        </div>
      )}

      {lista.itens.length === 0 ? (
        <p className="rounded-xl bg-surface-bg/50 p-4 text-sm">Nenhuma entrega disponível nesta página.</p>
      ) : (
        <ul role="list" className="divide-y divide-surface-bg">
          {lista.itens.map((entrega) => {
            const pedido = formatarIdPedido(entrega.idPedido)
            const rotulo = idAssumindo === entrega.idEntrega ? 'Assumindo…' : 'Assumir'
            return (
              <li key={entrega.idEntrega} className="grid gap-3 py-4 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center">
                <div className="min-w-0 wrap-break-word text-sm">
                  <h4 className="text-xl">Pedido {pedido}</h4>
                  <p className="font-semibold text-brand-dark">{entrega.nomeLoja}</p>
                  <p>Região de destino: {entrega.bairroDestino}, {entrega.cidadeDestino} – {entrega.estadoDestino}</p>
                  <p>
                    Previsão: <time dateTime={entrega.previsaoEntrega}>{formatarDataHora(entrega.previsaoEntrega)}</time>
                  </p>
                </div>
                <button
                  type="button"
                  disabled={ocupado || bloqueada}
                  aria-label={`${rotulo} · Pedido ${pedido}`}
                  aria-describedby={bloqueada ? 'logistica-bloqueio' : undefined}
                  onClick={() => onAssumir({ idEntrega: entrega.idEntrega, idPedido: entrega.idPedido, tipo: 'assumir' })}
                  className={botaoPrimarioClass}
                >
                  {rotulo}
                </button>
              </li>
            )
          })}
        </ul>
      )}
      <Paginacao lista={lista} ocupado={ocupado} onPaginar={onPaginar} rotulo="Paginação das entregas disponíveis" />
    </section>
  )
}

export function RotasEncerradasSection({ lista, ocupado, onPaginar }: ListaPaginadaProps<RotaResumo>) {
  return (
    <section aria-labelledby="logistica-encerradas" className={secaoPainelClass}>
      <h3 id="logistica-encerradas" className="text-2xl">Rotas encerradas</h3>
      {lista.itens.length === 0 ? (
        <p className="rounded-xl bg-surface-bg/50 p-4 text-sm">Nenhuma rota encerrada nesta página.</p>
      ) : (
        <ul role="list" className="divide-y divide-surface-bg">
          {lista.itens.map((rota) => (
            <li key={rota.idRota} className="space-y-1 py-4 text-sm">
              <h4 className="text-xl">Rota #{String(rota.idRota).padStart(6, '0')}</h4>
              <p>{rota.totalEntregas} {rota.totalEntregas === 1 ? 'entrega' : 'entregas'}</p>
              <p>Aberta em <time dateTime={rota.criadaEm}>{formatarDataHora(rota.criadaEm)}</time></p>
              <p>Encerrada em <time dateTime={rota.encerradaEm}>{formatarDataHora(rota.encerradaEm)}</time></p>
              {rota.idsPedidos.length > 0 && (
                <ul role="list" aria-label="Pedidos da rota" className="flex flex-wrap gap-x-4">
                  {rota.idsPedidos.map((idPedido) => (
                    <li key={idPedido}>
                      <Link
                        to={`/rastreio/${idPedido}`}
                        state={{ origemRastreio: 'painel-entregador' }}
                        className={linkRastreioClass}
                      >
                        Rastrear pedido {formatarIdPedido(idPedido)}
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </li>
          ))}
        </ul>
      )}
      <Paginacao lista={lista} ocupado={ocupado} onPaginar={onPaginar} rotulo="Paginação das rotas encerradas" />
    </section>
  )
}
