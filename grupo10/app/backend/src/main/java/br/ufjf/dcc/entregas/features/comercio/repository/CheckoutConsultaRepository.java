/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: Repositório estritamente de leitura (SELECT) para popular o fluxo de checkout
 * e a seleção de sessão do usuário (X-User-Id) na interface de Comércio e Finanças.
 */
package br.ufjf.dcc.entregas.features.comercio.repository;

import br.ufjf.dcc.entregas.features.comercio.dto.EnderecoEntregaClienteResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.LojaCheckoutResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.ProdutoCheckoutResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.UsuarioSessaoResponse;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJISTA;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA_ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO;

@Repository
public class CheckoutConsultaRepository {

    private final DSLContext dsl;

    public CheckoutConsultaRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public List<UsuarioSessaoResponse> listarUsuariosParaSessao() {
        List<UsuarioSessaoResponse> clientes = dsl.select(
                        PESSOA.ID_PESSOA,
                        PESSOA.NOME,
                        PESSOA.EMAIL
                )
                .from(CLIENTE)
                .join(PESSOA).on(PESSOA.ID_PESSOA.eq(CLIENTE.ID_PESSOA))
                .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                .orderBy(PESSOA.ID_PESSOA.asc())
                .limit(10)
                .fetch(record -> new UsuarioSessaoResponse(
                        record.get(PESSOA.ID_PESSOA),
                        record.get(PESSOA.NOME),
                        record.get(PESSOA.EMAIL),
                        true,
                        false,
                        null,
                        null
                ));

        List<UsuarioSessaoResponse> lojistas = dsl.select(
                        PESSOA.ID_PESSOA,
                        PESSOA.NOME,
                        PESSOA.EMAIL,
                        LOJA.ID_LOJA,
                        LOJA.NOME
                )
                .from(LOJISTA)
                .join(PESSOA).on(PESSOA.ID_PESSOA.eq(LOJISTA.ID_PESSOA))
                .join(LOJA).on(LOJA.ID_LOJISTA.eq(LOJISTA.ID_PESSOA))
                .orderBy(LOJA.ID_LOJA.asc())
                .limit(10)
                .fetch(record -> new UsuarioSessaoResponse(
                        record.get(PESSOA.ID_PESSOA),
                        record.get(PESSOA.NOME),
                        record.get(PESSOA.EMAIL),
                        false,
                        true,
                        record.get(LOJA.ID_LOJA),
                        record.get(LOJA.NOME)
                ));

        List<UsuarioSessaoResponse> usuarios = new ArrayList<>(clientes.size() + lojistas.size());
        usuarios.addAll(clientes);
        usuarios.addAll(lojistas);
        return usuarios;
    }

    public List<LojaCheckoutResponse> listarLojasComProdutosParaCheckout() {
        var lojas = dsl.selectFrom(LOJA)
                .orderBy(LOJA.ID_LOJA.asc())
                .limit(24)
                .fetch();

        List<Long> idsLoja = lojas.stream().map(loja -> loja.getIdLoja()).toList();
        if (idsLoja.isEmpty()) {
            return List.of();
        }

        Map<Long, List<ProdutoCheckoutResponse>> produtosPorLoja = dsl.selectFrom(PRODUTO)
                .where(PRODUTO.ID_LOJA.in(idsLoja))
                .orderBy(PRODUTO.ID_LOJA.asc(), PRODUTO.ID_PRODUTO.asc())
                .fetch(record -> new ProdutoCheckoutResponse(
                        record.getIdProduto(),
                        record.getIdLoja(),
                        record.getNome(),
                        record.getDescricao(),
                        record.getPreco(),
                        Boolean.TRUE.equals(record.getAtivo())
                ))
                .stream()
                .collect(Collectors.groupingBy(ProdutoCheckoutResponse::idLoja));

        return lojas.stream()
                .map(loja -> new LojaCheckoutResponse(
                        loja.getIdLoja(),
                        loja.getIdLojista(),
                        loja.getNome(),
                        loja.getCnpj(),
                        loja.getStatusFuncionamento().getLiteral(),
                        loja.getTempoEntregaEstimado(),
                        loja.getTaxaEntrega(),
                        produtosPorLoja.getOrDefault(loja.getIdLoja(), List.of())
                ))
                .toList();
    }

    public List<EnderecoEntregaClienteResponse> listarEnderecosDeEntregaDoCliente(Long idCliente) {
        Long idEnderecoAtual = dsl.select(CLIENTE.ID_ENDERECO_ATUAL)
                .from(CLIENTE)
                .where(CLIENTE.ID_PESSOA.eq(idCliente))
                .fetchOneInto(Long.class);

        return dsl.select(
                        ENDERECO.ID_ENDERECO,
                        PESSOA_ENDERECO.APELIDO,
                        ENDERECO.LOGRADOURO,
                        ENDERECO.NUMERO,
                        ENDERECO.BAIRRO,
                        ENDERECO.CEP,
                        ENDERECO.CIDADE,
                        ENDERECO.ESTADO,
                        PESSOA_ENDERECO.COMPLEMENTO,
                        PESSOA_ENDERECO.REFERENCIA
                )
                .from(PESSOA_ENDERECO)
                .join(ENDERECO).on(ENDERECO.ID_ENDERECO.eq(PESSOA_ENDERECO.ID_ENDERECO))
                .where(PESSOA_ENDERECO.ID_PESSOA.eq(idCliente))
                .orderBy(ENDERECO.ID_ENDERECO.asc())
                .fetch(record -> {
                    Long idEndereco = record.get(ENDERECO.ID_ENDERECO);
                    return new EnderecoEntregaClienteResponse(
                            idEndereco,
                            record.get(PESSOA_ENDERECO.APELIDO),
                            record.get(ENDERECO.LOGRADOURO),
                            record.get(ENDERECO.NUMERO),
                            record.get(ENDERECO.BAIRRO),
                            record.get(ENDERECO.CEP),
                            record.get(ENDERECO.CIDADE),
                            record.get(ENDERECO.ESTADO),
                            record.get(PESSOA_ENDERECO.COMPLEMENTO),
                            record.get(PESSOA_ENDERECO.REFERENCIA),
                            idEndereco.equals(idEnderecoAtual)
                    );
                });
    }
}
