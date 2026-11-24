/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Implementa: RF01 (acesso a dados de Pessoa, papéis, Telefone, Endereco e Pessoa_Endereco via jOOQ DSL)
 */
package br.ufjf.dcc.entregas.features.identidade.repository;

import br.ufjf.dcc.entregas.features.identidade.dto.PerfilResponse;
import br.ufjf.dcc.entregas.features.identidade.dto.PessoaResumoResponse;
import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import br.ufjf.dcc.entregas.jooq.enums.TipoTelefone;
import br.ufjf.dcc.entregas.jooq.enums.TipoVeiculo;
import br.ufjf.dcc.entregas.jooq.tables.records.PessoaRecord;
import org.jooq.Condition;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJISTA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA_ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;
import static br.ufjf.dcc.entregas.jooq.Tables.TELEFONE;
import static br.ufjf.dcc.entregas.jooq.Tables.VW_PERFIL_PESSOA;
import static org.jooq.impl.DSL.noCondition;

@Repository
public class PerfilRepository {

    private static final int LIMITE_LISTAGEM = 50;

    private final DSLContext dsl;

    public PerfilRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    /** Papéis atuais de uma pessoa (especialização total e sobreposta — RR16). */
    public record PapeisPessoa(
            boolean cliente,
            Long idEnderecoAtual,
            boolean lojista,
            boolean entregador,
            TipoVeiculo tipoVeiculo
    ) {}

    // ------------------------------------------------------------------ consultas

    /** Listagem com busca por nome, e-mail, CPF ou ID usando a visão vw_perfil_pessoa (E5). */
    public List<PessoaResumoResponse> listarPessoas(String busca) {
        Condition filtro = noCondition();
        if (busca != null && !busca.isBlank()) {
            String termo = "%" + busca.trim() + "%";
            filtro = VW_PERFIL_PESSOA.NOME.likeIgnoreCase(termo)
                    .or(VW_PERFIL_PESSOA.EMAIL.likeIgnoreCase(termo));
            String digitos = busca.replaceAll("\\D", "");
            if (!digitos.isEmpty()) {
                filtro = filtro.or(VW_PERFIL_PESSOA.CPF.like(digitos + "%"));
                if (digitos.length() <= 12 && digitos.equals(busca.trim())) {
                    filtro = filtro.or(VW_PERFIL_PESSOA.ID_PESSOA.eq(Long.parseLong(digitos)));
                }
            }
        }

        return dsl.selectFrom(VW_PERFIL_PESSOA)
                .where(filtro)
                .orderBy(VW_PERFIL_PESSOA.NOME.asc(), VW_PERFIL_PESSOA.ID_PESSOA.asc())
                .limit(LIMITE_LISTAGEM)
                .fetch(r -> new PessoaResumoResponse(
                        r.getIdPessoa(),
                        r.getNome(),
                        r.getCpf(),
                        r.getEmail(),
                        Boolean.TRUE.equals(r.getECliente()),
                        Boolean.TRUE.equals(r.getELojista()),
                        Boolean.TRUE.equals(r.getEEntregador()),
                        r.getTipoVeiculo() != null ? r.getTipoVeiculo().getLiteral() : null,
                        r.getTelefones(),
                        r.getQtdEnderecos() != null ? r.getQtdEnderecos() : 0L
                ));
    }

    public Optional<PessoaRecord> buscarPessoa(Long idPessoa) {
        return dsl.selectFrom(PESSOA)
                .where(PESSOA.ID_PESSOA.eq(idPessoa))
                .fetchOptional();
    }

    public Optional<PessoaRecord> buscarPessoaPorEmailOuCpf(String emailNormalizado, String cpfDigitos) {
        Condition cond = null;
        if (emailNormalizado != null && !emailNormalizado.isBlank()) {
            cond = PESSOA.EMAIL.eq(emailNormalizado);
        }
        if (cpfDigitos != null && cpfDigitos.length() == 11) {
            Condition cpfCond = PESSOA.CPF.eq(cpfDigitos);
            cond = cond == null ? cpfCond : cond.or(cpfCond);
        }
        if (cond == null) {
            return Optional.empty();
        }
        return dsl.selectFrom(PESSOA)
                .where(cond)
                .limit(1)
                .fetchOptional();
    }

    public record LojaResumo(Long idLoja, String nome) {}

