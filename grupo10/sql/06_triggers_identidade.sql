-- =================================================================================
-- GATILHOS - SUBDOMÍNIO: IDENTIDADE E CONTATO (E6)
-- Arquivo: 06_triggers_identidade.sql
-- Verificação (casos barrados e permitidos): verificacao_dos_gatilhos_identidade.sql
-- =================================================================================

BEGIN;

-- =================================================================================
-- RR12 — Imutabilidade dos dados de localização do endereço
--
-- Regra (Seção 2 do relatório): "Dados de localização (logradouro, numero, cep)
-- na tabela Endereco não podem sofrer alterações após sua inserção."
-- Mecanismo previsto no relatório: Gatilho (bloqueio de UPDATE).
--
-- Por que não cabe como restrição declarativa:
--   CHECK, NOT NULL, UNIQUE e FOREIGN KEY avaliam apenas o valor que está sendo
--   gravado (a linha nova). Nenhum deles consegue comparar o valor NOVO com o
--   valor ANTIGO da mesma linha, que é exatamente o que a regra exige
--   ("não pode mudar"). Só um gatilho BEFORE UPDATE tem acesso às duas versões
--   da linha, por meio das variáveis OLD (antes) e NEW (depois).
--
-- Por que a regra existe:
--   Um mesmo endereço é compartilhado por vários moradores (pessoa_endereco) e
--   é referenciado por pedidos e lojas. Se o logradouro de um endereço fosse
--   editado, todos os pedidos antigos passariam a "apontar" para outro lugar,
--   falsificando o histórico. Quem muda de endereço cadastra um endereço novo.
--
-- Comportamento:
--   - Bloqueia o UPDATE quando logradouro, numero ou cep mudam de valor.
--   - Permite atualizar as demais colunas (bairro, cidade, estado), que não estão
--     na RR12, e permite UPDATEs que regravam o mesmo valor.
--   - O erro usa SQLSTATE 23514 (check_violation) e um nome de restrição
--     (ck_endereco_localizacao_imutavel), no mesmo padrão dos gatilhos de
--     Logística, para identificar qual proteção barrou a operação.
-- =================================================================================
CREATE FUNCTION identidade_bloquear_alteracao_endereco()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- IS DISTINCT FROM compara tratando NULL como valor: só acusa mudança real.
    IF NEW.logradouro IS DISTINCT FROM OLD.logradouro
       OR NEW.numero  IS DISTINCT FROM OLD.numero
       OR NEW.cep     IS DISTINCT FROM OLD.cep THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'ck_endereco_localizacao_imutavel',
            MESSAGE = format(
                'RR12: logradouro, número e CEP do endereço %s não podem ser alterados',
                OLD.id_endereco),
            HINT = 'Cadastre um novo endereço e vincule-o à pessoa em pessoa_endereco.';
    END IF;

    -- Em um gatilho BEFORE, retornar NEW deixa o UPDATE prosseguir normalmente.
    RETURN NEW;
END;
$$;

-- BEFORE UPDATE OF ...: o gatilho só é disparado quando o comando UPDATE cita
-- alguma das três colunas protegidas; um UPDATE só de bairro nem o aciona.
-- FOR EACH ROW: a função roda uma vez para cada linha alterada.
CREATE TRIGGER trg_endereco_localizacao_imutavel
BEFORE UPDATE OF logradouro, numero, cep ON endereco
FOR EACH ROW
EXECUTE FUNCTION identidade_bloquear_alteracao_endereco();

COMMIT;
