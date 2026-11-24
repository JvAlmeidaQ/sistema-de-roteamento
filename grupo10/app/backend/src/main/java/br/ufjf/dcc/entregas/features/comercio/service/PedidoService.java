/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RegraNegocioException;
import br.ufjf.dcc.entregas.core.exception.RequisicaoInvalidaException;
import br.ufjf.dcc.entregas.core.security.AdminAccessService;
import br.ufjf.dcc.entregas.features.comercio.dto.CriarPedidoRequest;
import br.ufjf.dcc.entregas.features.comercio.dto.ItemPedidoRequest;
import br.ufjf.dcc.entregas.features.comercio.dto.ItemPedidoResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.PedidoResponse;
import br.ufjf.dcc.entregas.features.comercio.repository.PedidoRepository;
import br.ufjf.dcc.entregas.features.comercio.repository.PedidoRepository.ItemParaInsercao;
import br.ufjf.dcc.entregas.features.comercio.repository.PedidoRepository.PedidoDetalhadoRow;
import br.ufjf.dcc.entregas.jooq.enums.FormaPagamento;
import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import br.ufjf.dcc.entregas.jooq.tables.records.ProdutoRecord;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class PedidoService {

    private final PedidoRepository pedidoRepository;
    private final AdminAccessService adminAccessService;
    private final BigDecimal taxaServicoFixa;

    public PedidoService(
            PedidoRepository pedidoRepository,
            AdminAccessService adminAccessService,
            @Value("${app.financeiro.taxa-servico-fixa:2.50}") BigDecimal taxaServicoFixa
    ) {
        this.pedidoRepository = pedidoRepository;
        this.adminAccessService = adminAccessService;
        this.taxaServicoFixa = taxaServicoFixa;
    }

    /**
     * Cria um novo pedido e seus itens em transação única (RF02, RN01, RN07, RN09, RR03, RR04, RR09, RR10).
     */
    @Transactional
    public PedidoResponse criarPedido(Long idCliente, CriarPedidoRequest requisicao) {
        if (!pedidoRepository.clienteExiste(idCliente)) {
            throw new RecursoNaoEncontradoException("Cliente " + idCliente + " não encontrado.");
        }

        FormaPagamento formaPagamento = FormaPagamento.lookupLiteral(requisicao.formaPagamento());
        if (formaPagamento == null) {
            throw new RequisicaoInvalidaException("Forma de pagamento inválida: " + requisicao.formaPagamento());
        }

        var loja = pedidoRepository.buscarLoja(requisicao.idLoja())
                .orElseThrow(() -> new RecursoNaoEncontradoException("Loja " + requisicao.idLoja() + " não encontrada."));

        if (loja.getStatusFuncionamento() != StatusFuncionamento.aberta) {
            throw new RegraNegocioException("A loja '" + loja.getNome() + "' está fechada no momento.");
        }

        var enderecoCliente = pedidoRepository.buscarEnderecoDoCliente(idCliente, requisicao.idEndereco())
                .orElseThrow(() -> new RegraNegocioException("O endereço informado não está vinculado à sua conta."));

        Set<Long> idsProdutos = new HashSet<>();
        for (ItemPedidoRequest itemRequisicao : requisicao.itens()) {
            if (!idsProdutos.add(itemRequisicao.idProduto())) {
                throw new RequisicaoInvalidaException("Produto duplicado no pedido: " + itemRequisicao.idProduto());
            }
        }

        Map<Long, ProdutoRecord> produtosPorId = pedidoRepository.buscarProdutosPorIds(idsProdutos);
        List<ItemParaInsercao> itensParaInsercao = new java.util.ArrayList<>(requisicao.itens().size());
        BigDecimal subtotal = BigDecimal.ZERO;

        for (ItemPedidoRequest itemRequisicao : requisicao.itens()) {
            ProdutoRecord produto = produtosPorId.get(itemRequisicao.idProduto());
            if (produto == null) {
                throw new RecursoNaoEncontradoException("Produto " + itemRequisicao.idProduto() + " não encontrado.");
            }

            if (!produto.getIdLoja().equals(requisicao.idLoja())) {
                throw new RegraNegocioException("Todos os itens do pedido devem pertencer à mesma loja.");
            }

            if (!Boolean.TRUE.equals(produto.getAtivo())) {
                throw new RegraNegocioException("O produto '" + produto.getNome() + "' está indisponível no momento.");
            }

            BigDecimal precoUnitario = produto.getPreco().setScale(2, RoundingMode.HALF_UP);
            BigDecimal subtotalItem = precoUnitario
                    .multiply(BigDecimal.valueOf(itemRequisicao.quantidade()))
                    .setScale(2, RoundingMode.HALF_UP);

            subtotal = subtotal.add(subtotalItem);
            itensParaInsercao.add(new ItemParaInsercao(produto.getIdProduto(), itemRequisicao.quantidade(), precoUnitario));
        }

        BigDecimal taxaEntrega = loja.getTaxaEntrega().setScale(2, RoundingMode.HALF_UP);
        BigDecimal taxaServico = taxaServicoFixa.setScale(2, RoundingMode.HALF_UP);
        BigDecimal valorTotal = subtotal.add(taxaEntrega).add(taxaServico).setScale(2, RoundingMode.HALF_UP);

        Long idPedido = pedidoRepository.inserirPedido(
                requisicao.idLoja(),
                idCliente,
                requisicao.idEndereco(),
                enderecoCliente.getComplemento(),
                enderecoCliente.getReferencia(),
                requisicao.observacaoEntrega(),
                formaPagamento,
                subtotal,
                taxaEntrega,
                taxaServico,
                valorTotal
        );

        pedidoRepository.inserirItensPedido(idPedido, requisicao.idLoja(), itensParaInsercao);

        return buscarPorId(idCliente, idPedido);
    }

    /**
     * Atualiza o status do pedido conforme máquina de estados e perfil do usuário (RF03, RF06, RR06, RN12).
     */
    @Transactional
    public PedidoResponse atualizarStatus(Long idUsuarioAutenticado, Long idPedido, String statusDestinoLiteral) {
        StatusPedido statusDestino = StatusPedido.lookupLiteral(statusDestinoLiteral);
        if (statusDestino == null) {
            throw new RequisicaoInvalidaException("Status de pedido inválido: " + statusDestinoLiteral);
        }

        // Bloqueia a linha do pedido durante a transação para evitar corrida de estado (TOCTOU)
        pedidoRepository.buscarPedidoPorIdForUpdate(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pedido " + idPedido + " não encontrado."));

        PedidoDetalhadoRow pedido = pedidoRepository.buscarDetalhesPedido(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pedido " + idPedido + " não encontrado."));

        validarAutorizacaoPorPerfilUsuario(idUsuarioAutenticado, pedido, statusDestino);
        validarTransicaoPermitidaPeloComercio(pedido.status(), statusDestino);

        int atualizados = pedidoRepository.atualizarStatus(idPedido, pedido.status(), statusDestino);
        if (atualizados == 0) {
            throw new RegraNegocioException("O status do pedido foi alterado por outra operação. Atualize e tente novamente.");
        }

        return buscarPorId(idUsuarioAutenticado, idPedido);
    }

    public PedidoResponse buscarPorId(Long idUsuarioAutenticado, Long idPedido) {
        adminAccessService.exigirIdentificacao(idUsuarioAutenticado);
        PedidoDetalhadoRow pedido = pedidoRepository.buscarDetalhesPedido(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pedido " + idPedido + " não encontrado."));

        if (!adminAccessService.isAdmin(idUsuarioAutenticado)) {
            validarAcessoLeituraPedido(idUsuarioAutenticado, pedido);
        }

        List<ItemPedidoResponse> itens = pedidoRepository.listarItensPorPedidos(List.of(idPedido))
                .getOrDefault(idPedido, List.of());
        return montarResposta(pedido, itens);
    }

    public List<PedidoResponse> listarPedidos(
            Long idUsuarioAutenticado,
            Long idLoja,
            Long idCliente,
            String statusLiteral,
            OffsetDateTime dataInicio,
            OffsetDateTime dataFim,
            int limit
    ) {
        adminAccessService.exigirIdentificacao(idUsuarioAutenticado);

        if (dataInicio != null && dataFim != null && dataInicio.isAfter(dataFim)) {
            throw new RequisicaoInvalidaException("A data inicial não pode ser posterior à data final.");
        }

        StatusPedido status = null;
        if (statusLiteral != null && !statusLiteral.isBlank()) {
            status = StatusPedido.lookupLiteral(statusLiteral);
            if (status == null) {
                throw new RequisicaoInvalidaException("Status inválido: " + statusLiteral);
            }
        }

        boolean ehAdmin = adminAccessService.isAdmin(idUsuarioAutenticado);
        if (!ehAdmin) {
            if (idCliente != null && !idCliente.equals(idUsuarioAutenticado)) {
                throw new AcessoNegadoException("Acesso negado: não é permitido consultar pedidos de outro cliente.");
            }
            if (idLoja != null) {
                var loja = pedidoRepository.buscarLoja(idLoja)
                        .orElseThrow(() -> new RecursoNaoEncontradoException("Loja " + idLoja + " não encontrada."));
                if (!loja.getIdLojista().equals(idUsuarioAutenticado)) {
                    throw new AcessoNegadoException("Acesso negado: apenas o lojista proprietário pode listar pedidos desta loja.");
                }
            }
        }

        Long filtroUsuario = ehAdmin ? null : idUsuarioAutenticado;
        List<PedidoDetalhadoRow> rows = pedidoRepository.listarPedidos(
                idLoja, idCliente, filtroUsuario, status, dataInicio, dataFim, limit
        );
        if (rows.isEmpty()) {
            return List.of();
        }

        List<Long> idsPedido = rows.stream().map(PedidoDetalhadoRow::idPedido).toList();
        Map<Long, List<ItemPedidoResponse>> itensPorPedido = pedidoRepository.listarItensPorPedidos(idsPedido);

        return rows.stream()
                .map(row -> montarResposta(row, itensPorPedido.getOrDefault(row.idPedido(), List.of())))
                .toList();
    }

    private void validarAcessoLeituraPedido(Long idUsuarioAutenticado, PedidoDetalhadoRow pedido) {
        boolean ehClienteDono = pedido.idCliente().equals(idUsuarioAutenticado);
        boolean ehLojistaDono = pedido.idLojista().equals(idUsuarioAutenticado);
        if (!ehClienteDono && !ehLojistaDono) {
            throw new AcessoNegadoException("Acesso negado: você não possui permissão para consultar este pedido.");
        }
    }

    private void validarAutorizacaoPorPerfilUsuario(
            Long idUsuarioAutenticado,
            PedidoDetalhadoRow pedido,
            StatusPedido statusDestino
    ) {
        switch (statusDestino) {
            case aceito, recusado, em_preparacao, pronto -> {
                if (!pedido.idLojista().equals(idUsuarioAutenticado)) {
                    throw new AcessoNegadoException(
                            "Apenas o lojista responsável pela loja pode alterar o pedido para '" + statusDestino.getLiteral() + "'."
                    );
                }
            }
            case pago -> {
                if (!pedido.idCliente().equals(idUsuarioAutenticado)) {
                    throw new AcessoNegadoException("Apenas o cliente dono do pedido pode confirmar o pagamento.");
                }
            }
            case concluido -> throw new RegraNegocioException(
                    "O pedido é concluído automaticamente quando a entrega é finalizada."
            );
            case solicitado -> throw new RegraNegocioException("Não é permitido retornar o pedido para o status inicial.");
        }
    }

    private void validarTransicaoPermitidaPeloComercio(StatusPedido statusAtual, StatusPedido statusDestino) {
        boolean valida = switch (statusAtual) {
            case solicitado -> statusDestino == StatusPedido.aceito || statusDestino == StatusPedido.recusado;
            case aceito -> statusDestino == StatusPedido.pago;
            case pago -> statusDestino == StatusPedido.em_preparacao;
            case em_preparacao -> statusDestino == StatusPedido.pronto;
            default -> false;
        };

        if (!valida) {
            throw new RegraNegocioException(
                    "Esta alteração de status do pedido não é permitida no momento."
            );
        }
    }

    private PedidoResponse montarResposta(PedidoDetalhadoRow pedido, List<ItemPedidoResponse> itens) {
        return new PedidoResponse(
                pedido.idPedido(),
                pedido.idLoja(),
                pedido.nomeLoja(),
                pedido.idCliente(),
                pedido.nomeCliente(),
                pedido.idEndereco(),
                pedido.resumoEndereco(),
                pedido.complementoEntrega(),
                pedido.referenciaEntrega(),
                pedido.observacaoEntrega(),
                pedido.status().getLiteral(),
                pedido.statusEntrega(),
                pedido.dataPedido(),
                pedido.formaPagamento().getLiteral(),
                pedido.subtotal(),
                pedido.taxaEntrega(),
                pedido.taxaServico(),
                pedido.valorTotal(),
                itens,
                pedido.divisaoPagamento(),
                pedido.avaliacaoLoja(),
                pedido.avaliacaoEntregador()
        );
    }
}
