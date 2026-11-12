/* 06 — Perfilamento do baseline (versao instrumentada)
 * Copia do baseline/06_nbody.cpp com cronometros em volta de cada trecho.
 * A logica e a entrada sao as mesmas: tem que dar o mesmo checksum do baseline.
 * O baseline oficial continua sendo o 06_nbody.cpp, sem nenhuma alteracao.
 *
 * Compilar: make perfil   (ou: g++ -O2 -o 06_nbody_perfil 06_nbody_perfil.cpp)
 * Executar: ./06_nbody_perfil 2000 10   (num. de corpos; num. de passos)
 *
 * Trechos medidos:
 *   inicializacao  posicoes e massas iniciais, O(N)           (fora do tempo do baseline)
 *   alocacao       criar e zerar fx/fy a cada passo, O(N)     (dentro do tempo; serial)
 *   forcas         laco duplo i x j, O(N^2)                   (dentro do tempo; paralelizado)
 *   atualizacao    velocidades e posicoes, O(N)               (dentro do tempo; paralelizado)
 *   outros         resto do laco de passos: liberar fx/fy,     (dentro do tempo; serial)
 *                  controle do laco e os proprios cronometros
 *   checksum       soma final, O(N)                           (fora do tempo do baseline)
 * "tempo" e o mesmo intervalo que o baseline mede (so o laco de passos).
 */
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cmath>
#include <ctime>
using namespace std;

static double agora() {
    timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

int main(int argc, char** argv) {
    int N = (argc > 1) ? atoi(argv[1]) : 2000;
    int STEPS = (argc > 2) ? atoi(argv[2]) : 10;
    const double G = 6.674e-11, DT = 0.01, EPS = 1e-9;

    double i0 = agora();
    vector<double> x(N), y(N), vx(N, 0), vy(N, 0), m(N);
    for (int i = 0; i < N; i++) {
        x[i] = (i % 100) * 1.0; y[i] = (i / 100) * 1.0; m[i] = 1.0 + (i % 10);
    }
    double t_init = agora() - i0;

    double t_aloc = 0, t_forcas = 0, t_atual = 0;
    double t0 = agora();
    for (int s = 0; s < STEPS; s++) {
        double a0 = agora();
        vector<double> fx(N, 0), fy(N, 0);
        double a1 = agora();
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) if (i != j) {
                double dx = x[j]-x[i], dy = y[j]-y[i];
                double d2 = dx*dx + dy*dy + EPS;
                double f = G * m[i] * m[j] / d2;
                double inv = 1.0 / sqrt(d2);
                fx[i] += f * dx * inv; fy[i] += f * dy * inv;
            }
        double a2 = agora();
        for (int i = 0; i < N; i++) {
            vx[i] += DT * fx[i] / m[i]; vy[i] += DT * fy[i] / m[i];
            x[i] += DT * vx[i]; y[i] += DT * vy[i];
        }
        double a3 = agora();
        t_aloc += a1 - a0; t_forcas += a2 - a1; t_atual += a3 - a2;
    }
    double t1 = agora();
    double t_outros = (t1 - t0) - t_aloc - t_forcas - t_atual;

    double c0 = agora();
    double soma = 0;
    for (int i = 0; i < N; i++) soma += x[i] + y[i];
    double t_chk = agora() - c0;

    printf("N=%d passos=%d  checksum=%.6f  tempo=%.6f s\n", N, STEPS, soma, t1 - t0);
    printf("perfil: inicializacao=%.9f alocacao=%.9f forcas=%.9f atualizacao=%.9f outros=%.9f checksum=%.9f\n",
           t_init, t_aloc, t_forcas, t_atual, t_outros, t_chk);
    return 0;
}
