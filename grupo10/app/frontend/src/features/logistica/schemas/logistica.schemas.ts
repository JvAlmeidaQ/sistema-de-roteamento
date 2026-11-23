/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import { z } from 'zod'

const idSchema = z.number().int().positive()
const contagemSchema = z.number().int().nonnegative()
const dataHoraSchema = z.iso.datetime({ offset: true })
const statusEntregaSchema = z.enum(['aceita', 'a_caminho', 'entregue'])

export const paginaSchema = <T>(item: z.ZodType<T>) => z.object({
  itens: z.array(item),
  pagina: z.number().int().positive(),
  temProxima: z.boolean(),
})

const entregaDisponivelSchema = z.object({
  idEntrega: idSchema,
  idPedido: idSchema,
  nomeLoja: z.string(),
  bairroDestino: z.string(),
  cidadeDestino: z.string(),
  estadoDestino: z.string(),
  previsaoEntrega: dataHoraSchema,
})

const entregaDaRotaSchema = z.object({
  idEntrega: idSchema,
  idPedido: idSchema,
  nomeLoja: z.string(),
  enderecoColeta: z.string(),
  enderecoEntrega: z.string(),
  complementoEntrega: z.string().nullable(),
  referenciaEntrega: z.string().nullable(),
  observacaoEntrega: z.string().nullable(),
  status: statusEntregaSchema,
  previsaoEntrega: dataHoraSchema,
  atrasada: z.boolean(),
})

const rotaAtualSchema = z.object({
  idRota: idSchema,
  criadaEm: dataHoraSchema,
  totalEntregas: contagemSchema,
  vagas: contagemSchema,
  entregasAtivas: contagemSchema,
  entregasAtrasadas: contagemSchema,
  entregas: z.array(entregaDaRotaSchema),
})

const rotaResumoSchema = z.object({
  idRota: idSchema,
  criadaEm: dataHoraSchema,
  encerradaEm: dataHoraSchema,
  totalEntregas: contagemSchema,
  idsPedidos: z.array(idSchema),
})

export const painelLogisticaSchema = z.object({
  rotaAtual: rotaAtualSchema.nullable(),
  disponiveis: paginaSchema(entregaDisponivelSchema),
  encerradas: paginaSchema(rotaResumoSchema),
})

export const statusPedidoSchema = z.enum([
  'solicitado', 'aceito', 'recusado', 'pago', 'em_preparacao', 'pronto', 'concluido',
])
export const statusEntregaRastreioSchema = z.enum(['aguardando_entregador', ...statusEntregaSchema.options])

export const rastreioPedidoSchema = z.object({
  idPedido: idSchema,
  nomeLoja: z.string(),
  statusPedido: statusPedidoSchema,
  entrega: z.object({ status: statusEntregaRastreioSchema, previsaoEntrega: dataHoraSchema }).nullable(),
  eventos: z.array(z.object({
    tipo: z.enum(['PEDIDO', 'ENTREGA']),
    status: z.string(), // O histórico pode conter um status que a UI ainda não reconhece.
    dataHora: dataHoraSchema,
  })),
  historicoIncompleto: z.boolean(),
})
