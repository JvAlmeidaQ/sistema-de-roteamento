/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Atende: RN11 / RR14 (dígitos verificadores de CPF e CNPJ, validados na aplicação)
 */
package br.ufjf.dcc.entregas.features.identidade.service;

public final class DocumentoValidator {

    private DocumentoValidator() {
    }

    /** CPF com 11 dígitos numéricos e dígitos verificadores válidos (RN11). */
    public static boolean cpfValido(String cpf) {
        if (cpf == null || !cpf.matches("\\d{11}") || todosDigitosIguais(cpf)) {
            return false;
        }
        int dv1 = calcularDigitoCpf(cpf, 9);
        int dv2 = calcularDigitoCpf(cpf, 10);
        return dv1 == digito(cpf, 9) && dv2 == digito(cpf, 10);
    }

    /** CNPJ com 14 dígitos numéricos e dígitos verificadores válidos (RN11). */
    public static boolean cnpjValido(String cnpj) {
        if (cnpj == null || !cnpj.matches("\\d{14}") || todosDigitosIguais(cnpj)) {
            return false;
        }
        int[] pesos1 = {5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2};
        int[] pesos2 = {6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2};
        int dv1 = calcularDigitoCnpj(cnpj, pesos1);
        int dv2 = calcularDigitoCnpj(cnpj, pesos2);
        return dv1 == digito(cnpj, 12) && dv2 == digito(cnpj, 13);
    }

    private static int calcularDigitoCpf(String cpf, int quantidade) {
        int soma = 0;
        int peso = quantidade + 1;
        for (int i = 0; i < quantidade; i++) {
            soma += digito(cpf, i) * peso--;
        }
        int resto = (soma * 10) % 11;
        return resto == 10 ? 0 : resto;
    }

    private static int calcularDigitoCnpj(String cnpj, int[] pesos) {
        int soma = 0;
        for (int i = 0; i < pesos.length; i++) {
            soma += digito(cnpj, i) * pesos[i];
        }
        int resto = soma % 11;
        return resto < 2 ? 0 : 11 - resto;
    }

    private static int digito(String valor, int posicao) {
        return valor.charAt(posicao) - '0';
    }

    private static boolean todosDigitosIguais(String valor) {
        return valor.chars().distinct().count() == 1;
    }
}
