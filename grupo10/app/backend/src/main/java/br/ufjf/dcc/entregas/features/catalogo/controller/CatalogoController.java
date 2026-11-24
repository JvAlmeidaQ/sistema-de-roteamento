package br.ufjf.dcc.entregas.features.catalogo.controller;

import br.ufjf.dcc.entregas.features.catalogo.dto.AtualizarAtivoProdutoRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.AtualizarLojaRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.AtualizarProdutoRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.AtualizarStatusLojaRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.CategoriaResponse;
import br.ufjf.dcc.entregas.features.catalogo.dto.CriarCategoriaRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.CriarProdutoRequest;
import br.ufjf.dcc.entregas.features.catalogo.dto.LojaResponse;
import br.ufjf.dcc.entregas.features.catalogo.dto.ProdutoCatalogoResponse;
import br.ufjf.dcc.entregas.features.catalogo.service.CatalogoService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
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
@RequestMapping("/api/catalogo")
@Validated
public class CatalogoController {

    private final CatalogoService catalogoService;

    public CatalogoController(CatalogoService catalogoService) {
        this.catalogoService = catalogoService;
    }

    @GetMapping("/lojas/minha-loja")
    public LojaResponse obterMinhaLoja(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado
    ) {
        return catalogoService.obterMinhaLoja(idUsuarioAutenticado);
    }

    @GetMapping("/lojas/{idLoja}")
    public LojaResponse buscarLojaPorId(@PathVariable @Positive Long idLoja) {
        return catalogoService.buscarLojaPorId(idLoja);
    }

    @PatchMapping("/lojas/{idLoja}/status")
    public LojaResponse atualizarStatusLoja(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @Valid @RequestBody AtualizarStatusLojaRequest request
    ) {
        return catalogoService.atualizarStatusLoja(idUsuarioAutenticado, idLoja, request);
    }

    @PutMapping("/lojas/{idLoja}")
    public LojaResponse atualizarDadosLoja(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @Valid @RequestBody AtualizarLojaRequest request
    ) {
        return catalogoService.atualizarDadosLoja(idUsuarioAutenticado, idLoja, request);
    }

    @GetMapping("/lojas/{idLoja}/categorias")
    public List<CategoriaResponse> listarCategorias(@PathVariable @Positive Long idLoja) {
        return catalogoService.listarCategorias(idLoja);
    }

    @PostMapping("/lojas/{idLoja}/categorias")
    @ResponseStatus(HttpStatus.CREATED)
    public CategoriaResponse criarCategoria(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @Valid @RequestBody CriarCategoriaRequest request
    ) {
        return catalogoService.criarCategoria(idUsuarioAutenticado, idLoja, request);
    }

    @DeleteMapping("/lojas/{idLoja}/categorias/{idCategoria}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluirCategoria(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @PathVariable @Positive Long idCategoria
    ) {
        catalogoService.excluirCategoria(idUsuarioAutenticado, idLoja, idCategoria);
    }

    @GetMapping("/lojas/{idLoja}/produtos")
    public List<ProdutoCatalogoResponse> listarProdutos(
            @PathVariable @Positive Long idLoja,
            @RequestParam(required = false) @Positive Long idCategoria,
            @RequestParam(required = false) Boolean ativo
    ) {
        return catalogoService.listarProdutos(idLoja, idCategoria, ativo);
    }

    @GetMapping("/lojas/{idLoja}/produtos/{idProduto}")
    public ProdutoCatalogoResponse buscarProdutoPorId(
            @PathVariable @Positive Long idLoja,
            @PathVariable @Positive Long idProduto
    ) {
        return catalogoService.buscarProdutoPorId(idLoja, idProduto);
    }

    @PostMapping("/lojas/{idLoja}/produtos")
    @ResponseStatus(HttpStatus.CREATED)
    public ProdutoCatalogoResponse criarProduto(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @Valid @RequestBody CriarProdutoRequest request
    ) {
        return catalogoService.criarProduto(idUsuarioAutenticado, idLoja, request);
    }

    @PutMapping("/lojas/{idLoja}/produtos/{idProduto}")
    public ProdutoCatalogoResponse atualizarProduto(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @PathVariable @Positive Long idProduto,
            @Valid @RequestBody AtualizarProdutoRequest request
    ) {
        return catalogoService.atualizarProduto(idUsuarioAutenticado, idLoja, idProduto, request);
    }

    @PatchMapping("/lojas/{idLoja}/produtos/{idProduto}/ativo")
    public ProdutoCatalogoResponse atualizarAtivoProduto(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @PathVariable @Positive Long idProduto,
            @Valid @RequestBody AtualizarAtivoProdutoRequest request
    ) {
        return catalogoService.atualizarAtivoProduto(idUsuarioAutenticado, idLoja, idProduto, request.ativo());
    }
}
