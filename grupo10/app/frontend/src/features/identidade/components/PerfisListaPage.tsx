/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato — Listagem administrativa de perfis
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
      <header>
        <h2 className="text-3xl font-semibold text-brand-dark">Perfis cadastrados</h2>
        <p className="mt-1 text-sm text-text-default">
          Consulte os usuários da plataforma e suas funções vinculadas.
        </p>
      </header>

      <div className="rounded-2xl border border-surface-bg bg-surface p-6">
        <label htmlFor="busca-perfil" className="block text-xs font-semibold text-brand-dark">
          Buscar por nome, e-mail ou CPF
        </label>
        <div className="mt-1 flex gap-2">
          <input
            id="busca-perfil"
            type="search"
            maxLength={120}
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Ex.: Ana, nome@exemplo.com, 123.456…"
            className="w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline focus-visible:ring-2 focus-visible:ring-brand-outline/30"
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
                    <td colSpan={5} className="py-3">
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
