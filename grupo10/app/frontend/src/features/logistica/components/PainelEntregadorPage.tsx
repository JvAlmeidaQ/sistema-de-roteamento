/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { usePainelEntregador } from '../hooks/usePainelEntregador'
import { EntregasDisponiveisSection, RotasEncerradasSection } from './ListasPainel'
import { RotaAtualSection } from './RotaAtualSection'
import { botaoSecundarioClass, secaoPainelClass } from './painel.styles'

const ACAO_EM_ANDAMENTO = {
  assumir: 'Assumindo entrega…',
  a_caminho: 'Registrando retirada…',
  entregue: 'Finalizando entrega…',
}

export default function PainelEntregadorPage() {
  const { usuarioAtual, carregandoUsuarios } = useSessaoUsuario()

  return (
    <div className="space-y-6">
      <header className="space-y-1">
        <p className="text-sm font-semibold uppercase tracking-wide text-brand-dark">Logística</p>
        <h2 className="text-3xl sm:text-4xl">Painel do entregador</h2>
        <p>Consulte a fila de entregas e acompanhe a sua rota.</p>
      </header>

      {carregandoUsuarios ? (
        <p role="status" className={secaoPainelClass}>Carregando a sessão…</p>
      ) : usuarioAtual ? (
        <PainelDaSessao key={usuarioAtual.idPessoa} nome={usuarioAtual.nome} />
      ) : (
        <p role="status" className={secaoPainelClass}>Selecione uma conta no menu de sessão para acessar o painel.</p>
      )}
    </div>
  )
}

function PainelDaSessao({ nome }: { nome: string }) {
  const { painel, ocupado, acaoPendente, erro, feedback, atualizar, paginar, executarAcao } = usePainelEntregador()
  const sucesso = feedback?.tipo === 'sucesso' && !ocupado
  const mensagemStatus = acaoPendente
    ? ACAO_EM_ANDAMENTO[acaoPendente.tipo]
    : ocupado
      ? painel ? 'Atualizando painel…' : 'Carregando painel de entregas…'
      : sucesso ? feedback.mensagem : ''
  const erroAcao = feedback?.tipo === 'erro' ? feedback.mensagem : null

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="min-w-0 wrap-break-word text-sm">Sessão atual: <strong className="text-brand-dark">{nome}</strong></p>
        <button type="button" onClick={atualizar} disabled={ocupado} className={botaoSecundarioClass}>
          Atualizar painel
        </button>
      </div>

      <p
        role="status"
        className={mensagemStatus
          ? `rounded-xl px-4 py-3 text-sm text-brand-dark ${sucesso ? 'border border-state-success/50 bg-state-success/10' : 'bg-surface'}`
          : 'sr-only'}
      >
        {mensagemStatus}
      </p>
      {(erro || erroAcao) && (
        <div role="alert" className="space-y-1 rounded-xl border border-state-error/50 bg-surface px-4 py-3 text-sm text-brand-dark">
          {erroAcao && <p>{erroAcao}</p>}
          {erro && <p>{erro}</p>}
        </div>
      )}

      <div aria-busy={ocupado} className="space-y-6">
        {!painel && ocupado && (
          <div aria-hidden="true" className={`${secaoPainelClass} motion-safe:animate-pulse`}>
            <div className="h-6 w-1/3 rounded-lg bg-surface-bg" />
            <div className="h-16 rounded-xl bg-surface-bg" />
            <div className="h-24 rounded-xl bg-surface-bg" />
          </div>
        )}
        {painel && (
          <>
            <RotaAtualSection rota={painel.rotaAtual} ocupado={ocupado} acaoPendente={acaoPendente} onAcao={executarAcao} />
            <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
              <EntregasDisponiveisSection
                lista={painel.disponiveis}
                rota={painel.rotaAtual}
                ocupado={ocupado}
                idAssumindo={acaoPendente?.tipo === 'assumir' ? acaoPendente.idEntrega : undefined}
                onAssumir={executarAcao}
                onPaginar={(pagina) => paginar('paginaDisponiveis', pagina)}
              />
              <RotasEncerradasSection
                lista={painel.encerradas}
                ocupado={ocupado}
                onPaginar={(pagina) => paginar('paginaEncerradas', pagina)}
              />
            </div>
          </>
        )}
      </div>
    </div>
  )
}
