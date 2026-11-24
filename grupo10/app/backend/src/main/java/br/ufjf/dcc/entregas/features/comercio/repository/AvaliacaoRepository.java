/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.repository;

import br.ufjf.dcc.entregas.features.comercio.dto.AvaliacaoResponse;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.util.Optional;

import static br.ufjf.dcc.entregas.jooq.Tables.AVALIACAO_ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.AVALIACAO_LOJA;

@Repository
public class AvaliacaoRepository {

    private final DSLContext dsl;

    public AvaliacaoRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public Optional<AvaliacaoResponse> buscarAvaliacaoLoja(Long idPedido) {
        return dsl.selectFrom(AVALIACAO_LOJA)
                .where(AVALIACAO_LOJA.ID_PEDIDO.eq(idPedido))
                .fetchOptional(record -> new AvaliacaoResponse(
                        record.getIdPedido(),
                        record.getNota(),
                        record.getComentario(),
                        record.getDataAvaliacao()
                ));
    }

    public AvaliacaoResponse inserirAvaliacaoLoja(Long idPedido, Short nota, String comentario) {
        var record = dsl.insertInto(AVALIACAO_LOJA)
                .set(AVALIACAO_LOJA.ID_PEDIDO, idPedido)
                .set(AVALIACAO_LOJA.NOTA, nota)
                .set(AVALIACAO_LOJA.COMENTARIO, comentario)
                .returning()
                .fetchOne();

        return new AvaliacaoResponse(
                record.getIdPedido(),
                record.getNota(),
                record.getComentario(),
                record.getDataAvaliacao()
        );
    }

    public Optional<AvaliacaoResponse> buscarAvaliacaoEntregador(Long idPedido) {
        return dsl.selectFrom(AVALIACAO_ENTREGADOR)
                .where(AVALIACAO_ENTREGADOR.ID_PEDIDO.eq(idPedido))
                .fetchOptional(record -> new AvaliacaoResponse(
                        record.getIdPedido(),
                        record.getNota(),
                        record.getComentario(),
                        record.getDataAvaliacao()
                ));
    }

    public AvaliacaoResponse inserirAvaliacaoEntregador(Long idPedido, Short nota, String comentario) {
        var record = dsl.insertInto(AVALIACAO_ENTREGADOR)
                .set(AVALIACAO_ENTREGADOR.ID_PEDIDO, idPedido)
                .set(AVALIACAO_ENTREGADOR.NOTA, nota)
                .set(AVALIACAO_ENTREGADOR.COMENTARIO, comentario)
                .returning()
                .fetchOne();

        return new AvaliacaoResponse(
                record.getIdPedido(),
                record.getNota(),
                record.getComentario(),
                record.getDataAvaliacao()
        );
    }
}
