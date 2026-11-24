/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Implementa: Acesso somente leitura às tabelas historico_pedido, historico_entrega
 *             e às visões vw_auditoria_linha_tempo_pedido e vw_auditoria_sla_entregas via jOOQ DSL.
 * Atende: RN04, RN08, RR11 (nenhuma operação de INSERT/UPDATE/DELETE exposta).
 */
package br.ufjf.dcc.entregas.features.auditoria.repository;

import br.ufjf.dcc.entregas.features.auditoria.dto.EventoHistoricoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.LinhaTempoPedidoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.SlaEntregaResponse;
import org.jooq.Condition;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.HISTORICO_ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.HISTORICO_PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJISTA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;
import static br.ufjf.dcc.entregas.jooq.Tables.VW_AUDITORIA_LINHA_TEMPO_PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.VW_AUDITORIA_SLA_ENTREGAS;
import static org.jooq.impl.DSL.noCondition;

@Repository
public class AuditoriaRepository {

    private static final int LIMITE_LISTAGEM_SLA = 100;

    private final DSLContext dsl;

    public AuditoriaRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public boolean existePedido(Long idPedido) {
        return dsl.fetchExists(PEDIDO, PEDIDO.ID_PEDIDO.eq(idPedido));
    }

    public boolean existeEntrega(Long idEntrega) {
        return dsl.fetchExists(ENTREGA, ENTREGA.ID_ENTREGA.eq(idEntrega));
    }

    public boolean isLojista(Long idUsuario) {
        return dsl.fetchExists(LOJISTA, LOJISTA.ID_PESSOA.eq(idUsuario));
    }

    public boolean lojaPertenceAoLojista(Long idLoja, Long idLojista) {
        return dsl.fetchExists(LOJA, LOJA.ID_LOJA.eq(idLoja).and(LOJA.ID_LOJISTA.eq(idLojista)));
    }

    public boolean isEntregador(Long idUsuario) {
        return dsl.fetchExists(ENTREGADOR, ENTREGADOR.ID_PESSOA.eq(idUsuario));
    }

    public boolean usuarioParticipaDoPedido(Long idPedido, Long idUsuario) {
        boolean ehCliente = dsl.fetchExists(
                PEDIDO,
                PEDIDO.ID_PEDIDO.eq(idPedido).and(PEDIDO.ID_CLIENTE.eq(idUsuario))
        );
        if (ehCliente) {
            return true;
        }
        boolean ehLojista = dsl.fetchExists(
                dsl.selectOne()
                        .from(PEDIDO)
                        .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                        .where(PEDIDO.ID_PEDIDO.eq(idPedido).and(LOJA.ID_LOJISTA.eq(idUsuario)))
        );
        if (ehLojista) {
            return true;
        }
        return dsl.fetchExists(
                dsl.selectOne()
                        .from(ENTREGA)
                        .join(ROTA).on(ROTA.ID_ROTA.eq(ENTREGA.ID_ROTA))
                        .where(ENTREGA.ID_PEDIDO.eq(idPedido).and(ROTA.ID_ENTREGADOR.eq(idUsuario)))
        );
    }

    public boolean usuarioParticipaDaEntrega(Long idEntrega, Long idUsuario) {
        boolean ehEntregador = dsl.fetchExists(
                dsl.selectOne()
                        .from(ENTREGA)
                        .join(ROTA).on(ROTA.ID_ROTA.eq(ENTREGA.ID_ROTA))
                        .where(ENTREGA.ID_ENTREGA.eq(idEntrega).and(ROTA.ID_ENTREGADOR.eq(idUsuario)))
        );
        if (ehEntregador) {
            return true;
        }
        boolean ehCliente = dsl.fetchExists(
                dsl.selectOne()
                        .from(ENTREGA)
                        .join(PEDIDO).on(PEDIDO.ID_PEDIDO.eq(ENTREGA.ID_PEDIDO))
                        .where(ENTREGA.ID_ENTREGA.eq(idEntrega).and(PEDIDO.ID_CLIENTE.eq(idUsuario)))
        );
        if (ehCliente) {
            return true;
        }
        return dsl.fetchExists(
                dsl.selectOne()
                        .from(ENTREGA)
                        .join(PEDIDO).on(PEDIDO.ID_PEDIDO.eq(ENTREGA.ID_PEDIDO))
                        .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                        .where(ENTREGA.ID_ENTREGA.eq(idEntrega).and(LOJA.ID_LOJISTA.eq(idUsuario)))
        );
    }

