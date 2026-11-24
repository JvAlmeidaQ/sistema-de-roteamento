/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01
 */

export type TipoTelefone = 'celular' | 'fixo' | 'comercial'
export type TipoVeiculo = 'moto' | 'bicicleta' | 'carro'
export type StatusFuncionamento = 'aberta' | 'fechada'

/** Linha da listagem (visão vw_perfil_pessoa). */
export interface PessoaResumo {
  idPessoa: number
  nome: string
  cpf: string
  email: string
  cliente: boolean
  lojista: boolean
  entregador: boolean
  tipoVeiculo: TipoVeiculo | null
  telefones: string | null
  qtdEnderecos: number
}

export interface TelefonePerfil {
  numero: string
  tipo: TipoTelefone
}

export interface EnderecoPerfil {
  idEndereco: number
  logradouro: string
  numero: string
  bairro: string
  cep: string
  cidade: string
  estado: string
  apelido: string | null
  complemento: string | null
  referencia: string | null
  atual: boolean
}

export interface LojaPerfil {
  idLoja: number
  nome: string
  cnpj: string
  statusFuncionamento: StatusFuncionamento
}

export interface Perfil {
  idPessoa: number
  nome: string
  cpf: string
  email: string
  cliente: boolean
  lojista: boolean
  entregador: boolean
  tipoVeiculo: TipoVeiculo | null
  telefones: TelefonePerfil[]
  enderecos: EnderecoPerfil[]
  lojas: LojaPerfil[]
  restricoes: {
    clienteComPedidos: boolean
    lojistaComLojas: boolean
    entregadorComRotas: boolean
  }
}

export interface EnderecoRequest {
  idEndereco: number | null
  logradouro?: string
  numero?: string
  bairro?: string
  cep?: string
  cidade?: string
  estado?: string
  apelido: string | null
  complemento: string | null
  referencia: string | null
  atual: boolean
}

export interface LojaInicialRequest {
  nome: string
  cnpj: string
  telefone: string
  logradouro: string
  numero: string
  bairro: string
  cep: string
  cidade: string
  estado: string
  complementoEndereco: string | null
  tempoEntregaEstimado: number
  taxaEntrega: number
  statusFuncionamento: StatusFuncionamento
}

export interface PerfilRequest {
  nome: string
  cpf: string
  email: string
  cliente: boolean
  lojista: boolean
  entregador: boolean
  tipoVeiculo: TipoVeiculo | null
  telefones: TelefonePerfil[]
  enderecos: EnderecoRequest[]
  primeiraLoja: LojaInicialRequest | null
}
