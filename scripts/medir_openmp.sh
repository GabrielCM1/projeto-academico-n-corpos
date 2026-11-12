#!/usr/bin/env bash
# Mede a versao OpenMP (issue #3) e, na mesma sessao, o baseline.
# O speedup so faz sentido com os dois medidos na mesma maquina e nas mesmas
# condicoes (frequencia, temperatura, carga), por isso o baseline e remedido aqui.
#
# Protocolo: 4 execucoes por configuracao; a 1a e aquecimento e e descartada;
# vale a mediana das outras 3. N = 500, 1000, 2000, 4000; 10 passos; 1, 2, 4 e 8 threads.
# Feche os outros programas antes: com todas as CPUs ocupadas, qualquer processo
# extra atrasa uma thread e as outras esperam por ela na barreira.
#
# Uso: scripts/medir_openmp.sh     (ou: make medir)
# Gera:
#   resultados/openmp_06_nbody.csv                  n,steps,threads,repeticao,tempo_s,checksum,descartada
#   resultados/baseline_06_nbody_mesma_sessao.csv   n,steps,repeticao,tempo_s,checksum,descartada
#   resultados/maquina_openmp.txt                   nproc, CPU, ambiente, compilador e data
set -euo pipefail
# Locale neutro: em pt_BR o sort -g e o awk esperam virgula decimal e leem "0.0123" como 0.
export LC_ALL=C
cd "$(dirname "$0")/.."

NS=(500 1000 2000 4000)
THREADS=(1 2 4 8)
STEPS=10
REPS=4
CSV_OMP=resultados/openmp_06_nbody.csv
CSV_BASE=resultados/baseline_06_nbody_mesma_sessao.csv
MAQ=resultados/maquina_openmp.txt

make -s baseline openmp

lscpu_campo() { lscpu | sed -nE "s/^$1:[[:space:]]+//p" | head -1; }
ambiente() {
    if [[ -f /.dockerenv ]]; then echo "conteiner Docker"
    elif [[ -f /run/.containerenv ]]; then echo "conteiner $(sed -nE 's/^image="(.*)"/\1/p' /run/.containerenv)"
    else echo "direto no sistema"; fi
}
{
    echo "data:       $(date '+%Y-%m-%d %H:%M')"
    echo "nproc:      $(nproc)"
    echo "cpu:        $(lscpu_campo 'Model name')"
    echo "nucleos:    $(lscpu_campo 'Core\(s\) per socket') fisicos por soquete, $(lscpu_campo 'Thread\(s\) per core') threads por nucleo, $(lscpu_campo 'Socket\(s\)') soquete(s)"
    echo "memoria:    $(free -h | awk '/^Mem:/ {print $2}')"
    echo "so:         $(sed -nE 's/^PRETTY_NAME="(.*)"/\1/p' /etc/os-release), kernel $(uname -r)"
    echo "ambiente:   $(ambiente)"
    echo "energia:    $(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -1 | sed 's/1/na tomada/; s/0/na bateria/' || echo desconhecido)"
    echo "carga:      $(cut -d' ' -f1-3 /proc/loadavg) (media de 1, 5 e 15 min antes de medir)"
    echo "compilador: $(g++ --version | head -1)"
    echo "flags:      -O2 (baseline), -O2 -fopenmp (openmp); escalonamento padrao do programa (static)"
    echo "protocolo:  $REPS execucoes por configuracao, 1a descartada, mediana das outras 3; $STEPS passos"
} > "$MAQ"
cat "$MAQ"; echo

echo "n,steps,repeticao,tempo_s,checksum,descartada" > "$CSV_BASE"
echo "n,steps,threads,repeticao,tempo_s,checksum,descartada" > "$CSV_OMP"

mediana3() { printf "%s\n" "$@" | sort -g | sed -n 2p; }
campo()    { sed -nE "s/.*[[:space:]]$1=([0-9.]+).*/\1/p"; }

# $1 = rotulo, $2 = arquivo CSV, $3 = prefixo das colunas, $4 = threads esperadas (ou -), resto = comando
# Deixa a mediana em $MEDIANA.
mede() {
    local rotulo=$1 csv=$2 prefixo=$3 esperado=$4; shift 4
    local tempos=() out tempo chk desc
    for r in $(seq 1 $REPS); do
        out=$("$@")
        if [[ $esperado != - && $(echo "$out" | campo threads) != "$esperado" ]]; then
            echo "erro: pedi $esperado threads e o programa usou outra quantidade: $out" >&2; exit 1
        fi
        tempo=$(echo "$out" | campo tempo); chk=$(echo "$out" | campo checksum)
        if (( r == 1 )); then desc=sim; else desc=nao; tempos+=("$tempo"); fi
        echo "$prefixo,$r,$tempo,$chk,$desc" >> "$csv"
    done
    MEDIANA=$(mediana3 "${tempos[@]}")
    printf "%-20s checksum=%-16s mediana=%-9s s" "$rotulo" "$chk" "$MEDIANA"
}

for n in "${NS[@]}"; do
    mede "N=$n baseline" "$CSV_BASE" "$n,$STEPS" - ./baseline/06_nbody "$n" "$STEPS"; echo
    TBASE=$MEDIANA
    for t in "${THREADS[@]}"; do
        mede "N=$n threads=$t" "$CSV_OMP" "$n,$STEPS,$t" "$t" ./openmp/06_nbody_openmp "$n" "$STEPS" "$t"
        awk -v b="$TBASE" -v m="$MEDIANA" 'BEGIN { printf "  speedup=%.2f\n", b / m }'
    done
done
echo
echo "Resultados salvos em $CSV_OMP, $CSV_BASE e $MAQ"
