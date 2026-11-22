/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Camada Transversal: Core / Web
 */
package br.ufjf.dcc.entregas.core.web;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Encaminha rotas de interface (BrowserRouter) para index.html sem interceptar /api ou arquivos estáticos.
 */
@Controller
public class SpaForwardController {

    @GetMapping(value = {
            "/{path:[^\\.]*}",
            "/{path:^(?!api$)[^\\.]*}/{subpath:[^\\.]*}",
            "/{path:^(?!api$)[^\\.]*}/{subpath:[^\\.]*}/{rest:[^\\.]*}"
    })
    public String forwardSpa() {
        return "forward:/index.html";
    }
}
