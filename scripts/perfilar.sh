#!/usr/bin/env bash
# Perfilamento do baseline (issue #7): tempo de cada trecho, fracao paralelizavel
# e speedup maximo previsto pela Lei de Amdahl.
#
# Usa a copia instrumentada baseline/06_nbody_perfil.cpp (o baseline oficial nao
# muda). Antes de medir, confere com precisao total que a copia da exatamente o
# resultado do baseline (mesmo metodo do scripts/validar_openmp.sh).
#
# Protocolo: o mesmo do scripts/medir.sh. 4 execucoes por N, a 1a descartada,
# mediana das outras 3; espera o processador esfriar antes de cada N.
# A divisao por trecho e a da repeticao de tempo mediano, para as porcentagens
# somarem 100%.
#
# Fracao paralelizavel P = (forcas + atualizacao) / tempo, onde "tempo" e o mesmo
# intervalo que o baseline mede (o laco de passos). Sao os dois trechos que as
# versoes OpenMP e MPI dividem. Amdahl: S(p) = 1 / ((1 - P) + P / p).
#
# Uso: scripts/perfilar.sh     (ou: make perfil)
# Gera:
#   resultados/perfil_06_nbody.csv   n,steps,repeticao,tempo_s,inicializacao_s,alocacao_s,forcas_s,atualizacao_s,outros_s,soma_checksum_s,checksum,descartada
#   resultados/maquina_perfil.txt    nproc, CPU, ambiente, compilador e data
set -euo pipefail
# Locale neutro: em pt_BR o sort -g e o awk esperam virgula decimal e leem "0.0123" como 0.
export LC_ALL=C
cd "$(dirname "$0")/.."

NS=(500 1000 2000 4000)
STEPS=10
REPS=4
CSV=resultados/perfil_06_nbody.csv
MAQ=resultados/maquina_perfil.txt
BIN=baseline/06_nbody_perfil

make -s baseline/06_nbody "$BIN"
source scripts/info_maquina.sh

# --- 1. a copia instrumentada da o mesmo resultado do baseline? -----------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
EXTRA='{ double vel = 0; for (int i = 0; i < N; i++) vel += fabs(vx[i]) + fabs(vy[i]); printf("VALIDACAO checksum=%.17g vel=%.17g\\n", soma, vel); }'
for f in 06_nbody 06_nbody_perfil; do
    sed "/soma += x\[i\] + y\[i\];/a $EXTRA" "baseline/$f.cpp" > "$TMP/$f.cpp"
    grep -q VALIDACAO "$TMP/$f.cpp" || { echo "erro: nao consegui instrumentar $f" >&2; exit 1; }
    g++ -O2 "$TMP/$f.cpp" -o "$TMP/$f"
done
for n in "${NS[@]}"; do
    a=$("$TMP/06_nbody" "$n" "$STEPS" | grep VALIDACAO); b=$("$TMP/06_nbody_perfil" "$n" "$STEPS" | grep VALIDACAO)
    [[ "$a" == "$b" ]] || { echo "erro: com N=$n a copia instrumentada difere do baseline: $a / $b" >&2; exit 1; }
done
echo "Copia instrumentada confere com o baseline (precisao total) para N = ${NS[*]}"; echo

# --- 2. medicao ---------------------------------------------------------------
{
    info_maquina
    echo "flags:      -O2"
    echo "protocolo:  $REPS execucoes por N, 1a descartada, mediana das outras 3; $STEPS passos; espera ate ${ESFRIAR:-55}C antes de cada N"
} > "$MAQ"
cat "$MAQ"; echo

echo "n,steps,repeticao,tempo_s,inicializacao_s,alocacao_s,forcas_s,atualizacao_s,outros_s,soma_checksum_s,checksum,descartada" > "$CSV"
campo() { sed -nE "s/.*[[:space:]]$1=([0-9.]+).*/\1/p"; }

for n in "${NS[@]}"; do
    echo "== N=$n (processador: $(esfria))"
    for r in $(seq 1 $REPS); do
        out=$("./$BIN" "$n" "$STEPS")
        (( r == 1 )) && desc=sim || desc=nao
        l1=$(echo "$out" | head -1); l2=$(echo "$out" | tail -1)
        echo "$n,$STEPS,$r,$(echo "$l1" | campo tempo),$(echo "$l2" | campo inicializacao),$(echo "$l2" | campo alocacao),$(echo "$l2" | campo forcas),$(echo "$l2" | campo atualizacao),$(echo "$l2" | campo outros),$(echo "$l2" | campo checksum),$(echo "$l1" | campo checksum),$desc" >> "$CSV"
    done
    # repeticao de tempo mediano entre as validas
    awk -F, -v n="$n" 'NR > 1 && $1 == n && $NF == "nao"' "$CSV" | sort -t, -k4,4g | sed -n 2p | awk -F, '{
        t = $4
        printf "  tempo do laco de passos: %.6f s (repeticao %d)\n", t, $3
        printf "  %-14s %12.6f s %8.3f%%\n", "forcas",      $7, 100 * $7 / t
        printf "  %-14s %12.6f s %8.3f%%\n", "atualizacao", $8, 100 * $8 / t
        printf "  %-14s %12.6f s %8.3f%%\n", "alocacao",    $6, 100 * $6 / t
        printf "  %-14s %12.6f s %8.3f%%\n", "outros",      $9, 100 * $9 / t
        printf "  fora do tempo: inicializacao %.6f s, checksum %.6f s\n", $5, $10
        P = ($7 + $8) / t
        printf "  fracao paralelizavel P = %.5f; Amdahl: S(2) = %.3f, S(4) = %.3f, S(8) = %.3f, limite = %.0f\n", \
            P, 1 / ((1 - P) + P / 2), 1 / ((1 - P) + P / 4), 1 / ((1 - P) + P / 8), 1 / (1 - P)
    }'
done
echo
echo "Resultados salvos em $CSV e $MAQ"
