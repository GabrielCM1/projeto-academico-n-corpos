/* 06 — Simulacao de N corpos com OpenMP (memoria compartilhada)
 * Mesmo algoritmo do baseline (baseline/06_nbody.cpp): forca bruta O(N^2).
 *
 * Compilar: make openmp   (ou: g++ -O2 -fopenmp -o 06_nbody_openmp 06_nbody_openmp.cpp)
 * Executar: ./06_nbody_openmp 2000 10 4                       (corpos; passos; threads)
 *           ./06_nbody_openmp 2000 10                         (sem o 3o argumento: OMP_NUM_THREADS ou todos os nucleos)
 *           OMP_SCHEDULE=dynamic ./06_nbody_openmp 2000 10 4  (outro escalonamento no laco de forcas)
 *
 * Por que o resultado e identico ao do baseline:
 *  - Laco de atualizacao: cada i so le e escreve as proprias posicoes/velocidades.
 *  - Checksum: somado em sequencia, na mesma ordem do baseline. Um reduction(+)
 *    mudaria a ordem das somas e poderia alterar os ultimos digitos.
 */
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cmath>
#include <ctime>
#include <omp.h>
using namespace std;

static double agora() {
    timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

int main(int argc, char** argv) {
    int N = (argc > 1) ? atoi(argv[1]) : 2000;
    int STEPS = (argc > 2) ? atoi(argv[2]) : 10;
    // [Gabriel] numero de threads: 3o argumento, se vier. omp_set_num_threads vale
    // para todas as regioes paralelas seguintes e tem prioridade sobre a variavel
    // OMP_NUM_THREADS. Sem o argumento (ou com valor invalido), fica o padrao do
    // OpenMP: OMP_NUM_THREADS, ou um thread por nucleo.
    if (argc > 3) {
        int T = atoi(argv[3]);
        if (T > 0) omp_set_num_threads(T);
        else fprintf(stderr, "aviso: numero de threads invalido (%s), usando o padrao\n", argv[3]);
    }
    // Quantas threads as regioes paralelas vao usar de fato, para mostrar na saida.
    const int THREADS = omp_get_max_threads();

    // [Joao Pedro] escalonamento do laco de forcas.
    // O laco de forcas usa schedule(runtime), que le a variavel OMP_SCHEDULE;
    // assim o estudo comparativo (scripts/comparar_schedule.sh) troca a politica
    // sem recompilar. Sem a variavel, o padrao do GCC e dynamic com bloco 1, que
    // aqui fica ~13x mais lento por false sharing (ver openmp/README.md).
    // Por isso o padrao e fixado em static: a carga e igual para todo i (cada um
    // percorre os N corpos), entao blocos fixos bastam e nao ha custo de distribuicao.
    if (getenv("OMP_SCHEDULE") == nullptr) omp_set_schedule(omp_sched_static, 0);

    const double G = 6.674e-11, DT = 0.01, EPS = 1e-9;

    vector<double> x(N), y(N), vx(N, 0), vy(N, 0), m(N);
    for (int i = 0; i < N; i++) {
        x[i] = (i % 100) * 1.0; y[i] = (i / 100) * 1.0; m[i] = 1.0 + (i % 10);
    }

    double t0 = agora();
    for (int s = 0; s < STEPS; s++) {   // passos sao dependentes: ficam em sequencia
        vector<double> fx(N, 0), fy(N, 0);

        // [Henrique] laco de forcas, O(N^2): o hotspot (99,9% do tempo).
        // Cada thread recebe um bloco de indices i e so escreve em fx[i]/fy[i]
        // desse bloco; x, y e m sao so lidos. Nenhuma posicao e escrita por duas
        // threads, entao nao ha condicao de corrida (sem critical/atomic/reduction).
        // j, dx, dy, d2, f e inv sao declarados dentro do laco: privados de cada thread.
        // schedule(runtime): usa o escalonamento definido no inicio do main (static
        // por padrao) ou o de OMP_SCHEDULE, para o estudo comparativo.
        #pragma omp parallel for schedule(runtime)
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) if (i != j) {
                double dx = x[j]-x[i], dy = y[j]-y[i];
                double d2 = dx*dx + dy*dy + EPS;
                double f = G * m[i] * m[j] / d2;
                double inv = 1.0 / sqrt(d2);
                fx[i] += f * dx * inv; fy[i] += f * dy * inv;
            }

        // [Joao Pedro] laco de atualizacao, O(N): cada i so mexe nas proprias
        // variaveis, entao nao ha condicao de corrida. A barreira implicita no fim
        // do parallel for do laco de forcas garante que todas as forcas estao
        // prontas antes de qualquer posicao mudar. Aqui a carga e uniforme e o
        // trabalho por i e pequeno: static, sem custo de distribuicao.
        #pragma omp parallel for schedule(static)
        for (int i = 0; i < N; i++) {
            vx[i] += DT * fx[i] / m[i]; vy[i] += DT * fy[i] / m[i];
            x[i] += DT * vx[i]; y[i] += DT * vy[i];
        }
    }
    double t1 = agora();

    double soma = 0;
    for (int i = 0; i < N; i++) soma += x[i] + y[i];
    // [Gabriel] saida no mesmo formato do baseline, com o numero de threads usado
    printf("N=%d passos=%d threads=%d  checksum=%.6f  tempo=%.6f s\n", N, STEPS, THREADS, soma, t1 - t0);
    return 0;
}
