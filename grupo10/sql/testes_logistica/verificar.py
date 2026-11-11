#!/usr/bin/env python3
"""Validação funcional e concorrente em PostgreSQL 18 descartável."""
import subprocess
import time
from pathlib import Path

SQL = Path(__file__).resolve().parent.parent
NAME = "logistica-gatilhos-test"


def args(application="logistica_test"):
    return ["docker", "exec", "-i", "-e", f"PGAPPNAME={application}", NAME,
            "psql", "-X", "-qAt", "-U", "postgres", "-v", "ON_ERROR_STOP=1",
            "-v", "VERBOSITY=verbose"]


def run(text):
    return subprocess.run(args(), input=text, text=True, capture_output=True, timeout=60)


def sql(text):
    result = run(text)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()


def load(filename):
    return sql((SQL / filename).read_text())


def novo_pedido():
    return int(sql("INSERT INTO pedido (id_loja,id_cliente,id_endereco,status,subtotal,"
                   "taxa_entrega,taxa_servico,valor_total) SELECT id_loja,id_cliente,id_endereco,"
                   "'pronto',subtotal,taxa_entrega,taxa_servico,valor_total FROM pedido "
                   "WHERE id_pedido=6 RETURNING id_pedido;"))


def nova_rota():
    return int(sql("INSERT INTO rota (id_entregador) VALUES (1) RETURNING id_rota;"))


def atribuir(pedido, rota):
    return (f"UPDATE entrega SET id_rota={rota}, status='aceita' "
            f"WHERE id_pedido={pedido};")


def snapshot():
    return sql("SELECT json_agg(r ORDER BY id_rota) FROM rota r; "
               "SELECT json_agg(e ORDER BY id_entrega) FROM entrega e; "
               "SELECT json_agg(p ORDER BY id_pedido) FROM pedido p; "
               "SELECT json_agg(l ORDER BY id_loja) FROM loja l;")