    public Optional<LojaResumo> buscarPrimeiraLojaResumo(Long idLojista) {
        return dsl.select(LOJA.ID_LOJA, LOJA.NOME)
                .from(LOJA)
                .where(LOJA.ID_LOJISTA.eq(idLojista))
                .orderBy(LOJA.ID_LOJA.asc())
                .limit(1)
                .fetchOptional(r -> new LojaResumo(r.get(LOJA.ID_LOJA), r.get(LOJA.NOME)));
    }

    public PapeisPessoa buscarPapeis(Long idPessoa) {
        return dsl.select(
                        CLIENTE.ID_PESSOA,
                        CLIENTE.ID_ENDERECO_ATUAL,
                        LOJISTA.ID_PESSOA,
                        ENTREGADOR.ID_PESSOA,
                        ENTREGADOR.TIPO_VEICULO
                )
                .from(PESSOA)
                .leftJoin(CLIENTE).on(CLIENTE.ID_PESSOA.eq(PESSOA.ID_PESSOA))
                .leftJoin(LOJISTA).on(LOJISTA.ID_PESSOA.eq(PESSOA.ID_PESSOA))
                .leftJoin(ENTREGADOR).on(ENTREGADOR.ID_PESSOA.eq(PESSOA.ID_PESSOA))
                .where(PESSOA.ID_PESSOA.eq(idPessoa))
                .fetchOne(r -> new PapeisPessoa(
                        r.get(CLIENTE.ID_PESSOA) != null,
                        r.get(CLIENTE.ID_ENDERECO_ATUAL),
                        r.get(LOJISTA.ID_PESSOA) != null,
                        r.get(ENTREGADOR.ID_PESSOA) != null,
                        r.get(ENTREGADOR.TIPO_VEICULO)
                ));
    }

    public List<PerfilResponse.Telefone> listarTelefones(Long idPessoa) {
        return dsl.select(TELEFONE.NUMERO, TELEFONE.TIPO)
                .from(TELEFONE)
                .where(TELEFONE.ID_PESSOA.eq(idPessoa))
                .orderBy(TELEFONE.TIPO.asc(), TELEFONE.NUMERO.asc())
                .fetch(r -> new PerfilResponse.Telefone(r.value1(), r.value2().getLiteral()));
    }

    public List<PerfilResponse.Endereco> listarEnderecos(Long idPessoa, Long idEnderecoAtual) {
        return dsl.select(
                        ENDERECO.ID_ENDERECO,
                        ENDERECO.LOGRADOURO,
                        ENDERECO.NUMERO,
                        ENDERECO.BAIRRO,
                        ENDERECO.CEP,
                        ENDERECO.CIDADE,
                        ENDERECO.ESTADO,
                        PESSOA_ENDERECO.APELIDO,
                        PESSOA_ENDERECO.COMPLEMENTO,
                        PESSOA_ENDERECO.REFERENCIA
                )
                .from(PESSOA_ENDERECO)
                .join(ENDERECO).on(ENDERECO.ID_ENDERECO.eq(PESSOA_ENDERECO.ID_ENDERECO))
                .where(PESSOA_ENDERECO.ID_PESSOA.eq(idPessoa))
                .orderBy(ENDERECO.ID_ENDERECO.asc())
                .fetch(r -> new PerfilResponse.Endereco(
                        r.get(ENDERECO.ID_ENDERECO),
                        r.get(ENDERECO.LOGRADOURO),
                        r.get(ENDERECO.NUMERO),
                        r.get(ENDERECO.BAIRRO),
                        r.get(ENDERECO.CEP),
                        r.get(ENDERECO.CIDADE),
                        r.get(ENDERECO.ESTADO),
                        r.get(PESSOA_ENDERECO.APELIDO),
                        r.get(PESSOA_ENDERECO.COMPLEMENTO),
                        r.get(PESSOA_ENDERECO.REFERENCIA),
                        r.get(ENDERECO.ID_ENDERECO).equals(idEnderecoAtual)
                ));
    }

    public Set<Long> listarIdsEnderecosVinculados(Long idPessoa) {
        return dsl.select(PESSOA_ENDERECO.ID_ENDERECO)
                .from(PESSOA_ENDERECO)
                .where(PESSOA_ENDERECO.ID_PESSOA.eq(idPessoa))
                .fetchSet(PESSOA_ENDERECO.ID_ENDERECO);
    }

    public List<PerfilResponse.Loja> listarLojas(Long idLojista) {
        return dsl.select(LOJA.ID_LOJA, LOJA.NOME, LOJA.CNPJ, LOJA.STATUS_FUNCIONAMENTO)
                .from(LOJA)
                .where(LOJA.ID_LOJISTA.eq(idLojista))
                .orderBy(LOJA.ID_LOJA.asc())
                .fetch(r -> new PerfilResponse.Loja(r.value1(), r.value2(), r.value3(), r.value4().getLiteral()));
    }

