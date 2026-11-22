/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
import { useEffect, useState } from 'react'
import { checkoutApi, extrairMensagemErro } from '../api/comercio.api'
import type { EnderecoEntregaCliente, LojaCheckout, UsuarioSessao } from '../types/comercio.types'

export function useCheckoutCatalogo(usuarioAtual: UsuarioSessao | null) {
  const [lojas, setLojas] = useState<LojaCheckout[]>([])
  const [enderecos, setEnderecos] = useState<EnderecoEntregaCliente[]>([])
  const [carregandoLojas, setCarregandoLojas] = useState(true)
  const [carregandoEnderecos, setCarregandoEnderecos] = useState(false)
  const [erroCatalogo, setErroCatalogo] = useState<string | null>(null)

  useEffect(() => {
    let ativo = true
    setCarregandoLojas(true)
    checkoutApi
      .listarLojasCheckout()
      .then((lista) => {
        if (ativo) setLojas(lista)
      })
      .catch((e) => {
        if (ativo) setErroCatalogo(extrairMensagemErro(e))
      })
      .finally(() => {
        if (ativo) setCarregandoLojas(false)
      })
    return () => {
      ativo = false
    }
  }, [])

  useEffect(() => {
    if (!usuarioAtual?.perfilCliente) {
      setEnderecos([])
      return
    }
    let ativo = true
    setCarregandoEnderecos(true)
    checkoutApi
      .listarEnderecosEntregaCliente(usuarioAtual.idPessoa)
      .then((lista) => {
        if (ativo) setEnderecos(lista)
      })
      .catch((e) => {
        if (ativo) setErroCatalogo(extrairMensagemErro(e))
      })
      .finally(() => {
        if (ativo) setCarregandoEnderecos(false)
      })
    return () => {
      ativo = false
    }
  }, [usuarioAtual])

  return {
    lojas,
    enderecos,
    carregandoLojas,
    carregandoEnderecos,
    erroCatalogo,
  }
}
