#!/usr/bin/env bash
# Mede baseline, OpenMP e MPI na mesma sessao (issue #3 e curva do MPI).
#
# Protocolo: 4 execucoes por configuracao; a 1a e aquecimento e e descartada;
# vale a mediana das outras 3. N = 500, 1000, 2000, 4000; 10 passos;
# OpenMP com 1, 2, 4 e 8 threads; MPI com 1, 2, 4 e 8 processos.
#
# Por que intercalar: num notebook, a frequencia do processador cai conforme ele
# esquenta. Medindo uma versao inteira e depois a outra, a segunda pega o
# processador quente e parece mais lenta do que e (o MPI com 1 processo chegou a
# sair 2x mais lento que o baseline so por rodar depois do OpenMP). Por isso,
# para cada N:
#   1. espera o processador esfriar (se houver sensor de temperatura);
#   2. roda a 1a execucao de todas as configuracoes, depois a 2a, e assim por
#      diante. A variacao termica dentro do bloco afeta todas por igual.
#
# Afinidade (mesma regra para threads e processos): um por nucleo fisico,
# preenchendo os nucleos antes de usar a 2a thread de hardware de cada um.
#   OpenMP: OMP_PLACES=cores OMP_PROC_BIND=spread
#   MPI:    mpirun --use-hwthread-cpus --map-by core --bind-to core
#           (--use-hwthread-cpus: cada CPU logica e uma vaga; sem ela o OpenMPI
#           conta so os nucleos fisicos e o -np 8 nem roda)
# Sem afinidade fixa, o sistema as vezes poe duas threads/processos no MESMO
# nucleo fisico: esses dois andam na metade da velocidade e os outros esperam
# por eles. Com N = 1000, o MPI com 4 processos saiu ~2x mais lento em 6 de 10
# execucoes sem afinidade, e em 0 de 10 com ela; o OpenMP com 4 threads, em 2 de 10.
#
# Feche os outros programas antes: com todas as CPUs ocupadas, qualquer processo
# extra atrasa uma thread/processo e os outros esperam por ele na sincronizacao.
#
# Uso: scripts/medir.sh     (ou: make medir; sem MPI instalado, mede so baseline e OpenMP)
# Gera:
#   resultados/baseline_06_nbody_mesma_sessao.csv   n,steps,repeticao,tempo_s,checksum,descartada
#   resultados/openmp_06_nbody.csv                  n,steps,threads,repeticao,tempo_s,checksum,descartada
#   resultados/mpi_06_nbody.csv                     n,steps,processos,repeticao,tempo_s,comunicacao_s,checksum,descartada
#   resultados/maquina.txt                          nproc, CPU, ambiente, compiladores e data
set -euo pipefail
# Locale neutro: em pt_BR o sort -g e o awk esperam virgula decimal e leem "0.0123" como 0.
export LC_ALL=C
cd "$(dirname "$0")/.."

NS=(500 1000 2000 4000)
THREADS=(1 2 4 8)
PROCS=(1 2 4 8)
STEPS=10
REPS=4
ESFRIAR=${ESFRIAR:-55}       # temperatura (C) para comecar cada N
ESPERA_MAX=${ESPERA_MAX:-180} # espera maxima (s) por N
MPIRUN=(mpirun --use-hwthread-cpus --map-by core --bind-to core)
export OMP_PLACES=cores OMP_PROC_BIND=spread
CSV_BASE=resultados/baseline_06_nbody_mesma_sessao.csv
CSV_OMP=resultados/openmp_06_nbody.csv
CSV_MPI=resultados/mpi_06_nbody.csv
MAQ=resultados/maquina.txt

if command -v mpicxx >/dev/null && command -v mpirun >/dev/null; then
    COM_MPI=1; make -s baseline openmp mpi
else
    COM_MPI=0; PROCS=(); make -s baseline openmp
    echo "aviso: MPI nao instalado; medindo so baseline e OpenMP" >&2
fi

