/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.controller;

import br.ufjf.dcc.entregas.features.comercio.dto.AvaliacaoRequest;
import br.ufjf.dcc.entregas.features.comercio.dto.AvaliacaoResponse;
import br.ufjf.dcc.entregas.features.comercio.service.AvaliacaoService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/pedidos/{idPedido}/avaliacoes")
public class AvaliacaoController {

    private final AvaliacaoService avaliacaoService;

    public AvaliacaoController(AvaliacaoService avaliacaoService) {
        this.avaliacaoService = avaliacaoService;
    }

    @PostMapping("/loja")
    @ResponseStatus(HttpStatus.CREATED)
    public AvaliacaoResponse avaliarLoja(
            @RequestHeader("X-User-Id") @Positive Long idCliente,
            @PathVariable @Positive Long idPedido,
            @Valid @RequestBody AvaliacaoRequest request
    ) {
        return avaliacaoService.avaliarLoja(idCliente, idPedido, request);
    }

    @PostMapping("/entregador")
    @ResponseStatus(HttpStatus.CREATED)
    public AvaliacaoResponse avaliarEntregador(
            @RequestHeader("X-User-Id") @Positive Long idCliente,
            @PathVariable @Positive Long idPedido,
            @Valid @RequestBody AvaliacaoRequest request
    ) {
        return avaliacaoService.avaliarEntregador(idCliente, idPedido, request);
    }
}
