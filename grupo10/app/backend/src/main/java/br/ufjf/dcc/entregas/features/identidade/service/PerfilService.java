/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Implementa: RF01 (gerenciar dados pessoais, papéis, telefones, endereços e primeira loja do Lojista)
 * Atende: RN10, RN11, RR01, RR03, RR12, RR14, RR16, RR17
 *
 * As cardinalidades mínimas RR01 (lojista com loja), RR16 (ao menos um papel) e RR17 (ao menos um
 * telefone) são verificadas aqui, na camada de aplicação, dentro de uma única transação.
 */
package br.ufjf.dcc.entregas.features.identidade.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.ConflitoNegocioException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RegraNegocioException;
import br.ufjf.dcc.entregas.core.exception.RequisicaoInvalidaException;
import br.ufjf.dcc.entregas.core.security.AdminAccessService;
import br.ufjf.dcc.entregas.features.identidade.dto.PerfilRequest;
import br.ufjf.dcc.entregas.features.identidade.dto.PerfilResponse;
import br.ufjf.dcc.entregas.features.identidade.dto.PessoaResumoResponse;
import br.ufjf.dcc.entregas.features.identidade.repository.PerfilRepository;
import br.ufjf.dcc.entregas.features.identidade.repository.PerfilRepository.PapeisPessoa;
import br.ufjf.dcc.entregas.features.identidade.repository.PerfilRepository.TelefoneNovo;
import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import br.ufjf.dcc.entregas.jooq.enums.TipoTelefone;
import br.ufjf.dcc.entregas.jooq.enums.TipoVeiculo;
import br.ufjf.dcc.entregas.jooq.tables.records.PessoaRecord;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class PerfilService {

    private final PerfilRepository repository;
    private final AdminAccessService adminAccessService;

    public PerfilService(PerfilRepository repository, AdminAccessService adminAccessService) {
        this.repository = repository;
        this.adminAccessService = adminAccessService;
    }

    // ================================================================== consultas

    public List<PessoaResumoResponse> listarPessoas(Long idUsuarioAutenticado, String busca) {
        adminAccessService.exigirAdmin(idUsuarioAutenticado);
        return repository.listarPessoas(busca);
    }

    private void validarProprietario(Long idUsuarioAutenticado, Long idPessoa) {
        adminAccessService.exigirIdentificacao(idUsuarioAutenticado);
        if (!idUsuarioAutenticado.equals(idPessoa) && !adminAccessService.isAdmin(idUsuarioAutenticado)) {
            throw new AcessoNegadoException("Você só tem permissão para visualizar ou editar o seu próprio perfil.");
        }
    }

    public PerfilResponse buscarPerfilAutorizado(Long idUsuarioAutenticado, Long idPessoa) {
        validarProprietario(idUsuarioAutenticado, idPessoa);
        return buscarPerfil(idPessoa);
    }

    public PerfilResponse buscarPerfil(Long idPessoa) {
        PessoaRecord pessoa = repository.buscarPessoa(idPessoa)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pessoa " + idPessoa + " não encontrada."));
        PapeisPessoa papeis = repository.buscarPapeis(idPessoa);

        List<PerfilResponse.Loja> lojas = papeis.lojista() ? repository.listarLojas(idPessoa) : List.of();
        var restricoes = new PerfilResponse.Restricoes(
                papeis.cliente() && repository.clientePossuiPedidos(idPessoa),
                papeis.lojista() && !lojas.isEmpty(),
                papeis.entregador() && repository.entregadorPossuiRotas(idPessoa)
        );

        return new PerfilResponse(
                pessoa.getIdPessoa(),
                pessoa.getNome(),
                pessoa.getCpf(),
                pessoa.getEmail(),
                papeis.cliente(),
                papeis.lojista(),
                papeis.entregador(),
                papeis.tipoVeiculo() != null ? papeis.tipoVeiculo().getLiteral() : null,
                repository.listarTelefones(idPessoa),
                repository.listarEnderecos(idPessoa, papeis.idEnderecoAtual()),
                lojas,
                restricoes
        );
    }

    // ================================================================== criação

    @Transactional
    public PerfilResponse criarPerfil(PerfilRequest request) {
        String cpf = request.cpf();
        if (cpf == null || cpf.isBlank()) {
            throw new RequisicaoInvalidaException("CPF é obrigatório no cadastro.");
        }
        if (!DocumentoValidator.cpfValido(cpf)) {
            throw new RegraNegocioException("[RN11] CPF inválido: os dígitos verificadores não conferem.");
        }
        String nome = request.nome().trim();
        String email = normalizarEmail(request.email());

        validarRegrasComuns(request);
        TipoVeiculo tipoVeiculo = request.entregador() ? converterVeiculo(request.tipoVeiculo()) : null;
        if (request.lojista()) {
            validarPrimeiraLoja(request.primeiraLoja());
        }

        if (repository.existeCpf(cpf)) {
            throw new ConflitoNegocioException("Já existe uma pessoa cadastrada com este CPF.");
        }
        if (repository.existeEmailEmOutraPessoa(email, null)) {
            throw new ConflitoNegocioException("Já existe uma pessoa cadastrada com este e-mail.");
        }

        Long idPessoa = repository.inserirPessoa(nome, cpf, email);
        repository.substituirTelefones(idPessoa, converterTelefones(request.telefones()));

        Long idEnderecoAtual = null;
        Set<Long> vinculosCriados = new HashSet<>();
        for (PerfilRequest.Endereco endereco : request.enderecos()) {
            if (endereco.idEndereco() != null) {
                throw new RegraNegocioException("No cadastro, todos os endereços devem ser informados por completo.");
            }
            Long idEndereco = criarOuReaproveitarEndereco(endereco);
            if (!vinculosCriados.add(idEndereco)) {
                throw new RegraNegocioException("O mesmo endereço foi informado mais de uma vez.");
            }
            repository.vincularEndereco(idPessoa, idEndereco,
                    textoOpcional(endereco.apelido()),
                    textoOpcional(endereco.complemento()),
                    textoOpcional(endereco.referencia()));
            if (endereco.atual()) {
                idEnderecoAtual = idEndereco;
            }
        }

        if (request.cliente()) {
            repository.inserirCliente(idPessoa);
            repository.atualizarEnderecoAtual(idPessoa, idEnderecoAtual);
        }
        if (request.entregador()) {
            repository.inserirEntregador(idPessoa, tipoVeiculo);
        }
        if (request.lojista()) {
            repository.inserirLojista(idPessoa);
            criarPrimeiraLoja(idPessoa, request.primeiraLoja());
        }

        return buscarPerfil(idPessoa);
    }

    // ================================================================== edição

    @Transactional
    public PerfilResponse atualizarPerfil(Long idUsuarioAutenticado, Long idPessoa, PerfilRequest request) {
        validarProprietario(idUsuarioAutenticado, idPessoa);
        PessoaRecord pessoa = repository.buscarPessoa(idPessoa)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pessoa " + idPessoa + " não encontrada."));
        if (request.cpf() != null && !request.cpf().isBlank() && !request.cpf().equals(pessoa.getCpf())) {
            throw new RequisicaoInvalidaException("O CPF não pode ser alterado após o cadastro.");
        }

        String nome = request.nome().trim();
        String email = normalizarEmail(request.email());

        PapeisPessoa papeis = repository.buscarPapeis(idPessoa);
        validarRemocaoDePapeis(idPessoa, papeis, request);
        validarRegrasComuns(request);

        TipoVeiculo tipoVeiculo = request.entregador() ? converterVeiculo(request.tipoVeiculo()) : null;
        boolean novoLojista = request.lojista() && !papeis.lojista();
        if (novoLojista) {
            validarPrimeiraLoja(request.primeiraLoja());
        }

        if (repository.existeEmailEmOutraPessoa(email, idPessoa)) {
            throw new ConflitoNegocioException("Já existe outra pessoa cadastrada com este e-mail.");
        }

        Set<Long> vinculosAtuais = repository.listarIdsEnderecosVinculados(idPessoa);
        for (PerfilRequest.Endereco endereco : request.enderecos()) {
            if (endereco.idEndereco() != null && !vinculosAtuais.contains(endereco.idEndereco())) {
                throw new RegraNegocioException("O endereço " + endereco.idEndereco() + " não está vinculado a esta pessoa.");
            }
        }

        // 1. Dados pessoais e telefones
        repository.atualizarPessoa(idPessoa, nome, email);
        repository.substituirTelefones(idPessoa, converterTelefones(request.telefones()));

        // 2. Vínculos de endereço: edita os existentes e cria os novos
        Set<Long> vinculosMantidos = new HashSet<>();
        Long idEnderecoAtual = null;
        for (PerfilRequest.Endereco endereco : request.enderecos()) {
            Long idEndereco = endereco.idEndereco();
            if (idEndereco == null) {
                idEndereco = criarOuReaproveitarEndereco(endereco);
                if (!vinculosAtuais.contains(idEndereco) && !vinculosMantidos.contains(idEndereco)) {
                    repository.vincularEndereco(idPessoa, idEndereco,
                            textoOpcional(endereco.apelido()),
                            textoOpcional(endereco.complemento()),
                            textoOpcional(endereco.referencia()));
                } else if (vinculosMantidos.contains(idEndereco)) {
                    throw new RegraNegocioException("O mesmo endereço foi informado mais de uma vez.");
                } else {
                    repository.atualizarVinculoEndereco(idPessoa, idEndereco,
                            textoOpcional(endereco.apelido()),
                            textoOpcional(endereco.complemento()),
                            textoOpcional(endereco.referencia()));
                }
            } else {
                if (vinculosMantidos.contains(idEndereco)) {
                    throw new RegraNegocioException("O mesmo endereço foi informado mais de uma vez.");
                }
                repository.atualizarVinculoEndereco(idPessoa, idEndereco,
                        textoOpcional(endereco.apelido()),
                        textoOpcional(endereco.complemento()),
                        textoOpcional(endereco.referencia()));
            }
            vinculosMantidos.add(idEndereco);
            if (endereco.atual()) {
                idEnderecoAtual = idEndereco;
            }
        }

        // 3. Papel Cliente (o endereço atual é ajustado antes de remover vínculos antigos)
        if (request.cliente()) {
            if (!papeis.cliente()) {
                repository.inserirCliente(idPessoa);
            }
            repository.atualizarEnderecoAtual(idPessoa, idEnderecoAtual);
        } else if (papeis.cliente()) {
            repository.removerCliente(idPessoa);
        }

        // 4. Remove os vínculos de endereço que saíram da lista
        for (Long idEndereco : vinculosAtuais) {
            if (!vinculosMantidos.contains(idEndereco)) {
                repository.removerVinculoEndereco(idPessoa, idEndereco);
            }
        }

        // 5. Papel Entregador
        if (request.entregador()) {
            if (papeis.entregador()) {
                repository.atualizarVeiculo(idPessoa, tipoVeiculo);
            } else {
                repository.inserirEntregador(idPessoa, tipoVeiculo);
            }
        } else if (papeis.entregador()) {
            repository.removerEntregador(idPessoa);
        }

        // 6. Papel Lojista (RR01: a primeira loja nasce na mesma transação)
        if (novoLojista) {
            repository.inserirLojista(idPessoa);
            criarPrimeiraLoja(idPessoa, request.primeiraLoja());
        } else if (!request.lojista() && papeis.lojista()) {
            repository.removerLojista(idPessoa);
        }

        return buscarPerfil(idPessoa);
    }

    // ================================================================== regras

    /** Regras que valem tanto para criação quanto para edição. */
    private void validarRegrasComuns(PerfilRequest request) {
        if (!request.cliente() && !request.lojista() && !request.entregador()) {
            throw new RegraNegocioException("[RR16] A pessoa deve exercer ao menos um papel: Cliente, Lojista ou Entregador.");
        }

        if (request.telefones().isEmpty()) {
            throw new RegraNegocioException("[RR17] Informe ao menos um telefone.");
        }
        Set<String> numeros = new HashSet<>();
        for (PerfilRequest.Telefone telefone : request.telefones()) {
            if (!numeros.add(telefone.numero())) {
                throw new RegraNegocioException("O telefone " + telefone.numero() + " foi informado mais de uma vez.");
            }
            converterTipoTelefone(telefone.tipo());
        }

        for (PerfilRequest.Endereco endereco : request.enderecos()) {
            if (endereco.idEndereco() == null) {
                validarEnderecoCompleto(endereco);
            }
        }

        long marcadosComoAtual = request.enderecos().stream().filter(PerfilRequest.Endereco::atual).count();
        if (request.cliente()) {
            if (request.enderecos().isEmpty()) {
                throw new RegraNegocioException("Todo Cliente deve possuir ao menos um endereço cadastrado.");
            }
            if (marcadosComoAtual != 1) {
                throw new RegraNegocioException("Selecione exatamente um endereço atual para o Cliente.");
            }
        } else if (marcadosComoAtual > 0) {
            throw new RegraNegocioException("Somente um Cliente pode ter endereço atual.");
        }
    }

    private void validarRemocaoDePapeis(Long idPessoa, PapeisPessoa papeis, PerfilRequest request) {
        if (papeis.cliente() && !request.cliente() && repository.clientePossuiPedidos(idPessoa)) {
            throw new RegraNegocioException("Não é possível remover o papel de Cliente: a pessoa possui pedidos registrados.");
        }
        if (papeis.lojista() && !request.lojista() && repository.lojistaPossuiLojas(idPessoa)) {
            throw new RegraNegocioException("[RR01] Não é possível remover o papel de Lojista: a pessoa é responsável por loja(s) cadastrada(s).");
        }
        if (papeis.entregador() && !request.entregador() && repository.entregadorPossuiRotas(idPessoa)) {
            throw new RegraNegocioException("Não é possível remover o papel de Entregador: a pessoa possui rotas registradas.");
        }
    }

    private void validarEnderecoCompleto(PerfilRequest.Endereco endereco) {
        if (vazio(endereco.logradouro()) || vazio(endereco.numero()) || vazio(endereco.bairro())
                || vazio(endereco.cep()) || vazio(endereco.cidade()) || vazio(endereco.estado())) {
            throw new RegraNegocioException("Endereço novo incompleto: informe logradouro, número, bairro, CEP, cidade e UF.");
        }
    }

    private void validarPrimeiraLoja(PerfilRequest.LojaInicial loja) {
        if (loja == null) {
            throw new RegraNegocioException("[RR01] Todo Lojista deve possuir ao menos uma loja: preencha os dados da primeira loja.");
        }
        if (!DocumentoValidator.cnpjValido(loja.cnpj())) {
            throw new RegraNegocioException("[RN11] CNPJ inválido: os dígitos verificadores não conferem.");
        }
        converterStatusFuncionamento(loja.statusFuncionamento());
        if (repository.existeCnpj(loja.cnpj())) {
            throw new ConflitoNegocioException("Já existe uma loja cadastrada com este CNPJ.");
        }
    }

    private void criarPrimeiraLoja(Long idLojista, PerfilRequest.LojaInicial loja) {
        Long idEndereco = repository.buscarOuCriarEndereco(
                loja.logradouro().trim(), loja.numero().trim(), loja.bairro().trim(),
                loja.cep(), loja.cidade().trim(), loja.estado());
        repository.inserirLoja(
                idLojista,
                idEndereco,
                textoOpcional(loja.complementoEndereco()),
                loja.cnpj(),
                loja.nome().trim(),
                loja.telefone(),
                converterStatusFuncionamento(loja.statusFuncionamento()),
                loja.tempoEntregaEstimado(),
                loja.taxaEntrega()
        );
    }

    private Long criarOuReaproveitarEndereco(PerfilRequest.Endereco endereco) {
        return repository.buscarOuCriarEndereco(
                endereco.logradouro().trim(),
                endereco.numero().trim(),
                endereco.bairro().trim(),
                endereco.cep(),
                endereco.cidade().trim(),
                endereco.estado());
    }

    // ================================================================== conversões

    private List<TelefoneNovo> converterTelefones(List<PerfilRequest.Telefone> telefones) {
        Map<String, TelefoneNovo> unicos = new LinkedHashMap<>();
        for (PerfilRequest.Telefone telefone : telefones) {
            unicos.put(telefone.numero(), new TelefoneNovo(telefone.numero(), converterTipoTelefone(telefone.tipo())));
        }
        return new ArrayList<>(unicos.values());
    }

    private TipoTelefone converterTipoTelefone(String tipo) {
        TipoTelefone convertido = tipo == null ? null : TipoTelefone.lookupLiteral(tipo.trim().toLowerCase(Locale.ROOT));
        if (convertido == null) {
            throw new RequisicaoInvalidaException("Tipo de telefone inválido: use celular, fixo ou comercial.");
        }
        return convertido;
    }

    private TipoVeiculo converterVeiculo(String tipo) {
        if (tipo == null || tipo.isBlank()) {
            throw new RegraNegocioException("Informe o tipo de veículo do Entregador.");
        }
        TipoVeiculo convertido = TipoVeiculo.lookupLiteral(tipo.trim().toLowerCase(Locale.ROOT));
        if (convertido == null) {
            throw new RequisicaoInvalidaException("Tipo de veículo inválido: use moto, bicicleta ou carro.");
        }
        return convertido;
    }

    private StatusFuncionamento converterStatusFuncionamento(String status) {
        StatusFuncionamento convertido = status == null ? null
                : StatusFuncionamento.lookupLiteral(status.trim().toLowerCase(Locale.ROOT));
        if (convertido == null) {
            throw new RequisicaoInvalidaException("Status de funcionamento inválido: use aberta ou fechada.");
        }
        return convertido;
    }

    private static String normalizarEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private static String textoOpcional(String valor) {
        if (valor == null) {
            return null;
        }
        String limpo = valor.trim();
        return limpo.isEmpty() ? null : limpo;
    }

    private static boolean vazio(String valor) {
        return valor == null || valor.isBlank();
    }
}
