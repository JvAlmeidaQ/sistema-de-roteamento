/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: Repositório estritamente de leitura (SELECT) para popular o fluxo de checkout
 * e a seleção de sessão do usuário (X-User-Id) na interface de Comércio e Finanças.
 */
package br.ufjf.dcc.entregas.features.comercio.repository;

import br.ufjf.dcc.entregas.core.security.AdminAccessService;
import br.ufjf.dcc.entregas.features.comercio.dto.EnderecoEntregaClienteResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.LojaCheckoutResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.ProdutoCheckoutResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.UsuarioSessaoResponse;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJISTA;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA_ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO;

@Repository
public class CheckoutConsultaRepository {

    private final DSLContext dsl;
    private final AdminAccessService adminAccessService;

    public CheckoutConsultaRepository(DSLContext dsl, AdminAccessService adminAccessService) {
        this.dsl = dsl;
        this.adminAccessService = adminAccessService;
    }

    public List<UsuarioSessaoResponse> listarUsuariosParaSessao() {
        List<Long> idsSelecionados = new ArrayList<>();

        idsSelecionados.addAll(
                dsl.select(CLIENTE.ID_PESSOA)
                        .from(CLIENTE)
                        .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                        .orderBy(CLIENTE.ID_PESSOA.asc())
                        .limit(10)
                        .fetch(CLIENTE.ID_PESSOA)
        );
        idsSelecionados.addAll(
                dsl.select(LOJISTA.ID_PESSOA)
                        .from(LOJISTA)
                        .join(LOJA).on(LOJA.ID_LOJISTA.eq(LOJISTA.ID_PESSOA))
                        .orderBy(LOJA.ID_LOJA.asc())
                        .limit(10)
                        .fetch(LOJISTA.ID_PESSOA)
        );
        idsSelecionados.addAll(
                dsl.select(ENTREGADOR.ID_PESSOA)
                        .from(ENTREGADOR)
                        .orderBy(ENTREGADOR.ID_PESSOA.asc())
                        .limit(10)
                        .fetch(ENTREGADOR.ID_PESSOA)
        );

        if (idsSelecionados.isEmpty()) {
            return List.of();
        }

        List<Long> idsUnicos = idsSelecionados.stream().distinct().toList();

        var registros = dsl.select(
                        PESSOA.ID_PESSOA,
                        PESSOA.NOME,
                        PESSOA.EMAIL,
                        CLIENTE.ID_PESSOA,
                        LOJISTA.ID_PESSOA,
                        ENTREGADOR.ID_PESSOA,
                        LOJA.ID_LOJA,
                        LOJA.NOME
                )
                .from(PESSOA)
                .leftJoin(CLIENTE).on(CLIENTE.ID_PESSOA.eq(PESSOA.ID_PESSOA))
                .leftJoin(LOJISTA).on(LOJISTA.ID_PESSOA.eq(PESSOA.ID_PESSOA))
                .leftJoin(ENTREGADOR).on(ENTREGADOR.ID_PESSOA.eq(PESSOA.ID_PESSOA))
                .leftJoin(LOJA).on(LOJA.ID_LOJISTA.eq(LOJISTA.ID_PESSOA))
                .where(PESSOA.ID_PESSOA.in(idsUnicos))
                .orderBy(PESSOA.ID_PESSOA.asc(), LOJA.ID_LOJA.asc())
                .fetch();

        Map<Long, UsuarioSessaoResponse> consolidado = new LinkedHashMap<>();
        for (var r : registros) {
            Long idPessoa = r.get(PESSOA.ID_PESSOA);
            if (adminAccessService.isAdmin(idPessoa)) {
                continue;
            }
            if (!consolidado.containsKey(idPessoa)) {
                consolidado.put(idPessoa, new UsuarioSessaoResponse(
                        idPessoa,
                        r.get(PESSOA.NOME),
                        r.get(PESSOA.EMAIL),
                        r.get(CLIENTE.ID_PESSOA) != null,
                        r.get(LOJISTA.ID_PESSOA) != null,
                        r.get(ENTREGADOR.ID_PESSOA) != null,
                        false,
                        r.get(LOJA.ID_LOJA),
                        r.get(LOJA.NOME)
                ));
            }
        }
        return new ArrayList<>(consolidado.values());
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
