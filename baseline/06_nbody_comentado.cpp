/* ============================================================
 * 06_nbody.cpp — VERSAO COMENTADA PARA ESTUDO
 * ============================================================
 * Esta é uma cópia comentada do baseline original, só para
 * vocês entenderem o código com calma. A ENTREGA OFICIAL do
 * Marco 1 continua sendo o arquivo 06_nbody.cpp original,
 * sem nenhuma alteração de lógica ou de entrada — como o
 * README.md da disciplina exige.
 *
 * O que o programa faz, em uma frase: simula N partículas se
 * atraindo por gravidade, movendo todas elas STEPS vezes
 * seguidas ("passos de tempo"), e no final imprime um número
 * de conferência (checksum) e o tempo que levou.
 * ============================================================ */

#include <cstdio>   // printf — igual ao <stdio.h> do C
#include <cstdlib>  // atoi   — igual ao <stdlib.h> do C
#include <vector>   // vector — o "array que se redimensiona sozinho" do C++
#include <cmath>    // sqrt   — igual ao <math.h> do C
#include <ctime>    // clock_gettime — igual ao <time.h> do C

// Isso só permite escrever "vector" em vez de "std::vector" em
// todo o arquivo. Não muda a lógica de nada, é só preguiça boa.
using namespace std;

/* agora() — um "cronômetro". Pergunta pro relógio do computador
 * que horas são agora, em segundos (com muita casa decimal de
 * precisão), pra dar pra medir quanto tempo uma parte do
 * programa demorou. "static" aqui só quer dizer "essa função
 * só existe dentro deste arquivo" — não afeta o comportamento. */
static double agora() {
    timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

int main(int argc, char** argv) {
    /* argc e argv capturam o que foi digitado no terminal.
     * Exemplo: se você roda   ./06_nbody 2000 10
     *   argc = 3
     *   argv[0] = "./06_nbody"   (nome do programa, quase nunca se usa)
     *   argv[1] = "2000"          (texto! não é o número ainda)
     *   argv[2] = "10"            (texto! não é o número ainda)
     *
     * char** argv é só "um array de strings" (você já manja
     * ponteiro — char* é uma string, char** é um array delas). */

    /* atoi() converte TEXTO pra NÚMERO ("ascii to integer").
     * atoi("2000") devolve o inteiro 2000 de verdade.
     *
     * A linha abaixo usa o operador ternário (condição ? a : b),
     * que é só um if-else escrito numa linha. É EXATAMENTE igual a:
     *
     *   int N;
     *   if (argc > 1) { N = atoi(argv[1]); }
     *   else          { N = 2000; }
     *
     * Ou seja: "se a pessoa digitou um número de partículas, usa
     * ele; senão, usa 2000 partículas por padrão." */
    int N = (argc > 1) ? atoi(argv[1]) : 2000;

    // Mesma ideia: usa o número de passos digitado, ou 10 por padrão.
    int STEPS = (argc > 2) ? atoi(argv[2]) : 10;

    // Constantes de física. G é a força da gravidade (um número
    // fixo do universo). DT ("delta T") é o tamanho de cada salto
    // no tempo — quanto "tempo simulado" passa a cada passo. EPS
    // é um número minúsculo só pra nunca dividir por zero, caso
    // duas partículas fiquem exatamente coladas.
    const double G = 6.674e-11, DT = 0.01, EPS = 1e-9;

    /* vector<double> x(N) é a versão C++ de:
     *     double *x = malloc(N * sizeof(double));
     * Funciona igual a um array normal (x[i] funciona igual),
     * só que se auto-libera no final, sem precisar de free().
     *
     * x, y      = posição de cada partícula (coordenadas)
     * vx, vy    = velocidade de cada partícula (começam em 0,
     *             ou seja, paradas)
     * m         = massa de cada partícula                        */
    vector<double> x(N), y(N), vx(N, 0), vy(N, 0), m(N);

    // Espalha as N partículas numa grade (fileiras de 100 em 100)
    // e dá uma massa a cada uma. É só a "posição de largada".
    for (int i = 0; i < N; i++) {
        x[i] = (i % 100) * 1.0;
        y[i] = (i / 100) * 1.0;
        m[i] = 1.0 + (i % 10);
    }

    double t0 = agora();  // cronômetro: começa a contar aqui

    // ================= O LOOP PRINCIPAL =================
    // Repete tudo aqui dentro STEPS vezes — cada repetição é
    // um "frame" da simulação avançando no tempo.
    for (int s = 0; s < STEPS; s++) {

        // A cada passo, cria duas listas novas de força
        // (zeradas), uma pra força em x e outra em y, uma
        // posição por partícula.
        vector<double> fx(N, 0), fy(N, 0);

        // ---------- O HOTSPOT: calcular as forças ----------
        // Para cada partícula i, soma a força de atração de
        // TODAS as outras partículas j. Isso é O(N²): com N
        // partículas, são N × N pares pra calcular — é aqui
        // que o programa passa ~100% do tempo dele.
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) if (i != j) {
                double dx = x[j] - x[i], dy = y[j] - y[i];       // distância entre i e j, em x e em y
                double d2 = dx*dx + dy*dy + EPS;                  // distância ao quadrado (Pitágoras) + o EPS de segurança
                double f  = G * m[i] * m[j] / d2;                 // fórmula da gravidade de Newton
                double inv = 1.0 / sqrt(d2);                      // pra "decompor" a força na direção certa
                fx[i] += f * dx * inv;                            // acumula a força em x que i recebe de j
                fy[i] += f * dy * inv;                            // acumula a força em y que i recebe de j
            }

        // ---------- Atualizar posição e velocidade ----------
        // Física básica: força ÷ massa = aceleração; aceleração
        // muda a velocidade; velocidade muda a posição.
        for (int i = 0; i < N; i++) {
            vx[i] += DT * fx[i] / m[i];
            vy[i] += DT * fy[i] / m[i];
            x[i]  += DT * vx[i];
            y[i]  += DT * vy[i];
        }
    }
    // ================= FIM DO LOOP PRINCIPAL =================

    double t1 = agora();  // cronômetro: para de contar aqui

    // Soma a posição final de todas as partículas num único
    // número (checksum). Não tem nada a ver com física — é só
    // uma forma de conferir se a resposta bateu. As versões
    // paralelas de vocês (OpenMP e MPI) têm que dar esse MESMO
    // número pra mesma entrada, senão algo quebrou.
    double soma = 0;
    for (int i = 0; i < N; i++) soma += x[i] + y[i];

    printf("N=%d passos=%d  checksum=%.6f  tempo=%.6f s\n",
           N, STEPS, soma, t1 - t0);
    return 0;
}
