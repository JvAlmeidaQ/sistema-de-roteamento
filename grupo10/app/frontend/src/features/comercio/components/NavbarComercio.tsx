/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Barra de navegação principal adaptada ao papel ativo da sessão.
 */
import { LogOut, PackageCheck, ShieldCheck, Store, Truck, User } from 'lucide-react'
import { Link, NavLink, useNavigate } from 'react-router-dom'
import {
  ROTULO_PAPEL,
  rotaInicialPorPapel,
  useSessaoUsuario,
  type PapelAtivo,
} from '@/context/SessaoUsuarioContext'

export function NavbarComercio() {
  const {
    usuarioAtual,
    papelAtivo,
    papeisDisponiveis,
    selecionarPapel,
    sair,
  } = useSessaoUsuario()
  const navigate = useNavigate()

  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `rounded-full px-4 py-2 text-sm font-semibold transition-colors ${
      isActive
        ? 'bg-brand-lime text-brand-dark'
        : 'text-white/85 hover:bg-white/10 hover:text-white'
    }`

  const handleTrocarPapel = (novoPapel: PapelAtivo) => {
    selecionarPapel(novoPapel)
    navigate(rotaInicialPorPapel(novoPapel))
  }

  const handleSair = () => {
    sair()
    navigate('/entrar')
  }

  return (
    <header className="bg-brand-dark text-white shadow-low">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6">
        <Link
          to={usuarioAtual ? rotaInicialPorPapel(papelAtivo) : '/entrar'}
          className="flex items-center gap-3 rounded-2xl focus-visible:outline-2 focus-visible:outline-brand-lime"
        >
          <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-brand-lime text-brand-dark">
            <PackageCheck className="h-5 w-5" aria-hidden="true" />
          </div>
          <div>
            <h1 className="font-display text-lg font-semibold leading-tight text-white">
              Roteamento de Pedidos
            </h1>
            {usuarioAtual && papelAtivo && (
              <p className="text-xs text-white/75">
                Visão: <span className="font-semibold text-brand-lime">{ROTULO_PAPEL[papelAtivo]}</span>
              </p>
            )}
          </div>
        </Link>

        {usuarioAtual && papelAtivo ? (
          <>
            <nav className="flex flex-wrap items-center gap-2" aria-label="Navegação principal">
              {papelAtivo === 'cliente' && (
                <>
                  <NavLink to="/" end className={linkClass}>
                    Lojas
                  </NavLink>
                  <NavLink to="/pedidos" className={linkClass}>
                    Meus pedidos
                  </NavLink>
                </>
              )}

              {papelAtivo === 'entregador' && (
                <NavLink to="/painel-entregador" className={linkClass}>
                  Entregas
                </NavLink>
              )}

              {papelAtivo === 'lojista' && (
                <>
                  <NavLink to="/catalogo" className={linkClass}>
                    Minha loja
                  </NavLink>
                  <NavLink to="/pedidos" className={linkClass}>
                    Pedidos
                  </NavLink>
                  <NavLink to="/relatorios" className={linkClass}>
                    Relatórios
                  </NavLink>
                </>
              )}

              {papelAtivo === 'admin' && (
                <>
                  <NavLink to="/relatorios" className={linkClass}>
                    Financeiro
                  </NavLink>
                  <NavLink to="/perfis" className={linkClass}>
                    Perfis
                  </NavLink>
                </>
              )}

              <NavLink to={`/perfis/${usuarioAtual.idPessoa}`} className={linkClass}>
                Meu perfil
              </NavLink>
            </nav>

            <div className="flex flex-wrap items-center gap-2">
              {papeisDisponiveis.length > 1 && (
                <div className="flex items-center gap-1.5">
                  <label htmlFor="seletor-papel" className="text-xs font-semibold text-white/80">
                    Papel:
                  </label>
                  <select
                    id="seletor-papel"
                    value={papelAtivo}
                    onChange={(e) => handleTrocarPapel(e.target.value as PapelAtivo)}
                    className="rounded-full border border-white/20 bg-white/10 px-3 py-1.5 text-xs font-semibold text-white outline-none focus:border-brand-lime"
                  >
                    {papeisDisponiveis.map((p) => (
                      <option key={p} value={p} className="bg-brand-dark text-white">
                        {ROTULO_PAPEL[p]}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5 text-xs font-medium text-white">
                {papelAtivo === 'cliente' && <User className="h-3.5 w-3.5 text-brand-lime" aria-hidden="true" />}
                {papelAtivo === 'lojista' && <Store className="h-3.5 w-3.5 text-brand-lime" aria-hidden="true" />}
                {papelAtivo === 'entregador' && <Truck className="h-3.5 w-3.5 text-brand-lime" aria-hidden="true" />}
                {papelAtivo === 'admin' && <ShieldCheck className="h-3.5 w-3.5 text-brand-lime" aria-hidden="true" />}
                <span className="max-w-44 truncate">{usuarioAtual.nome}</span>
              </span>

              <button
                type="button"
                onClick={handleSair}
                className="inline-flex items-center gap-1.5 rounded-full border border-white/25 px-3 py-1.5 text-xs font-semibold text-white transition-colors hover:bg-white/10"
              >
                <LogOut className="h-3.5 w-3.5" aria-hidden="true" />
                Sair
              </button>
            </div>
          </>
        ) : (
          <nav className="flex items-center gap-2" aria-label="Acesso">
            <NavLink to="/entrar" className={linkClass}>
              Entrar
            </NavLink>
            <NavLink to="/cadastro" className={linkClass}>
              Criar conta
            </NavLink>
          </nav>
        )}
      </div>
    </header>
  )
}
