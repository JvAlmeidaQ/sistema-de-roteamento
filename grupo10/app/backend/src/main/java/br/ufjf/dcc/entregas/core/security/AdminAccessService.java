/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Camada Transversal: Core / Segurança
 */
package br.ufjf.dcc.entregas.core.security;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Centraliza a verificação de identificação do usuário e permissões administrativas.
 */
@Service
public class AdminAccessService {

    private final Set<Long> adminUserIds;

    public AdminAccessService(@Value("${app.security.admin-user-ids:}") List<Long> adminUserIds) {
        if (adminUserIds == null) {
            this.adminUserIds = Set.of();
        } else {
            this.adminUserIds = adminUserIds.stream()
                    .filter(Objects::nonNull)
                    .filter(id -> id > 0)
                    .collect(Collectors.toUnmodifiableSet());
        }
    }

    public boolean isAdmin(Long idUsuario) {
        return idUsuario != null && adminUserIds.contains(idUsuario);
    }

    public void exigirIdentificacao(Long idUsuario) {
        if (idUsuario == null || idUsuario <= 0) {
            throw new AcessoNegadoException("Identifique-se para acessar este recurso.");
        }
    }

    public void exigirAdmin(Long idUsuario) {
        exigirIdentificacao(idUsuario);
        if (!isAdmin(idUsuario)) {
            throw new AcessoNegadoException("Acesso restrito a administradores do sistema.");
        }
    }
}
