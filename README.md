# Projeto acadêmico: n-corpos

Projeto da disciplina Programação Paralela (CCO085, IESB 2026/2), Problema 6: simulação de N-corpos.

O programa simula N partículas que se atraem par a par. A cada passo de tempo, calcula a força de todas as partículas sobre cada uma (custo O(N²)) e depois atualiza velocidades e posições (O(N)). O cálculo de forças concentra 99,9% do tempo, então é ele que paralelizamos com OpenMP (memória compartilhada) e MPI (memória distribuída).

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `baseline/` | `06_nbody.cpp`, o código de referência do professor (não alterar), e uma cópia comentada para estudo |
| `openmp/` | Versão com threads OpenMP |
| `mpi/` | Versão com processos MPI e `MPI_Allgather` a cada passo |
| `resultados/` | Medições em CSV |

## Ambiente

Tudo é compilado e medido dentro do contêiner oficial da disciplina (`iesb/pp-lab:2026.2`, Ubuntu 24.04, g++ 13.3, OpenMP e MPI), montado pelo `ambiente_pp` do professor. Este repositório deve ficar clonado dentro de `ambiente_pp/codigos/`, que o contêiner enxerga como `/lab/codigos/`:

```bash
cd C:\parallel_programing\ambiente_pp\codigos
git clone https://github.com/GabrielCM1/projeto-academico-n-corpos.git
```

No terminal do VS Code, já dentro do contêiner:

```bash
cd /lab/codigos/projeto-academico-n-corpos
make
./baseline/06_nbody 2000 10
```

## Protocolo de medição

- Cada tamanho de entrada roda 4 vezes. A 1ª execução é descartada (aquecimento) e reporta-se a mediana das outras 3.
- `STEPS = 10` e N ∈ {500, 1000, 2000, 4000}.
- Compilação com `-O2`.
- O `checksum` de toda versão paralela deve bater com o do baseline para o mesmo N.

## Baseline medido (Marco 1)

| N | Tempo mediano | Razão para o N anterior |
|---:|---:|---:|
| 500 | 0,011210 s | — |
| 1000 | 0,042036 s | 3,75× |
| 2000 | 0,162749 s | 3,87× |
| 4000 | 0,651698 s | 4,00× |

Dobrar N multiplica o tempo por cerca de 4, o que confirma O(N²). Com fração paralelizável P ≈ 0,999, a Lei de Amdahl prevê speedup de ~3,99× com 4 threads e ~7,94× com 8.
