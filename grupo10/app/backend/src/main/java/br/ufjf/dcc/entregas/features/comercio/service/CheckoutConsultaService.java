/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: Serviço estritamente de leitura (SELECT) de apoio ao fluxo de checkout e sessão.
 */
package br.ufjf.dcc.entregas.features.comercio.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.security.AdminAccessService;
import br.ufjf.dcc.entregas.features.comercio.dto.EnderecoEntregaClienteResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.LojaCheckoutResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.UsuarioSessaoResponse;
import br.ufjf.dcc.entregas.features.comercio.repository.CheckoutConsultaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional(readOnly = true)
public class CheckoutConsultaService {

    private final CheckoutConsultaRepository checkoutConsultaRepository;
    private final AdminAccessService adminAccessService;

    public CheckoutConsultaService(
            CheckoutConsultaRepository checkoutConsultaRepository,
            AdminAccessService adminAccessService
    ) {
        this.checkoutConsultaRepository = checkoutConsultaRepository;
        this.adminAccessService = adminAccessService;
    }

    public List<UsuarioSessaoResponse> listarUsuariosParaSessao() {
        return checkoutConsultaRepository.listarUsuariosParaSessao();
    }

    public List<LojaCheckoutResponse> listarLojasParaCheckout() {
        return checkoutConsultaRepository.listarLojasComProdutosParaCheckout();
    }

    public List<EnderecoEntregaClienteResponse> listarEnderecosEntregaCliente(
            Long idUsuarioAutenticado,
            Long idCliente
    ) {
        adminAccessService.exigirIdentificacao(idUsuarioAutenticado);
        if (!idUsuarioAutenticado.equals(idCliente) && !adminAccessService.isAdmin(idUsuarioAutenticado)) {
            throw new AcessoNegadoException("Você só pode consultar os seus próprios endereços de entrega.");
        }
        return checkoutConsultaRepository.listarEnderecosDeEntregaDoCliente(idCliente);
    }
}
