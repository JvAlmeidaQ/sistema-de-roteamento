package br.ufjf.dcc.entregas.features.catalogo.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.ConflitoNegocioException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RegraNegocioException;
import br.ufjf.dcc.entregas.features.catalogo.dto.AtualizarLojaRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.AtualizarProdutoRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.AtualizarStatusLojaRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.CategoriaResponse;
import br.ufjf.dcc.entregas.features.catalogo.dto.CriarCategoriaRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.CriarProdutoRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.LojaResponse;
import br.ufjf.dcc.entregas.features.catalogo.dto.ProdutoCatalogoResponse;
import br.ufjf.dcc.entregas.features.catalogo.repository.CatalogoRepository;
import br.ufjf.dcc.entregas.jooq.tables.records.LojaRecord;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class CatalogoService {

    private final CatalogoRepository catalogoRepository;

    public CatalogoService(CatalogoRepository catalogoRepository) {
        this.catalogoRepository = catalogoRepository;
    }

    public LojaResponse obterMinhaLoja(Long idLojista) {
        if (idLojista == null) {
            throw new AcessoNegadoException("Usuário não identificado. Forneça o cabeçalho X-User-Id.");
        }
        return catalogoRepository.buscarLojaPorLojista(idLojista)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Nenhuma loja encontrada para o lojista " + idLojista));
    }

    public LojaResponse buscarLojaPorId(Long idLoja) {
        return catalogoRepository.buscarLojaPorId(idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Loja " + idLoja + " não encontrada."));
    }

    @Transactional
    public LojaResponse atualizarStatusLoja(Long idUsuarioAutenticado, Long idLoja, AtualizarStatusLojaRequest request) {
        validarPropriedadeLoja(idUsuarioAutenticado, idLoja);
        catalogoRepository.atualizarStatusFuncionamento(idLoja, request.statusFuncionamento());
        return buscarLojaPorId(idLoja);
    }

    @Transactional
    public LojaResponse atualizarDadosLoja(Long idUsuarioAutenticado, Long idLoja, AtualizarLojaRequest request) {
        validarPropriedadeLoja(idUsuarioAutenticado, idLoja);
        catalogoRepository.atualizarDadosLoja(
                idLoja,
                request.telefone().trim(),
                request.complementoEndereco() != null ? request.complementoEndereco().trim() : null,
                request.tempoEntregaEstimado(),
                request.taxaEntrega()
        );
        return buscarLojaPorId(idLoja);
    }

    public List<CategoriaResponse> listarCategorias(Long idLoja) {
        validarExistenciaLoja(idLoja);
        return catalogoRepository.listarCategoriasPorLoja(idLoja);
    }

    @Transactional
    public CategoriaResponse criarCategoria(Long idUsuarioAutenticado, Long idLoja, CriarCategoriaRequest request) {
        validarPropriedadeLoja(idUsuarioAutenticado, idLoja);
        String nomeNormalizado = request.nome().trim();
        if (nomeNormalizado.isEmpty()) {
            throw new RegraNegocioException("Nome da categoria não pode ser vazio.");
        }
        if (catalogoRepository.existeCategoriaComNomeNaLoja(idLoja, nomeNormalizado)) {
            throw new ConflitoNegocioException("Já existe uma categoria cadastrada com o nome '" + nomeNormalizado + "' nesta loja.");
        }

        Long idCategoria = catalogoRepository.inserirCategoria(idLoja, nomeNormalizado);
        return new CategoriaResponse(idCategoria, idLoja, nomeNormalizado, 0L);
    }

    @Transactional
    public void excluirCategoria(Long idUsuarioAutenticado, Long idLoja, Long idCategoria) {
        validarPropriedadeLoja(idUsuarioAutenticado, idLoja);
        catalogoRepository.buscarCategoriaPorIdELoja(idCategoria, idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Categoria " + idCategoria + " não encontrada nesta loja."));

        int produtosOrfaos = catalogoRepository.contarProdutosComApenasEstaCategoria(idLoja, idCategoria);
        if (produtosOrfaos > 0) {
            throw new RegraNegocioException("[RR18] Não é permitido excluir categoria pois deixaria " + produtosOrfaos + " produto(s) sem nenhuma categoria associada. Reclassifique o produto antes de excluir.");
        }

        catalogoRepository.excluirCategoria(idCategoria, idLoja);
    }

    public List<ProdutoCatalogoResponse> listarProdutos(Long idLoja, Long idCategoria, Boolean ativo) {
        validarExistenciaLoja(idLoja);
        return catalogoRepository.listarProdutosLoja(idLoja, idCategoria, ativo);
    }

    public ProdutoCatalogoResponse buscarProdutoPorId(Long idLoja, Long idProduto) {
        validarExistenciaLoja(idLoja);
        return catalogoRepository.buscarProdutoCatalogoPorIdELoja(idProduto, idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Produto " + idProduto + " não encontrado nesta loja."));
    }

    @Transactional
    public ProdutoCatalogoResponse criarProduto(Long idUsuarioAutenticado, Long idLoja, CriarProdutoRequest request) {
        validarPropriedadeLoja(idUsuarioAutenticado, idLoja);
        List<Long> categoriasValidadas = validarCategoriasDaLoja(idLoja, request.categoriasIds());

        Long idProduto = catalogoRepository.inserirProduto(
                idLoja,
                request.nome().trim(),
                request.descricao() != null ? request.descricao().trim() : null,
                request.preco()
        );

        catalogoRepository.associarProdutoCategorias(idLoja, idProduto, categoriasValidadas);

        return buscarProdutoPorIdELoja(idProduto, idLoja);
    }

    @Transactional
    public ProdutoCatalogoResponse atualizarProduto(
            Long idUsuarioAutenticado,
            Long idLoja,
            Long idProduto,
            AtualizarProdutoRequest request
    ) {
        validarPropriedadeLoja(idUsuarioAutenticado, idLoja);
        catalogoRepository.buscarProdutoPorIdELoja(idProduto, idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Produto " + idProduto + " não encontrado nesta loja."));

        List<Long> categoriasValidadas = validarCategoriasDaLoja(idLoja, request.categoriasIds());

        catalogoRepository.atualizarProduto(
                idProduto,
                idLoja,
                request.nome().trim(),
                request.descricao() != null ? request.descricao().trim() : null,
                request.preco()
        );

        catalogoRepository.associarProdutoCategorias(idLoja, idProduto, categoriasValidadas);

        return buscarProdutoPorIdELoja(idProduto, idLoja);
    }

    @Transactional
    public ProdutoCatalogoResponse atualizarAtivoProduto(
            Long idUsuarioAutenticado,
            Long idLoja,
            Long idProduto,
            Boolean ativo
    ) {
        validarPropriedadeLoja(idUsuarioAutenticado, idLoja);
        catalogoRepository.buscarProdutoPorIdELoja(idProduto, idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Produto " + idProduto + " não encontrado nesta loja."));

        catalogoRepository.atualizarAtivoProduto(idProduto, idLoja, ativo);

        return buscarProdutoPorIdELoja(idProduto, idLoja);
    }

    private void validarExistenciaLoja(Long idLoja) {
        if (catalogoRepository.buscarLojaRecord(idLoja).isEmpty()) {
            throw new RecursoNaoEncontradoException("Loja " + idLoja + " não encontrada.");
        }
    }

    private void validarPropriedadeLoja(Long idUsuarioAutenticado, Long idLoja) {
        if (idUsuarioAutenticado == null) {
            throw new AcessoNegadoException("Usuário não identificado. Forneça o cabeçalho X-User-Id.");
        }
        LojaRecord loja = catalogoRepository.buscarLojaRecord(idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Loja " + idLoja + " não encontrada."));

        if (!loja.getIdLojista().equals(idUsuarioAutenticado)) {
            throw new AcessoNegadoException("O usuário " + idUsuarioAutenticado + " não é o lojista proprietário da loja " + idLoja);
        }
    }

    private List<Long> validarCategoriasDaLoja(Long idLoja, List<Long> categoriasIds) {
        if (categoriasIds == null) {
            throw new RegraNegocioException("O produto deve ser associado a pelo menos uma categoria.");
        }
        List<Long> limpas = categoriasIds.stream()
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();

        if (limpas.isEmpty()) {
            throw new RegraNegocioException("O produto deve ser associado a pelo menos uma categoria.");
        }
        var validas = catalogoRepository.validarCategoriasPertencemALoja(idLoja, limpas);
        if (validas.size() != limpas.size()) {
            throw new RegraNegocioException("[RN07] Uma ou mais categorias informadas não pertencem à loja " + idLoja);
        }
        return limpas;
    }

    private ProdutoCatalogoResponse buscarProdutoPorIdELoja(Long idProduto, Long idLoja) {
        return catalogoRepository.buscarProdutoCatalogoPorIdELoja(idProduto, idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Produto " + idProduto + " não encontrado."));
    }
}
