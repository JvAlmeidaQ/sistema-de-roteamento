/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Catálogo
 */
import { z } from 'zod'

export const atualizarLojaSchema = z.object({
  telefone: z
    .string()
    .trim()
    .min(1, 'Telefone é obrigatório.')
    .max(20, 'Telefone não pode exceder 20 caracteres.'),
  complementoEndereco: z
    .string()
    .trim()
    .max(80, 'Complemento não pode exceder 80 caracteres.')
    .optional()
    .or(z.literal('')),
  tempoEntregaEstimado: z
    .number({ error: 'Informe um valor numérico válido.' })
    .int('O tempo estimado deve ser um número inteiro.')
    .positive('RN09/RR13: O tempo de entrega deve ser estritamente maior que zero.'),
  taxaEntrega: z
    .number({ error: 'Informe um valor numérico válido.' })
    .min(0, 'RR13: A taxa de entrega não pode ser negativa.'),
})

export type AtualizarLojaFormValues = z.infer<typeof atualizarLojaSchema>

export const criarCategoriaSchema = z.object({
  nome: z
    .string()
    .trim()
    .min(1, 'Nome da categoria é obrigatório.')
    .max(80, 'Nome não pode exceder 80 caracteres.'),
})

export type CriarCategoriaFormValues = z.infer<typeof criarCategoriaSchema>

export const produtoSchema = z.object({
  nome: z
    .string()
    .trim()
    .min(1, 'Nome do produto é obrigatório.')
    .max(120, 'Nome não pode exceder 120 caracteres.'),
  descricao: z
    .string()
    .trim()
    .max(1000, 'Descrição não pode exceder 1000 caracteres.')
    .optional()
    .or(z.literal('')),
  preco: z
    .number({ error: 'Informe um valor numérico válido.' })
    .positive('RN09/RR13: O preço deve ser estritamente maior que zero.'),
  categoriasIds: z
    .array(z.number())
    .min(1, 'RR18: O produto deve pertencer a pelo menos uma categoria.'),
})

export type ProdutoFormValues = z.infer<typeof produtoSchema>
