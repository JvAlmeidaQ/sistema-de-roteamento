/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — contratos de leitura (RF05, RF10, RN04, RN08)
 */

export type DominioEvento = 'COMERCIAL' | 'LOGISTICO'

export interface HistoricoPedidoEvento {
  idPedido: number
  status: string
  dataHora: string
}

export interface HistoricoEntregaEvento {
  idEntrega: number
  status: string
  dataHora: string
}

export interface LinhaTempoEvento {
  idPedido: number
  idLoja: number
  idCliente: number
  dominioEvento: DominioEvento
  statusEvento: string
  dataHora: string
}

export interface SlaEntregaItem {
  idEntrega: number
  idPedido: number
  idLoja: number
  nomeLoja: string
  idRota: number | null
  dataPedido: string
  previsaoEntrega: string
  entregueEm: string
  atrasada: boolean
  desvioMinutos: number
}

export interface FiltroSlaEntregas {
  idLoja?: number
  apenasAtrasadas?: boolean
  inicio?: string
  fim?: string
}