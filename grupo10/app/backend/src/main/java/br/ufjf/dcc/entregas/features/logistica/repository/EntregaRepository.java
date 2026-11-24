/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística
 */
package br.ufjf.dcc.entregas.features.logistica.repository;

import br.ufjf.dcc.entregas.features.logistica.dto.EntregadorSessaoResponse;
import br.ufjf.dcc.entregas.features.logistica.dto.PainelEntregadorResponse.EntregaDaRota;
import br.ufjf.dcc.entregas.features.logistica.dto.PainelEntregadorResponse.EntregaDisponivel;
import br.ufjf.dcc.entregas.features.logistica.dto.PainelEntregadorResponse.RotaResumo;
import br.ufjf.dcc.entregas.jooq.enums.StatusEntrega;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import br.ufjf.dcc.entregas.jooq.tables.Endereco;
import br.ufjf.dcc.entregas.jooq.tables.records.EntregaRecord;
import br.ufjf.dcc.entregas.jooq.tables.records.RotaRecord;
import br.ufjf.dcc.entregas.jooq.tables.records.VwPainelRotasLogisticaRecord;
import org.jooq.DSLContext;
import org.jooq.Field;
import org.jooq.Record;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static br.ufjf.dcc.entregas.jooq.Tables.ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;
import static br.ufjf.dcc.entregas.jooq.Tables.VW_PAINEL_ROTAS_LOGISTICA;
import static org.jooq.impl.DSL.currentOffsetDateTime;
import static org.jooq.impl.DSL.field;

@Repository
public class EntregaRepository {

    private static final Endereco COLETA = ENDERECO.as("coleta");
    private static final Endereco DESTINO = ENDERECO.as("destino");
    // Nas escritas, usa a hora posterior à espera pelo lock, não o início da transação.
    private static final Field<OffsetDateTime> AGORA_DA_INSTRUCAO = field("statement_timestamp()", OffsetDateTime.class);

    private final DSLContext dsl;

    public EntregaRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public List<EntregadorSessaoResponse> listarEntregadoresSessao() {
        return dsl.select(ENTREGADOR.ID_PESSOA, PESSOA.NOME)
                .from(ENTREGADOR)
                .join(PESSOA).on(PESSOA.ID_PESSOA.eq(ENTREGADOR.ID_PESSOA))
                .orderBy(ENTREGADOR.ID_PESSOA)
                .fetch(r -> new EntregadorSessaoResponse(r.value1(), r.value2()));
    }

    public boolean entregadorExiste(long idEntregador) {
        return dsl.fetchExists(ENTREGADOR, ENTREGADOR.ID_PESSOA.eq(idEntregador));
    }

    public boolean bloquearEntregador(long idEntregador) {
        return dsl.select(ENTREGADOR.ID_PESSOA)
                .from(ENTREGADOR)
                .where(ENTREGADOR.ID_PESSOA.eq(idEntregador))
                .forUpdate()
                .fetchOptional().isPresent();
    }

    public Optional<EntregaRecord> buscarEntregaForUpdate(long idEntrega) {
        return dsl.selectFrom(ENTREGA)
                .where(ENTREGA.ID_ENTREGA.eq(idEntrega))
                .forUpdate()
                .fetchOptional();
    }

    public boolean possuiEntregaAtivaAtrasada(long idEntregador) {
        return dsl.fetchExists(dsl.selectOne().from(ENTREGA)
                .join(ROTA).on(ROTA.ID_ROTA.eq(ENTREGA.ID_ROTA))
                .where(ROTA.ID_ENTREGADOR.eq(idEntregador))
                .and(ENTREGA.STATUS.in(StatusEntrega.aceita, StatusEntrega.a_caminho))
                .and(ENTREGA.PREVISAO_ENTREGA.lt(AGORA_DA_INSTRUCAO)));
    }

    public long criarRota(long idEntregador) {
        return dsl.insertInto(ROTA)
                .set(ROTA.ID_ENTREGADOR, idEntregador)
                .set(ROTA.CRIADA_EM, AGORA_DA_INSTRUCAO)
                .returningResult(ROTA.ID_ROTA)
                .fetchSingle(ROTA.ID_ROTA);
    }

