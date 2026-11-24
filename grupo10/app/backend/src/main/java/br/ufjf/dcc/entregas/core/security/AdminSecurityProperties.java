/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Camada Transversal: Core / Segurança
 */
package br.ufjf.dcc.entregas.core.security;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
@ConfigurationProperties(prefix = "app.security")
public class AdminSecurityProperties {

    private List<Long> adminUserIds = new ArrayList<>();

    public List<Long> getAdminUserIds() {
        return adminUserIds;
    }

    public void setAdminUserIds(List<Long> adminUserIds) {
        this.adminUserIds = adminUserIds != null ? adminUserIds : new ArrayList<>();
    }
}
