# Baseline e perfilamento

`06_nbody.cpp` é o código sequencial de referência fornecido pelo professor. **Ele não é alterado.** O checksum que ele imprime é o gabarito das versões OpenMP e MPI.

| Arquivo | Para que serve |
|---|---|
| `06_nbody.cpp` | baseline oficial |
| `06_nbody_comentado.cpp` | cópia comentada, para estudo |
| `06_nbody_perfil.cpp` | cópia com cronômetros em volta de cada trecho, para o perfilamento |

```bash
make baseline && ./baseline/06_nbody 2000 10   # corpos, passos
make perfil                                    # perfilamento completo (gera os CSVs)
```

## O que o algoritmo faz

A cada passo de tempo, o programa:

1. **Calcula as forças:** para cada partícula `i`, soma a atração gravitacional de todas as outras `j ≠ i`. É um laço duplo com N·(N−1) iterações.
2. **Atualiza o estado:** converte a força em aceleração (F/m), atualiza a velocidade e, com ela, a posição (método de Euler explícito).

O passo `s+1` usa as posições do passo `s`, então os passos são sequenciais. O paralelismo está **dentro** de cada passo.

## Complexidade

| Trecho | Custo por passo | Total |
|---|---|---|
| Cálculo de forças | O(N²) | O(STEPS·N²) |
| Atualização | O(N) | O(STEPS·N) |
| Alocação de `fx`/`fy` | O(N) | O(STEPS·N) |
| Inicialização e checksum | — | O(N), uma vez só |

Total: **O(STEPS·N²)**, dominado pelo cálculo de forças. Memória: O(N).

Os tempos medidos confirmam: quando N dobra, o tempo multiplica por cerca de 4. Medianas de [`resultados/baseline_06_nbody_mesma_sessao.csv`](../resultados/baseline_06_nbody_mesma_sessao.csv), a mesma sessão das medições de OpenMP e MPI:

| N | Tempo (10 passos) | Razão para o N anterior |
|---:|---:|---:|
| 500 | 0,0100 s | — |
| 1000 | 0,0395 s | 3,95× |
| 2000 | 0,1543 s | 3,91× |
| 4000 | 0,6146 s | 3,98× |

## Perfilamento (`make perfil`)

O `06_nbody_perfil.cpp` repete as contas do baseline e mede cada trecho com `clock_gettime`. Antes de medir, o `scripts/perfilar.sh` confere com precisão total (`%.17g` e a soma das velocidades) que a cópia dá **exatamente** o resultado do baseline nos 4 tamanhos.

Protocolo, o mesmo das outras medições:

- 4 execuções por N, a 1ª descartada, mediana das outras 3;
- espera o processador esfriar até 55 °C antes de cada N;
- contêiner oficial da disciplina ([`resultados/maquina_perfil.txt`](../resultados/maquina_perfil.txt)).

A tabela mostra a repetição de tempo mediano, para as porcentagens somarem 100%. Dados de todas as repetições em [`resultados/perfil_06_nbody.csv`](../resultados/perfil_06_nbody.csv).

| Trecho | N = 500 | N = 1000 | N = 2000 | N = 4000 |
|---|---:|---:|---:|---:|
| Cálculo de forças | 0,011080 s (**99,78%**) | 0,042098 s (**99,90%**) | 0,169837 s (**99,94%**) | 0,679651 s (**99,97%**) |
| Atualização | 0,000014 s (0,12%) | 0,000025 s (0,06%) | 0,000056 s (0,03%) | 0,000128 s (0,02%) |
| Alocação de `fx`/`fy` | 0,000008 s (0,07%) | 0,000015 s (0,04%) | 0,000031 s (0,02%) | 0,000054 s (0,01%) |
| Outros (liberar `fx`/`fy`, controle do laço, cronômetros) | 0,000003 s (0,03%) | 0,000003 s (0,01%) | 0,000008 s (0,005%) | 0,000029 s (0,004%) |
| **Laço de passos (o "tempo" do baseline)** | 0,011105 s | 0,042141 s | 0,169932 s | 0,679862 s |

Fora do tempo que o baseline mede, a inicialização leva de 0,011 a 0,078 ms e o checksum menos de 0,005 ms.

**Hotspot: o cálculo de forças**, com 99,8% a 99,97% do tempo. É o trecho que as versões OpenMP e MPI dividem entre threads e processos. Os números confirmam o Marco 1, que tinha medido 99,9% para N = 2000.

## Fração paralelizável e Lei de Amdahl

As versões paralelas dividem o cálculo de forças e a atualização. O que continua serial dentro do tempo medido é a alocação de `fx`/`fy` e o resto do laço. Então:

P = (forças + atualização) ÷ tempo do laço de passos

S(p) = 1 ÷ ((1 − P) + P ÷ p)

| N | P | S(2) | S(4) | S(8) | Limite (p → ∞) |
|---:|---:|---:|---:|---:|---:|
| 500 | 0,99903 | 1,998× | 3,988× | 7,946× | 1029× |
| 1000 | 0,99957 | 1,999× | 3,995× | 7,976× | 2338× |
| 2000 | 0,99977 | 2,000× | 3,997× | 7,987× | 4314× |
| 4000 | 0,99988 | 2,000× | 3,999× | 7,993× | 8157× |

**A fração serial diminui quando N cresce.** A parte serial é O(N) e a paralelizável é O(N²), então a fração serial cai como 1/N. Problemas maiores escalam melhor.

### O que isso diz sobre os speedups medidos

Pela Lei de Amdahl, com 4 threads ou processos o speedup deveria ser praticamente 4×. Os medidos ficaram em 3,3× a 3,5× no OpenMP e 3,6× a 3,8× no MPI, para N ≥ 1000 ([`openmp/README.md`](../openmp/README.md#medições-make-medir), [`mpi/README.md`](../mpi/README.md#medição-padronizada-make-medir)).

A diferença **não vem da parte serial do código**, que é menor que 0,1%. Ela vem de custos que a Lei de Amdahl não considera:

- **Custo da própria paralelização:** abrir e fechar regiões paralelas, barreiras e a comunicação do MPI. O OpenMP com 1 thread já é 3% a 10% mais lento que o baseline.
- **Frequência do processador:** com mais núcleos trabalhando ao mesmo tempo, o processador do notebook baixa a frequência para caber no limite de potência e temperatura. Cada núcleo fica mais lento que no sequencial.
- **Hyper-threading:** a máquina tem 4 núcleos físicos e 8 lógicos. A Lei de Amdahl prevê 7,99× com 8, mas supõe 8 processadores iguais. Na prática, a 5ª à 8ª threads dividem os mesmos núcleos com as 4 primeiras, e o limite real fica perto de 4×.
