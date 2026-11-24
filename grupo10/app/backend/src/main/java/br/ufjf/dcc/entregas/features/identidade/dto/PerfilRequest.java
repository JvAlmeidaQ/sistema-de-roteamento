/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Implementa: RF01 (criação e edição do perfil de uma Pessoa)
 * Atende: RN10/RR14 (formato de CPF, CNPJ, CEP, UF e telefone), RR16 (papéis sobrepostos)
 */
package br.ufjf.dcc.entregas.features.identidade.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.List;

/**
 * Corpo usado tanto na criação (POST) quanto na edição (PUT) do perfil.
 * Na edição o CPF é imutável: se enviado, precisa ser igual ao já cadastrado.
 */
public record PerfilRequest(
        @NotBlank(message = "Nome é obrigatório.")
        @Size(max = 120, message = "Nome não pode exceder 120 caracteres.")
        String nome,

        @Pattern(regexp = "\\d{11}", message = "CPF deve conter exatamente 11 dígitos numéricos.")
        String cpf,

        @NotBlank(message = "E-mail é obrigatório.")
        @Email(message = "E-mail inválido.")
        @Size(max = 255, message = "E-mail não pode exceder 255 caracteres.")
        String email,

        boolean cliente,
        boolean lojista,
        boolean entregador,

        /** Obrigatório quando {@code entregador = true}: moto, bicicleta ou carro. */
        String tipoVeiculo,

        @NotNull(message = "Lista de telefones é obrigatória.")
        @Size(max = 20, message = "É permitido cadastrar no máximo 20 telefones.")
        List<@Valid @NotNull Telefone> telefones,

        @NotNull(message = "Lista de endereços é obrigatória.")
        @Size(max = 20, message = "É permitido cadastrar no máximo 20 endereços.")
        List<@Valid @NotNull Endereco> enderecos,

        /** Obrigatória quando a pessoa passa a ser Lojista e ainda não possui loja (RR01). */
        @Valid
        LojaInicial primeiraLoja
) {

    public record Telefone(
            @NotBlank(message = "Número do telefone é obrigatório.")
            @Pattern(regexp = "\\d{10,11}", message = "Telefone deve conter 10 ou 11 dígitos numéricos (DDD + número).")
            String numero,

            @NotBlank(message = "Tipo do telefone é obrigatório.")
            String tipo
    ) {}

    /**
     * Vínculo Pessoa ↔ Endereço. Com {@code idEndereco} preenchido, referencia um vínculo já existente
     * e apenas apelido/complemento/referência são considerados (RR12: Endereco é imutável).
     * Sem {@code idEndereco}, os dados de localização são obrigatórios e o endereço é reaproveitado
     * se já existir com o mesmo logradouro, número e CEP (RR12).
     */
    public record Endereco(
            @Positive(message = "Identificador de endereço deve ser positivo.")
            Long idEndereco,

            @Size(max = 150, message = "Logradouro não pode exceder 150 caracteres.")
            String logradouro,

            @Size(max = 10, message = "Número não pode exceder 10 caracteres.")
            String numero,

            @Size(max = 80, message = "Bairro não pode exceder 80 caracteres.")
            String bairro,

            @Pattern(regexp = "\\d{8}", message = "CEP deve conter exatamente 8 dígitos numéricos.")
            String cep,

            @Size(max = 80, message = "Cidade não pode exceder 80 caracteres.")
            String cidade,

            @Pattern(regexp = "[A-Z]{2}", message = "UF deve conter 2 letras maiúsculas.")
            String estado,

            @Size(max = 40, message = "Apelido não pode exceder 40 caracteres.")
            String apelido,

            @Size(max = 80, message = "Complemento não pode exceder 80 caracteres.")
            String complemento,

            @Size(max = 150, message = "Referência não pode exceder 150 caracteres.")
            String referencia,

            /** Marca o endereço atual do Cliente (exatamente um quando a pessoa é Cliente). */
            boolean atual
    ) {}

    public record LojaInicial(
            @NotBlank(message = "Nome da loja é obrigatório.")
            @Size(max = 120, message = "Nome da loja não pode exceder 120 caracteres.")
            String nome,

            @NotBlank(message = "CNPJ é obrigatório.")
            @Pattern(regexp = "\\d{14}", message = "CNPJ deve conter exatamente 14 dígitos numéricos.")
            String cnpj,

            @NotBlank(message = "Telefone da loja é obrigatório.")
            @Pattern(regexp = "\\d{10,11}", message = "Telefone da loja deve conter 10 ou 11 dígitos numéricos.")
            String telefone,

            @NotBlank(message = "Logradouro da loja é obrigatório.")
            @Size(max = 150, message = "Logradouro não pode exceder 150 caracteres.")
            String logradouro,

            @NotBlank(message = "Número do endereço da loja é obrigatório.")
            @Size(max = 10, message = "Número não pode exceder 10 caracteres.")
            String numero,

            @NotBlank(message = "Bairro da loja é obrigatório.")
            @Size(max = 80, message = "Bairro não pode exceder 80 caracteres.")
            String bairro,

            @NotBlank(message = "CEP da loja é obrigatório.")
            @Pattern(regexp = "\\d{8}", message = "CEP deve conter exatamente 8 dígitos numéricos.")
            String cep,

            @NotBlank(message = "Cidade da loja é obrigatória.")
            @Size(max = 80, message = "Cidade não pode exceder 80 caracteres.")
            String cidade,

            @NotBlank(message = "UF da loja é obrigatória.")
            @Pattern(regexp = "[A-Z]{2}", message = "UF deve conter 2 letras maiúsculas.")
            String estado,

            @Size(max = 80, message = "Complemento não pode exceder 80 caracteres.")
            String complementoEndereco,

            @NotNull(message = "Tempo de entrega estimado é obrigatório.")
            @Positive(message = "Tempo de entrega estimado deve ser maior que zero.")
            Integer tempoEntregaEstimado,

            @NotNull(message = "Taxa de entrega é obrigatória.")
            @PositiveOrZero(message = "Taxa de entrega não pode ser negativa.")
            @Digits(integer = 10, fraction = 2, message = "Taxa de entrega deve ter no máximo 2 casas decimais.")
            BigDecimal taxaEntrega,

            @NotBlank(message = "Status de funcionamento inicial é obrigatório.")
            String statusFuncionamento
    ) {}
}
