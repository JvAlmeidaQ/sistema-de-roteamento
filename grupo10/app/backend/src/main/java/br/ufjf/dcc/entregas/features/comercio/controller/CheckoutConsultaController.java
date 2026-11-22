/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: Controller estritamente de leitura (GET) para popular seletores do fluxo
 * de checkout e troca de sessão do usuário (X-User-Id) na interface.
 */
package br.ufjf.dcc.entregas.features.comercio.controller;

import br.ufjf.dcc.entregas.features.comercio.dto.EnderecoEntregaClienteResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.LojaCheckoutResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.UsuarioSessaoResponse;
import br.ufjf.dcc.entregas.features.comercio.service.CheckoutConsultaService;
import jakarta.validation.constraints.Positive;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Validated
@RestController
@RequestMapping("/api/comercio/checkout")
public class CheckoutConsultaController {

    private final CheckoutConsultaService checkoutConsultaService;

    public CheckoutConsultaController(CheckoutConsultaService checkoutConsultaService) {
        this.checkoutConsultaService = checkoutConsultaService;
    }

    @GetMapping("/usuarios")
    public List<UsuarioSessaoResponse> listarUsuariosParaSessao() {
        return checkoutConsultaService.listarUsuariosParaSessao();
    }

    @GetMapping("/lojas")
    public List<LojaCheckoutResponse> listarLojasParaCheckout() {
        return checkoutConsultaService.listarLojasParaCheckout();
    }

    @GetMapping("/clientes/{idCliente}/enderecos")
    public List<EnderecoEntregaClienteResponse> listarEnderecosEntregaCliente(
            @PathVariable @Positive Long idCliente
    ) {
        return checkoutConsultaService.listarEnderecosEntregaCliente(idCliente);
    }
}
