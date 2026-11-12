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

## Medição padronizada (`make medir`)

Medição feita junto com o baseline e o OpenMP, na mesma sessão e com o mesmo protocolo (detalhes em [`openmp/README.md`](../openmp/README.md#medições-make-medir)):

- contêiner oficial da disciplina, Intel i7-8550U com 4 núcleos físicos (`nproc` = 8);
- 4 execuções por configuração, a 1ª descartada, mediana das outras 3;
- espera o processador esfriar antes de cada N e intercala as configurações;
- um processo por núcleo físico: `mpirun --use-hwthread-cpus --map-by core --bind-to core -np P`.

O `--use-hwthread-cpus` conta cada CPU lógica como uma vaga; sem ele, o `-np 8` nem roda nesta máquina. Com a afinidade padrão do `--use-hwthread-cpus`, o `-np 2` põe os dois processos no **mesmo** núcleo físico. Sem afinidade nenhuma, o sistema às vezes faz isso sozinho: com N = 1000 e 4 processos, 6 de 10 execuções saíram cerca de 2× mais lentas. Com `--map-by core --bind-to core`, nenhuma.

Dados brutos em [`resultados/mpi_06_nbody.csv`](../resultados/mpi_06_nbody.csv). Speedup em relação ao baseline medido na mesma sessão:

| N | baseline | 1 processo | 2 processos | 4 processos | 8 processos |
|---:|---:|---:|---:|---:|---:|
| 500 | 0,0100 s | 1,04× | 1,95× | 2,97× | 3,50× |
| 1000 | 0,0395 s | 1,03× | 1,99× | 3,76× | 3,66× |
| 2000 | 0,1543 s | 1,00× | 1,99× | 3,69× | 3,72× |
| 4000 | 0,6146 s | 0,96× | 1,91× | 3,64× | 3,53× |

Tempo de comunicação (mediana, `Allgatherv` de x e y somado nos 10 passos) para N = 4000:

| Processos | Tempo total | Comunicação | % do total |
|---:|---:|---:|---:|
| 1 | 0,6400 s | 0,000003 s | 0,0% |
| 2 | 0,3220 s | 0,0016 s | 0,5% |
| 4 | 0,1688 s | 0,0022 s | 1,3% |
| 8 | 0,1739 s | 0,0021 s | 1,2% |

As 64 execuções do MPI deram o checksum do baseline.

### O que os tempos mostram

- **1 processo empata com o baseline.** Com um processo só, o `Allgatherv` não troca nada, e o resto do programa é o mesmo código sequencial.
- **2 e 4 processos ficam perto do ideal: 1,9× a 2,0× e 3,6× a 3,8× a partir de N = 1000.** É um pouco melhor que o OpenMP com 4 threads (3,3× a 3,5×), que paga o custo de abrir e fechar regiões paralelas a cada passo. Cada processo MPI tem a própria memória e nunca disputa linha de cache com os outros.
- **A comunicação é pequena nesta máquina.** São no máximo 1,3% do tempo, porque os processos estão no mesmo computador e o OpenMPI troca os dados por memória compartilhada, sem rede.
- **O tempo de "comunicação" inclui espera.** O `Allgatherv` só termina quando todos os processos chegam nele. Se um processo atrasa, os outros ficam parados dentro da chamada, e esse tempo é contado como comunicação. Foi assim que as execuções sem afinidade apareceram: o tempo de comunicação subia junto com o total.
- **8 processos empatam com 4.** Como no OpenMP, os 4 processos extras dividem os núcleos físicos com os 4 primeiros.
- **Diferença para a primeira medição.** Na máquina de 20 núcleos, 8 processos tinham 0,046 s de comunicação. Aqui, com 4 núcleos, a troca é menor, mas também não há núcleos livres para ganhar com mais processos. Por isso as duas tabelas não devem ser comparadas diretamente.
