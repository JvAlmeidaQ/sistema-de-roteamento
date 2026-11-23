/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística
 */
package br.ufjf.dcc.entregas.features.logistica.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record PainelEntregadorResponse(
        RotaAtual rotaAtual,
        Pagina<EntregaDisponivel> disponiveis,
        Pagina<RotaResumo> encerradas
) {
    public record Pagina<T>(List<T> itens, int pagina, boolean temProxima) {}

    public record EntregaDisponivel(
            long idEntrega,
            long idPedido,
            String nomeLoja,
            String bairroDestino,
            String cidadeDestino,
            String estadoDestino,
            OffsetDateTime previsaoEntrega
    ) {}

    public record RotaAtual(
            long idRota,
            OffsetDateTime criadaEm,
            int totalEntregas,
            int vagas,
            int entregasAtivas,
            int entregasAtrasadas,
            List<EntregaDaRota> entregas
    ) {}

    public record EntregaDaRota(
            long idEntrega,
            long idPedido,
            String nomeLoja,
            String enderecoColeta,
            String enderecoEntrega,
            String complementoEntrega,
            String referenciaEntrega,
            String observacaoEntrega,
            String status,
            OffsetDateTime previsaoEntrega,
            boolean atrasada
    ) {}

    public record RotaResumo(
            long idRota,
            OffsetDateTime criadaEm,
            OffsetDateTime encerradaEm,
            int totalEntregas,
            List<Long> idsPedidos
    ) {}
}
