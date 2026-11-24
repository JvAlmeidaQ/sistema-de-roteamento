/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Implementa: RF01 (Cadastrar e Gerenciar Conta — UC1): criação, edição, consulta e busca de perfis
 */
package br.ufjf.dcc.entregas.features.identidade.controller;

import br.ufjf.dcc.entregas.features.identidade.dto.PerfilRequest;
import br.ufjf.dcc.entregas.features.identidade.dto.PerfilResponse;
import br.ufjf.dcc.entregas.features.identidade.dto.PessoaResumoResponse;
import br.ufjf.dcc.entregas.features.identidade.service.PerfilService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/identidade/pessoas")
@Validated
public class IdentidadeController {

    private final PerfilService perfilService;

    public IdentidadeController(PerfilService perfilService) {
        this.perfilService = perfilService;
    }

    @GetMapping
    public List<PessoaResumoResponse> listar(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @RequestParam(required = false) @Size(max = 120) String busca
    ) {
        return perfilService.listarPessoas(idUsuarioAutenticado, busca);
    }

    @GetMapping("/{idPessoa}")
    public PerfilResponse buscar(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idPessoa
    ) {
        return perfilService.buscarPerfilAutorizado(idUsuarioAutenticado, idPessoa);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PerfilResponse criar(@Valid @RequestBody PerfilRequest request) {
        return perfilService.criarPerfil(request);
    }

    @PutMapping("/{idPessoa}")
    public PerfilResponse atualizar(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idPessoa,
            @Valid @RequestBody PerfilRequest request
    ) {
        return perfilService.atualizarPerfil(idUsuarioAutenticado, idPessoa, request);
    }
}
