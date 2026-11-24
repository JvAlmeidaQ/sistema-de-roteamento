/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01 (visualização do perfil de uma Pessoa)
 */
import type { ReactNode } from 'react'
import { Link, useLocation, useParams } from 'react-router-dom'
import { usePerfil } from '../hooks/usePerfis'
import { ROTULO_TELEFONE, ROTULO_VEICULO, mascaraCep, mascaraCnpj, mascaraCpf, mascaraTelefone } from '../utils/formatadores'
import { PapelBadges } from './PapelBadges'

function Cartao({ titulo, children, acao }: { titulo: string; children: ReactNode; acao?: ReactNode }) {
  return (
    <section className="rounded-3xl bg-surface p-6 shadow-low">
      <div className="mb-3 flex items-center justify-between gap-2">
        <h3 className="text-lg">{titulo}</h3>
        {acao}
      </div>
      {children}
    </section>
  )
}

export default function PerfilDetalhePage() {
  const { id } = useParams()
  const idPessoa = Number(id)
  const valido = Number.isSafeInteger(idPessoa) && idPessoa > 0
  const { perfil, carregando, erro } = usePerfil(valido ? idPessoa : null)
  const location = useLocation()
  const mensagemSucesso = (location.state as { mensagem?: string } | null)?.mensagem

  if (!valido) {
    return <p role="alert" className="text-state-error">Identificador de pessoa inválido.</p>
  }
  if (carregando) {
    return (
      <div className="space-y-4" role="status" aria-label="Carregando perfil">
        <div className="h-24 animate-pulse rounded-3xl bg-surface" />
        <div className="grid gap-4 md:grid-cols-2">
          <div className="h-40 animate-pulse rounded-3xl bg-surface" />
          <div className="h-40 animate-pulse rounded-3xl bg-surface" />
        </div>
      </div>
    )
  }
  if (erro || !perfil) {
    return (
      <div className="space-y-3">
        <p role="alert" className="rounded-2xl bg-state-error/10 px-4 py-3 text-sm text-state-error">
          {erro?.status === 404 ? 'Pessoa não encontrada.' : erro?.mensagem ?? 'Não foi possível carregar o perfil.'}
        </p>
        <Link to="/perfis" className="text-sm font-semibold text-brand-outline hover:underline">← Voltar para a lista</Link>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <Link to="/perfis" className="text-sm font-semibold text-brand-outline hover:underline">← Perfis</Link>

      {mensagemSucesso && (
        <p role="status" className="rounded-2xl bg-state-success/15 px-4 py-3 text-sm font-semibold text-brand-dark">
          {mensagemSucesso}
        </p>
      )}

      <header className="flex flex-wrap items-start justify-between gap-4 rounded-3xl bg-surface p-6 shadow-low">
        <div className="space-y-2">
          <p className="text-xs font-semibold text-text-default">Pessoa #{perfil.idPessoa}</p>
          <h2 className="text-3xl">{perfil.nome}</h2>
          <PapelBadges
            cliente={perfil.cliente}
            lojista={perfil.lojista}
            entregador={perfil.entregador}
            tipoVeiculo={perfil.tipoVeiculo}
          />
          <dl className="grid gap-x-8 gap-y-1 pt-2 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-xs font-semibold text-brand-dark">CPF</dt>
              <dd className="tabular-nums">{mascaraCpf(perfil.cpf)}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold text-brand-dark">E-mail</dt>
              <dd>{perfil.email}</dd>
            </div>
          </dl>
        </div>
        <Link
          to={`/perfis/${perfil.idPessoa}/editar`}
          className="rounded-full bg-brand-lime px-5 py-2 text-sm font-semibold text-brand-dark shadow-low transition-colors hover:bg-brand-green/40"
        >
          Editar perfil
        </Link>
      </header>

      <div className="grid gap-6 md:grid-cols-2">
        <Cartao titulo={`Telefones (${perfil.telefones.length})`}>
          {perfil.telefones.length === 0 ? (
            <p className="text-sm">Nenhum telefone cadastrado.</p>
          ) : (
            <ul className="divide-y divide-surface-bg">
              {perfil.telefones.map((t) => (
                <li key={t.numero} className="flex items-center justify-between py-2 text-sm">
                  <span className="tabular-nums text-brand-dark">{mascaraTelefone(t.numero)}</span>
                  <span className="text-xs">{ROTULO_TELEFONE[t.tipo] ?? t.tipo}</span>
                </li>
              ))}
            </ul>
          )}
        </Cartao>

        <Cartao titulo="Funções">
          <ul className="space-y-2 text-sm">
            <li>
              <span className="font-semibold text-brand-dark">Cliente:</span>{' '}
              {perfil.cliente ? 'sim' : 'não'}
              {perfil.restricoes.clienteComPedidos && ' · possui pedidos registrados'}
            </li>
            <li>
              <span className="font-semibold text-brand-dark">Lojista:</span>{' '}
              {perfil.lojista ? `sim · ${perfil.lojas.length} loja(s)` : 'não'}
            </li>
            <li>
              <span className="font-semibold text-brand-dark">Entregador:</span>{' '}
              {perfil.entregador ? `sim · ${ROTULO_VEICULO[perfil.tipoVeiculo ?? ''] ?? perfil.tipoVeiculo}` : 'não'}
              {perfil.restricoes.entregadorComRotas && ' · possui rotas registradas'}
            </li>
          </ul>
        </Cartao>
      </div>

      <Cartao titulo={`Endereços (${perfil.enderecos.length})`}>
        {perfil.enderecos.length === 0 ? (
          <p className="text-sm">Nenhum endereço vinculado.</p>
        ) : (
          <ul className="grid gap-3 md:grid-cols-2">
            {perfil.enderecos.map((e) => (
              <li
                key={e.idEndereco}
                className={`rounded-2xl border p-4 text-sm ${e.atual ? 'border-brand-green bg-brand-lime/10' : 'border-surface-bg'}`}
              >
                <div className="mb-1 flex items-center justify-between gap-2">
                  <span className="font-semibold text-brand-dark">{e.apelido || 'Endereço'}</span>
                  {e.atual && (
                    <span className="rounded-full bg-brand-lime px-2.5 py-0.5 text-xs font-semibold text-brand-dark">
                      Endereço atual
                    </span>
                  )}
                </div>
                <p>
                  {e.logradouro}, {e.numero}
                  {e.complemento ? ` — ${e.complemento}` : ''}
                </p>
                <p>
                  {e.bairro} · {e.cidade}/{e.estado} · CEP {mascaraCep(e.cep)}
                </p>
                {e.referencia && <p className="text-xs">Referência: {e.referencia}</p>}
              </li>
            ))}
          </ul>
        )}
      </Cartao>

      {perfil.lojista && (
        <Cartao
          titulo={`Lojas (${perfil.lojas.length})`}
          acao={
            <Link to="/catalogo" className="text-xs font-semibold text-brand-outline hover:underline">
              Abrir Painel do Lojista →
            </Link>
          }
        >
          <ul className="divide-y divide-surface-bg">
            {perfil.lojas.map((l) => (
              <li key={l.idLoja} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
                <span className="font-semibold text-brand-dark">
                  #{l.idLoja} · {l.nome}
                </span>
                <span className="tabular-nums">{mascaraCnpj(l.cnpj)}</span>
                <span
                  className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                    l.statusFuncionamento === 'aberta'
                      ? 'bg-state-success/15 text-brand-dark'
                      : 'bg-state-cancelled/15 text-state-error'
                  }`}
                >
                  {l.statusFuncionamento === 'aberta' ? 'Aberta' : 'Fechada'}
                </span>
              </li>
            ))}
          </ul>
          <p className="mt-2 text-xs">O Painel do Lojista usa a pessoa selecionada na sessão (X-User-Id).</p>
        </Cartao>
      )}
    </div>
  )
}