    public List<EventoHistoricoResponse> listarHistoricoPedido(Long idPedido) {
        return dsl.select(HISTORICO_PEDIDO.STATUS, HISTORICO_PEDIDO.DATA_HORA)
                .from(HISTORICO_PEDIDO)
                .where(HISTORICO_PEDIDO.ID_PEDIDO.eq(idPedido))
                .orderBy(HISTORICO_PEDIDO.DATA_HORA.asc())
                .fetch(r -> new EventoHistoricoResponse(
                        r.value1().getLiteral(),
                        r.value2()
                ));
    }

    public List<EventoHistoricoResponse> listarHistoricoEntrega(Long idEntrega) {
        return dsl.select(HISTORICO_ENTREGA.STATUS, HISTORICO_ENTREGA.DATA_HORA)
                .from(HISTORICO_ENTREGA)
                .where(HISTORICO_ENTREGA.ID_ENTREGA.eq(idEntrega))
                .orderBy(HISTORICO_ENTREGA.DATA_HORA.asc())
                .fetch(r -> new EventoHistoricoResponse(
                        r.value1().getLiteral(),
                        r.value2()
                ));
    }

    public List<LinhaTempoPedidoResponse> listarLinhaTempoPedido(Long idPedido) {
        return dsl.selectFrom(VW_AUDITORIA_LINHA_TEMPO_PEDIDO)
                .where(VW_AUDITORIA_LINHA_TEMPO_PEDIDO.ID_PEDIDO.eq(idPedido))
                .orderBy(VW_AUDITORIA_LINHA_TEMPO_PEDIDO.DATA_HORA.asc())
                .fetch(r -> new LinhaTempoPedidoResponse(
                        r.getIdPedido(),
                        r.getIdLoja(),
                        r.getIdCliente(),
                        r.getDominioEvento(),
                        r.getStatusEvento(),
                        r.getDataHora()
                ));
    }

    public List<SlaEntregaResponse> listarSlaEntregas(
            Long idLoja,
            Boolean apenasAtrasadas,
            OffsetDateTime inicio,
            OffsetDateTime fim,
            Long idLojistaEscopo,
            Long idEntregadorEscopo
    ) {
        Condition filtro = noCondition();

        if (idLojistaEscopo != null) {
            filtro = filtro.and(VW_AUDITORIA_SLA_ENTREGAS.ID_LOJA.in(
                    dsl.select(LOJA.ID_LOJA).from(LOJA).where(LOJA.ID_LOJISTA.eq(idLojistaEscopo))
            ));
        }
        if (idEntregadorEscopo != null) {
            filtro = filtro.and(VW_AUDITORIA_SLA_ENTREGAS.ID_ROTA.in(
                    dsl.select(ROTA.ID_ROTA).from(ROTA).where(ROTA.ID_ENTREGADOR.eq(idEntregadorEscopo))
            ));
        }
        if (idLoja != null) {
            filtro = filtro.and(VW_AUDITORIA_SLA_ENTREGAS.ID_LOJA.eq(idLoja));
        }
        if (Boolean.TRUE.equals(apenasAtrasadas)) {
            filtro = filtro.and(VW_AUDITORIA_SLA_ENTREGAS.ATRASADA.isTrue());
        }
        if (inicio != null) {
            filtro = filtro.and(VW_AUDITORIA_SLA_ENTREGAS.ENTREGUE_EM.ge(inicio));
        }
        if (fim != null) {
            filtro = filtro.and(VW_AUDITORIA_SLA_ENTREGAS.ENTREGUE_EM.le(fim));
        }

        return dsl.selectFrom(VW_AUDITORIA_SLA_ENTREGAS)
                .where(filtro)
                .orderBy(VW_AUDITORIA_SLA_ENTREGAS.ENTREGUE_EM.desc())
                .limit(LIMITE_LISTAGEM_SLA)
                .fetch(r -> new SlaEntregaResponse(
                        r.getIdEntrega(),
                        r.getIdPedido(),
                        r.getIdLoja(),
                        r.getNomeLoja(),
                        r.getIdRota(),
                        r.getDataPedido(),
                        r.getPrevisaoEntrega(),
                        r.getEntregueEm(),
                        Boolean.TRUE.equals(r.getAtrasada()),
                        r.getDesvioMinutos()
                ));
    }
}