    public boolean existeCpf(String cpf) {
        return dsl.fetchExists(PESSOA, PESSOA.CPF.eq(cpf));
    }

    public boolean existeEmailEmOutraPessoa(String email, Long idPessoaIgnorada) {
        Condition condicao = PESSOA.EMAIL.equalIgnoreCase(email);
        if (idPessoaIgnorada != null) {
            condicao = condicao.and(PESSOA.ID_PESSOA.ne(idPessoaIgnorada));
        }
        return dsl.fetchExists(PESSOA, condicao);
    }

    public boolean existeCnpj(String cnpj) {
        return dsl.fetchExists(LOJA, LOJA.CNPJ.eq(cnpj));
    }

    public boolean clientePossuiPedidos(Long idPessoa) {
        return dsl.fetchExists(PEDIDO, PEDIDO.ID_CLIENTE.eq(idPessoa));
    }

    public boolean lojistaPossuiLojas(Long idPessoa) {
        return dsl.fetchExists(LOJA, LOJA.ID_LOJISTA.eq(idPessoa));
    }

    public boolean entregadorPossuiRotas(Long idPessoa) {
        return dsl.fetchExists(ROTA, ROTA.ID_ENTREGADOR.eq(idPessoa));
    }

    // ------------------------------------------------------------------ Pessoa

    public Long inserirPessoa(String nome, String cpf, String email) {
        return dsl.insertInto(PESSOA)
                .set(PESSOA.NOME, nome)
                .set(PESSOA.CPF, cpf)
                .set(PESSOA.EMAIL, email)
                .returningResult(PESSOA.ID_PESSOA)
                .fetchOneInto(Long.class);
    }

    public void atualizarPessoa(Long idPessoa, String nome, String email) {
        dsl.update(PESSOA)
                .set(PESSOA.NOME, nome)
                .set(PESSOA.EMAIL, email)
                .where(PESSOA.ID_PESSOA.eq(idPessoa))
                .execute();
    }

    // ------------------------------------------------------------------ Telefone

    /** Substitui o conjunto de telefones (entidade fraca com PK (id_pessoa, numero)). */
    public void substituirTelefones(Long idPessoa, List<TelefoneNovo> telefones) {
        dsl.deleteFrom(TELEFONE).where(TELEFONE.ID_PESSOA.eq(idPessoa)).execute();
        for (TelefoneNovo telefone : telefones) {
            dsl.insertInto(TELEFONE)
                    .set(TELEFONE.ID_PESSOA, idPessoa)
                    .set(TELEFONE.NUMERO, telefone.numero())
                    .set(TELEFONE.TIPO, telefone.tipo())
                    .execute();
        }
    }

    public record TelefoneNovo(String numero, TipoTelefone tipo) {}

    // ------------------------------------------------------------------ Endereco / Pessoa_Endereco

    /**
     * Reaproveita o Endereco com o mesmo (logradouro, numero, cep) ou cria um novo.
     * Endereco é imutável (RR12), portanto nunca é atualizado aqui.
     */
    public Long buscarOuCriarEndereco(String logradouro, String numero, String bairro,
                                      String cep, String cidade, String estado) {
        dsl.insertInto(ENDERECO)
                .set(ENDERECO.LOGRADOURO, logradouro)
                .set(ENDERECO.NUMERO, numero)
                .set(ENDERECO.BAIRRO, bairro)
                .set(ENDERECO.CEP, cep)
                .set(ENDERECO.CIDADE, cidade)
                .set(ENDERECO.ESTADO, estado)
                .onConflict(ENDERECO.LOGRADOURO, ENDERECO.NUMERO, ENDERECO.CEP)
                .doNothing()
                .execute();

        return dsl.select(ENDERECO.ID_ENDERECO)
                .from(ENDERECO)
                .where(ENDERECO.LOGRADOURO.eq(logradouro)
                        .and(ENDERECO.NUMERO.eq(numero))
                        .and(ENDERECO.CEP.eq(cep)))
                .fetchOneInto(Long.class);
    }