def concorrencia(isolation, expected):
    rota = nova_rota()
    pedidos = [novo_pedido() for _ in range(3)]
    sql(atribuir(pedidos[0], rota))
    a = subprocess.Popen(args("logistica_a"), stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    b = subprocess.Popen(args("logistica_b"), stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        a.stdin.write(f"BEGIN ISOLATION LEVEL {isolation}; SET LOCAL statement_timeout='15s';"
                      + atribuir(pedidos[1], rota) + "SELECT 'holding';\n")
        a.stdin.flush()
        if a.stdout.readline().strip() != "holding":
            raise RuntimeError("Sessão A não adquiriu a vaga")
        b.stdin.write(f"BEGIN ISOLATION LEVEL {isolation}; SET LOCAL statement_timeout='15s';"
                      "SELECT 'snapshot', count(*) FROM rota;\n")
        b.stdin.flush()
        if not b.stdout.readline().startswith("snapshot|"):
            raise RuntimeError("Sessão B não fixou o snapshot")
        b.stdin.write(atribuir(pedidos[2], rota) + "COMMIT;\n")
        b.stdin.flush()
        deadline = time.monotonic() + 10
        while sql("SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE "
                  "application_name='logistica_b' AND wait_event_type='Lock' "
                  "AND cardinality(pg_blocking_pids(pid)) > 0);") != "t":
            if time.monotonic() > deadline or b.poll() is not None:
                raise RuntimeError("Sessão B não aguardou o bloqueio da rota")
            time.sleep(0.05)
        a.stdin.write("COMMIT;\n")
        a.stdin.flush()
        _, error_a = a.communicate(timeout=20)
        _, error_b = b.communicate(timeout=20)
        if a.returncode or not b.returncode or expected not in error_b:
            raise RuntimeError(f"Concorrência {isolation}: A={error_a}; B={error_b}")
        if sql(f"SELECT count(*) FROM entrega WHERE id_rota={rota};") != "2":
            raise RuntimeError("RN02 violada na disputa concorrente")
        if sql(f"SELECT status FROM entrega WHERE id_pedido={pedidos[2]};") != "aguardando_entregador":
            raise RuntimeError("Transação rejeitada deixou alteração parcial")
        print(f"PASSOU: disputa da última vaga em {isolation}; perdedora rejeitada com {expected}")
    finally:
        for process in (a, b):
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=20)


def matriz_status():
    states = ["aguardando_entregador", "aceita", "a_caminho", "entregue"]
    for old_index, old in enumerate(states):
        for new_index, new in enumerate(states):
            pedido, rota = novo_pedido(), nova_rota()
            if old_index >= 1:
                sql(atribuir(pedido, rota))
            for state in states[2:old_index + 1]:
                sql(f"UPDATE entrega SET status='{state}' WHERE id_pedido={pedido};")
            route = "NULL" if new_index == 0 else str(rota)
            result = run(f"UPDATE entrega SET status='{new}',id_rota={route} WHERE id_pedido={pedido};")
            allowed = new_index == old_index or new_index == old_index + 1
            if allowed and result.returncode:
                raise RuntimeError(result.stderr)
            if not allowed and (not result.returncode or "ck_entrega_transicao_status" not in result.stderr):
                raise RuntimeError(f"Transição {old} -> {new}: {result.stderr}")
    print("PASSOU: matriz completa das 16 combinações de status")


def main():
    created = False
    try:
        subprocess.run(["docker", "run", "-d", "--network", "none", "--name", NAME,
                        "--tmpfs", "/var/lib/postgresql", "-e", "POSTGRES_HOST_AUTH_METHOD=trust",
                        "postgres:18"], check=True, capture_output=True, text=True, timeout=120)
        created = True
        deadline = time.monotonic() + 60
        while True:
            logs = subprocess.run(["docker", "logs", NAME], capture_output=True, text=True, timeout=10)
            if "init process complete" in logs.stdout and run("SELECT 1;").returncode == 0:
                break
            if time.monotonic() > deadline:
                raise RuntimeError("PostgreSQL não ficou pronto")
            time.sleep(0.5)
        load("testes_logistica/fixtures/dependencias.sql")
        load("01_esquema_logistica.sql")
        sql("INSERT INTO pedido (id_loja,id_cliente,id_endereco,status,subtotal,taxa_entrega,"
            "taxa_servico,valor_total) SELECT 1,1,1,CASE WHEN i IN (4,5) THEN 'concluido' "
            "ELSE 'pronto' END::status_pedido,40,5,2,47 FROM generate_series(1,6) g(i);")
        load("02_carga_logistica.sql")
        load("03_verificacao_logistica.sql")
        print("PASSOU: E4 antes da instalação dos gatilhos")
        load("05_visoes_logistica.sql")
        load("06_triggers_logistica.sql")
        before = snapshot()
        for _ in range(2):
            load("verificacao_dos_gatilhos_logistica.sql")
            if snapshot() != before:
                raise RuntimeError("A verificação dos gatilhos alterou a carga")
        print("PASSOU: verificação SQL dos gatilhos repetida, preservando toda a carga")
        load("07_indices_logistica.sql")
        load("04_consultas_logistica.sql")
        if sql("SELECT count(*) FROM vw_painel_rotas_logistica;") != "3":
            raise RuntimeError("Visão não preservou as rotas da carga")
        print("PASSOU: regressão E5 e instalação dos índices")
        matriz_status()
        for isolation, code in [("READ COMMITTED", "23514"), ("REPEATABLE READ", "40001"),
                                ("SERIALIZABLE", "40001")]:
            concorrencia(isolation, code)
        rota = nova_rota()
        pedidos = [novo_pedido() for _ in range(3)]
        result = run(f"UPDATE entrega SET status='aceita', id_rota={rota} "
                     f"WHERE id_pedido IN ({','.join(map(str, pedidos))});")
        if not result.returncode or "ck_rota_maximo_duas_entregas" not in result.stderr:
            raise RuntimeError("UPDATE multirregistro não protegeu RN02")
        if sql(f"SELECT count(*) FROM entrega WHERE id_rota={rota};") != "0":
            raise RuntimeError("UPDATE multirregistro deixou atribuições parciais")
        print("PASSOU: atribuição multirregistro rejeitada atomicamente")
        for pedido in pedidos[:2]:
            sql(atribuir(pedido, rota))
            sql(f"UPDATE entrega SET status='a_caminho' WHERE id_pedido={pedido};")
            sql(f"UPDATE entrega SET status='entregue' WHERE id_pedido={pedido};")
        result = run(atribuir(pedidos[2], rota))
        if not result.returncode or "ck_rota_maximo_duas_entregas" not in result.stderr:
            raise RuntimeError("Entregas concluídas deixaram de contar para RN02")
        print("PASSOU: duas entregas concluídas continuam ocupando a capacidade da rota")
        for path in SQL.rglob("*.sql"):
            if any(marker in path.read_text() for marker in ("--", "/*", "*/")):
                raise RuntimeError(f"Comentário SQL em {path}")
        print("PASSOU: nenhum comentário nos arquivos SQL")
    finally:
        if created:
            subprocess.run(["docker", "rm", "-f", "-v", NAME], check=True,
                           capture_output=True, timeout=30)


if __name__ == "__main__":
    main()
