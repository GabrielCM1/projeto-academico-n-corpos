/* 06 — Simulacao de N corpos com MPI (memoria distribuida)
 * Mesmo algoritmo do baseline (baseline/06_nbody.cpp): forca bruta O(N^2).
 *
 * Compilar: make mpi   (ou: mpicxx -O2 -o 06_nbody_mpi 06_nbody_mpi.cpp)
 * Executar: mpirun -np 4 ./06_nbody_mpi 2000 10   (processos; corpos; passos)
 *
 * Decomposicao de dominio:
 *  - Cada processo fica com um bloco contiguo de particulas i (N/P, e os
 *    primeiros N%P processos ficam com uma a mais). Ele calcula as forcas e
 *    atualiza velocidade e posicao so desse bloco.
 *  - Todos os processos guardam TODAS as posicoes x, y, porque a forca sobre i
 *    depende de todos os j. As massas e posicoes iniciais sao deterministicas,
 *    entao cada processo calcula as suas sem comunicar.
 *  - Ao fim de cada passo, MPI_Allgatherv junta os blocos atualizados de x e y
 *    em todos os processos (Allgatherv porque os blocos podem ter tamanhos
 *    diferentes quando N nao divide por P).
 *
 * Por que o resultado e identico ao do baseline, bit a bit:
 *  - Cada fx[i] soma j de 0 a N-1, na mesma ordem e com as mesmas operacoes.
 *  - O checksum e somado em sequencia no rank 0, que tem todas as posicoes
 *    depois do Allgatherv. Um MPI_Reduce com soma mudaria a ordem das somas
 *    e poderia alterar os ultimos digitos.
 */
#include <mpi.h>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cmath>
using namespace std;

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);
    int rank, P;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &P);

    int N = (argc > 1) ? atoi(argv[1]) : 2000;
    int STEPS = (argc > 2) ? atoi(argv[2]) : 10;
    const double G = 6.674e-11, DT = 0.01, EPS = 1e-9;

    // Estado inicial: igual ao baseline, calculado por todos os processos.
    vector<double> x(N), y(N), vx(N, 0), vy(N, 0), m(N);
    for (int i = 0; i < N; i++) {
        x[i] = (i % 100) * 1.0; y[i] = (i / 100) * 1.0; m[i] = 1.0 + (i % 10);
    }

    // Tamanho (cont) e inicio (desl) do bloco de cada processo.
    vector<int> cont(P), desl(P);
    for (int r = 0, ini = 0; r < P; r++) {
        cont[r] = N / P + (r < N % P ? 1 : 0);
        desl[r] = ini;
        ini += cont[r];
    }
    const int ini = desl[rank], fim = ini + cont[rank];

    MPI_Barrier(MPI_COMM_WORLD);          // todos comecam a cronometrar juntos
    double t0 = MPI_Wtime(), tcomm = 0;

    for (int s = 0; s < STEPS; s++) {     // passos sao dependentes: ficam em sequencia
        vector<double> fx(cont[rank], 0), fy(cont[rank], 0);

        // Forcas, O(N^2/P): so as particulas do meu bloco, contra todas as outras.
        for (int i = ini; i < fim; i++)
            for (int j = 0; j < N; j++) if (i != j) {
                double dx = x[j]-x[i], dy = y[j]-y[i];
                double d2 = dx*dx + dy*dy + EPS;
                double f = G * m[i] * m[j] / d2;
                double inv = 1.0 / sqrt(d2);
                fx[i-ini] += f * dx * inv; fy[i-ini] += f * dy * inv;
            }

        // Atualizacao, O(N/P): so o meu bloco. Ninguem le x, y de outro bloco
        // aqui, entao posso mudar as posicoes antes da troca.
        for (int i = ini; i < fim; i++) {
            vx[i] += DT * fx[i-ini] / m[i]; vy[i] += DT * fy[i-ini] / m[i];
            x[i] += DT * vx[i]; y[i] += DT * vy[i];
        }

        // Comunicacao: cada processo manda o seu bloco de x e y para todos.
        double tc = MPI_Wtime();
        MPI_Allgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL,
                       x.data(), cont.data(), desl.data(), MPI_DOUBLE, MPI_COMM_WORLD);
        MPI_Allgatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL,
                       y.data(), cont.data(), desl.data(), MPI_DOUBLE, MPI_COMM_WORLD);
        tcomm += MPI_Wtime() - tc;
    }
    double tlocal = MPI_Wtime() - t0;

    // O tempo do programa e o do processo mais lento.
    double tempo, comunicacao;
    MPI_Reduce(&tlocal, &tempo, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&tcomm, &comunicacao, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

    // Fora da medicao: o rank 0 reune as velocidades finais, para ter o estado
    // completo (usado na validacao com precisao total).
    if (rank == 0) {
        MPI_Gatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL,
                    vx.data(), cont.data(), desl.data(), MPI_DOUBLE, 0, MPI_COMM_WORLD);
        MPI_Gatherv(MPI_IN_PLACE, 0, MPI_DATATYPE_NULL,
                    vy.data(), cont.data(), desl.data(), MPI_DOUBLE, 0, MPI_COMM_WORLD);
    } else {
        MPI_Gatherv(vx.data() + ini, cont[rank], MPI_DOUBLE,
                    nullptr, nullptr, nullptr, MPI_DOUBLE, 0, MPI_COMM_WORLD);
        MPI_Gatherv(vy.data() + ini, cont[rank], MPI_DOUBLE,
                    nullptr, nullptr, nullptr, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    }

    if (rank == 0) {
        double soma = 0;
        for (int i = 0; i < N; i++) soma += x[i] + y[i];
        printf("N=%d passos=%d processos=%d  checksum=%.6f  tempo=%.6f s  comunicacao=%.6f s\n",
               N, STEPS, P, soma, tempo, comunicacao);
    }

    MPI_Finalize();
    return 0;
}
