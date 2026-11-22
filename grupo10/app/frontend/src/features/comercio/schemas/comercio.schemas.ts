/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { z } from 'zod'

export const criarPedidoSchema = z.object({
  idLoja: z.number().int().positive('Selecione uma loja válida.'),
  idEndereco: z.number().int().positive('Selecione um endereço de entrega (RR03).'),
  formaPagamento: z.enum(['pix', 'cartao_credito', 'cartao_debito', 'dinheiro'], {
    message: 'Selecione uma forma de pagamento.',
  }),
  observacaoEntrega: z
    .string()
    .max(255, 'A observação deve ter no máximo 255 caracteres.')
    .optional(),
  itens: z
    .array(
      z.object({
        idProduto: z.number().int().positive(),
        quantidade: z
          .number()
          .int('A quantidade deve ser um número inteiro.')
          .min(1, 'RN09/RR13: A quantidade mínima é 1.'),
      }),
    )
    .min(1, 'RR19: Adicione ao menos um item ao pedido.'),
})

export type CriarPedidoFormValues = z.infer<typeof criarPedidoSchema>

export const avaliacaoSchema = z.object({
  nota: z
    .number()
    .int('RN06/RR15: A nota deve ser um número inteiro.')
    .min(1, 'RN06/RR15: A nota mínima é 1.')
    .max(5, 'RN06/RR15: A nota máxima é 5.'),
  comentario: z
    .string()
    .max(1000, 'O comentário deve ter no máximo 1000 caracteres.')
    .optional(),
})

export type AvaliacaoFormValues = z.infer<typeof avaliacaoSchema>