source scripts/info_maquina.sh
{
    info_maquina
    echo "afinidade:  um por nucleo fisico; OpenMP com OMP_PLACES=$OMP_PLACES OMP_PROC_BIND=$OMP_PROC_BIND"
    (( COM_MPI )) && echo "mpi:        $(mpirun --version | head -1); execucao: ${MPIRUN[*]} -np P"
    echo "flags:      -O2 (baseline e mpicxx), -O2 -fopenmp (openmp); escalonamento padrao do OpenMP (static)"
    echo "protocolo:  $REPS execucoes por configuracao, 1a descartada, mediana das outras 3; $STEPS passos;"
    echo "            configuracoes do mesmo N intercaladas; espera ate ${ESFRIAR}C (max ${ESPERA_MAX} s) antes de cada N"
} > "$MAQ"
cat "$MAQ"; echo

echo "n,steps,repeticao,tempo_s,checksum,descartada" > "$CSV_BASE"
echo "n,steps,threads,repeticao,tempo_s,checksum,descartada" > "$CSV_OMP"
echo "n,steps,processos,repeticao,tempo_s,comunicacao_s,checksum,descartada" > "$CSV_MPI"

mediana3() { printf "%s\n" "$@" | sort -g | sed -n 2p; }
campo()    { sed -nE "s/.*[[:space:]]$1=([0-9.]+).*/\1/p"; }

# Roda uma configuracao uma vez. $1 = tipo (base|omp|mpi), $2 = N, $3 = threads/processos, $4 = repeticao
roda() {
    local tipo=$1 n=$2 k=$3 r=$4 out desc
    (( r == 1 )) && desc=sim || desc=nao
    case $tipo in
        base) out=$(./baseline/06_nbody "$n" "$STEPS")
              echo "$n,$STEPS,$r,$(echo "$out" | campo tempo),$(echo "$out" | campo checksum),$desc" >> "$CSV_BASE" ;;
        omp)  out=$(./openmp/06_nbody_openmp "$n" "$STEPS" "$k")
              [[ $(echo "$out" | campo threads) == "$k" ]] || { echo "erro: pedi $k threads: $out" >&2; exit 1; }
              echo "$n,$STEPS,$k,$r,$(echo "$out" | campo tempo),$(echo "$out" | campo checksum),$desc" >> "$CSV_OMP" ;;
        mpi)  out=$("${MPIRUN[@]}" -np "$k" ./mpi/06_nbody_mpi "$n" "$STEPS")
              [[ $(echo "$out" | campo processos) == "$k" ]] || { echo "erro: pedi $k processos: $out" >&2; exit 1; }
              echo "$n,$STEPS,$k,$r,$(echo "$out" | campo tempo),$(echo "$out" | campo comunicacao),$(echo "$out" | campo checksum),$desc" >> "$CSV_MPI" ;;
    esac
}

# Mediana das execucoes validas. $1 = CSV, $2 = N, $3 = coluna do k (0 = baseline), $4 = k, $5 = coluna do valor
med() {
    mediana3 $(awk -F, -v n="$2" -v ck="$3" -v k="$4" -v cv="$5" \
        'NR > 1 && $1 == n && (ck == 0 || $ck == k) && $NF == "nao" {print $cv}' "$1")
}

for n in "${NS[@]}"; do
    echo "== N=$n (processador: $(esfria))"
    for r in $(seq 1 $REPS); do
        roda base "$n" 0 "$r"
        for t in "${THREADS[@]}"; do roda omp "$n" "$t" "$r"; done
        for p in "${PROCS[@]}";   do roda mpi "$n" "$p" "$r"; done
    done
    tb=$(med "$CSV_BASE" "$n" 0 0 4)
    printf "  %-14s mediana=%s s\n" baseline "$tb"
    for t in "${THREADS[@]}"; do
        m=$(med "$CSV_OMP" "$n" 3 "$t" 5)
        printf "  %-14s mediana=%s s  speedup=%.2f\n" "threads=$t" "$m" "$(awk -v b="$tb" -v m="$m" 'BEGIN{print b/m}')"
    done
    for p in "${PROCS[@]}"; do
        m=$(med "$CSV_MPI" "$n" 3 "$p" 5); c=$(med "$CSV_MPI" "$n" 3 "$p" 6)
        printf "  %-14s mediana=%s s  speedup=%.2f  comunicacao=%s s\n" "processos=$p" "$m" "$(awk -v b="$tb" -v m="$m" 'BEGIN{print b/m}')" "$c"
    done
done
echo
echo "Resultados salvos em $CSV_BASE, $CSV_OMP, $CSV_MPI e $MAQ"