    public void vincularEndereco(Long idPessoa, Long idEndereco, String apelido, String complemento, String referencia) {
        dsl.insertInto(PESSOA_ENDERECO)
                .set(PESSOA_ENDERECO.ID_PESSOA, idPessoa)
                .set(PESSOA_ENDERECO.ID_ENDERECO, idEndereco)
                .set(PESSOA_ENDERECO.APELIDO, apelido)
                .set(PESSOA_ENDERECO.COMPLEMENTO, complemento)
                .set(PESSOA_ENDERECO.REFERENCIA, referencia)
                .execute();
    }

    /** Atualiza apenas os dados particulares do morador (RR12), sem afetar outros vínculos. */
    public void atualizarVinculoEndereco(Long idPessoa, Long idEndereco, String apelido, String complemento, String referencia) {
        dsl.update(PESSOA_ENDERECO)
                .set(PESSOA_ENDERECO.APELIDO, apelido)
                .set(PESSOA_ENDERECO.COMPLEMENTO, complemento)
                .set(PESSOA_ENDERECO.REFERENCIA, referencia)
                .where(PESSOA_ENDERECO.ID_PESSOA.eq(idPessoa)
                        .and(PESSOA_ENDERECO.ID_ENDERECO.eq(idEndereco)))
                .execute();
    }

    public void removerVinculoEndereco(Long idPessoa, Long idEndereco) {
        dsl.deleteFrom(PESSOA_ENDERECO)
                .where(PESSOA_ENDERECO.ID_PESSOA.eq(idPessoa)
                        .and(PESSOA_ENDERECO.ID_ENDERECO.eq(idEndereco)))
                .execute();
    }

    // ------------------------------------------------------------------ papéis

    public void inserirCliente(Long idPessoa) {
        dsl.insertInto(CLIENTE)
                .set(CLIENTE.ID_PESSOA, idPessoa)
                .execute();
    }

    public void atualizarEnderecoAtual(Long idPessoa, Long idEndereco) {
        dsl.update(CLIENTE)
                .set(CLIENTE.ID_ENDERECO_ATUAL, idEndereco)
                .where(CLIENTE.ID_PESSOA.eq(idPessoa))
                .execute();
    }

    public void removerCliente(Long idPessoa) {
        dsl.deleteFrom(CLIENTE).where(CLIENTE.ID_PESSOA.eq(idPessoa)).execute();
    }

    public void inserirLojista(Long idPessoa) {
        dsl.insertInto(LOJISTA)
                .set(LOJISTA.ID_PESSOA, idPessoa)
                .execute();
    }

    public void removerLojista(Long idPessoa) {
        dsl.deleteFrom(LOJISTA).where(LOJISTA.ID_PESSOA.eq(idPessoa)).execute();
    }

    public void inserirEntregador(Long idPessoa, TipoVeiculo tipoVeiculo) {
        dsl.insertInto(ENTREGADOR)
                .set(ENTREGADOR.ID_PESSOA, idPessoa)
                .set(ENTREGADOR.TIPO_VEICULO, tipoVeiculo)
                .execute();
    }

    public void atualizarVeiculo(Long idPessoa, TipoVeiculo tipoVeiculo) {
        dsl.update(ENTREGADOR)
                .set(ENTREGADOR.TIPO_VEICULO, tipoVeiculo)
                .where(ENTREGADOR.ID_PESSOA.eq(idPessoa))
                .execute();
    }

    public void removerEntregador(Long idPessoa) {
        dsl.deleteFrom(ENTREGADOR).where(ENTREGADOR.ID_PESSOA.eq(idPessoa)).execute();
    }

    // ------------------------------------------------------------------ Loja (primeira loja do Lojista — RR01)

    public Long inserirLoja(Long idLojista, Long idEndereco, String complementoEndereco, String cnpj,
                            String nome, String telefone, StatusFuncionamento statusFuncionamento,
                            Integer tempoEntregaEstimado, BigDecimal taxaEntrega) {
        return dsl.insertInto(LOJA)
                .set(LOJA.ID_LOJISTA, idLojista)
                .set(LOJA.ID_ENDERECO, idEndereco)
                .set(LOJA.COMPLEMENTO_ENDERECO, complementoEndereco)
                .set(LOJA.CNPJ, cnpj)
                .set(LOJA.NOME, nome)
                .set(LOJA.TELEFONE, telefone)
                .set(LOJA.STATUS_FUNCIONAMENTO, statusFuncionamento)
                .set(LOJA.TEMPO_ENTREGA_ESTIMADO, tempoEntregaEstimado)
                .set(LOJA.TAXA_ENTREGA, taxaEntrega)
                .returningResult(LOJA.ID_LOJA)
                .fetchOneInto(Long.class);
    }
}
