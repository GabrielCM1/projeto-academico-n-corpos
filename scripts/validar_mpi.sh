#!/usr/bin/env bash
# Valida a versao MPI contra o baseline (issue #6).
#
# Mesmo metodo do scripts/validar_openmp.sh: o checksum de 6 casas nao detecta
# erro nas forcas, entao compila copias temporarias do baseline e do MPI (os
# originais nao mudam) que imprimem tambem:
#   - o checksum com precisao total (%.17g: identifica o double bit a bit);
#   - vel = soma de |vx| + |vy|, que depende diretamente de todas as forcas.
# Os dois valores tem que ser IDENTICOS para todas as combinacoes.
#
# Inclui -np 3 de proposito: 500, 1000, 2000 e 4000 nao dividem por 3, entao
# testa os blocos de tamanhos diferentes.
#
# Uso: scripts/validar_mpi.sh            (gera resultados/validacao_mpi.csv)
set -euo pipefail
cd "$(dirname "$0")/.."

NS=(500 1000 2000 4000)
PROCS=(1 2 3 4 8)
STEPS=10
CSV=resultados/validacao_mpi.csv

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Insere a linha de validacao logo depois do laco do checksum, nos dois programas.
# No MPI esse laco roda so no rank 0, que ja tem as posicoes e velocidades finais.
EXTRA='{ double vel = 0; for (int i = 0; i < N; i++) vel += fabs(vx[i]) + fabs(vy[i]); printf("VALIDACAO checksum=%.17g vel=%.17g\\n", soma, vel); }'
instrumenta() {  # $1 = fonte original, $2 = copia
    sed "/soma += x\[i\] + y\[i\];/a $EXTRA" "$1" > "$2"
    grep -q VALIDACAO "$2" || { echo "erro: nao consegui instrumentar $1" >&2; exit 1; }
}
instrumenta baseline/06_nbody.cpp  "$TMP/base.cpp"
instrumenta mpi/06_nbody_mpi.cpp   "$TMP/mpi.cpp"
g++    -O2 "$TMP/base.cpp" -o "$TMP/base"
mpicxx -O2 "$TMP/mpi.cpp"  -o "$TMP/mpi"

campo() { grep VALIDACAO | sed -E "s/.*$1=([^ ]+).*/\1/"; }

echo "n,steps,processos,checksum_baseline,checksum_mpi,vel_baseline,vel_mpi,igual" > "$CSV"
falhas=0; total=0
for n in "${NS[@]}"; do
    base=$("$TMP/base" "$n" "$STEPS")
    cb=$(echo "$base" | campo checksum); vb=$(echo "$base" | campo vel)
    for p in "${PROCS[@]}"; do
        saida=$(mpirun --oversubscribe -np "$p" "$TMP/mpi" "$n" "$STEPS")
        cm=$(echo "$saida" | campo checksum); vm=$(echo "$saida" | campo vel)
        if [[ "$cb" == "$cm" && "$vb" == "$vm" ]]; then ok=sim; else ok=nao; falhas=$((falhas+1)); fi
        total=$((total+1))
        echo "$n,$STEPS,$p,$cb,$cm,$vb,$vm,$ok" >> "$CSV"
        printf "N=%-5d processos=%d checksum=%-22s vel=%-24s %s\n" "$n" "$p" "$cm" "$vm" \
            "$([[ $ok == sim ]] && echo OK || echo "DIFERENTE (baseline: $cb / $vb)")"
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