    public boolean atribuirEntrega(long idEntrega, long idRota) {
        return dsl.update(ENTREGA)
                .set(ENTREGA.ID_ROTA, idRota)
                .set(ENTREGA.STATUS, StatusEntrega.aceita)
                .where(ENTREGA.ID_ENTREGA.eq(idEntrega))
                .and(ENTREGA.STATUS.eq(StatusEntrega.aguardando_entregador))
                .and(ENTREGA.ID_ROTA.isNull())
                .andExists(dsl.selectOne().from(PEDIDO)
                        .where(PEDIDO.ID_PEDIDO.eq(ENTREGA.ID_PEDIDO))
                        .and(PEDIDO.STATUS.eq(StatusPedido.pronto)))
                .execute() == 1;
    }

    public Optional<RotaRecord> buscarRotaDoEntregador(long idRota, long idEntregador) {
        return dsl.selectFrom(ROTA)
                .where(ROTA.ID_ROTA.eq(idRota))
                .and(ROTA.ID_ENTREGADOR.eq(idEntregador))
                .fetchOptional();
    }

    public void atualizarStatus(long idEntrega, StatusEntrega destino) {
        dsl.update(ENTREGA)
                .set(ENTREGA.STATUS, destino)
                .where(ENTREGA.ID_ENTREGA.eq(idEntrega))
                .execute();
    }

    public void encerrarRotaSemEntregasAtivas(long idRota) {
        dsl.update(ROTA)
                .set(ROTA.ENCERRADA_EM, AGORA_DA_INSTRUCAO)
                .where(ROTA.ID_ROTA.eq(idRota))
                .and(ROTA.ENCERRADA_EM.isNull())
                .andNotExists(dsl.selectOne().from(ENTREGA)
                        .where(ENTREGA.ID_ROTA.eq(idRota))
                        .and(ENTREGA.STATUS.ne(StatusEntrega.entregue)))
                .execute();
    }

    public List<EntregaDisponivel> listarDisponiveis(int inicio, int limite) {
        return dsl.select(ENTREGA.ID_ENTREGA, ENTREGA.ID_PEDIDO, LOJA.NOME,
                        DESTINO.BAIRRO, DESTINO.CIDADE, DESTINO.ESTADO, ENTREGA.PREVISAO_ENTREGA)
                .from(ENTREGA)
                .join(PEDIDO).on(PEDIDO.ID_PEDIDO.eq(ENTREGA.ID_PEDIDO))
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .join(DESTINO).on(DESTINO.ID_ENDERECO.eq(PEDIDO.ID_ENDERECO))
                .where(ENTREGA.STATUS.eq(StatusEntrega.aguardando_entregador))
                .and(ENTREGA.ID_ROTA.isNull())
                .and(PEDIDO.STATUS.eq(StatusPedido.pronto))
                .orderBy(ENTREGA.ID_ENTREGA.desc())
                .limit(limite)
                .offset(inicio)
                .fetch(r -> new EntregaDisponivel(r.value1(), r.value2(), r.value3(), r.value4(),
                        r.value5(), r.value6(), r.value7()));
    }

    public Optional<VwPainelRotasLogisticaRecord> buscarRotaAberta(long idEntregador) {
        var painel = VW_PAINEL_ROTAS_LOGISTICA;
        return dsl.selectFrom(painel)
                .where(painel.ID_ENTREGADOR.eq(idEntregador))
                .and(painel.ENCERRADA_EM.isNull())
                .orderBy(painel.CRIADA_EM.desc(), painel.ID_ROTA.desc())
                .limit(1)
                .fetchOptional();
    }

