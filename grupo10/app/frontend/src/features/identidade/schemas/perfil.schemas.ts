/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01
 * Espelha no cliente as regras do PerfilService: RN10, RN11, RR01, RR03, RR12, RR14, RR16 e RR17.
 */
import { z } from 'zod'
import { cnpjValido, cpfValido, soDigitos } from '../utils/formatadores'

const UF_REGEX = /^[A-Z]{2}$/
const EMAIL_REGEX = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

const telefoneSchema = z.object({
  numero: z
    .string()
    .refine((v) => /^\d{10,11}$/.test(soDigitos(v)), 'Informe DDD + número (10 ou 11 dígitos).'),
  tipo: z.enum(['celular', 'fixo', 'comercial']),
})

const enderecoSchema = z.object({
  /** null = endereço novo; número = vínculo já existente (dados de localização imutáveis — RR12). */
  idEndereco: z.number().nullable(),
  logradouro: z.string().trim().max(150, 'Máximo de 150 caracteres.'),
  numero: z.string().trim().max(10, 'Máximo de 10 caracteres.'),
  bairro: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
  cep: z.string(),
  cidade: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
  estado: z.string().trim(),
  apelido: z.string().trim().max(40, 'Máximo de 40 caracteres.'),
  complemento: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
  referencia: z.string().trim().max(150, 'Máximo de 150 caracteres.'),
})

const primeiraLojaSchema = z.object({
  nome: z.string().trim().max(120, 'Máximo de 120 caracteres.'),
  cnpj: z.string(),
  telefone: z.string(),
  logradouro: z.string().trim().max(150, 'Máximo de 150 caracteres.'),
  numero: z.string().trim().max(10, 'Máximo de 10 caracteres.'),
  bairro: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
  cep: z.string(),
  cidade: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
  estado: z.string().trim(),
  complementoEndereco: z.string().trim().max(80, 'Máximo de 80 caracteres.'),
  tempoEntregaEstimado: z.string(),
  taxaEntrega: z.string(),
  statusFuncionamento: z.enum(['aberta', 'fechada']),
})

