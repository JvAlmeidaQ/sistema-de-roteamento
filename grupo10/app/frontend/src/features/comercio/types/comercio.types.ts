/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */

export type FormaPagamento = 'pix' | 'cartao_credito' | 'cartao_debito' | 'dinheiro'

export type StatusPedido =
  | 'solicitado'
  | 'aceito'
  | 'recusado'
  | 'pago'
  | 'em_preparacao'
  | 'pronto'
  | 'concluido'

export interface UsuarioSessao {
  idPessoa: number
  nome: string
  email?: string
  perfilCliente: boolean
  perfilLojista: boolean
  perfilEntregador?: boolean
  administrador?: boolean
  idLoja: number | null
  nomeLoja: string | null
}

export interface ProdutoCheckout {
  idProduto: number
  idLoja: number
  nome: string
  descricao: string | null
  preco: number
  ativo: boolean
}

export interface LojaCheckout {
  idLoja: number
  idLojista: number
  nome: string
  cnpj: string
  statusFuncionamento: 'aberta' | 'fechada'
  tempoEntregaEstimado: number
  taxaEntrega: number
  produtos: ProdutoCheckout[]
}

export interface EnderecoEntregaCliente {
  idEndereco: number
  apelido: string | null
  logradouro: string
  numero: string
  bairro: string
  cep: string
  cidade: string
  estado: string
  complemento: string | null
  referencia: string | null
  enderecoAtual: boolean
}

export interface ItemPedidoResponse {
  idProduto: number
  nomeProduto: string
  quantidade: number
  valorUnitario: number
  subtotalItem: number
}

export interface DivisaoPagamentoResponse {
  idPedido: number
  valorTotal: number
  parcelaLoja: number
  comissaoEntregador: number
  taxaPlataforma: number
  calculadaEm: string
}

export interface AvaliacaoResponse {
  idPedido: number
  nota: number
  comentario: string | null
  dataAvaliacao: string
}

export interface PedidoResponse {
  idPedido: number
  idLoja: number
  nomeLoja: string
  idCliente: number
  nomeCliente: string
  idEndereco: number
  resumoEndereco: string
  complementoEntrega: string | null
  referenciaEntrega: string | null
  observacaoEntrega: string | null
  status: StatusPedido
  statusEntrega: string | null
  dataPedido: string
  formaPagamento: FormaPagamento
  subtotal: number
  taxaEntrega: number
  taxaServico: number
  valorTotal: number
  itens: ItemPedidoResponse[]
  divisaoPagamento: DivisaoPagamentoResponse | null
  avaliacaoLoja: AvaliacaoResponse | null
  avaliacaoEntregador: AvaliacaoResponse | null
}

export interface ResumoFinanceiroLoja {
  idLoja: number
  nomeLoja: string
  pedidosConcluidos: number
  faturamentoBruto: number
  repasseTotalLoja: number
  totalComissaoEntregadores: number
  receitaPlataforma: number
  mediaAvaliacaoLoja: number | null
}

export interface RelatorioPedidosLoja {
  idLoja: number
  nomeLoja: string
  totalPedidosFiltrados: number
  faturamentoFiltrado: number
  ticketMedioFiltrado: number
  pedidos: PedidoResponse[]
}

export interface ConsultaEstrategicaResponse {
  numero: number
  titulo: string
  descricao: string
  colunas: string[]
  linhas: Record<string, unknown>[]
}

export interface ApiErrorPayload {
  status: number
  error: string
  message: string
  sqlState?: string | null
  timestamp?: string
  details?: string[]
}
