# Versão MPI

`06_nbody_mpi.cpp` roda o mesmo algoritmo do baseline, com as partículas divididas entre processos.

```bash
make mpi
mpirun -np 4 ./mpi/06_nbody_mpi 2000 10   # processos, partículas, passos
```

A saída mostra o `checksum`, o `tempo` total (o do processo mais lento) e quanto desse tempo foi `comunicacao`.

## Como funciona

1. **Divisão:** cada processo fica com um bloco de partículas seguidas. Quando N não divide pelo número de processos, os primeiros ficam com uma partícula a mais.
2. **Cálculo:** cada processo calcula as forças e move só as partículas do seu bloco. Para isso ele precisa da posição de **todas** as partículas, então todo processo guarda a lista completa de posições.
3. **Troca:** ao fim de cada passo, `MPI_Allgatherv` manda o bloco atualizado de cada processo para todos os outros. É a única comunicação dentro do laço.

O estado inicial é calculado por cada processo, sem comunicação, porque é determinístico.

## Por que o resultado é idêntico ao baseline

- Cada força soma as outras partículas na mesma ordem do baseline, com as mesmas contas.
- O checksum é somado em sequência no processo 0. Um `MPI_Reduce` com soma mudaria a ordem e poderia alterar os últimos dígitos.

Para conferir com precisão total (N = 500 a 4000, com 1, 2, 3, 4 e 8 processos):

```bash
make validar-mpi
```

O `-np 3` testa o caso em que os blocos têm tamanhos diferentes.

## Primeira medição (indicativa)

N = 4000, 10 passos, mediana de 3 execuções (a 1ª descartada), contêiner com 20 núcleos:

| Processos | Tempo | Comunicação | Speedup |
|---:|---:|---:|---:|
| sequencial | 0,472 s | — | 1,00× |
| 1 | 0,475 s | 0,000 s | 0,99× |
| 2 | 0,241 s | 0,003 s | 1,96× |
| 4 | 0,118 s | 0,002 s | 4,00× |
| 8 | 0,130 s | 0,046 s | 3,63× |

Até 4 processos, o speedup é praticamente o ideal. Com 8, a comunicação passa a pesar: cada passo troca todas as posições entre todos os processos, e o tempo de troca supera o que se ganha dividindo o cálculo.
