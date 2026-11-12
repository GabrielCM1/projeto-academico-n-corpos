#!/usr/bin/env bash
# Compara politicas de escalonamento no laco de forcas (issue #1, parte do Joao Pedro).
# 4 execucoes por configuracao; a 1a e aquecimento e e descartada; vale a mediana das outras 3.
# A politica e passada pela variavel OMP_SCHEDULE (o laco usa schedule(runtime)).
#
# Uso: scripts/comparar_schedule.sh        (gera resultados/schedule_06_nbody.csv)
set -euo pipefail
# Locale neutro: em pt_BR o sort -g e o awk esperam virgula decimal e leem "0.0123" como 0.
export LC_ALL=C
cd "$(dirname "$0")/.."

NS=(2000 4000)
THREADS=(4 8)
SCHEDS=(static static,1 dynamic dynamic,16 dynamic,64 guided)
STEPS=10
REPS=4
CSV=resultados/schedule_06_nbody.csv
BIN=openmp/06_nbody_openmp

make -s openmp
echo "n,steps,threads,schedule,repeticao,tempo_s,checksum,descartada" > "$CSV"

mediana3() { printf "%s\n" "$@" | sort -g | sed -n 2p; }

printf "%-6s %-8s %-12s %s\n" N threads schedule "mediana (s)"
for n in "${NS[@]}"; do
    for t in "${THREADS[@]}"; do
        for s in "${SCHEDS[@]}"; do
            tempos=()
            for r in $(seq 1 $REPS); do
                out=$(OMP_NUM_THREADS=$t OMP_SCHEDULE=$s "$BIN" "$n" "$STEPS" "$t")
                tempo=$(echo "$out" | sed -E 's/.*tempo=([0-9.]+).*/\1/')
                chk=$(echo "$out" | sed -E 's/.*checksum=([0-9.]+).*/\1/')
                if (( r == 1 )); then desc=sim; else desc=nao; tempos+=("$tempo"); fi
                echo "$n,$STEPS,$t,\"$s\",$r,$tempo,$chk,$desc" >> "$CSV"
            done
            printf "%-6s %-8s %-12s %s\n" "$n" "$t" "$s" "$(mediana3 "${tempos[@]}")"
        done
    done
done
echo
echo "Resultado salvo em $CSV"
