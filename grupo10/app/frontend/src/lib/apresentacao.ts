/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Utilitários de apresentação e formatação em linguagem natural de produto.
 */

export function limparNomeLoja(nome: string | null | undefined): string {
  if (!nome) return ''
  return nome.replace(/\s+#\d+$/, '').trim()
}

export function limparNomeProduto(nome: string | null | undefined): string {
  if (!nome) return ''
  return nome.replace(/\s+-\s+Loja\s+\d+$/, '').trim()
}

const FORMAS_PAGAMENTO: Record<string, string> = {
  pix: 'Pix',
  cartao_credito: 'Cartão de crédito',
  cartao_debito: 'Cartão de débito',
  dinheiro: 'Dinheiro',
}

export function formatarFormaPagamento(forma: string | null | undefined): string {
  if (!forma) return '—'
  return FORMAS_PAGAMENTO[forma] ?? forma
}

const STATUS_PEDIDO_ROTULO: Record<string, string> = {
  solicitado: 'Solicitado',
  aceito: 'Aceito',
  pago: 'Pago',
  em_preparacao: 'Em preparação',
  pronto: 'Pronto para entrega',
  concluido: 'Concluído',
  recusado: 'Recusado',
}

export function formatarStatusPedido(status: string | null | undefined): string {
  if (!status) return '—'
  return STATUS_PEDIDO_ROTULO[status] ?? status
}

const STATUS_ENTREGA_ROTULO: Record<string, string> = {
  aguardando_entregador: 'Aguardando entregador',
  aceita: 'Aceita',
  a_caminho: 'A caminho',
  entregue: 'Entregue',
}

export function formatarStatusEntrega(status: string | null | undefined): string {
  if (!status) return '—'
  return STATUS_ENTREGA_ROTULO[status] ?? status
}

const COLUNAS_CONSULTA: Record<string, string> = {
  id_pedido: 'Pedido',
  id_loja: 'Loja',
  id_cliente: 'Cliente',
  id_pessoa: 'Pessoa',
  nome: 'Nome',
  email: 'E-mail',
  cnpj: 'CNPJ',
  valor_total: 'Valor total',
  nota: 'Nota',
  qtd_pedidos: 'Qtd. pedidos',
  repasse_total_loja: 'Repasse líquido',
  ticket_medio: 'Ticket médio',
  forma_pagamento: 'Pagamento',
  status: 'Status',
}

export function formatarColunaConsulta(coluna: string): string {
  const chave = coluna.toLowerCase()
  if (COLUNAS_CONSULTA[chave]) return COLUNAS_CONSULTA[chave]
  return coluna.replaceAll('_', ' ')
}

export function formatarCodigoPedido(id: number): string {
  return `Pedido ${id}`
}

export function formatarCodigoRota(id: number): string {
  return `Rota ${id}`
}
