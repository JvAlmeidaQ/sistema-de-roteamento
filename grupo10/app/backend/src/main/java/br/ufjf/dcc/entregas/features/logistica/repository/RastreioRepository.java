/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística — RF05
 */
package br.ufjf.dcc.entregas.features.logistica.repository;

import br.ufjf.dcc.entregas.features.logistica.dto.RastreioPedidoResponse.Evento;
import br.ufjf.dcc.entregas.features.logistica.dto.RastreioPedidoResponse.TipoEvento;
import br.ufjf.dcc.entregas.jooq.enums.StatusEntrega;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.HISTORICO_ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.HISTORICO_PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;

@Repository
public class RastreioRepository {

    private final DSLContext dsl;

    public RastreioRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public Optional<PedidoRastreavel> buscarPedido(long idPedido) {
        return dsl.select(PEDIDO.ID_CLIENTE, LOJA.ID_LOJISTA, LOJA.NOME, PEDIDO.STATUS,
                        ENTREGA.ID_ENTREGA, ENTREGA.STATUS, ENTREGA.PREVISAO_ENTREGA, ROTA.ID_ENTREGADOR)
                .from(PEDIDO)
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .leftJoin(ENTREGA).on(ENTREGA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .leftJoin(ROTA).on(ROTA.ID_ROTA.eq(ENTREGA.ID_ROTA))
                .where(PEDIDO.ID_PEDIDO.eq(idPedido))
                .fetchOptional(r -> new PedidoRastreavel(r.value1(), r.value2(), r.value3(), r.value4(),
                        r.value5(), r.value6(), r.value7(), r.value8()));
    }

    public List<Evento> listarEventosPedido(long idPedido) {
        return dsl.select(HISTORICO_PEDIDO.STATUS, HISTORICO_PEDIDO.DATA_HORA)
                .from(HISTORICO_PEDIDO)
                .where(HISTORICO_PEDIDO.ID_PEDIDO.eq(idPedido))
                .fetch(r -> new Evento(TipoEvento.PEDIDO, r.value1().getLiteral(), r.value2()));
    }

    public List<Evento> listarEventosEntrega(long idEntrega) {
        return dsl.select(HISTORICO_ENTREGA.STATUS, HISTORICO_ENTREGA.DATA_HORA)
                .from(HISTORICO_ENTREGA)
                .where(HISTORICO_ENTREGA.ID_ENTREGA.eq(idEntrega))
                .fetch(r -> new Evento(TipoEvento.ENTREGA, r.value1().getLiteral(), r.value2()));
    }

    public record PedidoRastreavel(
            long idCliente,
            long idLojista,
            String nomeLoja,
            StatusPedido statusPedido,
            Long idEntrega,
            StatusEntrega statusEntrega,
            OffsetDateTime previsaoEntrega,
            Long idEntregador
    ) {}
}
