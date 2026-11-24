/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Logística
 */
import { z } from 'zod'
import { api } from '@/lib/api'

const entregadoresSessaoSchema = z.array(z.object({
  idPessoa: z.number().int().positive(),
  nome: z.string(),
}))

export async function listarEntregadoresSessao() {
  const { data } = await api.get<unknown>('/logistica/sessao/entregadores')
  return entregadoresSessaoSchema.parse(data)
}