    public List<EntregaDaRota> listarEntregasDaRota(long idRota) {
        var atrasada = field(ENTREGA.STATUS.in(StatusEntrega.aceita, StatusEntrega.a_caminho)
                .and(ENTREGA.PREVISAO_ENTREGA.lt(currentOffsetDateTime()))).as("atrasada");

        return dsl.select(ENTREGA.ID_ENTREGA, ENTREGA.ID_PEDIDO, ENTREGA.STATUS, ENTREGA.PREVISAO_ENTREGA,
                        LOJA.NOME, LOJA.COMPLEMENTO_ENDERECO,
                        COLETA.LOGRADOURO, COLETA.NUMERO, COLETA.BAIRRO, COLETA.CIDADE, COLETA.ESTADO, COLETA.CEP,
                        DESTINO.LOGRADOURO, DESTINO.NUMERO, DESTINO.BAIRRO, DESTINO.CIDADE, DESTINO.ESTADO, DESTINO.CEP,
                        PEDIDO.COMPLEMENTO_ENTREGA, PEDIDO.REFERENCIA_ENTREGA, PEDIDO.OBSERVACAO_ENTREGA, atrasada)
                .from(ENTREGA)
                .join(PEDIDO).on(PEDIDO.ID_PEDIDO.eq(ENTREGA.ID_PEDIDO))
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .join(COLETA).on(COLETA.ID_ENDERECO.eq(LOJA.ID_ENDERECO))
                .join(DESTINO).on(DESTINO.ID_ENDERECO.eq(PEDIDO.ID_ENDERECO))
                .where(ENTREGA.ID_ROTA.eq(idRota))
                .orderBy(ENTREGA.ID_ENTREGA)
                .fetch(r -> {
                    String coleta = formatarEndereco(r, COLETA);
                    String complementoColeta = r.get(LOJA.COMPLEMENTO_ENDERECO);
                    if (complementoColeta != null && !complementoColeta.isBlank()) {
                        coleta += " (" + complementoColeta + ")";
                    }
                    return new EntregaDaRota(r.get(ENTREGA.ID_ENTREGA), r.get(ENTREGA.ID_PEDIDO), r.get(LOJA.NOME),
                            coleta, formatarEndereco(r, DESTINO), r.get(PEDIDO.COMPLEMENTO_ENTREGA),
                            r.get(PEDIDO.REFERENCIA_ENTREGA), r.get(PEDIDO.OBSERVACAO_ENTREGA),
                            r.get(ENTREGA.STATUS).getLiteral(), r.get(ENTREGA.PREVISAO_ENTREGA),
                            Boolean.TRUE.equals(r.get(atrasada)));
                });
    }

    public List<RotaResumo> listarRotasEncerradas(long idEntregador, int inicio, int limite) {
        var painel = VW_PAINEL_ROTAS_LOGISTICA;
        var rotas = dsl.select(painel.ID_ROTA, painel.CRIADA_EM, painel.ENCERRADA_EM, painel.TOTAL_ENTREGAS)
                .from(painel)
                .where(painel.ID_ENTREGADOR.eq(idEntregador))
                .and(painel.ENCERRADA_EM.isNotNull())
                .orderBy(painel.ENCERRADA_EM.desc(), painel.ID_ROTA.desc())
                .limit(limite)
                .offset(inicio)
                .fetch();
        if (rotas.isEmpty()) {
            return List.of();
        }

        var pedidosPorRota = dsl.select(ENTREGA.ID_ROTA, ENTREGA.ID_PEDIDO)
                .from(ENTREGA)
                .where(ENTREGA.ID_ROTA.in(rotas.getValues(painel.ID_ROTA)))
                .orderBy(ENTREGA.ID_ROTA, ENTREGA.ID_ENTREGA)
                .fetchGroups(ENTREGA.ID_ROTA, ENTREGA.ID_PEDIDO);
        return rotas.map(r -> new RotaResumo(r.value1(), r.value2(), r.value3(), r.value4().intValue(),
                List.copyOf(pedidosPorRota.getOrDefault(r.value1(), List.of()))));
    }

    private static String formatarEndereco(Record r, Endereco endereco) {
        String cep = r.get(endereco.CEP);
        return "%s, %s — %s, %s/%s · CEP %s-%s".formatted(r.get(endereco.LOGRADOURO), r.get(endereco.NUMERO),
                r.get(endereco.BAIRRO), r.get(endereco.CIDADE), r.get(endereco.ESTADO), cep.substring(0, 5), cep.substring(5));
    }
}
