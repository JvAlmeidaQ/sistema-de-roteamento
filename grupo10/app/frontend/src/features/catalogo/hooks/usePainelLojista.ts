/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Catálogo
 */
import { useCallback, useEffect, useMemo, useState } from 'react'
import { catalogoApi, extrairMensagemErro } from '../api/catalogo.api'
import type {
  CategoriaResponse,
  LojaResponse,
  ProdutoCatalogoResponse,
  StatusFuncionamento,
} from '../types/catalogo.types'
import type {
  AtualizarLojaFormValues,
  CriarCategoriaFormValues,
  ProdutoFormValues,
} from '../schemas/catalogo.schemas'
import type { UsuarioSessao } from '@/features/comercio/types/comercio.types'

export function usePainelLojista(usuarioAtual: UsuarioSessao | null) {
  const [loja, setLoja] = useState<LojaResponse | null>(null)
  const [categorias, setCategorias] = useState<CategoriaResponse[]>([])
  const [produtos, setProdutos] = useState<ProdutoCatalogoResponse[]>([])

  const [carregandoLoja, setCarregandoLoja] = useState(true)
  const [carregandoCategorias, setCarregandoCategorias] = useState(false)
  const [carregandoProdutos, setCarregandoProdutos] = useState(false)
  const [salvando, setSalvando] = useState(false)
  const [alternandoProdutoId, setAlternandoProdutoId] = useState<number | null>(null)

  const [erroLoja, setErroLoja] = useState<string | null>(null)
  const [erroOperacao, setErroOperacao] = useState<string | null>(null)
  const [mensagemSucesso, setMensagemSucesso] = useState<string | null>(null)

  // Filtros de visualização
  const [filtroCategoria, setFiltroCategoria] = useState<number | null>(null)
  const [filtroAtivo, setFiltroAtivo] = useState<'todos' | 'ativo' | 'inativo'>('todos')
  const [buscaTexto, setBuscaTexto] = useState('')

  const limparMensagens = useCallback(() => {
    setErroOperacao(null)
    setMensagemSucesso(null)
  }, [])

  // Carrega a loja vinculada ao lojista autenticado
  const carregarLoja = useCallback(async () => {
    if (!usuarioAtual) {
      setLoja(null)
      setCategorias([])
      setProdutos([])
      setCarregandoLoja(false)
      return
    }

    setCarregandoLoja(true)
    setErroLoja(null)
    try {
      // Tenta obter a loja através do cabeçalho X-User-Id contextual
      const lojaResp = await catalogoApi.obterMinhaLoja()
      setLoja(lojaResp)
    } catch (e) {
      setLoja(null)
      setCategorias([])
      setProdutos([])
      setErroLoja(extrairMensagemErro(e))
    } finally {
      setCarregandoLoja(false)
    }
  }, [usuarioAtual])

  useEffect(() => {
    carregarLoja()
  }, [carregarLoja])

  // Carrega categorias da loja
  const carregarCategorias = useCallback(async (idLoja: number) => {
    setCarregandoCategorias(true)
    try {
      const lista = await catalogoApi.listarCategorias(idLoja)
      setCategorias(lista)
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
    } finally {
      setCarregandoCategorias(false)
    }
  }, [])

  // Carrega produtos da loja com filtros
  const carregarProdutos = useCallback(
    async (idLoja: number) => {
      setCarregandoProdutos(true)
      try {
        const ativoParam =
          filtroAtivo === 'ativo' ? true : filtroAtivo === 'inativo' ? false : undefined
        const catParam = filtroCategoria ?? undefined

        const lista = await catalogoApi.listarProdutos(idLoja, {
          idCategoria: catParam,
          ativo: ativoParam,
        })
        setProdutos(lista)
      } catch (e) {
        setErroOperacao(extrairMensagemErro(e))
      } finally {
        setCarregandoProdutos(false)
      }
    },
    [filtroAtivo, filtroCategoria]
  )

  useEffect(() => {
    if (loja?.idLoja) {
      carregarCategorias(loja.idLoja)
    }
  }, [loja?.idLoja, carregarCategorias])

  useEffect(() => {
    if (loja?.idLoja) {
      carregarProdutos(loja.idLoja)
    }
  }, [loja?.idLoja, carregarProdutos])

  // Ações da Loja
  const alternarStatusLoja = async (novoStatus: StatusFuncionamento) => {
    if (!loja) return
    limparMensagens()
    setSalvando(true)
    try {
      const atualizada = await catalogoApi.atualizarStatusLoja(loja.idLoja, novoStatus)
      setLoja(atualizada)
      setMensagemSucesso(
        `Loja ${novoStatus === 'aberta' ? 'aberta' : 'fechada'} com sucesso! (RF07)`
      )
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
    } finally {
      setSalvando(false)
    }
  }

  const salvarDadosLoja = async (valores: AtualizarLojaFormValues) => {
    if (!loja) return
    limparMensagens()
    setSalvando(true)
    try {
      const atualizada = await catalogoApi.atualizarDadosLoja(loja.idLoja, valores)
      setLoja(atualizada)
      setMensagemSucesso('Informações operacionais da loja atualizadas com sucesso!')
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
    } finally {
      setSalvando(false)
    }
  }

  // Ações de Categoria
  const adicionarCategoria = async (valores: CriarCategoriaFormValues): Promise<boolean> => {
    if (!loja) return false
    limparMensagens()
    setSalvando(true)
    try {
      await catalogoApi.criarCategoria(loja.idLoja, valores)
      setMensagemSucesso(`Categoria "${valores.nome}" criada com sucesso!`)
      await carregarCategorias(loja.idLoja)
      return true
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
      return false
    } finally {
      setSalvando(false)
    }
  }

  const removerCategoria = async (idCategoria: number) => {
    if (!loja) return
    limparMensagens()
    setSalvando(true)
    try {
      await catalogoApi.excluirCategoria(loja.idLoja, idCategoria)
      setMensagemSucesso('Categoria excluída com sucesso!')
      if (filtroCategoria === idCategoria) {
        setFiltroCategoria(null)
      }
      await Promise.all([carregarCategorias(loja.idLoja), carregarProdutos(loja.idLoja)])
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
    } finally {
      setSalvando(false)
    }
  }

  // Ações de Produto
  const adicionarProduto = async (valores: ProdutoFormValues): Promise<boolean> => {
    if (!loja) return false
    limparMensagens()
    setSalvando(true)
    try {
      await catalogoApi.criarProduto(loja.idLoja, valores)
      setMensagemSucesso(`Produto "${valores.nome}" adicionado com sucesso!`)
      await Promise.all([carregarProdutos(loja.idLoja), carregarCategorias(loja.idLoja)])
      return true
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
      return false
    } finally {
      setSalvando(false)
    }
  }

  const editarProduto = async (idProduto: number, valores: ProdutoFormValues): Promise<boolean> => {
    if (!loja) return false
    limparMensagens()
    setSalvando(true)
    try {
      await catalogoApi.atualizarProduto(loja.idLoja, idProduto, valores)
      setMensagemSucesso(`Produto "${valores.nome}" atualizado com sucesso!`)
      await Promise.all([carregarProdutos(loja.idLoja), carregarCategorias(loja.idLoja)])
      return true
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
      return false
    } finally {
      setSalvando(false)
    }
  }

  const alternarAtivoProduto = async (idProduto: number, ativoAtual: boolean) => {
    if (!loja || alternandoProdutoId === idProduto) return
    limparMensagens()
    setAlternandoProdutoId(idProduto)
    try {
      const atualizado = await catalogoApi.atualizarAtivoProduto(
        loja.idLoja,
        idProduto,
        !ativoAtual
      )
      setProdutos((antigos) => {
        const atualizados = antigos.map((p) => (p.idProduto === idProduto ? atualizado : p))
        if (filtroAtivo === 'ativo') return atualizados.filter((p) => p.ativo)
        if (filtroAtivo === 'inativo') return atualizados.filter((p) => !p.ativo)
        return atualizados
      })
      setMensagemSucesso(
        `Produto ${atualizado.ativo ? 'ativado' : 'pausado'} com sucesso! (RF07)`
      )
    } catch (e) {
      setErroOperacao(extrairMensagemErro(e))
    } finally {
      setAlternandoProdutoId(null)
    }
  }

  // Filtragem em memória por texto de busca
  const produtosFiltrados = useMemo(() => {
    if (!buscaTexto.trim()) return produtos
    const termo = buscaTexto.toLowerCase()
    return produtos.filter(
      (p) =>
        p.nome.toLowerCase().includes(termo) ||
        (p.descricao && p.descricao.toLowerCase().includes(termo))
    )
  }, [produtos, buscaTexto])

  return {
    loja,
    categorias,
    produtos: produtosFiltrados,
    totalProdutosSemFiltroTexto: produtos.length,
    carregandoLoja,
    carregandoCategorias,
    carregandoProdutos,
    salvando,
    alternandoProdutoId,
    erroLoja,
    erroOperacao,
    mensagemSucesso,
    filtroCategoria,
    setFiltroCategoria,
    filtroAtivo,
    setFiltroAtivo,
    buscaTexto,
    setBuscaTexto,
    limparMensagens,
    alternarStatusLoja,
    salvarDadosLoja,
    adicionarCategoria,
    removerCategoria,
    adicionarProduto,
    editarProduto,
    alternarAtivoProduto,
    recarregarTudo: () => {
      carregarLoja()
      if (loja?.idLoja) {
        carregarCategorias(loja.idLoja)
        carregarProdutos(loja.idLoja)
      }
    },
  }
}
