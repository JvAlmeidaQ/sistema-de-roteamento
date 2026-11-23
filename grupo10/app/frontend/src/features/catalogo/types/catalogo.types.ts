/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Catálogo
 */

export type StatusFuncionamento = 'aberta' | 'fechada'

export interface CategoriaSimples {
  idCategoria: number
  nome: string
}

export interface CategoriaResponse {
  idCategoria: number
  idLoja: number
  nome: string
  totalProdutos: number
}

export interface ProdutoCatalogoResponse {
  idProduto: number
  idLoja: number
  nome: string
  descricao: string | null
  preco: number
  ativo: boolean
  categorias: CategoriaSimples[]
}

export interface LojaResponse {
  idLoja: number
  idLojista: number
  idEndereco: number
  complementoEndereco: string | null
  cnpj: string
  nome: string
  telefone: string
  statusFuncionamento: StatusFuncionamento
  tempoEntregaEstimado: number
  taxaEntrega: number
  logradouro: string
  numero: string
  bairro: string
  cidade: string
  estado: string
  cep: string
}

export interface AtualizarLojaRequest {
  telefone: string
  complementoEndereco?: string | null
  tempoEntregaEstimado: number
  taxaEntrega: number
}

export interface AtualizarStatusLojaRequest {
  statusFuncionamento: StatusFuncionamento
}

export interface CriarCategoriaRequest {
  nome: string
}

export interface CriarProdutoRequest {
  nome: string
  descricao?: string | null
  preco: number
  categoriasIds: number[]
}

export interface AtualizarProdutoRequest {
  nome: string
  descricao?: string | null
  preco: number
  categoriasIds: number[]
}

export interface AtualizarAtivoProdutoRequest {
  ativo: boolean
}

export interface FiltrosProdutos {
  idCategoria?: number | null
  ativo?: boolean | null
  busca?: string
}
