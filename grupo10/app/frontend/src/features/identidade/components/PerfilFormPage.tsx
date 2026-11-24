/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — RF01 (criação e edição de perfil)
 * Atende no cliente: RN10, RN11, RR01, RR03, RR12, RR14, RR16 e RR17
 */
import { useEffect, useState, type ChangeEvent, type ReactNode } from 'react'
import { useFieldArray, useForm, type Path } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { identidadeApi, lerErroApi, type ErroApi } from '../api/identidade.api'
import { usePerfil } from '../hooks/usePerfis'
import {
  ENDERECO_VAZIO,
  PRIMEIRA_LOJA_VAZIA,
  perfilSchema,
  type PerfilFormValues,
} from '../schemas/perfil.schemas'
import type { Perfil, PerfilRequest, TipoVeiculo } from '../types/identidade.types'
import {
  mascaraCep,
  mascaraCnpj,
  mascaraCpf,
  mascaraTelefone,
  soDigitos,
} from '../utils/formatadores'

const inputClass =
  'mt-1 w-full rounded-2xl border border-surface-bg bg-surface px-4 py-2 text-sm text-brand-dark outline-none focus:border-brand-outline focus-visible:ring-2 focus-visible:ring-brand-outline/30 read-only:bg-surface-bg/50 read-only:text-text-default'

const mascaraUf = (valor: string) => valor.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 2)
const textoOuNulo = (valor: string) => (valor.trim() ? valor.trim() : null)

function mensagemDe(erro: unknown): string | undefined {
  if (!erro || typeof erro !== 'object') return undefined
  const { message, root } = erro as { message?: string; root?: { message?: string } }
  return message ?? root?.message
}

function Campo({ id, label, erro, children, className }: {
  id?: string
  label: string
  erro?: unknown
  children: ReactNode
  className?: string
}) {
  const mensagem = mensagemDe(erro)
  const erroId = id && mensagem ? `${id}-erro` : undefined
  return (
    <div className={className}>
      <label htmlFor={id} className="block text-xs font-semibold text-brand-dark">{label}</label>
      {children}
      {mensagem && <p id={erroId} role="alert" className="mt-1 text-xs text-state-error">{mensagem}</p>}
    </div>
  )
}

function Secao({ titulo, descricao, children }: { titulo: string; descricao?: string; children: ReactNode }) {
  return (
    <section className="rounded-3xl bg-surface p-6 shadow-low">
      <h3 className="text-lg">{titulo}</h3>
      {descricao && <p className="mb-4 text-xs">{descricao}</p>}
      <div className={descricao ? '' : 'mt-4'}>{children}</div>
    </section>
  )
}

function valoresIniciais(perfil: Perfil | null): PerfilFormValues {
  if (!perfil) {
    return {
      modoEdicao: false,
      possuiLoja: false,
      nome: '',
      cpf: '',
      email: '',
      cliente: true,
      lojista: false,
      entregador: false,
      tipoVeiculo: '',
      telefones: [{ numero: '', tipo: 'celular' }],
      enderecos: [{ ...ENDERECO_VAZIO, apelido: 'Casa' }],
      indiceEnderecoAtual: 0,
      primeiraLoja: { ...PRIMEIRA_LOJA_VAZIA },
    }
  }
  const indiceAtual = perfil.enderecos.findIndex((e) => e.atual)
  return {
    modoEdicao: true,
    possuiLoja: perfil.lojas.length > 0,
    nome: perfil.nome,
    cpf: mascaraCpf(perfil.cpf),
    email: perfil.email,
    cliente: perfil.cliente,
    lojista: perfil.lojista,
    entregador: perfil.entregador,
    tipoVeiculo: perfil.tipoVeiculo ?? '',
    telefones: perfil.telefones.map((t) => ({ numero: mascaraTelefone(t.numero), tipo: t.tipo })),
    enderecos: perfil.enderecos.map((e) => ({
      idEndereco: e.idEndereco,
      logradouro: e.logradouro,
      numero: e.numero,
      bairro: e.bairro,
      cep: mascaraCep(e.cep),
      cidade: e.cidade,
      estado: e.estado,
      apelido: e.apelido ?? '',
      complemento: e.complemento ?? '',
      referencia: e.referencia ?? '',
    })),
    indiceEnderecoAtual: indiceAtual >= 0 ? indiceAtual : null,
    primeiraLoja: { ...PRIMEIRA_LOJA_VAZIA },
  }
}

