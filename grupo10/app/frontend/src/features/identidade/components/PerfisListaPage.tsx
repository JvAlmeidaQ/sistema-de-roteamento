/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01 (listagem e busca de perfis, visão vw_perfil_pessoa)
 */
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { usePessoas } from '../hooks/usePerfis'
import { mascaraCpf } from '../utils/formatadores'
import { PapelBadges } from './PapelBadges'

export default function PerfisListaPage() {
  const [busca, setBusca] = useState('')
  const { pessoas, carregando, erro } = usePessoas(busca)
  const navigate = useNavigate()

  return (
    <section className="space-y-6">
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-3xl">Perfis (RF01)</h2>
          <p className="text-sm">
            Pessoas cadastradas e seus papéis de Cliente, Lojista e Entregador (especialização total e sobreposta — ADR-003).
          </p>
        </div>
        <Link
          to="/perfis/novo"
          className="rounded-full bg-brand-lime px-5 py-2 text-sm font-semibold text-brand-dark shadow-low transition-colors hover:bg-brand-green/40"
        >
          + Novo perfil
        </Link>
      </header>

      <div className="rounded-3xl bg-surface p-6 shadow-low">
        <label htmlFor="busca-perfil" className="block text-xs font-semibold text-brand-dark">
          Buscar por nome, e-mail, CPF ou ID
        </label>
        <div className="mt-1 flex gap-2">
          <input
            id="busca-perfil"
            type="search"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Ex.: Ana, pessoa12@exemplo.com, 123.456…"
            className="w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
          />
          {busca && (
            <button
              type="button"
              onClick={() => setBusca('')}
              className="rounded-full px-4 text-xs font-semibold text-text-default hover:bg-surface-bg"
            >
              Limpar
            </button>
          )}
        </div>

        {erro && (
          <p role="alert" className="mt-4 rounded-2xl bg-state-error/10 px-4 py-3 text-sm text-state-error">
            {erro.mensagem}
          </p>
        )}

        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-sm">
            <thead>
              <tr className="border-b border-surface-bg text-xs uppercase tracking-wide text-text-default">
                <th className="py-2 pr-3">ID</th>
                <th className="py-2 pr-3">Nome</th>
                <th className="py-2 pr-3">CPF</th>
                <th className="py-2 pr-3">E-mail</th>
                <th className="py-2 pr-3">Funções</th>
                <th className="py-2 pr-3 text-right">Endereços</th>
              </tr>
            </thead>
            <tbody>
              {carregando && pessoas.length === 0 &&
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i} className="border-b border-surface-bg/60">
                    <td colSpan={6} className="py-3">
                      <div className="h-4 animate-pulse rounded bg-surface-bg" />
                    </td>
                  </tr>
                ))}
              {pessoas.map((p) => (
                <tr
                  key={p.idPessoa}
                  onClick={() => navigate(`/perfis/${p.idPessoa}`)}
                  className="cursor-pointer border-b border-surface-bg/60 transition-colors hover:bg-surface-bg/40"
                >
                  <td className="py-2.5 pr-3 text-xs text-text-default">#{p.idPessoa}</td>
                  <td className="py-2.5 pr-3 font-semibold text-brand-dark">
                    <Link to={`/perfis/${p.idPessoa}`} onClick={(e) => e.stopPropagation()} className="hover:underline">
                      {p.nome}
                    </Link>
                  </td>
                  <td className="py-2.5 pr-3 tabular-nums">{mascaraCpf(p.cpf)}</td>
                  <td className="py-2.5 pr-3">{p.email}</td>
                  <td className="py-2.5 pr-3">
                    <PapelBadges cliente={p.cliente} lojista={p.lojista} entregador={p.entregador} tipoVeiculo={p.tipoVeiculo} />
                  </td>
                  <td className="py-2.5 pr-3 text-right tabular-nums">{p.qtdEnderecos}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {!carregando && !erro && pessoas.length === 0 && (
            <p className="py-8 text-center text-sm">
              Nenhuma pessoa encontrada. Experimente ajustar a busca.
            </p>
          )}
          {pessoas.length === 50 && (
            <p className="pt-3 text-xs">Mostrando os 50 primeiros resultados. Refine a busca para encontrar outras pessoas.</p>
          )}
        </div>
      </div>
    </section>
  )
}
