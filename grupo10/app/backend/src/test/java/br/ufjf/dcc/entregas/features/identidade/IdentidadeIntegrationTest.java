/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Verifica: RF01, RN10, RN11, RR01, RR12, RR16, RR17, ADR-002 e ADR-003 pela API /api/identidade/pessoas
 */
package br.ufjf.dcc.entregas.features.identidade;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.jooq.DSLContext;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA_ENDERECO;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class IdentidadeIntegrationTest {

    // CPFs e CNPJs com dígitos verificadores válidos e fora da faixa da carga (02_carga.sql)
    private static final String CPF_A = "93541287691";
    private static final String CPF_B = "84621539728";
    private static final String CPF_C = "71359026452";
    private static final String CNPJ_VALIDO = "45678912000155";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private DSLContext dsl;

    // ------------------------------------------------------------------ criação

    @Test
    @DisplayName("RF01/ADR-003: cria pessoa com papéis sobrepostos (Cliente + Entregador), telefone e endereço atual")
    void deveCriarPerfilComPapeisSobrepostos() throws Exception {
        ObjectNode payload = perfilBase(CPF_A, "ana.teste@exemplo.com");
        payload.put("cliente", true);
        payload.put("entregador", true);
        payload.put("tipoVeiculo", "moto");

        JsonNode criado = lerJson(criar(payload).andExpect(status().isCreated()));

        assertThat(criado.get("cliente").asBoolean()).isTrue();
        assertThat(criado.get("entregador").asBoolean()).isTrue();
        assertThat(criado.get("lojista").asBoolean()).isFalse();
        assertThat(criado.get("tipoVeiculo").asText()).isEqualTo("moto");
        assertThat(criado.get("telefones")).hasSize(1);
        assertThat(criado.get("enderecos")).hasSize(1);
        assertThat(criado.get("enderecos").get(0).get("atual").asBoolean()).isTrue();

        long idPessoa = criado.get("idPessoa").asLong();
        mockMvc.perform(get("/api/identidade/pessoas/{id}", idPessoa))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cpf").value(CPF_A))
                .andExpect(jsonPath("$.email").value("ana.teste@exemplo.com"));

        // A listagem (vw_perfil_pessoa) encontra a pessoa pelo CPF
        mockMvc.perform(get("/api/identidade/pessoas").param("busca", CPF_A))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].idPessoa").value(idPessoa))
                .andExpect(jsonPath("$[0].cliente").value(true))
                .andExpect(jsonPath("$[0].entregador").value(true));
    }

    @Test
    @DisplayName("RR01: cria Lojista junto com a primeira loja na mesma transação")
    void deveCriarLojistaComPrimeiraLoja() throws Exception {
        ObjectNode payload = perfilBase(CPF_B, "lojista.teste@exemplo.com");
        payload.put("lojista", true);
        payload.set("enderecos", objectMapper.createArrayNode());
        payload.set("primeiraLoja", lojaInicial(CNPJ_VALIDO));

        JsonNode criado = lerJson(criar(payload).andExpect(status().isCreated()));

        assertThat(criado.get("lojista").asBoolean()).isTrue();
        assertThat(criado.get("lojas")).hasSize(1);
        assertThat(criado.get("lojas").get(0).get("cnpj").asText()).isEqualTo(CNPJ_VALIDO);
        assertThat(criado.get("restricoes").get("lojistaComLojas").asBoolean()).isTrue();
        assertThat(dsl.fetchExists(LOJA, LOJA.CNPJ.eq(CNPJ_VALIDO))).isTrue();
    }

    @Test
    @DisplayName("RN11: rejeita CPF e CNPJ com dígitos verificadores inválidos (422)")
    void deveRejeitarDocumentosComDigitoInvalido() throws Exception {
        ObjectNode cpfInvalido = perfilBase("93541287692", "cpf.invalido@exemplo.com");
        cpfInvalido.put("cliente", true);
        criar(cpfInvalido)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("RN11")));

        ObjectNode cnpjInvalido = perfilBase(CPF_C, "cnpj.invalido@exemplo.com");
        cnpjInvalido.put("lojista", true);
        cnpjInvalido.set("enderecos", objectMapper.createArrayNode());
        cnpjInvalido.set("primeiraLoja", lojaInicial("45678912000156"));
        criar(cnpjInvalido)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("CNPJ")));
    }

    @Test
    @DisplayName("RN10: rejeita CPF fora do formato de 11 dígitos (400) e CPF duplicado (409)")
    void deveRejeitarCpfMalFormadoEDuplicado() throws Exception {
        ObjectNode malFormado = perfilBase("1234567890", "formato@exemplo.com");
        malFormado.put("cliente", true);
        criar(malFormado).andExpect(status().isBadRequest());

        ObjectNode primeiro = perfilBase(CPF_A, "primeiro@exemplo.com");
        primeiro.put("cliente", true);
        criar(primeiro).andExpect(status().isCreated());

        ObjectNode duplicado = perfilBase(CPF_A, "segundo@exemplo.com");
        duplicado.put("cliente", true);
        criar(duplicado).andExpect(status().isConflict());
    }

    @Test
    @DisplayName("RR16/RR17/RR01: exige papel, telefone, endereço atual do Cliente, veículo do Entregador e loja do Lojista")
    void deveValidarCardinalidadesMinimas() throws Exception {
        ObjectNode semPapel = perfilBase(CPF_A, "sem.papel@exemplo.com");
        semPapel.set("enderecos", objectMapper.createArrayNode());
        criar(semPapel)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("RR16")));

        ObjectNode semTelefone = perfilBase(CPF_A, "sem.telefone@exemplo.com");
        semTelefone.put("cliente", true);
        semTelefone.set("telefones", objectMapper.createArrayNode());
        criar(semTelefone)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("RR17")));

        ObjectNode clienteSemAtual = perfilBase(CPF_A, "sem.atual@exemplo.com");
        clienteSemAtual.put("cliente", true);
        ((ObjectNode) clienteSemAtual.get("enderecos").get(0)).put("atual", false);
        criar(clienteSemAtual).andExpect(status().isUnprocessableEntity());

        ObjectNode entregadorSemVeiculo = perfilBase(CPF_A, "sem.veiculo@exemplo.com");
        entregadorSemVeiculo.put("entregador", true);
        entregadorSemVeiculo.set("enderecos", objectMapper.createArrayNode());
        criar(entregadorSemVeiculo).andExpect(status().isUnprocessableEntity());

        ObjectNode lojistaSemLoja = perfilBase(CPF_A, "sem.loja@exemplo.com");
        lojistaSemLoja.put("lojista", true);
        lojistaSemLoja.set("enderecos", objectMapper.createArrayNode());
        criar(lojistaSemLoja)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("RR01")));
    }

    // ------------------------------------------------------------------ endereços (ADR-002 / RR12)

    @Test
    @DisplayName("ADR-002: endereço físico é compartilhado e o complemento é isolado por morador")
    void deveCompartilharEnderecoEIsolarComplemento() throws Exception {
        ObjectNode moradorA = perfilBase(CPF_A, "morador.a@exemplo.com");
        moradorA.put("cliente", true);
        JsonNode perfilA = lerJson(criar(moradorA).andExpect(status().isCreated()));

        ObjectNode moradorB = perfilBase(CPF_B, "morador.b@exemplo.com");
        moradorB.put("cliente", true);
        ((ObjectNode) moradorB.get("enderecos").get(0)).put("complemento", "Apto 202");
        JsonNode perfilB = lerJson(criar(moradorB).andExpect(status().isCreated()));

        long idEnderecoA = perfilA.get("enderecos").get(0).get("idEndereco").asLong();
        long idEnderecoB = perfilB.get("enderecos").get(0).get("idEndereco").asLong();
        assertThat(idEnderecoB).isEqualTo(idEnderecoA);

        // Morador A edita apenas o próprio complemento
        ObjectNode edicaoA = paraRequest(perfilA);
        ((ObjectNode) edicaoA.get("enderecos").get(0)).put("complemento", "Apto 101");
        editar(perfilA.get("idPessoa").asLong(), edicaoA)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enderecos[0].complemento").value("Apto 101"));

        String complementoB = dsl.select(PESSOA_ENDERECO.COMPLEMENTO)
                .from(PESSOA_ENDERECO)
                .where(PESSOA_ENDERECO.ID_PESSOA.eq(perfilB.get("idPessoa").asLong()))
                .fetchOneInto(String.class);
        assertThat(complementoB).isEqualTo("Apto 202");
    }

    @Test
    @DisplayName("RF01: troca o endereço atual do Cliente e remove o vínculo antigo")
    void deveTrocarEnderecoAtualERemoverVinculoAntigo() throws Exception {
        ObjectNode payload = perfilBase(CPF_A, "mudanca@exemplo.com");
        payload.put("cliente", true);
        JsonNode perfil = lerJson(criar(payload).andExpect(status().isCreated()));

        ObjectNode edicao = paraRequest(perfil);
        ArrayNode enderecos = objectMapper.createArrayNode();
        enderecos.add(enderecoNovo("Rua Nova do Teste", "77", "36015000", true));
        edicao.set("enderecos", enderecos);

        editar(perfil.get("idPessoa").asLong(), edicao)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enderecos", hasSize(1)))
                .andExpect(jsonPath("$.enderecos[0].logradouro").value("Rua Nova do Teste"))
                .andExpect(jsonPath("$.enderecos[0].atual").value(true));
    }

    // ------------------------------------------------------------------ edição

    @Test
    @DisplayName("RF01: CPF é imutável na edição (400) e pessoa inexistente retorna 404")
    void deveManterCpfImutavel() throws Exception {
        ObjectNode payload = perfilBase(CPF_A, "imutavel@exemplo.com");
        payload.put("cliente", true);
        JsonNode perfil = lerJson(criar(payload).andExpect(status().isCreated()));

        ObjectNode edicao = paraRequest(perfil);
        edicao.put("cpf", CPF_B);
        editar(perfil.get("idPessoa").asLong(), edicao).andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/identidade/pessoas/{id}", 999_999_999L))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("RF01/RR01: impede remover papel de Cliente com pedidos e de Lojista com loja")
    void deveImpedirRemocaoDePapelComHistorico() throws Exception {
        Long idCliente = dsl.select(PEDIDO.ID_CLIENTE).from(PEDIDO).limit(1).fetchOneInto(Long.class);
        assertThat(idCliente).isNotNull();
        JsonNode perfilCliente = lerJson(mockMvc.perform(get("/api/identidade/pessoas/{id}", idCliente))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.restricoes.clienteComPedidos").value(true)));

        ObjectNode semCliente = paraRequest(perfilCliente);
        semCliente.put("cliente", false);
        semCliente.put("lojista", true);
        semCliente.set("primeiraLoja", lojaInicial(CNPJ_VALIDO));
        desmarcarEnderecoAtual(semCliente);
        editar(idCliente, semCliente).andExpect(status().isUnprocessableEntity());

        Long idLojista = dsl.select(LOJA.ID_LOJISTA).from(LOJA).limit(1).fetchOneInto(Long.class);
        JsonNode perfilLojista = lerJson(mockMvc.perform(get("/api/identidade/pessoas/{id}", idLojista))
                .andExpect(status().isOk()));

        ObjectNode semLojista = paraRequest(perfilLojista);
        semLojista.put("lojista", false);
        semLojista.put("entregador", true);
        semLojista.put("tipoVeiculo", "bicicleta");
        editar(idLojista, semLojista)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("RR01")));
    }

    // ------------------------------------------------------------------ apoio

    private ResultActions criar(ObjectNode payload) throws Exception {
        return mockMvc.perform(post("/api/identidade/pessoas")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(payload)));
    }

    private ResultActions editar(long idPessoa, ObjectNode payload) throws Exception {
        return mockMvc.perform(put("/api/identidade/pessoas/{id}", idPessoa)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(payload)));
    }

    private JsonNode lerJson(ResultActions resultado) throws Exception {
        return objectMapper.readTree(resultado.andReturn().getResponse().getContentAsString());
    }

    /** Pessoa sem papéis, com um telefone e um endereço marcado como atual. */
    private ObjectNode perfilBase(String cpf, String email) {
        ObjectNode payload = objectMapper.createObjectNode();
        payload.put("nome", "Pessoa de Teste");
        payload.put("cpf", cpf);
        payload.put("email", email);
        payload.put("cliente", false);
        payload.put("lojista", false);
        payload.put("entregador", false);

        ArrayNode telefones = objectMapper.createArrayNode();
        ObjectNode telefone = objectMapper.createObjectNode();
        telefone.put("numero", "32999990000");
        telefone.put("tipo", "celular");
        telefones.add(telefone);
        payload.set("telefones", telefones);

        ArrayNode enderecos = objectMapper.createArrayNode();
        enderecos.add(enderecoNovo("Rua do Teste Integrado", "100", "36010000", true));
        payload.set("enderecos", enderecos);
        return payload;
    }

    private ObjectNode enderecoNovo(String logradouro, String numero, String cep, boolean atual) {
        ObjectNode endereco = objectMapper.createObjectNode();
        endereco.put("logradouro", logradouro);
        endereco.put("numero", numero);
        endereco.put("bairro", "Centro");
        endereco.put("cep", cep);
        endereco.put("cidade", "Juiz de Fora");
        endereco.put("estado", "MG");
        endereco.put("apelido", "Casa");
        endereco.put("atual", atual);
        return endereco;
    }

    private ObjectNode lojaInicial(String cnpj) {
        ObjectNode loja = objectMapper.createObjectNode();
        loja.put("nome", "Loja de Teste");
        loja.put("cnpj", cnpj);
        loja.put("telefone", "3232100000");
        loja.put("logradouro", "Avenida da Loja de Teste");
        loja.put("numero", "500");
        loja.put("bairro", "Centro");
        loja.put("cep", "36016000");
        loja.put("cidade", "Juiz de Fora");
        loja.put("estado", "MG");
        loja.put("tempoEntregaEstimado", 30);
        loja.put("taxaEntrega", 5.50);
        loja.put("statusFuncionamento", "aberta");
        return loja;
    }

    /** Converte a resposta de GET/POST no corpo de edição (PUT), como faz a tela. */
    private ObjectNode paraRequest(JsonNode perfil) {
        ObjectNode payload = objectMapper.createObjectNode();
        payload.put("nome", perfil.get("nome").asText());
        payload.put("cpf", perfil.get("cpf").asText());
        payload.put("email", perfil.get("email").asText());
        payload.put("cliente", perfil.get("cliente").asBoolean());
        payload.put("lojista", perfil.get("lojista").asBoolean());
        payload.put("entregador", perfil.get("entregador").asBoolean());
        if (!perfil.get("tipoVeiculo").isNull()) {
            payload.put("tipoVeiculo", perfil.get("tipoVeiculo").asText());
        }

        ArrayNode telefones = objectMapper.createArrayNode();
        perfil.get("telefones").forEach(t -> {
            ObjectNode telefone = objectMapper.createObjectNode();
            telefone.put("numero", t.get("numero").asText());
            telefone.put("tipo", t.get("tipo").asText());
            telefones.add(telefone);
        });
        payload.set("telefones", telefones);

        ArrayNode enderecos = objectMapper.createArrayNode();
        perfil.get("enderecos").forEach(e -> {
            ObjectNode endereco = objectMapper.createObjectNode();
            endereco.put("idEndereco", e.get("idEndereco").asLong());
            endereco.set("apelido", e.get("apelido"));
            endereco.set("complemento", e.get("complemento"));
            endereco.set("referencia", e.get("referencia"));
            endereco.put("atual", e.get("atual").asBoolean());
            enderecos.add(endereco);
        });
        payload.set("enderecos", enderecos);
        return payload;
    }

    private void desmarcarEnderecoAtual(ObjectNode payload) {
        payload.get("enderecos").forEach(e -> ((ObjectNode) e).put("atual", false));
    }
}