export const perfilSchema = z
  .object({
    modoEdicao: z.boolean(),
    /** Verdadeiro quando a pessoa já é Lojista com loja: o bloco "Primeira loja" não é exigido. */
    possuiLoja: z.boolean(),
    nome: z.string().trim().min(1, 'Nome é obrigatório.').max(120, 'Máximo de 120 caracteres.'),
    cpf: z.string(),
    email: z
      .string()
      .trim()
      .min(1, 'E-mail é obrigatório.')
      .max(255, 'Máximo de 255 caracteres.')
      .regex(EMAIL_REGEX, 'Informe um e-mail válido.'),
    cliente: z.boolean(),
    lojista: z.boolean(),
    entregador: z.boolean(),
    tipoVeiculo: z.enum(['', 'moto', 'bicicleta', 'carro']),
    telefones: z.array(telefoneSchema).min(1, 'RR17: informe ao menos um telefone.'),
    enderecos: z.array(enderecoSchema),
    indiceEnderecoAtual: z.number().nullable(),
    primeiraLoja: primeiraLojaSchema,
  })
  .superRefine((v, ctx) => {
    const erro = (path: (string | number)[], message: string) =>
      ctx.addIssue({ code: 'custom', path, message })

    if (!v.modoEdicao) {
      if (soDigitos(v.cpf).length !== 11) erro(['cpf'], 'RN10: o CPF deve ter 11 dígitos.')
      else if (!cpfValido(v.cpf)) erro(['cpf'], 'RN11: CPF inválido (dígitos verificadores não conferem).')
    }

    if (!v.cliente && !v.lojista && !v.entregador) {
      erro(['cliente'], 'RR16: selecione ao menos uma função.')
    }
    if (v.entregador && !v.tipoVeiculo) {
      erro(['tipoVeiculo'], 'Informe o veículo do entregador.')
    }

    const numeros = v.telefones.map((t) => soDigitos(t.numero))
    numeros.forEach((numero, i) => {
      if (numero && numeros.indexOf(numero) !== i) erro(['telefones', i, 'numero'], 'Telefone repetido.')
    })

    v.enderecos.forEach((endereco, i) => {
      if (endereco.idEndereco !== null) return
      if (!endereco.logradouro) erro(['enderecos', i, 'logradouro'], 'Logradouro é obrigatório.')
      if (!endereco.numero) erro(['enderecos', i, 'numero'], 'Número é obrigatório.')
      if (!endereco.bairro) erro(['enderecos', i, 'bairro'], 'Bairro é obrigatório.')
      if (soDigitos(endereco.cep).length !== 8) erro(['enderecos', i, 'cep'], 'RR14: o CEP deve ter 8 dígitos.')
      if (!endereco.cidade) erro(['enderecos', i, 'cidade'], 'Cidade é obrigatória.')
      if (!UF_REGEX.test(endereco.estado)) erro(['enderecos', i, 'estado'], 'RR14: UF com 2 letras.')
    })

    if (v.cliente) {
      if (v.enderecos.length === 0) {
        erro(['enderecos'], 'Todo cliente precisa de ao menos um endereço.')
      } else if (v.indiceEnderecoAtual === null || v.indiceEnderecoAtual >= v.enderecos.length) {
        erro(['indiceEnderecoAtual'], 'Selecione o endereço atual do cliente.')
      }
    }

    if (v.lojista && !v.possuiLoja) {
      const loja = v.primeiraLoja
      const base = ['primeiraLoja']
      if (!loja.nome) erro([...base, 'nome'], 'Nome da loja é obrigatório.')
      if (soDigitos(loja.cnpj).length !== 14) erro([...base, 'cnpj'], 'RN10: o CNPJ deve ter 14 dígitos.')
      else if (!cnpjValido(loja.cnpj)) erro([...base, 'cnpj'], 'RN11: CNPJ inválido (dígitos verificadores não conferem).')
      if (!/^\d{10,11}$/.test(soDigitos(loja.telefone))) erro([...base, 'telefone'], 'Informe DDD + número.')
      if (!loja.logradouro) erro([...base, 'logradouro'], 'Logradouro é obrigatório.')
      if (!loja.numero) erro([...base, 'numero'], 'Número é obrigatório.')
      if (!loja.bairro) erro([...base, 'bairro'], 'Bairro é obrigatório.')
      if (soDigitos(loja.cep).length !== 8) erro([...base, 'cep'], 'RR14: o CEP deve ter 8 dígitos.')
      if (!loja.cidade) erro([...base, 'cidade'], 'Cidade é obrigatória.')
      if (!UF_REGEX.test(loja.estado)) erro([...base, 'estado'], 'RR14: UF com 2 letras.')
      const tempo = Number(loja.tempoEntregaEstimado)
      if (!Number.isInteger(tempo) || tempo <= 0) {
        erro([...base, 'tempoEntregaEstimado'], 'RR13: tempo em minutos, maior que zero.')
      }
      const taxaTexto = loja.taxaEntrega.trim()
      const taxa = Number(taxaTexto.replace(',', '.'))
      if (!/^\d{1,10}([.,]\d{1,2})?$/.test(taxaTexto) || Number.isNaN(taxa) || taxa < 0) {
        erro([...base, 'taxaEntrega'], 'RR13: informe uma taxa não negativa com até 2 casas decimais.')
      }
    }
  })

export type PerfilFormValues = z.infer<typeof perfilSchema>
export type EnderecoFormValues = z.infer<typeof enderecoSchema>

export const ENDERECO_VAZIO: EnderecoFormValues = {
  idEndereco: null,
  logradouro: '',
  numero: '',
  bairro: '',
  cep: '',
  cidade: '',
  estado: '',
  apelido: '',
  complemento: '',
  referencia: '',
}

export const PRIMEIRA_LOJA_VAZIA: PerfilFormValues['primeiraLoja'] = {
  nome: '',
  cnpj: '',
  telefone: '',
  logradouro: '',
  numero: '',
  bairro: '',
  cep: '',
  cidade: '',
  estado: '',
  complementoEndereco: '',
  tempoEntregaEstimado: '',
  taxaEntrega: '',
  statusFuncionamento: 'aberta',
}
