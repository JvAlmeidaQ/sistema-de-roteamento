/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Implementa: Regras de consulta de trilha de auditoria e SLA de entregas.
 * Atende: RF05, RF06, RF10, RN03, RN04, RN08, RR11.
 */
package br.ufjf.dcc.entregas.features.auditoria.service;

import br.ufjf.dcc.entregas.features.auditoria.dto.EventoHistoricoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.LinhaTempoPedidoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.SlaEntregaResponse;
import br.ufjf.dcc.entregas.features.auditoria.repository.AuditoriaRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class AuditoriaService {

    private final AuditoriaRepository auditoriaRepository;

    public AuditoriaService(AuditoriaRepository auditoriaRepository) {
        this.auditoriaRepository = auditoriaRepository;
    }

    public List<EventoHistoricoResponse> consultarHistoricoPedido(Long idPedido) {
        validarExistenciaPedido(idPedido);
        return auditoriaRepository.listarHistoricoPedido(idPedido);
    }

    public List<EventoHistoricoResponse> consultarHistoricoEntrega(Long idEntrega) {
        if (!auditoriaRepository.existeEntrega(idEntrega)) {
            throw new ResponseStatusException(
                    HttpStatus.NOT_FOUND,
                    "Entrega não encontrada para o identificador informado: " + idEntrega
            );
        }
        return auditoriaRepository.listarHistoricoEntrega(idEntrega);
    }

    public List<LinhaTempoPedidoResponse> consultarLinhaTempoPedido(Long idPedido) {
        validarExistenciaPedido(idPedido);
        return auditoriaRepository.listarLinhaTempoPedido(idPedido);
    }

    public List<SlaEntregaResponse> consultarSlaEntregas(
            Long idLoja,
            Boolean apenasAtrasadas,
            OffsetDateTime inicio,
            OffsetDateTime fim
    ) {
        if (inicio != null && fim != null && inicio.isAfter(fim)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "A data de início não pode ser posterior à data de fim."
            );
        }
        return auditoriaRepository.listarSlaEntregas(idLoja, apenasAtrasadas, inicio, fim);
    }

    private void validarExistenciaPedido(Long idPedido) {
        if (!auditoriaRepository.existePedido(idPedido)) {
            throw new ResponseStatusException(
                    HttpStatus.NOT_FOUND,
                    "Pedido não encontrado para o identificador informado: " + idPedido
            );
        }
    }
}