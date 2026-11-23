/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Catálogo (UC2: Gerenciar Loja e Catálogo — RF07, RN01, RN07, RN09, RR04, RR13, RR18)
 */
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { usePainelLojista } from '../hooks/usePainelLojista'
import { StatusFuncionamentoToggle } from './StatusFuncionamentoToggle'
import { FormProdutoModal } from './FormProdutoModal'
import {
  atualizarLojaSchema,
  criarCategoriaSchema,
  type AtualizarLojaFormValues,
  type CriarCategoriaFormValues,
  type ProdutoFormValues,
} from '../schemas/catalogo.schemas'
import type { ProdutoCatalogoResponse } from '../types/catalogo.types'

export function formatarMoeda(valor: number | null | undefined): string {
  if (valor == null) return 'R$ 0,00'
  return valor.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
}

export function PainelLojistaPage() {
  const { usuarioAtual } = useSessaoUsuario()
  const {
    loja,
    categorias,
    produtos,
    totalProdutosSemFiltroTexto,
    carregandoLoja,
    carregandoCategorias,
    carregandoProdutos,
    salvando,
    erroLoja,
    erroOperacao,
    mensagemSucesso,
    filtroCategoria,
    setFiltroCategoria,
    filtroAtivo,
    setFiltroAtivo,
    buscaTexto,
    setBuscaTexto,
    limparMensagens,
    alternarStatusLoja,
    salvarDadosLoja,
    adicionarCategoria,
    removerCategoria,
    adicionarProduto,
    editarProduto,
    alternarAtivoProduto,
  } = usePainelLojista(usuarioAtual)

  const [abaAtiva, setAbaAtiva] = useState<'produtos' | 'categorias' | 'configuracoes'>('produtos')
  const [modalProdutoAberto, setModalProdutoAberto] = useState(false)
  const [produtoParaEditar, setProdutoParaEditar] = useState<ProdutoCatalogoResponse | null>(null)

  // Formulário de Categoria
  const {
    register: registerCategoria,
    handleSubmit: handleSubmitCategoria,
    reset: resetCategoria,
    formState: { errors: errorsCategoria },
  } = useForm<CriarCategoriaFormValues>({
    resolver: zodResolver(criarCategoriaSchema),
    defaultValues: { nome: '' },
  })

  // Formulário de Loja
  const {
    register: registerLoja,
    handleSubmit: handleSubmitLoja,
    reset: resetLoja,
    formState: { errors: errorsLoja },
  } = useForm<AtualizarLojaFormValues>({
    resolver: zodResolver(atualizarLojaSchema),
    values: loja
      ? {
          telefone: loja.telefone,
          complementoEndereco: loja.complementoEndereco || '',
          tempoEntregaEstimado: loja.tempoEntregaEstimado,
          taxaEntrega: loja.taxaEntrega,
        }
      : undefined,
  })

  const onCriarCategoria = async (valores: CriarCategoriaFormValues) => {
    await adicionarCategoria(valores)
    resetCategoria()
  }

  const onSalvarLoja = async (valores: AtualizarLojaFormValues) => {
    await salvarDadosLoja(valores)
  }

  const abrirModalNovoProduto = () => {
    setProdutoParaEditar(null)
    setModalProdutoAberto(true)
  }

  const abrirModalEditarProduto = (prod: ProdutoCatalogoResponse) => {
    setProdutoParaEditar(prod)
    setModalProdutoAberto(true)
  }

  const onSalvarProdutoModal = async (valores: ProdutoFormValues) => {
    if (produtoParaEditar) {
      await editarProduto(produtoParaEditar.idProduto, valores)
    } else {
      await adicionarProduto(valores)
    }
  }

  if (carregandoLoja) {
    return (
      <div className="flex h-96 items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-brand-outline border-t-transparent" />
          <p className="text-sm font-medium text-brand-dark">Carregando dados da loja...</p>
        </div>
      </div>
    )
  }

  if (!loja) {
    return (
      <div className="rounded-2xl border border-state-pending/30 bg-surface p-8 text-center shadow-low">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-state-pending/15 text-2xl text-brand-pit">
          🏬
        </div>
        <h2 className="mt-4 font-display text-xl font-bold text-brand-dark">
          Painel de Gestão do Catálogo (Lojista)
        </h2>
        <p className="mt-2 text-sm text-text-default">
          {erroLoja ||
            'Nenhuma loja encontrada para o usuário atualmente selecionado na sessão.'}
        </p>
        <p className="mt-2 text-xs text-text-default">
          Utilize o seletor <strong>Sessão (X-User-Id)</strong> no cabeçalho superior e escolha um
          usuário com perfil de <strong>Lojista</strong> para gerenciar o catálogo.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Banner de Feedback Global */}
      {mensagemSucesso && (
        <div className="flex items-center justify-between rounded-2xl border border-brand-green/30 bg-state-success/15 px-5 py-3 text-sm text-brand-dark shadow-xs">
          <span>✓ {mensagemSucesso}</span>
          <button
            type="button"
            onClick={limparMensagens}
            className="text-xs font-semibold text-brand-dark/70 hover:text-brand-dark"
          >
            Fechar
          </button>
        </div>
      )}

      {erroOperacao && (
        <div className="flex items-center justify-between rounded-2xl border border-state-error/30 bg-state-cancelled/15 px-5 py-3 text-sm text-state-error shadow-xs">
          <span>⚠️ {erroOperacao}</span>
          <button
            type="button"
            onClick={limparMensagens}
            className="text-xs font-semibold text-state-error/70 hover:text-state-error"
          >
            Fechar
          </button>
        </div>
      )}

      {/* Cartão de Cabeçalho da Loja */}
      <section className="rounded-2xl border border-surface-bg bg-surface p-6 shadow-low">
        <div className="flex flex-col justify-between gap-4 md:flex-row md:items-center">
          <div>
            <div className="flex items-center gap-3">
              <h2 className="font-display text-2xl font-bold text-brand-dark">{loja.nome}</h2>
              <span className="rounded-full bg-surface-bg px-2.5 py-0.5 text-xs font-semibold text-text-default">
                CNPJ: {loja.cnpj.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/, '$1.$2.$3/$4-$5')}
              </span>
            </div>
            <p className="mt-1 text-xs text-text-default">
              📍 {loja.logradouro}, {loja.numero} {loja.complementoEndereco ? `(${loja.complementoEndereco})` : ''} — {loja.bairro}, {loja.cidade}/{loja.estado} (CEP: {loja.cep})
            </p>
          </div>

          <StatusFuncionamentoToggle
            status={loja.statusFuncionamento}
            onToggle={alternarStatusLoja}
            disabled={salvando}
          />
        </div>

        {/* Estatísticas Rápidas da Loja */}
        <div className="mt-6 grid grid-cols-2 gap-4 border-t border-surface-bg pt-4 sm:grid-cols-4">
          <div className="rounded-xl bg-surface-bg/40 p-3">
            <span className="text-[11px] font-semibold text-text-default uppercase">Taxa de Entrega</span>
            <p className="mt-0.5 text-base font-bold text-brand-dark">{formatarMoeda(loja.taxaEntrega)}</p>
          </div>
          <div className="rounded-xl bg-surface-bg/40 p-3">
            <span className="text-[11px] font-semibold text-text-default uppercase">Tempo Estimado</span>
            <p className="mt-0.5 text-base font-bold text-brand-dark">{loja.tempoEntregaEstimado} min</p>
          </div>
          <div className="rounded-xl bg-surface-bg/40 p-3">
            <span className="text-[11px] font-semibold text-text-default uppercase">Total de Categorias</span>
            <p className="mt-0.5 text-base font-bold text-brand-dark">{categorias.length}</p>
          </div>
          <div className="rounded-xl bg-surface-bg/40 p-3">
            <span className="text-[11px] font-semibold text-text-default uppercase">Total de Produtos</span>
            <p className="mt-0.5 text-base font-bold text-brand-dark">{totalProdutosSemFiltroTexto}</p>
          </div>
        </div>
      </section>

      {/* Navegação por Abas */}
      <div className="flex border-b border-surface-bg">
        <button
          type="button"
          onClick={() => setAbaAtiva('produtos')}
          className={`flex items-center gap-2 border-b-2 px-6 py-3 text-sm font-semibold transition-colors ${
            abaAtiva === 'produtos'
              ? 'border-brand-lime text-brand-dark'
              : 'border-transparent text-text-default hover:text-brand-dark'
          }`}
        >
          🍔 Produtos do Catálogo
          <span className="rounded-full bg-surface-bg px-2 py-0.5 text-xs">{produtos.length}</span>
        </button>

        <button
          type="button"
          onClick={() => setAbaAtiva('categorias')}
          className={`flex items-center gap-2 border-b-2 px-6 py-3 text-sm font-semibold transition-colors ${
            abaAtiva === 'categorias'
              ? 'border-brand-lime text-brand-dark'
              : 'border-transparent text-text-default hover:text-brand-dark'
          }`}
        >
          🏷️ Categorias
          <span className="rounded-full bg-surface-bg px-2 py-0.5 text-xs">{categorias.length}</span>
        </button>

        <button
          type="button"
          onClick={() => setAbaAtiva('configuracoes')}
          className={`border-b-2 px-6 py-3 text-sm font-semibold transition-colors ${
            abaAtiva === 'configuracoes'
              ? 'border-brand-lime text-brand-dark'
              : 'border-transparent text-text-default hover:text-brand-dark'
          }`}
        >
          ⚙️ Configurações da Loja
        </button>
      </div>

      {/* ABA 1: PRODUTOS */}
      {abaAtiva === 'produtos' && (
        <section className="space-y-4">
          {/* Barra de Filtros e Ação */}
          <div className="flex flex-col gap-3 rounded-2xl border border-surface-bg bg-surface p-4 shadow-xs md:flex-row md:items-center md:justify-between">
            <div className="flex flex-1 flex-wrap items-center gap-2">
              <input
                type="text"
                value={buscaTexto}
                onChange={(e) => setBuscaTexto(e.target.value)}
                placeholder="Buscar produto por nome ou descrição..."
                className="w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-xs font-medium text-brand-dark outline-none focus:border-brand-outline sm:w-64"
              />

              <select
                value={filtroCategoria ?? ''}
                onChange={(e) => setFiltroCategoria(e.target.value ? Number(e.target.value) : null)}
                className="rounded-2xl border border-surface-bg bg-surface px-3 py-2 text-xs font-medium text-brand-dark outline-none focus:border-brand-outline"
              >
                <option value="">Todas as Categorias</option>
                {categorias.map((c) => (
                  <option key={c.idCategoria} value={c.idCategoria}>
                    {c.nome} ({c.totalProdutos})
                  </option>
                ))}
              </select>

              <div className="flex rounded-full border border-surface-bg bg-surface-bg/50 p-0.5 text-xs">
                <button
                  type="button"
                  onClick={() => setFiltroAtivo('todos')}
                  className={`rounded-full px-3 py-1 font-semibold transition-all ${
                    filtroAtivo === 'todos' ? 'bg-surface text-brand-dark shadow-xs' : 'text-text-default'
                  }`}
                >
                  Todos
                </button>
                <button
                  type="button"
                  onClick={() => setFiltroAtivo('ativo')}
                  className={`rounded-full px-3 py-1 font-semibold transition-all ${
                    filtroAtivo === 'ativo' ? 'bg-surface text-brand-dark shadow-xs' : 'text-text-default'
                  }`}
                >
                  Ativos
                </button>
                <button
                  type="button"
                  onClick={() => setFiltroAtivo('inativo')}
                  className={`rounded-full px-3 py-1 font-semibold transition-all ${
                    filtroAtivo === 'inativo' ? 'bg-surface text-brand-dark shadow-xs' : 'text-text-default'
                  }`}
                >
                  Pausados (RF07)
                </button>
              </div>
            </div>

            <button
              type="button"
              onClick={abrirModalNovoProduto}
              className="inline-flex items-center justify-center gap-1.5 rounded-full bg-brand-lime px-5 py-2 text-xs font-semibold text-brand-dark shadow-low transition-all hover:bg-brand-green/30"
            >
              + Novo Produto
            </button>
          </div>

          {/* Lista de Produtos */}
          {carregandoProdutos ? (
            <div className="rounded-2xl border border-surface-bg bg-surface p-12 text-center text-sm text-text-default">
              Carregando catálogo...
            </div>
          ) : produtos.length === 0 ? (
            <div className="rounded-2xl border border-surface-bg bg-surface p-12 text-center text-sm text-text-default">
              Nenhum produto encontrado com os filtros selecionados.
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
              {produtos.map((produto) => (
                <div
                  key={produto.idProduto}
                  className={`flex flex-col justify-between rounded-2xl border p-5 transition-all ${
                    produto.ativo
                      ? 'border-surface-bg bg-surface shadow-xs hover:border-brand-outline/40'
                      : 'border-state-cancelled/20 bg-surface/60 opacity-80'
                  }`}
                >
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <h4 className="font-display text-base font-semibold text-brand-dark">
                        {produto.nome}
                      </h4>
                      <span
                        className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${
                          produto.ativo
                            ? 'bg-state-success/15 text-brand-dark'
                            : 'bg-state-cancelled/15 text-state-error'
                        }`}
                      >
                        {produto.ativo ? 'Disponível' : 'Pausado (RF07)'}
                      </span>
                    </div>

                    {produto.descricao && (
                      <p className="mt-1 text-xs text-text-default line-clamp-2">{produto.descricao}</p>
                    )}

                    <div className="mt-2 flex flex-wrap gap-1">
                      {produto.categorias.map((cat) => (
                        <span
                          key={cat.idCategoria}
                          className="rounded-full bg-surface-bg px-2 py-0.5 text-[10px] font-medium text-text-default"
                        >
                          {cat.nome}
                        </span>
                      ))}
                    </div>
                  </div>

                  <div className="mt-5 flex items-center justify-between border-t border-surface-bg pt-3">
                    <span className="font-display text-base font-bold text-brand-dark">
                      {formatarMoeda(produto.preco)}
                    </span>

                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => alternarAtivoProduto(produto.idProduto, produto.ativo)}
                        className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${
                          produto.ativo
                            ? 'border border-state-cancelled/40 text-state-error hover:bg-state-cancelled/10'
                            : 'border border-brand-green/40 bg-brand-lime/30 text-brand-dark hover:bg-brand-lime'
                        }`}
                        title="Pausar ou reativar venda deste produto (RF07)"
                      >
                        {produto.ativo ? 'Pausar' : 'Ativar'}
                      </button>

                      <button
                        type="button"
                        onClick={() => abrirModalEditarProduto(produto)}
                        className="rounded-full bg-surface-bg px-3 py-1 text-xs font-semibold text-brand-dark hover:bg-surface-bg/80"
                      >
                        Editar
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      )}

      {/* ABA 2: CATEGORIAS */}
      {abaAtiva === 'categorias' && (
        <section className="space-y-6">
          {/* Formulário de Criação de Categoria */}
          <div className="rounded-2xl border border-surface-bg bg-surface p-6 shadow-xs">
            <h3 className="font-display text-base font-semibold text-brand-dark">
              Adicionar Nova Categoria
            </h3>
            <form onSubmit={handleSubmitCategoria(onCriarCategoria)} className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-start">
              <div className="flex-1">
                <input
                  type="text"
                  placeholder="Nome da categoria (ex: Sobremesas, Bebidas Geladas...)"
                  {...registerCategoria('nome')}
                  className="w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
                />
                {errorsCategoria.nome && (
                  <p className="mt-1 text-xs text-state-error">{errorsCategoria.nome.message}</p>
                )}
              </div>
              <button
                type="submit"
                disabled={salvando}
                className="rounded-full bg-brand-lime px-6 py-2 text-xs font-semibold text-brand-dark shadow-low transition-all hover:bg-brand-green/30 disabled:opacity-50"
              >
                {salvando ? 'Salvando...' : '+ Criar Categoria'}
              </button>
            </form>
          </div>

          {/* Tabela de Categorias */}
          <div className="overflow-hidden rounded-2xl border border-surface-bg bg-surface shadow-xs">
            <div className="border-b border-surface-bg px-6 py-4">
              <h3 className="font-display text-base font-semibold text-brand-dark">
                Categorias Cadastradas na Loja
              </h3>
              <p className="text-xs text-text-default">
                Regra RR18: Categorias que forem a única classificação de algum produto não podem ser excluídas até que os produtos sejam reclassificados.
              </p>
            </div>

            {carregandoCategorias ? (
              <div className="p-8 text-center text-sm text-text-default">Carregando categorias...</div>
            ) : categorias.length === 0 ? (
              <div className="p-8 text-center text-sm text-text-default">
                Nenhuma categoria cadastrada. Crie a primeira acima.
              </div>
            ) : (
              <div className="divide-y divide-surface-bg">
                {categorias.map((cat) => (
                  <div key={cat.idCategoria} className="flex items-center justify-between px-6 py-3.5">
                    <div>
                      <span className="font-display text-sm font-semibold text-brand-dark">
                        {cat.nome}
                      </span>
                      <span className="ml-3 rounded-full bg-surface-bg px-2.5 py-0.5 text-xs text-text-default">
                        {cat.totalProdutos} {cat.totalProdutos === 1 ? 'produto associado' : 'produtos associados'}
                      </span>
                    </div>

                    <button
                      type="button"
                      disabled={salvando}
                      onClick={() => removerCategoria(cat.idCategoria)}
                      className="rounded-full px-3 py-1 text-xs font-semibold text-state-error hover:bg-state-cancelled/10 transition-colors disabled:opacity-50"
                      title="Excluir categoria (RR18 validado no backend)"
                    >
                      Excluir
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>
      )}

      {/* ABA 3: CONFIGURAÇÕES DA LOJA */}
      {abaAtiva === 'configuracoes' && (
        <section className="rounded-2xl border border-surface-bg bg-surface p-6 shadow-xs">
          <h3 className="font-display text-lg font-semibold text-brand-dark">
            Configurações Operacionais da Loja
          </h3>
          <p className="mt-1 text-xs text-text-default">
            Atualize dados de contato, frete e tempo de preparo para os pedidos dos clientes.
          </p>

          <form onSubmit={handleSubmitLoja(onSalvarLoja)} className="mt-6 space-y-4 max-w-xl">
            <div>
              <label htmlFor="loja-tel" className="block text-xs font-semibold text-brand-dark">
                Telefone de Contato *
              </label>
              <input
                id="loja-tel"
                type="text"
                {...registerLoja('telefone')}
                className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
              />
              {errorsLoja.telefone && (
                <p className="mt-1 text-xs text-state-error">{errorsLoja.telefone.message}</p>
              )}
            </div>

            <div>
              <label htmlFor="loja-comp" className="block text-xs font-semibold text-brand-dark">
                Complemento de Endereço (opcional)
              </label>
              <input
                id="loja-comp"
                type="text"
                placeholder="Ex: Sala 10, Box 4..."
                {...registerLoja('complementoEndereco')}
                className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
              />
              {errorsLoja.complementoEndereco && (
                <p className="mt-1 text-xs text-state-error">{errorsLoja.complementoEndereco.message}</p>
              )}
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <label htmlFor="loja-tempo" className="block text-xs font-semibold text-brand-dark">
                  Tempo Estimado (min) * — <span className="text-[11px] text-text-default">RR13: &gt; 0</span>
                </label>
                <input
                  id="loja-tempo"
                  type="number"
                  min="1"
                  {...registerLoja('tempoEntregaEstimado')}
                  className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
                />
                {errorsLoja.tempoEntregaEstimado && (
                  <p className="mt-1 text-xs text-state-error">{errorsLoja.tempoEntregaEstimado.message}</p>
                )}
              </div>

              <div>
                <label htmlFor="loja-taxa" className="block text-xs font-semibold text-brand-dark">
                  Taxa de Entrega (R$) * — <span className="text-[11px] text-text-default">RR13: &gt;= 0</span>
                </label>
                <input
                  id="loja-taxa"
                  type="number"
                  step="0.01"
                  min="0.00"
                  {...registerLoja('taxaEntrega')}
                  className="mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline"
                />
                {errorsLoja.taxaEntrega && (
                  <p className="mt-1 text-xs text-state-error">{errorsLoja.taxaEntrega.message}</p>
                )}
              </div>
            </div>

            <div className="border-t border-surface-bg pt-4">
              <button
                type="submit"
                disabled={salvando}
                className="rounded-full bg-brand-lime px-6 py-2.5 text-xs font-semibold text-brand-dark shadow-low transition-all hover:bg-brand-green/30 disabled:opacity-50"
              >
                {salvando ? 'Salvando...' : 'Salvar Alterações'}
              </button>
            </div>
          </form>
        </section>
      )}

      {/* Modal de Criação / Edição de Produto */}
      <FormProdutoModal
        aberto={modalProdutoAberto}
        onFechar={() => setModalProdutoAberto(false)}
        onSalvar={onSalvarProdutoModal}
        produtoParaEditar={produtoParaEditar}
        categoriasDisponiveis={categorias}
        salvando={salvando}
      />
    </div>
  )
}
