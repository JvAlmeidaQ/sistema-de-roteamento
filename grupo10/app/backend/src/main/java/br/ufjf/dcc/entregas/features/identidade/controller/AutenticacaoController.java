/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 */
package br.ufjf.dcc.entregas.features.identidade.controller;

import br.ufjf.dcc.entregas.features.identidade.dto.DisponibilidadeResponse;
import br.ufjf.dcc.entregas.features.identidade.dto.EntrarRequest;
import br.ufjf.dcc.entregas.features.identidade.dto.SessaoAutenticadaResponse;
import br.ufjf.dcc.entregas.features.identidade.service.PerfilService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/identidade/autenticacao")
@Validated
public class AutenticacaoController {

    private final PerfilService perfilService;

    public AutenticacaoController(PerfilService perfilService) {
        this.perfilService = perfilService;
    }

    @GetMapping("/disponibilidade")
    public DisponibilidadeResponse verificarDisponibilidade(
            @RequestParam(required = false) @Size(max = 255) String email,
            @RequestParam(required = false) @Size(max = 20) String cpf
    ) {
        return perfilService.verificarDisponibilidade(email, cpf);
    }

    @PostMapping("/entrar")
    public SessaoAutenticadaResponse entrar(@Valid @RequestBody EntrarRequest request) {
        return perfilService.entrar(request.identificador());
    }

    @GetMapping("/sessao")
    public SessaoAutenticadaResponse obterSessao(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado
    ) {
        return perfilService.obterSessao(idUsuarioAutenticado);
    }
}
