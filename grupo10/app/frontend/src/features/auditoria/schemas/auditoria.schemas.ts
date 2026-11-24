/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Auditoria — validação de filtros de consulta (RF05, RF10)
 */
import { z } from 'zod'

export const buscaRastreioSchema = z.object({
  tipo: z.enum(['pedido', 'entrega']),
  id: z
    .string()
    .trim()
    .min(1, 'Informe o identificador para consultar.')
    .refine((v) => /^\d+$/.test(v) && Number(v) > 0, 'Informe um ID numérico inteiro positivo.'),
})

export type BuscaRastreioFormValues = z.infer<typeof buscaRastreioSchema>

export const filtroSlaSchema = z
  .object({
    idLoja: z
      .string()
      .trim()
      .refine((v) => v === '' || (/^\d+$/.test(v) && Number(v) > 0), 'ID da loja deve ser um número positivo.'),
    inicio: z.string(),
    fim: z.string(),
    apenasAtrasadas: z.boolean(),
  })
  .refine(
    (dados) => {
      if (!dados.inicio || !dados.fim) return true
      return new Date(dados.inicio).getTime() <= new Date(dados.fim).getTime()
    },
    {
      message: 'A data inicial não pode ser posterior à data final.',
      path: ['fim'],
    },
  )

export type FiltroSlaFormValues = z.infer<typeof filtroSlaSchema>