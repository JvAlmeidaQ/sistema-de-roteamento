/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 * Subdomínio: Identidade e Contato — máscaras e validação de documentos (RN10, RN11)
 */

export const soDigitos = (valor: string) => valor.replace(/\D/g, '')

function aplicarMascara(valor: string, padrao: string) {
  const digitos = soDigitos(valor)
  let resultado = ''
  let i = 0
  for (const caractere of padrao) {
    if (i >= digitos.length) break
    if (caractere === '#') {
      resultado += digitos[i++]
    } else {
      resultado += caractere
    }
  }
  return resultado
}

export const mascaraCpf = (valor: string) => aplicarMascara(valor, '###.###.###-##')
export const mascaraCnpj = (valor: string) => aplicarMascara(valor, '##.###.###/####-##')
export const mascaraCep = (valor: string) => aplicarMascara(valor, '#####-###')

export function mascaraTelefone(valor: string) {
  const digitos = soDigitos(valor).slice(0, 11)
  return digitos.length <= 10
    ? aplicarMascara(digitos, '(##) ####-####')
    : aplicarMascara(digitos, '(##) #####-####')
}

/** RN11: dígitos verificadores de CPF (mesmo algoritmo do DocumentoValidator.java). */
export function cpfValido(valor: string) {
  const cpf = soDigitos(valor)
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false
  const calcular = (quantidade: number) => {
    let soma = 0
    for (let i = 0; i < quantidade; i++) soma += Number(cpf[i]) * (quantidade + 1 - i)
    const resto = (soma * 10) % 11
    return resto === 10 ? 0 : resto
  }
  return calcular(9) === Number(cpf[9]) && calcular(10) === Number(cpf[10])
}

/** RN11: dígitos verificadores de CNPJ (mesmo algoritmo do DocumentoValidator.java). */
export function cnpjValido(valor: string) {
  const cnpj = soDigitos(valor)
  if (cnpj.length !== 14 || /^(\d)\1{13}$/.test(cnpj)) return false
  const calcular = (pesos: number[]) => {
    const soma = pesos.reduce((acc, peso, i) => acc + Number(cnpj[i]) * peso, 0)
    const resto = soma % 11
    return resto < 2 ? 0 : 11 - resto
  }
  const dv1 = calcular([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
  const dv2 = calcular([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
  return dv1 === Number(cnpj[12]) && dv2 === Number(cnpj[13])
}

export const ROTULO_VEICULO: Record<string, string> = {
  moto: 'Moto',
  bicicleta: 'Bicicleta',
  carro: 'Carro',
}

export const ROTULO_TELEFONE: Record<string, string> = {
  celular: 'Celular',
  fixo: 'Fixo',
  comercial: 'Comercial',
}
