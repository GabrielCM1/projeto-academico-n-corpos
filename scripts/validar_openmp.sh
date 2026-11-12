#!/usr/bin/env bash
# Valida a versao OpenMP contra o baseline (issue #2).
#
# Por que nao basta comparar o checksum impresso (%.6f):
#   as forcas sao minusculas (G = 6.674e-11), entao as posicoes mudam so na
#   9a casa decimal. Um programa com as forcas ZERADAS tambem imprime
#   checksum=118000.000000 para N=2000. Com 6 casas o checksum nao detecta erro.
#
# O que este script faz:
#   compila copias temporarias do baseline e do OpenMP (os originais nao mudam)
#   que imprimem, alem da linha normal:
#     - o checksum com precisao total (%.17g: identifica o double bit a bit);
#     - vel = soma de |vx| + |vy|, que depende diretamente de todas as forcas.
#   Os dois valores tem que ser IDENTICOS para todas as combinacoes.
#
# Uso: scripts/validar_openmp.sh            (gera resultados/validacao_openmp.csv)
set -euo pipefail
cd "$(dirname "$0")/.."

NS=(500 1000 1414 2000 2828 4000)   # 1414 e 2828: tamanhos da escalabilidade fraca
THREADS=(1 2 4 8)
SCHEDS=(static dynamic guided)
STEPS=10
CSV=resultados/validacao_openmp.csv

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Insere a linha de validacao logo depois do laco do checksum, nos dois programas.
EXTRA='{ double vel = 0; for (int i = 0; i < N; i++) vel += fabs(vx[i]) + fabs(vy[i]); printf("VALIDACAO checksum=%.17g vel=%.17g\\n", soma, vel); }'
instrumenta() {  # $1 = fonte original, $2 = copia
    sed "/soma += x\[i\] + y\[i\];/a $EXTRA" "$1" > "$2"
    grep -q VALIDACAO "$2" || { echo "erro: nao consegui instrumentar $1" >&2; exit 1; }
}
instrumenta baseline/06_nbody.cpp        "$TMP/base.cpp"
instrumenta openmp/06_nbody_openmp.cpp   "$TMP/omp.cpp"
g++ -O2          "$TMP/base.cpp" -o "$TMP/base"
g++ -O2 -fopenmp "$TMP/omp.cpp"  -o "$TMP/omp"

campo() { grep VALIDACAO | sed -E "s/.*$1=([^ ]+).*/\1/"; }

echo "n,steps,threads,schedule,checksum_baseline,checksum_openmp,vel_baseline,vel_openmp,igual" > "$CSV"
falhas=0; total=0
for n in "${NS[@]}"; do
    base=$("$TMP/base" "$n" "$STEPS")
    cb=$(echo "$base" | campo checksum); vb=$(echo "$base" | campo vel)
    for t in "${THREADS[@]}"; do
        for s in "${SCHEDS[@]}"; do
            # threads e escalonamento pelas variaveis padrao do OpenMP
            omp=$(OMP_NUM_THREADS=$t OMP_SCHEDULE=$s "$TMP/omp" "$n" "$STEPS" "$t")
            co=$(echo "$omp" | campo checksum); vo=$(echo "$omp" | campo vel)
            if [[ "$cb" == "$co" && "$vb" == "$vo" ]]; then ok=sim; else ok=nao; falhas=$((falhas+1)); fi
            total=$((total+1))
            echo "$n,$STEPS,$t,$s,$cb,$co,$vb,$vo,$ok" >> "$CSV"
            printf "N=%-5d threads=%d %-8s checksum=%-22s vel=%-24s %s\n" "$n" "$t" "$s" "$co" "$vo" \
                "$([[ $ok == sim ]] && echo OK || echo "DIFERENTE (baseline: $cb / $vb)")"
        done
    done
done

echo
echo "Resultado salvo em $CSV"
if (( falhas == 0 )); then
    echo "OK: as $total combinacoes deram resultado identico ao baseline."
else
    echo "FALHA: $falhas de $total combinacoes diferem do baseline." >&2
    exit 1
fi
