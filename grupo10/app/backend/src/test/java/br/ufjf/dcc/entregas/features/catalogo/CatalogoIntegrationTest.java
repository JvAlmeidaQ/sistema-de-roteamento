/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Catálogo
 */
package br.ufjf.dcc.entregas.features.catalogo;

import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.jooq.DSLContext;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static br.ufjf.dcc.entregas.jooq.Tables.CATEGORIA;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class CatalogoIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private DSLContext dsl;

    @Test
    @DisplayName("Deve consultar loja por ID e por sessão do lojista (minha-loja), validando endereço e 403 sem identificação")
    void deveConsultarLojaPorIdEMinhaLoja() throws Exception {
        var lojas = dsl.selectFrom(LOJA).limit(2).fetch();
        assertThat(lojas).hasSize(2);

        var lojaA = lojas.get(0);
        Long idLojaA = lojaA.getIdLoja();
        Long idLojistaA = lojaA.getIdLojista();

        // 1. Busca por ID direto (pública)
        mockMvc.perform(get("/api/catalogo/lojas/{idLoja}", idLojaA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idLoja").value(idLojaA))
                .andExpect(jsonPath("$.nome").value(lojaA.getNome()))
                .andExpect(jsonPath("$.cnpj").value(lojaA.getCnpj()))
                .andExpect(jsonPath("$.logradouro").isNotEmpty())
                .andExpect(jsonPath("$.cidade").isNotEmpty());

        // 2. Busca pela rota contextual do lojista autenticado
        mockMvc.perform(get("/api/catalogo/lojas/minha-loja")
                        .header("X-User-Id", idLojistaA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idLoja").value(idLojaA))
                .andExpect(jsonPath("$.idLojista").value(idLojistaA));

        // 3. Consulta de minha-loja sem cabeçalho X-User-Id deve retornar 403 Forbidden
        mockMvc.perform(get("/api/catalogo/lojas/minha-loja"))
                .andExpect(status().isForbidden());

        // 4. Loja inexistente deve retornar 404 Not Found
        mockMvc.perform(get("/api/catalogo/lojas/{idLoja}", 999999L))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("Deve atualizar status de funcionamento (RF07) e impedir alteração por lojista não proprietário (403)")
    void deveAtualizarStatusFuncionamentoComAutorizacao() throws Exception {
        var lojas = dsl.selectFrom(LOJA).limit(2).fetch();
        var loja = lojas.get(0);
        var outraLoja = lojas.get(1);

        Long idLoja = loja.getIdLoja();
        Long idDono = loja.getIdLojista();
        Long idOutroLojista = outraLoja.getIdLojista();

        // 1. Tentativa de alteração por usuário não proprietário -> 403 Forbidden
        mockMvc.perform(patch("/api/catalogo/lojas/{idLoja}/status", idLoja)
                        .header("X-User-Id", idOutroLojista)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"statusFuncionamento\":\"fechada\"}"))
                .andExpect(status().isForbidden());

        // 2. Lojista proprietário altera para 'fechada' -> 200 OK
        mockMvc.perform(patch("/api/catalogo/lojas/{idLoja}/status", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"statusFuncionamento\":\"fechada\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.statusFuncionamento").value("fechada"));

        // Comprova persistência imediata no banco
        StatusFuncionamento statusNoBanco = dsl.select(LOJA.STATUS_FUNCIONAMENTO)
                .from(LOJA)
                .where(LOJA.ID_LOJA.eq(idLoja))
                .fetchOneInto(StatusFuncionamento.class);
        assertThat(statusNoBanco).isEqualTo(StatusFuncionamento.fechada);

        // 3. Reabertura para 'aberta' -> 200 OK
        mockMvc.perform(patch("/api/catalogo/lojas/{idLoja}/status", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"statusFuncionamento\":\"aberta\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.statusFuncionamento").value("aberta"));
    }

    @Test
    @DisplayName("Deve atualizar dados operacionais da loja e validar restrições de tempo (>0) e taxa (>=0)")
    void deveAtualizarDadosOperacionaisEValidarConstraints() throws Exception {
        var loja = dsl.selectFrom(LOJA).limit(1).fetchOne();
        assertThat(loja).isNotNull();
        Long idLoja = loja.getIdLoja();
        Long idDono = loja.getIdLojista();

        // 1. Atualização bem-sucedida
        String payloadValido = """
                {
                  "telefone": "32998877665",
                  "complementoEndereco": "Loja 02 - Térreo",
                  "tempoEntregaEstimado": 45,
                  "taxaEntrega": 8.50
                }
                """;

        mockMvc.perform(put("/api/catalogo/lojas/{idLoja}", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadValido))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.telefone").value("32998877665"))
                .andExpect(jsonPath("$.complementoEndereco").value("Loja 02 - Térreo"))
                .andExpect(jsonPath("$.tempoEntregaEstimado").value(45))
                .andExpect(jsonPath("$.taxaEntrega").value(8.50));

        // 2. Validação negativa: tempo de entrega zero ou negativo -> 400 Bad Request
        String payloadTempoInvalido = """
                {
                  "telefone": "32998877665",
                  "tempoEntregaEstimado": 0,
                  "taxaEntrega": 5.00
                }
                """;
        mockMvc.perform(put("/api/catalogo/lojas/{idLoja}", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadTempoInvalido))
                .andExpect(status().isBadRequest());

        // 3. Validação negativa: taxa de entrega negativa -> 400 Bad Request
        String payloadTaxaNegativa = """
                {
                  "telefone": "32998877665",
                  "tempoEntregaEstimado": 30,
                  "taxaEntrega": -1.50
                }
                """;
        mockMvc.perform(put("/api/catalogo/lojas/{idLoja}", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadTaxaNegativa))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("Deve gerenciar categorias: criar, listar, rejeitar duplicidade (409) e proteger cardinalidade mínima de produtos (RR18 -> 422)")
    void deveGerenciarCategoriasEProtegerRR18() throws Exception {
        var loja = dsl.selectFrom(LOJA).limit(1).fetchOne();
        assertThat(loja).isNotNull();
        Long idLoja = loja.getIdLoja();
        Long idDono = loja.getIdLojista();

        // 1. Criação de nova categoria válida
        String nomeNovaCategoria = "Sobremesas Artesanais " + System.currentTimeMillis();
        String payloadCategoria = "{\"nome\": \"" + nomeNovaCategoria + "\"}";

        String respCat = mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/categorias", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadCategoria))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.nome").value(nomeNovaCategoria))
                .andExpect(jsonPath("$.totalProdutos").value(0))
                .andReturn().getResponse().getContentAsString();

        JsonNode jsonCat = objectMapper.readTree(respCat);
        Long idCategoriaCriada = jsonCat.get("idCategoria").asLong();

        // 2. Tentativa de criar categoria com mesmo nome na mesma loja -> 409 Conflict
        mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/categorias", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadCategoria))
                .andExpect(status().isConflict());

        // 3. Listagem de categorias da loja confirma presença da nova categoria
        mockMvc.perform(get("/api/catalogo/lojas/{idLoja}/categorias", idLoja))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThanOrEqualTo(1))));

        // 4. Exclusão de categoria sem produtos associados -> 204 No Content
        mockMvc.perform(delete("/api/catalogo/lojas/{idLoja}/categorias/{idCategoria}", idLoja, idCategoriaCriada)
                        .header("X-User-Id", idDono))
                .andExpect(status().isNoContent());

        // 5. Proteção RR18: tentar excluir uma categoria que é a ÚNICA de algum produto deve falhar com 422
        // Cria uma categoria exclusiva e um produto vinculado apenas a ela
        String payloadCatExclusiva = "{\"nome\": \"Categoria Exclusiva RR18 " + System.currentTimeMillis() + "\"}";
        String respCatExclusiva = mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/categorias", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadCatExclusiva))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        Long idCatExclusiva = objectMapper.readTree(respCatExclusiva).get("idCategoria").asLong();

        String payloadProdExclusivo = """
                {
                  "nome": "Produto Exclusivo RR18",
                  "preco": 10.00,
                  "categoriasIds": [%d]
                }
                """.formatted(idCatExclusiva);
        mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/produtos", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadProdExclusivo))
                .andExpect(status().isCreated());

        // Agora a categoria possui um produto cuja ÚNICA categoria é ela -> 422 Unprocessable Entity
        mockMvc.perform(delete("/api/catalogo/lojas/{idLoja}/categorias/{idCategoria}", idLoja, idCatExclusiva)
                        .header("X-User-Id", idDono))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Reclassifique-os")));
    }

    @Test
    @DisplayName("Deve cadastrar, consultar individualmente, atualizar e alternar ativo de produto (RF07), rejeitando preço <= 0")
    void deveCadastrarConsultarEAtualizarProduto() throws Exception {
        var loja = dsl.selectFrom(LOJA).limit(1).fetchOne();
        assertThat(loja).isNotNull();
        Long idLoja = loja.getIdLoja();
        Long idDono = loja.getIdLojista();

        // Busca duas categorias válidas da loja
        var categorias = dsl.select(CATEGORIA.ID_CATEGORIA)
                .from(CATEGORIA)
                .where(CATEGORIA.ID_LOJA.eq(idLoja))
                .limit(2)
                .fetchInto(Long.class);
        assertThat(categorias).isNotEmpty();
        Long idCat1 = categorias.get(0);

        // 1. Cadastro de novo produto
        String payloadNovo = """
                {
                  "nome": "Hambúrguer Especial Artesanal",
                  "descricao": "Blend 180g com queijo prato e bacon",
                  "preco": 32.50,
                  "categoriasIds": [%d]
                }
                """.formatted(idCat1);

        String respNovo = mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/produtos", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadNovo))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.nome").value("Hambúrguer Especial Artesanal"))
                .andExpect(jsonPath("$.preco").value(32.50))
                .andExpect(jsonPath("$.ativo").value(true))
                .andExpect(jsonPath("$.categorias", hasSize(1)))
                .andReturn().getResponse().getContentAsString();

        JsonNode jsonNovo = objectMapper.readTree(respNovo);
        Long idProdutoCriado = jsonNovo.get("idProduto").asLong();

        // 2. Consulta individual do produto recém-criado
        mockMvc.perform(get("/api/catalogo/lojas/{idLoja}/produtos/{idProduto}", idLoja, idProdutoCriado))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idProduto").value(idProdutoCriado))
                .andExpect(jsonPath("$.nome").value("Hambúrguer Especial Artesanal"));

        // 3. Atualização de dados e preço do produto
        String payloadEdicao = """
                {
                  "nome": "Hambúrguer Especial Artesanal Duplo",
                  "descricao": "Dois blends de 180g com dobro de queijo",
                  "preco": 42.00,
                  "categoriasIds": [%d]
                }
                """.formatted(idCat1);

        mockMvc.perform(put("/api/catalogo/lojas/{idLoja}/produtos/{idProduto}", idLoja, idProdutoCriado)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadEdicao))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nome").value("Hambúrguer Especial Artesanal Duplo"))
                .andExpect(jsonPath("$.preco").value(42.00));

        // 4. RF07: Pausar venda de produto sem exclusão física (ativo = false)
        mockMvc.perform(patch("/api/catalogo/lojas/{idLoja}/produtos/{idProduto}/ativo", idLoja, idProdutoCriado)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ativo\": false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ativo").value(false));

        // Filtro de listagem por status ativo confirma produto inativo
        mockMvc.perform(get("/api/catalogo/lojas/{idLoja}/produtos?ativo=false", idLoja))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.idProduto == " + idProdutoCriado + ")]").exists());

        // Reativação
        mockMvc.perform(patch("/api/catalogo/lojas/{idLoja}/produtos/{idProduto}/ativo", idLoja, idProdutoCriado)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ativo\": true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ativo").value(true));

        // 5. Validação negativa: preço estritamente positivo (RN09 / RR13)
        String payloadPrecoInvalido = """
                {
                  "nome": "Produto Preço Zero",
                  "preco": 0.00,
                  "categoriasIds": [%d]
                }
                """.formatted(idCat1);

        mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/produtos", idLoja)
                        .header("X-User-Id", idDono)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadPrecoInvalido))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("Deve rejeitar associações com categorias de outra loja (RN07) e suportar IDs duplicados de categoria com sanitização")
    void deveValidarRN07EIntegridadeMultiLoja() throws Exception {
        var lojas = dsl.selectFrom(LOJA).limit(2).fetch();
        assertThat(lojas).hasSize(2);

        var loja1 = lojas.get(0);
        var loja2 = lojas.get(1);

        Long idLoja1 = loja1.getIdLoja();
        Long idDono1 = loja1.getIdLojista();

        // Busca categoria da loja 1 e categoria da loja 2
        Long idCatLoja1 = dsl.select(CATEGORIA.ID_CATEGORIA)
                .from(CATEGORIA)
                .where(CATEGORIA.ID_LOJA.eq(idLoja1))
                .limit(1)
                .fetchOneInto(Long.class);

        Long idCatLoja2 = dsl.select(CATEGORIA.ID_CATEGORIA)
                .from(CATEGORIA)
                .where(CATEGORIA.ID_LOJA.eq(loja2.getIdLoja()))
                .limit(1)
                .fetchOneInto(Long.class);

        // 1. RN07: Vincular produto da Loja 1 a categoria da Loja 2 deve falhar com 422
        String payloadCategoriaCruzada = """
                {
                  "nome": "Produto Cruzado Inválido",
                  "preco": 19.90,
                  "categoriasIds": [%d, %d]
                }
                """.formatted(idCatLoja1, idCatLoja2);

        mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/produtos", idLoja1)
                        .header("X-User-Id", idDono1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadCategoriaCruzada))
                .andExpect(status().isUnprocessableEntity());

        // 2. Sanitização de categorias repetidas no payload (ex.: [c1, c1]) -> não pode falhar com PK duplicate 23505
        String payloadCategoriasRepetidas = """
                {
                  "nome": "Produto Categorias Repetidas",
                  "preco": 25.00,
                  "categoriasIds": [%d, %d]
                }
                """.formatted(idCatLoja1, idCatLoja1);

        mockMvc.perform(post("/api/catalogo/lojas/{idLoja}/produtos", idLoja1)
                        .header("X-User-Id", idDono1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payloadCategoriasRepetidas))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.categorias", hasSize(1)));
    }
}
