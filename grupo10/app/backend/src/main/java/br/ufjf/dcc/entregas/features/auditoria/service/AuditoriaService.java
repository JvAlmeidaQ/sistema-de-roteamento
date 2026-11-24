/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Implementa: Regras de consulta de trilha de auditoria e SLA de entregas.
 * Atende: RF05, RF06, RF10, RN03, RN04, RN08, RR11.
 */
package br.ufjf.dcc.entregas.features.auditoria.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RequisicaoInvalidaException;
import br.ufjf.dcc.entregas.core.security.AdminAccessService;
import br.ufjf.dcc.entregas.features.auditoria.dto.EventoHistoricoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.LinhaTempoPedidoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.SlaEntregaResponse;
import br.ufjf.dcc.entregas.features.auditoria.repository.AuditoriaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class AuditoriaService {

    private final AuditoriaRepository auditoriaRepository;
    private final AdminAccessService adminAccessService;

    public AuditoriaService(
            AuditoriaRepository auditoriaRepository,
            AdminAccessService adminAccessService
    ) {
        this.auditoriaRepository = auditoriaRepository;
        this.adminAccessService = adminAccessService;
    }

    public List<EventoHistoricoResponse> consultarHistoricoPedido(Long idPedido, Long idUsuario) {
        adminAccessService.exigirIdentificacao(idUsuario);
        validarAcessoPedido(idPedido, idUsuario);
        return auditoriaRepository.listarHistoricoPedido(idPedido);
    }

    public List<EventoHistoricoResponse> consultarHistoricoEntrega(Long idEntrega, Long idUsuario) {
        adminAccessService.exigirIdentificacao(idUsuario);
        if (!auditoriaRepository.existeEntrega(idEntrega)) {
            throw new RecursoNaoEncontradoException(
                    "Entrega não encontrada para o identificador informado: " + idEntrega
            );
        }
        if (!adminAccessService.isAdmin(idUsuario)
                && !auditoriaRepository.usuarioParticipaDaEntrega(idEntrega, idUsuario)) {
            throw new AcessoNegadoException(
                    "Você não possui permissão para consultar o histórico desta entrega."
            );
        }
        return auditoriaRepository.listarHistoricoEntrega(idEntrega);
    }

    public List<LinhaTempoPedidoResponse> consultarLinhaTempoPedido(Long idPedido, Long idUsuario) {
        adminAccessService.exigirIdentificacao(idUsuario);
        validarAcessoPedido(idPedido, idUsuario);
        return auditoriaRepository.listarLinhaTempoPedido(idPedido);
    }

    public List<SlaEntregaResponse> consultarSlaEntregas(
            Long idLoja,
            Boolean apenasAtrasadas,
            OffsetDateTime inicio,
            OffsetDateTime fim,
            Long idUsuario,
            String papelAtivo
    ) {
        adminAccessService.exigirIdentificacao(idUsuario);
        if (inicio != null && fim != null && inicio.isAfter(fim)) {
            throw new RequisicaoInvalidaException(
                    "A data de início não pode ser posterior à data de fim."
            );
        }
        if (adminAccessService.atuandoComoAdmin(idUsuario, papelAtivo)) {
            return auditoriaRepository.listarSlaEntregas(idLoja, apenasAtrasadas, inicio, fim, null, null);
        }
        String roleNorm = papelAtivo != null ? papelAtivo.trim().toLowerCase() : "";
        if ("entregador".equals(roleNorm)) {
            if (!auditoriaRepository.isEntregador(idUsuario)) {
                throw new AcessoNegadoException("Você não possui perfil de entregador.");
            }
            return auditoriaRepository.listarSlaEntregas(idLoja, apenasAtrasadas, inicio, fim, null, idUsuario);
        }
        if ("lojista".equals(roleNorm)) {
            if (!auditoriaRepository.isLojista(idUsuario)) {
                throw new AcessoNegadoException("Você não possui perfil de lojista.");
            }
            if (idLoja != null && !auditoriaRepository.lojaPertenceAoLojista(idLoja, idUsuario)) {
                throw new AcessoNegadoException("Você só pode consultar o SLA das suas próprias lojas.");
            }
            return auditoriaRepository.listarSlaEntregas(idLoja, apenasAtrasadas, inicio, fim, idUsuario, null);
        }
        if (roleNorm.isEmpty() || "admin".equals(roleNorm)) {
            if (auditoriaRepository.isLojista(idUsuario)) {
                if (idLoja != null && !auditoriaRepository.lojaPertenceAoLojista(idLoja, idUsuario)) {
                    throw new AcessoNegadoException("Você só pode consultar o SLA das suas próprias lojas.");
                }
                return auditoriaRepository.listarSlaEntregas(idLoja, apenasAtrasadas, inicio, fim, idUsuario, null);
            }
            if (auditoriaRepository.isEntregador(idUsuario)) {
                return auditoriaRepository.listarSlaEntregas(idLoja, apenasAtrasadas, inicio, fim, null, idUsuario);
            }
        }
        throw new AcessoNegadoException(
                "O painel de SLA é restrito a administradores, lojistas e entregadores."
        );
    }

    private void validarAcessoPedido(Long idPedido, Long idUsuario) {
        if (!auditoriaRepository.existePedido(idPedido)) {
            throw new RecursoNaoEncontradoException(
                    "Pedido não encontrado para o identificador informado: " + idPedido
            );
        }
        if (!adminAccessService.isAdmin(idUsuario)
                && !auditoriaRepository.usuarioParticipaDoPedido(idPedido, idUsuario)) {
            throw new AcessoNegadoException(
                    "Você não possui permissão para consultar o histórico deste pedido."
            );
        }
    }
}