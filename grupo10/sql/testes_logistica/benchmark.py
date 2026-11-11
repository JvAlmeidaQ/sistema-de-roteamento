#!/usr/bin/env python3
"""Benchmark descartável, sem dependências Python externas."""
import hashlib
import json
import platform
import re
import statistics
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
SQL = HERE.parent
NAME = "logistica-benchmark-test"
IMAGE = "postgres:18"
QUERIES = {"Q1 — Entregas ativas atrasadas por pedido e loja": "atrasos.sql",
           "Q2 — Fila global de pedidos prontos (L4)": "fila_prontos.sql"}
MARKER = "## Resultados da execução real"


def command(args, data=None, timeout=180):
    result = subprocess.run(args, input=data, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"{args!r}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def psql(text, database="volume"):
    return command(["docker", "exec", "-i", NAME, "psql", "-X", "-qAt",
                    "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d", database], text)


def load(path, database):
    return psql(path.read_text(), database)


def bootstrap(database):
    psql(f"CREATE DATABASE {database};", "postgres")
    load(HERE / "fixtures/dependencias.sql", database)
    load(SQL / "01_esquema_logistica.sql", database)


def measured(query):
    return psql("EXPLAIN (ANALYZE, BUFFERS, SETTINGS, SUMMARY, FORMAT TEXT) " + query)


def main():
    started = datetime.now(timezone.utc).isoformat()
    created = False
    output = [MARKER, "", f"Início (UTC): `{started}`.", ""]
    try:
        command(["docker", "run", "-d", "--name", NAME,
                 "--tmpfs", "/var/lib/postgresql", "-e", "POSTGRES_PASSWORD=benchmark-descartavel",
                 IMAGE])
        created = True
        deadline = time.monotonic() + 120
        while True:
            logs = command(["docker", "logs", NAME])
            if "PostgreSQL init process complete; ready for start up." in logs:
                try:
                    if psql("SELECT 1;", "postgres").strip() == "1":
                        break
                except RuntimeError:
                    pass
            if time.monotonic() > deadline:
                raise RuntimeError("Timeout aguardando init process complete e SELECT 1")
            time.sleep(1)
        bootstrap("funcional")
        psql("INSERT INTO pedido (id_loja,id_cliente,id_endereco,status,subtotal,"
             "taxa_entrega,taxa_servico,valor_total) SELECT 1,1,1,"
             "CASE WHEN i IN (4,5) THEN 'concluido' ELSE 'pronto' END::status_pedido,"
             "40,5,2,47 FROM generate_series(1,6) AS g(i);", "funcional")
        load(SQL / "02_carga_logistica.sql", "funcional")
        load(SQL / "07_indices_logistica.sql", "funcional")
        load(SQL / "03_verificacao_logistica.sql", "funcional")
        statements = (SQL / "04_consultas_logistica.sql").read_text().split(";")
        counts = []
        for query in statements:
            if query.strip():
                counts.append(int(psql("SELECT count(*) FROM (" + query + ") AS q;", "funcional")))
        if counts != [1, 1000, 1, 1, 1, 1]:
            raise RuntimeError(f"Contagens funcionais inesperadas: {counts}")
        if psql("SELECT count(*) FROM rota; SELECT count(*) FROM entrega;", "funcional").split() != ["3", "6"]:
            raise RuntimeError("Verificação alterou a carga funcional")
        load(SQL / "05_visoes_logistica.sql", "funcional")
        if psql("SELECT count(*) FROM vw_painel_rotas_logistica;", "funcional").strip() != "3":
            raise RuntimeError("Visão funcional deveria conter três rotas")
        output += ["### Validação funcional separada", "",
                   "Carga oficial: 3 rotas, 6 entregas; verificação oficial executada sem erro "
                   "após criar os índices (cenários positivos e negativos, com rollback). "
                   f"Contagens das seis consultas: `{counts}`; visão: 3 linhas. "
                   "A fixture possui 1.000 entregadores, inclusive os IDs 1, 2 e 3 exigidos pela carga.", ""]
        bootstrap("volume")
        load(HERE / "fixtures/carga_volume.sql", "volume")
        psql("VACUUM (FREEZE, ANALYZE);")
        checks = psql("SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal; "
                      "SELECT count(*) FROM (SELECT id_rota FROM entrega WHERE id_rota IS NOT NULL "
                      "GROUP BY id_rota HAVING count(*) > 2) AS q;").split()
        if checks != ["0", "0"]:
            raise RuntimeError(f"Gatilhos externos ou rota acima da capacidade: {checks}")
        metadata = psql("SELECT version(); SELECT name || '=' || setting || COALESCE(' ' || unit, '') "
                        "FROM pg_settings WHERE name IN ('shared_buffers','work_mem','effective_cache_size',"
                        "'max_parallel_workers_per_gather','random_page_cost','seq_page_cost','jit',"
                        "'enable_seqscan','default_statistics_target') ORDER BY name;")
        image = command(["docker", "image", "inspect", IMAGE, "--format", "{{json .RepoDigests}}"])
        output += ["### Ambiente", "", f"Host: `{platform.platform()}`; arquitetura `{platform.machine()}`.", "",
                   f"Imagem: `{image.strip()}`. Armazenamento descartável em tmpfs; sem portas publicadas.", "",
                   "```text", metadata.strip(), "```", ""]
        sizes_before = psql("SELECT relname, pg_size_pretty(pg_relation_size(oid)), "
                            "pg_size_pretty(pg_total_relation_size(oid)) FROM pg_class "
                            "WHERE relname IN ('pedido','entrega','rota') ORDER BY relname;")
        counts = psql("SELECT 'pedido', count(*) FROM pedido UNION ALL SELECT 'entrega', count(*) FROM entrega "
                     "UNION ALL SELECT 'rota', count(*) FROM rota UNION ALL "
                     "SELECT 'pedido pronto', count(*) FROM pedido WHERE status='pronto' UNION ALL "
                     "SELECT 'entrega ativa', count(*) FROM entrega WHERE status IN ('aceita','a_caminho');")
        output += ["### Volume e tamanhos anteriores (tabela | heap | total com índices)", "", "```text",
                   counts.strip(), sizes_before.strip(), "```", ""]
        results = {}
        fingerprints = {}
        for phase in ("Antes", "Depois"):
            if phase == "Depois":
                load(SQL / "07_indices_logistica.sql", "volume")
            results[phase] = {}
            for title, filename in QUERIES.items():
                query = (HERE / filename).read_text()
                rows = psql(query)
                fingerprint = hashlib.sha256(rows.encode()).hexdigest()
                row_count = len(rows.splitlines())
                expected = {"atrasos.sql": 250, "fila_prontos.sql": 1000}[filename]
                if row_count != expected:
                    raise RuntimeError(f"Contagem inesperada em {filename}: {row_count}, esperado {expected}")
                if phase == "Antes":
                    fingerprints[title] = (fingerprint, row_count)
                elif fingerprints[title] != (fingerprint, row_count):
                    raise RuntimeError(f"Resultado mudou após índices: {title}")
                measured(query)
                plans = [measured(query) for _ in range(5)]
                times = [float(re.search(r"Execution Time: ([0-9.]+) ms", plan)[1]) for plan in plans]
                results[phase][title] = {"times_ms": times, "median_ms": statistics.median(times),
                                         "rows": row_count, "sha256": fingerprint, "plans": plans}
        output += ["### Resumo dos tempos do executor", "",
                   "Uma execução de aquecimento por consulta/fase, seguida de cinco medições. "
                   "O checksum também executa a consulta antes do aquecimento. "
                   "Tempos abaixo são `Execution Time`, sem o tempo de inicialização do cliente/docker. "
                   "Resultados ordenados e SHA-256 idênticos antes/depois.", "",
                   "| Consulta | Linhas | Antes (ms, 5 execuções) | Depois (ms, 5 execuções) | Medianas antes/depois (ms) | Razão antes/depois |",
                   "| --- | ---: | --- | --- | --- | ---: |"]
        for title in QUERIES:
            a, b = results["Antes"][title], results["Depois"][title]
            output.append(f"| {title} | {a['rows']} | {a['times_ms']} | {b['times_ms']} | "
                          f"{a['median_ms']:.3f} / {b['median_ms']:.3f} | {a['median_ms']/b['median_ms']:.2f}x |")
        output += ["", "### Índices criados (definição e tamanho real)", "", "```text",
                   psql("SELECT indexname, indexdef FROM pg_indexes WHERE indexname LIKE 'idx_%' ORDER BY indexname; "
                        "SELECT relname, pg_size_pretty(pg_relation_size(oid)) FROM pg_class "
                        "WHERE relname LIKE 'idx_%' ORDER BY relname;").strip(), "```", ""]
        for title, filename in QUERIES.items():
            output += [f"### {title}", "", f"Fonte: `testes_logistica/{filename}`.", "", "```sql",
                       (HERE / filename).read_text().strip(), "```", "",
                       f"SHA-256 do resultado psql ordenado: `{fingerprints[title][0]}`.", ""]
            for phase in ("Antes", "Depois"):
                output += [f"#### {phase}: plano completo da primeira medição", "",
                           "```text", results[phase][title]["plans"][0].strip(), "```", ""]
        (HERE / "resultados.json").write_text(json.dumps({"started_utc": started, "results": results},
                                                       ensure_ascii=False, indent=2) + "\n")
        doc = SQL / "experimentos_logistica.md"
        introduction = doc.read_text().split(MARKER)[0].rstrip()
        doc.write_text(introduction + "\n\n" + "\n".join(output).rstrip() + "\n")
        print("Validação funcional, checksums e benchmark concluídos.")
        for title in QUERIES:
            print(title, {phase: results[phase][title]["median_ms"] for phase in results})
    finally:
        if created:
            command(["docker", "rm", "-f", "-v", NAME])
            print(f"Container {NAME} removido, incluindo armazenamento descartável.")


if __name__ == "__main__":
    main()
