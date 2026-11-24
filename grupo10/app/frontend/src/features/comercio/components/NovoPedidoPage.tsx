/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças (disponível em VITE_APP_MODE=bd e full)
 */
import { zodResolver } from '@hookform/resolvers/zod'
import { useEffect, useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import { CheckCircle2 } from 'lucide-react'
import { useSessaoUsuario } from '@/context/SessaoUsuarioContext'
import { limparNomeLoja } from '@/lib/apresentacao'
import { extrairMensagemErro, pedidosApi } from '../api/comercio.api'
import { useCheckoutCatalogo } from '../hooks/useCheckoutCatalogo'
import { type CriarPedidoFormValues, criarPedidoSchema } from '../schemas/comercio.schemas'
import type { PedidoResponse, ProdutoCheckout } from '../types/comercio.types'
import { CarrinhoCheckoutAside } from './CarrinhoCheckoutAside'
import { CatalogoLojaSection } from './CatalogoLojaSection'
import { StatusBadge, formatarIdPedido, formatarMoeda } from './StatusBadge'

const TAXA_SERVICO_FIXA = 2.5

export function NovoPedidoPage() {
  const { usuarioAtual } = useSessaoUsuario()
  const { lojas, enderecos, carregandoLojas, carregandoEnderecos, erroCatalogo } =
    useCheckoutCatalogo(usuarioAtual)

  const [produtosMapa, setProdutosMapa] = useState<Record<number, ProdutoCheckout>>({})
  const [enviando, setEnviando] = useState(false)
  const [erroEnvio, setErroEnvio] = useState<string | null>(null)
  const [pedidoCriado, setPedidoCriado] = useState<PedidoResponse | null>(null)

  const form = useForm<CriarPedidoFormValues>({
    resolver: zodResolver(criarPedidoSchema),
    defaultValues: {
      idLoja: 0,
      idEndereco: 0,
      formaPagamento: 'pix',
      observacaoEntrega: '',
      itens: [],
    },
  })

  const idLojaSelecionada = form.watch('idLoja')
  const itensForm = form.watch('itens')

  useEffect(() => {
    if (lojas.length === 0 || idLojaSelecionada > 0) return
    const inicial = lojas.find((l) => l.statusFuncionamento === 'aberta') ?? lojas[0]
    if (inicial) form.setValue('idLoja', inicial.idLoja)
  }, [lojas, idLojaSelecionada, form])

  useEffect(() => {
    const atual = enderecos.find((e) => e.enderecoAtual) ?? enderecos[0]
    form.setValue('idEndereco', atual ? atual.idEndereco : 0)
  }, [enderecos, form])

  const lojaAtual = useMemo(
    () => lojas.find((l) => l.idLoja === idLojaSelecionada) ?? null,
    [lojas, idLojaSelecionada],
  )

  const trocarLoja = (novoIdLoja: number) => {
    form.setValue('idLoja', novoIdLoja)
    // RN07: um pedido não pode misturar produtos de lojas diferentes
    form.setValue('itens', [])
    setProdutosMapa({})
    setErroEnvio(null)
  }

  const adicionarProduto = (produto: ProdutoCheckout) => {
    setErroEnvio(null)
    setProdutosMapa((prev) => ({ ...prev, [produto.idProduto]: produto }))
    const atuais = form.getValues('itens')
    const existente = atuais.find((i) => i.idProduto === produto.idProduto)
    const atualizados = existente
      ? atuais.map((i) =>
          i.idProduto === produto.idProduto ? { ...i, quantidade: i.quantidade + 1 } : i,
        )
      : [...atuais, { idProduto: produto.idProduto, quantidade: 1 }]
    form.setValue('itens', atualizados, { shouldValidate: true })
  }

  const alterarQuantidade = (idProduto: number, delta: number) => {
    const atualizados = form
      .getValues('itens')
      .map((i) => (i.idProduto === idProduto ? { ...i, quantidade: i.quantidade + delta } : i))
      .filter((i) => i.quantidade > 0)
    form.setValue('itens', atualizados, { shouldValidate: true })
  }

  const itensCarrinho = useMemo(
    () =>
      itensForm
        .map((i) => ({ produto: produtosMapa[i.idProduto], quantidade: i.quantidade }))
        .filter((i): i is { produto: ProdutoCheckout; quantidade: number } => Boolean(i.produto)),
    [itensForm, produtosMapa],
  )

  const subtotal = useMemo(
    () => itensCarrinho.reduce((acc, item) => acc + item.produto.preco * item.quantidade, 0),
    [itensCarrinho],
  )
  const taxaEntrega = lojaAtual?.taxaEntrega ?? 0
  const valorTotal = subtotal + taxaEntrega + TAXA_SERVICO_FIXA

  const onSubmit = form.handleSubmit(async (valores) => {
    setErroEnvio(null)
    setPedidoCriado(null)

    if (!usuarioAtual?.perfilCliente) {
      setErroEnvio('Selecione um usuário com perfil de Cliente no topo para enviar um pedido.')
      return
    }

    try {
      setEnviando(true)
      const criado = await pedidosApi.criar({
        ...valores,
        observacaoEntrega: valores.observacaoEntrega?.trim() || undefined,
      })
      setPedidoCriado(criado)
      form.setValue('itens', [])
      form.setValue('observacaoEntrega', '')
      setProdutosMapa({})
    } catch (e) {
      setErroEnvio(extrairMensagemErro(e))
    } finally {
      setEnviando(false)
    }
  })

  const erroExibido = erroEnvio ?? erroCatalogo

  return (
    <div className="space-y-6">
      <div>
        <h2 className="font-display text-3xl font-semibold text-brand-dark">
          Fazer pedido
        </h2>
        <p className="mt-1 text-sm text-text-default">
          Escolha uma loja aberta, monte seu carrinho e finalize o pedido.
        </p>
      </div>

      {erroExibido && (
        <div
          role="alert"
          className="rounded-2xl border border-state-error/40 bg-state-error/10 px-4 py-3 text-sm font-medium text-state-error"
        >
          {erroExibido}
        </div>
      )}

      {pedidoCriado && (
        <div
          role="status"
          aria-live="polite"
          className="rounded-2xl border border-state-success/40 bg-surface p-5"
        >
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="inline-flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-brand-green">
                <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
                Pedido registrado com sucesso
              </span>
              <h3 className="mt-0.5 font-display text-xl font-semibold text-brand-dark">
                {formatarIdPedido(pedidoCriado.idPedido)} · {limparNomeLoja(pedidoCriado.nomeLoja)}
              </h3>
            </div>
            <StatusBadge status={pedidoCriado.status} />
          </div>
          <p className="mt-2 text-sm text-text-default">
            Entrega em: <strong>{pedidoCriado.resumoEndereco}</strong>
            {pedidoCriado.complementoEntrega ? ` (${pedidoCriado.complementoEntrega})` : ''}
          </p>
          <p className="mt-1 text-xs text-text-default">
            Subtotal {formatarMoeda(pedidoCriado.subtotal)} + Entrega{' '}
            {formatarMoeda(pedidoCriado.taxaEntrega)} + Serviço{' '}
            {formatarMoeda(pedidoCriado.taxaServico)} ={' '}
            <strong className="text-brand-dark">{formatarMoeda(pedidoCriado.valorTotal)}</strong>
          </p>
        </div>
      )}

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <CatalogoLojaSection
          lojas={lojas}
          lojaAtual={lojaAtual}
          idLojaSelecionada={idLojaSelecionada}
          carregandoLojas={carregandoLojas}
          onTrocarLoja={trocarLoja}
          onAdicionarProduto={adicionarProduto}
        />

        <CarrinhoCheckoutAside
          form={form}
          itensCarrinho={itensCarrinho}
          enderecos={enderecos}
          carregandoEnderecos={carregandoEnderecos}
          lojaFechada={lojaAtual?.statusFuncionamento === 'fechada'}
          subtotal={subtotal}
          taxaEntrega={taxaEntrega}
          taxaServico={TAXA_SERVICO_FIXA}
          valorTotal={valorTotal}
          enviando={enviando}
          onAlterarQuantidade={alterarQuantidade}
          onSubmit={onSubmit}
        />
      </div>
    </div>
  )
}
