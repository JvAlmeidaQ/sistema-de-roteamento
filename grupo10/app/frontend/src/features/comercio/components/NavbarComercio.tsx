/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { NavLink } from 'react-router-dom'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import type { UsuarioSessao } from '../types/comercio.types'

const isBd = import.meta.env.VITE_APP_MODE === 'bd'

function rotuloUsuario(usuario: UsuarioSessao) {
  const perfis: string[] = []
  if (!isBd && usuario.perfilEntregador) perfis.push('Entregador')
  if (usuario.perfilCliente) perfis.push('Cliente')
  if (usuario.perfilLojista) perfis.push(usuario.nomeLoja ? `Lojista: ${usuario.nomeLoja}` : 'Lojista')
  return `#${usuario.idPessoa} · ${usuario.nome}${perfis.length ? ` (${perfis.join(' · ')})` : ''}`
}

export function NavbarComercio() {
  const { usuarios, usuarioAtual, selecionarUsuario, carregandoUsuarios, errosUsuarios } = useSessaoUsuario()

  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `rounded-full px-4 py-2 text-sm font-semibold transition-colors ${
      isActive
        ? 'bg-brand-lime text-brand-dark'
        : 'text-white/85 hover:bg-white/10 hover:text-white'
    }`

  return (
    <header className="bg-brand-dark text-white shadow-low">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-brand-lime font-display text-lg font-bold text-brand-dark">
            CF
          </div>
          <div>
            <h1 className="font-display text-lg font-semibold leading-tight text-white">
              Roteamento de Pedidos
            </h1>
            <p className="text-xs text-white/75">
              Comércio e Finanças · Modo{' '}
              <span className="font-semibold text-brand-lime">
                {isBd ? 'BD (Estrito)' : 'ES (Completo)'}
              </span>
            </p>
          </div>
        </div>

        <nav className="flex flex-wrap items-center gap-2" aria-label="Navegação principal">
          <NavLink to="/" end className={linkClass}>
            Novo Pedido (RF02)
          </NavLink>
          {!isBd && (
            <NavLink to="/pedidos" className={linkClass}>
              Gestão de Pedidos (RF03–RF09)
            </NavLink>
          )}
          <NavLink to="/relatorios" className={linkClass}>
            Relatórios Financeiros (RF10)
          </NavLink>
          {!isBd && (
            <NavLink to="/painel-entregador" className={linkClass}>
              Painel do entregador
            </NavLink>
          )}
        </nav>

        <div className="w-full min-w-0 max-w-full space-y-2 sm:w-auto">
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <label htmlFor="seletor-usuario" className="text-xs font-semibold text-white/80">
              Sessão (X-User-Id):
            </label>
            <select
              id="seletor-usuario"
              aria-describedby={errosUsuarios.length ? 'erros-sessao' : undefined}
              disabled={carregandoUsuarios || usuarios.length === 0}
              value={usuarioAtual?.idPessoa ?? ''}
              title={usuarioAtual ? rotuloUsuario(usuarioAtual) : undefined}
              onChange={(e) => selecionarUsuario(Number(e.target.value))}
              className="w-full min-w-0 max-w-full truncate rounded-full border border-white/20 bg-white/10 px-3 py-1.5 text-xs font-medium text-white outline-none focus:border-brand-lime sm:w-auto sm:max-w-xs"
            >
              {usuarios.length === 0 && (
                <option value="" className="bg-brand-dark text-white">
                  {carregandoUsuarios ? 'Carregando contas…' : 'Nenhuma conta disponível'}
                </option>
              )}
              {usuarios.map((u) => (
                <option key={u.idPessoa} value={u.idPessoa} className="bg-brand-dark text-white">
                  {rotuloUsuario(u)}
                </option>
              ))}
            </select>
          </div>
          {errosUsuarios.length > 0 && (
            <div id="erros-sessao" role="alert" className="max-w-sm space-y-1 rounded-lg border border-white/20 bg-white/10 px-3 py-2 wrap-anywhere text-xs">
              {errosUsuarios.map((erro) => <p key={erro}>{erro}</p>)}
            </div>
          )}
        </div>
      </div>
    </header>
  )
}
