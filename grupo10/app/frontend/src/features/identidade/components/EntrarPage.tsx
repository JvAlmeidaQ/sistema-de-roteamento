/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato — Tela de Entrada
 */
import { useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { ArrowRight, LogIn, Store, Truck, User, ShieldCheck, UserPlus } from 'lucide-react'
import {
  papeisDoUsuario,
  rotaInicialPorPapel,
  ROTULO_PAPEL,
  useSessaoUsuario,
} from '@/context/SessaoUsuarioContext'
import { limparNomeLoja } from '@/lib/apresentacao'
import { lerErroApi } from '../api/identidade.api'

export default function EntrarPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const { usuarios, entrar, entrarComSessao, carregandoUsuarios } = useSessaoUsuario()

  const stateInicial = location.state as { identificador?: string; aviso?: string } | null
  const [identificador, setIdentificador] = useState(stateInicial?.identificador ?? '')
  const [aviso] = useState(stateInicial?.aviso ?? '')
  const [erro, setErro] = useState<string | null>(null)
  const [enviando, setEnviando] = useState(false)

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setErro(null)
    if (!identificador.trim()) {
      setErro('Informe seu e-mail ou CPF cadastrado.')
      return
    }
    try {
      setEnviando(true)
      const sessao = await entrar(identificador.trim())
      const papeis = papeisDoUsuario(sessao)
      navigate(rotaInicialPorPapel(papeis[0] ?? 'cliente'), { replace: true })
    } catch (err) {
      setErro(lerErroApi(err).mensagem)
    } finally {
      setEnviando(false)
    }
  }

  const entrarRapido = (idPessoa: number) => {
    const conta = usuarios.find((u) => u.idPessoa === idPessoa)
    if (!conta) return
    entrarComSessao(conta)
    const papeis = papeisDoUsuario(conta)
    navigate(rotaInicialPorPapel(papeis[0] ?? 'cliente'), { replace: true })
  }

  return (
    <div className="mx-auto max-w-4xl space-y-6 py-4">
      <div className="grid gap-6 md:grid-cols-2">
        <section className="rounded-2xl border border-surface-bg bg-surface p-6">
          <div className="flex items-center gap-2 text-brand-dark">
            <LogIn className="h-5 w-5 text-brand-outline" aria-hidden="true" />
            <h2 className="text-2xl font-semibold">Entrar</h2>
          </div>
          <p className="mt-1 text-sm text-text-default">
            Acesse sua conta com o e-mail ou CPF cadastrado.
          </p>

          {aviso && (
            <p role="status" className="mt-4 rounded-2xl border border-state-pending/40 bg-state-pending/15 px-4 py-3 text-sm text-brand-pit">
              {aviso}
            </p>
          )}

          {erro && (
            <p role="alert" className="mt-4 rounded-2xl border border-state-error/40 bg-state-error/10 px-4 py-3 text-sm text-state-error">
              {erro}
            </p>
          )}

          <form onSubmit={handleSubmit} className="mt-5 space-y-4" noValidate>
            <div>
              <label htmlFor="entrar-identificador" className="block text-xs font-semibold text-brand-dark">
                E-mail ou CPF
              </label>
              <input
                id="entrar-identificador"
                type="text"
                value={identificador}
                onChange={(e) => setIdentificador(e.target.value)}
                placeholder="nome@exemplo.com ou 000.000.000-00"
                className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2.5 text-sm text-brand-dark outline-none focus:border-brand-outline focus-visible:ring-2 focus-visible:ring-brand-outline/30"
              />
            </div>

            <button
              type="submit"
              disabled={enviando}
              className="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-full bg-brand-lime px-6 py-2.5 text-sm font-semibold text-brand-dark transition-colors hover:bg-brand-lime/80 disabled:opacity-50"
            >
              {enviando ? 'Entrando...' : 'Entrar'}
              <ArrowRight className="h-4 w-4" aria-hidden="true" />
            </button>
          </form>

          <div className="mt-6 border-t border-surface-bg pt-4 text-sm text-text-default">
            <span>Ainda não tem conta? </span>
            <Link
              to="/cadastro"
              className="inline-flex items-center gap-1 font-semibold text-brand-outline hover:underline"
            >
              <UserPlus className="h-4 w-4" aria-hidden="true" />
              Criar nova conta
            </Link>
          </div>
        </section>

        <section className="rounded-2xl border border-surface-bg bg-surface p-6">
          <h3 className="text-lg font-semibold text-brand-dark">Contas cadastradas</h3>
          <p className="mt-1 text-xs text-text-default">
            Selecione uma conta existente para acesso rápido.
          </p>

          {carregandoUsuarios ? (
            <div className="mt-4 space-y-2">
              {Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="h-12 animate-pulse rounded-2xl bg-surface-bg" />
              ))}
            </div>
          ) : usuarios.length === 0 ? (
            <p className="mt-4 text-sm text-text-default">Nenhuma conta disponível.</p>
          ) : (
            <ul className="mt-4 max-h-96 space-y-2 overflow-y-auto pr-1">
              {usuarios.map((u) => {
                const papeis = papeisDoUsuario(u)
                return (
                  <li key={u.idPessoa}>
                    <button
                      type="button"
                      onClick={() => entrarRapido(u.idPessoa)}
                      className="flex w-full items-center justify-between gap-3 rounded-2xl border border-surface-bg px-4 py-2.5 text-left transition-colors hover:border-brand-outline/50 hover:bg-surface-bg/40"
                    >
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-semibold text-brand-dark">{u.nome}</p>
                        <div className="mt-0.5 flex flex-wrap gap-1.5">
                          {papeis.map((p) => (
                            <span
                              key={p}
                              className="inline-flex items-center gap-1 rounded-full bg-surface-bg px-2 py-0.5 text-[11px] font-semibold text-brand-dark"
                            >
                              {p === 'cliente' && <User className="h-3 w-3" aria-hidden="true" />}
                              {p === 'lojista' && <Store className="h-3 w-3" aria-hidden="true" />}
                              {p === 'entregador' && <Truck className="h-3 w-3" aria-hidden="true" />}
                              {p === 'admin' && <ShieldCheck className="h-3 w-3" aria-hidden="true" />}
                              {p === 'lojista' && u.nomeLoja
                                ? `${ROTULO_PAPEL[p]} · ${limparNomeLoja(u.nomeLoja)}`
                                : ROTULO_PAPEL[p]}
                            </span>
                          ))}
                        </div>
                      </div>
                      <ArrowRight className="h-4 w-4 shrink-0 text-brand-outline" aria-hidden="true" />
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </section>
      </div>
    </div>
  )
}