function montarPayload(v: PerfilFormValues, perfil: Perfil | null): PerfilRequest {
  const precisaLoja = v.lojista && !v.possuiLoja
  const loja = v.primeiraLoja
  return {
    nome: v.nome.trim(),
    cpf: perfil ? perfil.cpf : soDigitos(v.cpf),
    email: v.email.trim(),
    cliente: v.cliente,
    lojista: v.lojista,
    entregador: v.entregador,
    tipoVeiculo: v.entregador && v.tipoVeiculo ? (v.tipoVeiculo as TipoVeiculo) : null,
    telefones: v.telefones.map((t) => ({ numero: soDigitos(t.numero), tipo: t.tipo })),
    enderecos: v.enderecos.map((e, i) => {
      const comum = {
        apelido: textoOuNulo(e.apelido),
        complemento: textoOuNulo(e.complemento),
        referencia: textoOuNulo(e.referencia),
        atual: v.cliente && v.indiceEnderecoAtual === i,
      }
      return e.idEndereco !== null
        ? { idEndereco: e.idEndereco, ...comum }
        : {
            idEndereco: null,
            logradouro: e.logradouro.trim(),
            numero: e.numero.trim(),
            bairro: e.bairro.trim(),
            cep: soDigitos(e.cep),
            cidade: e.cidade.trim(),
            estado: e.estado,
            ...comum,
          }
    }),
    primeiraLoja: precisaLoja
      ? {
          nome: loja.nome.trim(),
          cnpj: soDigitos(loja.cnpj),
          telefone: soDigitos(loja.telefone),
          logradouro: loja.logradouro.trim(),
          numero: loja.numero.trim(),
          bairro: loja.bairro.trim(),
          cep: soDigitos(loja.cep),
          cidade: loja.cidade.trim(),
          estado: loja.estado,
          complementoEndereco: textoOuNulo(loja.complementoEndereco),
          tempoEntregaEstimado: Number(loja.tempoEntregaEstimado),
          taxaEntrega: Number(loja.taxaEntrega.replace(',', '.')),
          statusFuncionamento: loja.statusFuncionamento,
        }
      : null,
  }
}

