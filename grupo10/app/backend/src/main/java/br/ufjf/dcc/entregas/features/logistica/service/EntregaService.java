/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística
 */
package br.ufjf.dcc.entregas.features.logistica.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.ConflitoNegocioException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RegraNegocioException;
import br.ufjf.dcc.entregas.features.logistica.dto.EntregadorSessaoResponse;
import br.ufjf.dcc.entregas.features.logistica.dto.PainelEntregadorResponse;
import br.ufjf.dcc.entregas.features.logistica.dto.PainelEntregadorResponse.Pagina;
import br.ufjf.dcc.entregas.features.logistica.dto.PainelEntregadorResponse.RotaAtual;
import br.ufjf.dcc.entregas.features.logistica.repository.EntregaRepository;
import br.ufjf.dcc.entregas.jooq.enums.StatusEntrega;
import br.ufjf.dcc.entregas.jooq.tables.records.EntregaRecord;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class EntregaService {

    private static final int TAMANHO_PAGINA = 10;

    private final EntregaRepository entregaRepository;

    public EntregaService(EntregaRepository entregaRepository) {
        this.entregaRepository = entregaRepository;
    }

    @Transactional(readOnly = true)
    public List<EntregadorSessaoResponse> listarEntregadoresSessao() {
        return entregaRepository.listarEntregadoresSessao();
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public PainelEntregadorResponse consultarPainel(long idEntregador, int paginaDisponiveis, int paginaEncerradas) {
        if (!entregaRepository.entregadorExiste(idEntregador)) {
            throw new AcessoNegadoException("O painel de Logística é exclusivo de entregadores.");
        }

        RotaAtual rotaAtual = entregaRepository.buscarRotaAberta(idEntregador)
                .map(rota -> new RotaAtual(
                        rota.getIdRota(), rota.getCriadaEm(), rota.getTotalEntregas().intValue(),
                        rota.getVagas().intValue(), rota.getEntregasAtivas().intValue(),
                        rota.getEntregasAtrasadas().intValue(),
                        entregaRepository.listarEntregasDaRota(rota.getIdRota())
                ))
                .orElse(null);

        var disponiveis = entregaRepository.listarDisponiveis(inicio(paginaDisponiveis), TAMANHO_PAGINA + 1);
        var encerradas = entregaRepository.listarRotasEncerradas(idEntregador, inicio(paginaEncerradas), TAMANHO_PAGINA + 1);
        return new PainelEntregadorResponse(rotaAtual, paginar(disponiveis, paginaDisponiveis), paginar(encerradas, paginaEncerradas));
    }

    @Transactional
    public void assumirEntrega(long idEntregador, long idEntrega) {
        bloquearEntregador(idEntregador);
        EntregaRecord entrega = buscarEntregaBloqueada(idEntrega);
        if (entrega.getStatus() != StatusEntrega.aguardando_entregador || entrega.getIdRota() != null) {
            throw new ConflitoNegocioException("A entrega não está mais disponível para aceite.");
        }

        if (entregaRepository.possuiEntregaAtivaAtrasada(idEntregador)) {
            throw new RegraNegocioException("Finalize a entrega em atraso antes de assumir outra.");
        }

        long idRota = entregaRepository.buscarRotaAberta(idEntregador)
                .map(rota -> {
                    if (rota.getVagas() <= 0) {
                        throw new RegraNegocioException("Você já atingiu o limite de 2 entregas na rota atual.");
                    }
                    return rota.getIdRota();
                })
                .orElseGet(() -> entregaRepository.criarRota(idEntregador));

        // Uma única atualização preserva o CHECK que vincula o status à presença de rota.
        if (!entregaRepository.atribuirEntrega(idEntrega, idRota)) {
            throw new ConflitoNegocioException("A entrega não está mais disponível para aceite.");
        }
    }

    @Transactional
    public void atualizarStatus(long idEntregador, long idEntrega, String novoStatus) {
        bloquearEntregador(idEntregador);
        EntregaRecord entrega = buscarEntregaBloqueada(idEntrega);

        var rota = Optional.ofNullable(entrega.getIdRota())
                .flatMap(idRota -> entregaRepository.buscarRotaDoEntregador(idRota, idEntregador))
                .orElseThrow(() -> new AcessoNegadoException("Somente o entregador responsável pode atualizar a entrega."));
        if (rota.getEncerradaEm() != null) {
            throw new ConflitoNegocioException("A rota da entrega já foi encerrada.");
        }

        StatusEntrega atual = entrega.getStatus();
        StatusEntrega destino = StatusEntrega.lookupLiteral(novoStatus);
        boolean permitida = (atual == StatusEntrega.aceita && destino == StatusEntrega.a_caminho)
                || (atual == StatusEntrega.a_caminho && destino == StatusEntrega.entregue);
        if (!permitida) {
            throw new RegraNegocioException("Esta atualização de status da entrega não é permitida.");
        }

        entregaRepository.atualizarStatus(idEntrega, destino);
        if (destino == StatusEntrega.entregue) {
            entregaRepository.encerrarRotaSemEntregasAtivas(rota.getIdRota());
        }
    }

    private void bloquearEntregador(long idEntregador) {
        // A linha do entregador existe mesmo sem rota: ela serializa a abertura e as alterações da rota.
        if (!entregaRepository.bloquearEntregador(idEntregador)) {
            throw new AcessoNegadoException("A operação é exclusiva de entregadores.");
        }
    }

    private EntregaRecord buscarEntregaBloqueada(long idEntrega) {
        return entregaRepository.buscarEntregaForUpdate(idEntrega)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Entrega " + idEntrega + " não encontrada."));
    }

    private static int inicio(int pagina) {
        return (pagina - 1) * TAMANHO_PAGINA;
    }

    private static <T> Pagina<T> paginar(List<T> itens, int pagina) {
        boolean temProxima = itens.size() > TAMANHO_PAGINA;
        return new Pagina<>(temProxima ? itens.subList(0, TAMANHO_PAGINA) : itens, pagina, temProxima);
    }
}
