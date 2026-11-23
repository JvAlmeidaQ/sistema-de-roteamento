-- Disciplina: DCC061 (Engenharia de Software)
-- RN08 / RR11: alinha o código de imutabilidade ao contrato documentado.
-- Mantém a migração 08 intacta para bancos que já a aplicaram.

CREATE OR REPLACE FUNCTION rastreio_impedir_alteracao_de_evento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = '23001',
        CONSTRAINT = 'ck_historico_imutavel',
        MESSAGE = 'RN08/RR11: eventos de rastreio não podem ser alterados ou excluídos';
END;
$$;