export default function PerfilFormPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { usuarioAtual } = useSessaoUsuario()
  const idPessoa = id ? Number(id) : null
  const modoEdicao = idPessoa !== null
  const idValido = !modoEdicao || (Number.isSafeInteger(idPessoa) && (idPessoa ?? 0) > 0)
  const { perfil, carregando, erro: erroCarga } = usePerfil(
    modoEdicao && idValido ? idPessoa : null,
    usuarioAtual?.idPessoa ?? null,
  )
  const [erroApi, setErroApi] = useState<ErroApi | null>(null)

  const {
    register,
    control,
    handleSubmit,
    reset,
    watch,
    setValue,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<PerfilFormValues>({
    resolver: zodResolver(perfilSchema),
    defaultValues: valoresIniciais(null),
  })

  const telefones = useFieldArray({ control, name: 'telefones' })
  const enderecos = useFieldArray({ control, name: 'enderecos' })

  useEffect(() => {
    if (!modoEdicao) {
      reset(valoresIniciais(null))
      setErroApi(null)
    } else if (perfil) {
      reset(valoresIniciais(perfil))
    }
  }, [modoEdicao, perfil, reset])

  const cliente = watch('cliente')
  const lojista = watch('lojista')
  const entregador = watch('entregador')
  const possuiLoja = watch('possuiLoja')
  const indiceAtual = watch('indiceEnderecoAtual')

  const restricoes = perfil?.restricoes
  const travaCliente = !!(perfil?.cliente && restricoes?.clienteComPedidos)
  const travaLojista = !!(perfil?.lojista && restricoes?.lojistaComLojas)
  const travaEntregador = !!(perfil?.entregador && restricoes?.entregadorComRotas)

  const comMascara = (nome: Path<PerfilFormValues>, mascara: (valor: string) => string) => {
    const registro = register(nome)
    return {
      ...registro,
      onChange: (e: ChangeEvent<HTMLInputElement>) => {
        e.target.value = mascara(e.target.value)
        return registro.onChange(e)
      },
    }
  }

  const removerEndereco = (indice: number) => {
    enderecos.remove(indice)
    if (indiceAtual === null) return
    if (indice === indiceAtual) setValue('indiceEnderecoAtual', null)
    else if (indice < indiceAtual) setValue('indiceEnderecoAtual', indiceAtual - 1)
  }

  const adicionarEndereco = () => {
    enderecos.append({ ...ENDERECO_VAZIO })
    if (indiceAtual === null) setValue('indiceEnderecoAtual', enderecos.fields.length)
  }

  const onSubmit = async (valores: PerfilFormValues) => {
    setErroApi(null)
    try {
      const payload = montarPayload(valores, perfil)
      const salvo = modoEdicao && idPessoa !== null
        ? await identidadeApi.atualizarPerfil(idPessoa, payload)
        : await identidadeApi.criarPerfil(payload)
      navigate(`/perfis/${salvo.idPessoa}`, {
        state: { mensagem: modoEdicao ? 'Perfil atualizado com sucesso.' : 'Perfil cadastrado com sucesso.' },
      })
    } catch (e) {
      const falha = lerErroApi(e)
      setErroApi(falha)
      if (falha.status === 409) {
        if (/CPF/i.test(falha.mensagem)) setError('cpf', { message: falha.mensagem })
        if (/e-mail/i.test(falha.mensagem)) setError('email', { message: falha.mensagem })
        if (/CNPJ/i.test(falha.mensagem)) setError('primeiraLoja.cnpj', { message: falha.mensagem })
      }
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  if (!idValido) {
    return <p role="alert" className="text-state-error">Identificador de pessoa inválido.</p>
  }
  if (modoEdicao && carregando) {
    return <div className="h-64 animate-pulse rounded-3xl bg-surface" role="status" aria-label="Carregando perfil" />
  }
  if (modoEdicao && (erroCarga || !perfil)) {
    return (
      <div className="space-y-3">
        <p role="alert" className="rounded-2xl bg-state-error/10 px-4 py-3 text-sm text-state-error">
          {erroCarga?.status === 403
            ? 'Você só tem permissão para editar o seu próprio perfil. Selecione esta conta no seletor Sessão (X-User-Id) para continuar.'
            : erroCarga?.status === 404
              ? 'Pessoa não encontrada.'
              : erroCarga?.mensagem ?? 'Não foi possível carregar o perfil.'}
        </p>
        <Link to="/perfis" className="text-sm font-semibold text-brand-outline hover:underline">← Voltar para a lista</Link>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate className="space-y-6">
      <header className="space-y-1">
        <Link
          to={modoEdicao ? `/perfis/${idPessoa}` : '/perfis'}
          className="text-sm font-semibold text-brand-outline hover:underline"
        >
          ← {modoEdicao ? 'Voltar ao perfil' : 'Perfis'}
        </Link>
        <h2 className="text-3xl">{modoEdicao ? `Editar perfil — ${perfil?.nome}` : 'Novo perfil'}</h2>
        <p className="text-sm">Campos com * são obrigatórios. Tudo é salvo em uma única transação.</p>
      </header>

      {erroApi && (
        <div role="alert" className="rounded-2xl bg-state-error/10 px-4 py-3 text-sm text-state-error">
          <p className="font-semibold">{erroApi.mensagem}</p>
          {erroApi.detalhes.length > 0 && (
            <ul className="mt-1 list-disc pl-5 text-xs">
              {erroApi.detalhes.map((d) => <li key={d}>{d}</li>)}
            </ul>
          )}
        </div>
      )}

      {/* ------------------------------------------------------------ Dados pessoais */}
      <Secao titulo="Dados pessoais">
        <div className="grid gap-4 md:grid-cols-3">
          <Campo id="perfil-nome" label="Nome completo *" erro={errors.nome} className="md:col-span-3">
            <input id="perfil-nome" {...register('nome')} className={inputClass} autoComplete="name" />
          </Campo>
          <Campo
            id="perfil-cpf"
            label={modoEdicao ? 'CPF (não pode ser alterado)' : 'CPF * (RN10/RN11)'}
            erro={errors.cpf}
          >
            <input
              id="perfil-cpf"
              inputMode="numeric"
              placeholder="000.000.000-00"
              readOnly={modoEdicao}
              {...comMascara('cpf', mascaraCpf)}
              className={inputClass}
            />
          </Campo>
          <Campo id="perfil-email" label="E-mail *" erro={errors.email} className="md:col-span-2">
            <input id="perfil-email" type="email" {...register('email')} className={inputClass} autoComplete="email" />
          </Campo>
        </div>
      </Secao>

      {/* ------------------------------------------------------------ Funções */}
      <Secao
        titulo="Funções"
        descricao="RR16: escolha ao menos uma. A mesma pessoa pode acumular mais de uma função."
      >
        <div className="grid gap-3 md:grid-cols-3">
          {([
            ['cliente', 'Cliente', 'Faz pedidos nas lojas.', travaCliente, 'Possui pedidos registrados.'],
            ['lojista', 'Lojista', 'Responsável por uma ou mais lojas.', travaLojista, 'Responsável por loja(s) — RR01.'],
            ['entregador', 'Entregador', 'Realiza entregas em rotas.', travaEntregador, 'Possui rotas registradas.'],
          ] as const).map(([campo, titulo, descricao, travado, motivo]) => (
            <label
              key={campo}
              className={`flex cursor-pointer gap-3 rounded-2xl border p-4 transition-colors ${
                watch(campo) ? 'border-brand-green bg-brand-lime/15' : 'border-surface-bg hover:bg-surface-bg/40'
              } ${travado ? 'cursor-not-allowed' : ''}`}
            >
              <input
                type="checkbox"
                {...register(campo)}
                aria-disabled={travado}
                onClick={travado ? (e) => e.preventDefault() : undefined}
                className="mt-1 accent-brand-green"
              />
              <span className="text-sm">
                <span className="block font-semibold text-brand-dark">{titulo}</span>
                <span className="block text-xs">{travado ? `Não pode ser removida: ${motivo}` : descricao}</span>
              </span>
            </label>
          ))}
        </div>
        {mensagemDe(errors.cliente) && (
          <p className="mt-2 text-xs text-state-error">{mensagemDe(errors.cliente)}</p>
        )}

        {entregador && (
          <Campo id="perfil-veiculo" label="Veículo do entregador *" erro={errors.tipoVeiculo} className="mt-4 max-w-xs">
            <select id="perfil-veiculo" {...register('tipoVeiculo')} className={inputClass}>
              <option value="">Selecione…</option>
              <option value="moto">Moto</option>
              <option value="bicicleta">Bicicleta</option>
              <option value="carro">Carro</option>
            </select>
          </Campo>
        )}
      </Secao>

      {/* ------------------------------------------------------------ Telefones */}
      <Secao titulo="Telefones" descricao="RR17: ao menos um telefone, com DDD.">
        <div className="space-y-3">
          {telefones.fields.map((field, i) => (
            <div key={field.id} className="flex flex-wrap items-start gap-3">
              <Campo id={`tel-${i}`} label={`Telefone ${i + 1} *`} erro={errors.telefones?.[i]?.numero} className="min-w-48 flex-1">
                <input
                  id={`tel-${i}`}
                  inputMode="tel"
                  placeholder="(32) 99999-0000"
                  {...comMascara(`telefones.${i}.numero`, mascaraTelefone)}
                  className={inputClass}
                />
              </Campo>
              <Campo id={`tel-tipo-${i}`} label="Tipo" className="w-40">
                <select id={`tel-tipo-${i}`} {...register(`telefones.${i}.tipo`)} className={inputClass}>
                  <option value="celular">Celular</option>
                  <option value="fixo">Fixo</option>
                  <option value="comercial">Comercial</option>
                </select>
              </Campo>
              <button
                type="button"
                onClick={() => telefones.remove(i)}
                disabled={telefones.fields.length === 1}
                title={telefones.fields.length === 1 ? 'RR17: a pessoa precisa de ao menos um telefone.' : 'Remover telefone'}
                className="mt-6 rounded-full px-3 py-2 text-xs font-semibold text-state-error hover:bg-state-error/10 disabled:opacity-40"
              >
                Remover
              </button>
            </div>
          ))}
        </div>
        {mensagemDe(errors.telefones) && (
          <p className="mt-2 text-xs text-state-error">{mensagemDe(errors.telefones)}</p>
        )}
        <button
          type="button"
          onClick={() => telefones.append({ numero: '', tipo: 'celular' })}
          className="mt-3 rounded-full border border-brand-outline px-4 py-1.5 text-xs font-semibold text-brand-outline hover:bg-brand-lime/20"
        >
          + Adicionar telefone
        </button>
      </Secao>

      {/* ------------------------------------------------------------ Endereços */}
      <Secao
        titulo="Endereços"
        descricao={
          cliente
            ? 'Todo cliente precisa de ao menos um endereço e de um endereço atual. Rua, número e CEP de um endereço salvo não mudam (RR12); para mudar, adicione outro e remova o antigo.'
            : 'Opcional para quem não é cliente. Rua, número e CEP de um endereço salvo não mudam (RR12).'
        }
      >
        <div className="space-y-4">
          {enderecos.fields.map((field, i) => {
            const existente = field.idEndereco !== null
            const erroEndereco = errors.enderecos?.[i]
            return (
              <div
                key={field.id}
                className={`rounded-2xl border p-4 ${cliente && indiceAtual === i ? 'border-brand-green bg-brand-lime/10' : 'border-surface-bg'}`}
              >
                <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                  <span className="text-sm font-semibold text-brand-dark">
                    {existente ? `Endereço salvo #${field.idEndereco}` : 'Novo endereço'}
                  </span>
                  <div className="flex items-center gap-3">
                    {cliente && (
                      <label className="flex items-center gap-2 text-xs font-semibold text-brand-dark">
                        <input
                          type="radio"
                          name="endereco-atual"
                          checked={indiceAtual === i}
                          onChange={() => setValue('indiceEnderecoAtual', i, { shouldValidate: true })}
                          className="accent-brand-green"
                        />
                        Endereço atual
                      </label>
                    )}
                    <button
                      type="button"
                      onClick={() => removerEndereco(i)}
                      className="rounded-full px-3 py-1 text-xs font-semibold text-state-error hover:bg-state-error/10"
                    >
                      Remover
                    </button>
                  </div>
                </div>

                <div className="grid gap-3 md:grid-cols-6">
                  <Campo id={`end-log-${i}`} label="Logradouro *" erro={erroEndereco?.logradouro} className="md:col-span-4">
                    <input id={`end-log-${i}`} readOnly={existente} {...register(`enderecos.${i}.logradouro`)} className={inputClass} />
                  </Campo>
                  <Campo id={`end-num-${i}`} label="Número *" erro={erroEndereco?.numero} className="md:col-span-2">
                    <input id={`end-num-${i}`} readOnly={existente} {...register(`enderecos.${i}.numero`)} className={inputClass} />
                  </Campo>
                  <Campo id={`end-bairro-${i}`} label="Bairro *" erro={erroEndereco?.bairro} className="md:col-span-2">
                    <input id={`end-bairro-${i}`} readOnly={existente} {...register(`enderecos.${i}.bairro`)} className={inputClass} />
                  </Campo>
                  <Campo id={`end-cep-${i}`} label="CEP *" erro={erroEndereco?.cep} className="md:col-span-1">
                    <input
                      id={`end-cep-${i}`}
                      inputMode="numeric"
                      placeholder="00000-000"
                      readOnly={existente}
                      {...comMascara(`enderecos.${i}.cep`, mascaraCep)}
                      className={inputClass}
                    />
                  </Campo>
                  <Campo id={`end-cidade-${i}`} label="Cidade *" erro={erroEndereco?.cidade} className="md:col-span-2">
                    <input id={`end-cidade-${i}`} readOnly={existente} {...register(`enderecos.${i}.cidade`)} className={inputClass} />
                  </Campo>
                  <Campo id={`end-uf-${i}`} label="UF *" erro={erroEndereco?.estado} className="md:col-span-1">
                    <input
                      id={`end-uf-${i}`}
                      placeholder="MG"
                      readOnly={existente}
                      {...comMascara(`enderecos.${i}.estado`, mascaraUf)}
                      className={inputClass}
                    />
                  </Campo>
                  <Campo id={`end-apelido-${i}`} label="Apelido" erro={erroEndereco?.apelido} className="md:col-span-2">
                    <input id={`end-apelido-${i}`} placeholder="Casa, Trabalho…" {...register(`enderecos.${i}.apelido`)} className={inputClass} />
                  </Campo>
                  <Campo id={`end-comp-${i}`} label="Complemento" erro={erroEndereco?.complemento} className="md:col-span-2">
                    <input id={`end-comp-${i}`} placeholder="Apto, bloco…" {...register(`enderecos.${i}.complemento`)} className={inputClass} />
                  </Campo>
                  <Campo id={`end-ref-${i}`} label="Referência" erro={erroEndereco?.referencia} className="md:col-span-2">
                    <input id={`end-ref-${i}`} {...register(`enderecos.${i}.referencia`)} className={inputClass} />
                  </Campo>
                </div>
              </div>
            )
          })}
        </div>
        {(mensagemDe(errors.enderecos) || mensagemDe(errors.indiceEnderecoAtual)) && (
          <p className="mt-2 text-xs text-state-error">
            {mensagemDe(errors.enderecos) ?? mensagemDe(errors.indiceEnderecoAtual)}
          </p>
        )}
        <button
          type="button"
          onClick={adicionarEndereco}
          className="mt-3 rounded-full border border-brand-outline px-4 py-1.5 text-xs font-semibold text-brand-outline hover:bg-brand-lime/20"
        >
          + Adicionar endereço
        </button>
      </Secao>

      {/* ------------------------------------------------------------ Primeira loja (RR01) */}
      {lojista && !possuiLoja && (
        <Secao
          titulo="Primeira loja"
          descricao="RR01: todo lojista precisa de ao menos uma loja. Ela é criada junto com o perfil; produtos e categorias são cadastrados depois, no Painel do Lojista."
        >
          <div className="grid gap-3 md:grid-cols-6">
            <Campo id="loja-nome" label="Nome da loja *" erro={errors.primeiraLoja?.nome} className="md:col-span-3">
              <input id="loja-nome" {...register('primeiraLoja.nome')} className={inputClass} />
            </Campo>
            <Campo id="loja-cnpj" label="CNPJ * (RN10/RN11)" erro={errors.primeiraLoja?.cnpj} className="md:col-span-2">
              <input
                id="loja-cnpj"
                inputMode="numeric"
                placeholder="00.000.000/0000-00"
                {...comMascara('primeiraLoja.cnpj', mascaraCnpj)}
                className={inputClass}
              />
            </Campo>
            <Campo id="loja-tel" label="Telefone *" erro={errors.primeiraLoja?.telefone} className="md:col-span-1">
              <input
                id="loja-tel"
                inputMode="tel"
                {...comMascara('primeiraLoja.telefone', mascaraTelefone)}
                className={inputClass}
              />
            </Campo>
            <Campo id="loja-log" label="Logradouro *" erro={errors.primeiraLoja?.logradouro} className="md:col-span-4">
              <input id="loja-log" {...register('primeiraLoja.logradouro')} className={inputClass} />
            </Campo>
            <Campo id="loja-num" label="Número *" erro={errors.primeiraLoja?.numero} className="md:col-span-1">
              <input id="loja-num" {...register('primeiraLoja.numero')} className={inputClass} />
            </Campo>
            <Campo id="loja-comp" label="Complemento" erro={errors.primeiraLoja?.complementoEndereco} className="md:col-span-1">
              <input id="loja-comp" placeholder="Sala 3" {...register('primeiraLoja.complementoEndereco')} className={inputClass} />
            </Campo>
            <Campo id="loja-bairro" label="Bairro *" erro={errors.primeiraLoja?.bairro} className="md:col-span-2">
              <input id="loja-bairro" {...register('primeiraLoja.bairro')} className={inputClass} />
            </Campo>
            <Campo id="loja-cep" label="CEP *" erro={errors.primeiraLoja?.cep} className="md:col-span-1">
              <input
                id="loja-cep"
                inputMode="numeric"
                placeholder="00000-000"
                {...comMascara('primeiraLoja.cep', mascaraCep)}
                className={inputClass}
              />
            </Campo>
            <Campo id="loja-cidade" label="Cidade *" erro={errors.primeiraLoja?.cidade} className="md:col-span-2">
              <input id="loja-cidade" {...register('primeiraLoja.cidade')} className={inputClass} />
            </Campo>
            <Campo id="loja-uf" label="UF *" erro={errors.primeiraLoja?.estado} className="md:col-span-1">
              <input id="loja-uf" placeholder="MG" {...comMascara('primeiraLoja.estado', mascaraUf)} className={inputClass} />
            </Campo>
            <Campo id="loja-tempo" label="Tempo de entrega (min) *" erro={errors.primeiraLoja?.tempoEntregaEstimado} className="md:col-span-2">
              <input id="loja-tempo" type="number" min={1} step={1} {...register('primeiraLoja.tempoEntregaEstimado')} className={inputClass} />
            </Campo>
            <Campo id="loja-taxa" label="Taxa de entrega (R$) *" erro={errors.primeiraLoja?.taxaEntrega} className="md:col-span-2">
              <input id="loja-taxa" inputMode="decimal" placeholder="5,00" {...register('primeiraLoja.taxaEntrega')} className={inputClass} />
            </Campo>
            <Campo id="loja-status" label="Começa" className="md:col-span-2">
              <select id="loja-status" {...register('primeiraLoja.statusFuncionamento')} className={inputClass}>
                <option value="aberta">Aberta</option>
                <option value="fechada">Fechada</option>
              </select>
            </Campo>
          </div>
        </Secao>
      )}

      {lojista && possuiLoja && perfil && (
        <Secao titulo="Lojas" descricao="As lojas são gerenciadas no Painel do Lojista (dados operacionais, catálogo e status).">
          <ul className="space-y-1 text-sm">
            {perfil.lojas.map((l) => (
              <li key={l.idLoja}>
                <span className="font-semibold text-brand-dark">#{l.idLoja} · {l.nome}</span> — CNPJ {mascaraCnpj(l.cnpj)}
              </li>
            ))}
          </ul>
        </Secao>
      )}

      <div className="flex items-center justify-end gap-3">
        <button
          type="button"
          onClick={() => navigate(-1)}
          disabled={isSubmitting}
          className="rounded-full px-5 py-2 text-sm font-semibold text-text-default hover:bg-surface"
        >
          Cancelar
        </button>
        <button
          type="submit"
          disabled={isSubmitting}
          className="rounded-full bg-brand-lime px-6 py-2 text-sm font-semibold text-brand-dark shadow-low transition-colors hover:bg-brand-green/40 disabled:opacity-50"
        >
          {isSubmitting ? 'Salvando…' : modoEdicao ? 'Salvar alterações' : 'Cadastrar perfil'}
        </button>
      </div>
    </form>
  )
}
