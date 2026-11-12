# Resultados

Todos os arquivos desta pasta são gerados pelos scripts em `scripts/`, pelos alvos do `make`. Em cada CSV de medição:

- cada linha é uma execução;
- a coluna `descartada` marca a 1ª execução de cada configuração, que é aquecimento;
- o valor de cada configuração é a **mediana das 3 linhas com `descartada = nao`**.

## Arquivos

| Arquivo | Gerado por | O que tem |
|---|---|---|
| `baseline_06_nbody_mesma_sessao.csv` | `make medir` | sequencial, N = 500 a 4000, medido na mesma sessão do OpenMP e do MPI. **Use este para o speedup.** |
| `openmp_06_nbody.csv` | `make medir` | OpenMP com 1, 2, 4 e 8 threads |
| `mpi_06_nbody.csv` | `make medir` | MPI com 1, 2, 4 e 8 processos, com o tempo de comunicação |
| `maquina.txt` | `make medir` | máquina, ambiente, afinidade e temperatura no início de cada N |
| `fraca_baseline_06_nbody.csv`, `fraca_openmp_06_nbody.csv`, `fraca_mpi_06_nbody.csv` | `make fraca` | escalabilidade fraca: N = 1000·√P. A coluna `threads`/`processos` é o P de cada N. |
| `maquina_fraca.txt` | `make fraca` | o mesmo, para a sessão da escalabilidade fraca |
| `perfil_06_nbody.csv`, `maquina_perfil.txt` | `make perfil` | tempo de cada trecho do sequencial (ver [`baseline/README.md`](../baseline/README.md)) |
| `validacao_openmp.csv`, `validacao_mpi.csv` | `make validar`, `make validar-mpi` | comparação com o baseline em precisão total: 72 de 72 e 30 de 30 iguais |
| `schedule_06_nbody.csv` | `make schedule` | comparação de `static`, `dynamic` e `guided` no OpenMP (ver [`openmp/README.md`](../openmp/README.md)). Medido antes da padronização, fora do contêiner oficial. |
| `baseline_06_nbody.csv` | Marco 1 | sequencial medido em setembro, em outra sessão. Fica como histórico e **não** entra no speedup. |

Tudo, menos o `schedule` e o do Marco 1, foi medido no contêiner oficial da disciplina (`iesb/pp-lab:2026.2`). A máquina é um Intel i7-8550U com 4 núcleos físicos (`nproc` = 8). O protocolo é o mesmo em todos os casos:

- 4 execuções por configuração, a 1ª descartada;
- espera o processador esfriar até 55 °C antes de cada tamanho;
- configurações do mesmo tamanho intercaladas;
- uma thread ou processo por núcleo físico.

## Escalabilidade fraca (`make fraca`)

Na escalabilidade **forte** (`make medir`), o problema fica do mesmo tamanho e o número de threads ou processos aumenta. Na **fraca**, o problema cresce junto com P, para cada thread ou processo ter sempre o mesmo trabalho. Se o tempo continuar igual, a escalabilidade é perfeita.

Como o cálculo de forças custa N² por passo, o trabalho por thread ou processo fica constante com **N = 1000·√P**:

| P | 1 | 2 | 4 | 8 |
|---|---:|---:|---:|---:|
| N | 1000 | 1414 | 2000 | 2828 |
| N² ÷ P | 1,00·10⁶ | 1,00·10⁶ | 1,00·10⁶ | 1,00·10⁶ |

Eficiência fraca = T(1, 1000) ÷ T(P, 1000·√P), comparando cada versão com ela mesma rodando com 1 thread ou processo. O ideal é 1.

Medianas, em segundos. Os 4 blocos começaram com o processador a 55 °C ou menos, e todas as execuções deram o checksum do baseline com o mesmo N:

| P | N | Sequencial | OpenMP | Eficiência OpenMP | MPI | Comunicação MPI | Eficiência MPI |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1000 | 0,0394 | 0,0407 | 1,000 | 0,0387 | 0,000001 | 1,000 |
| 2 | 1414 | 0,0781 | 0,0418 | 0,973 | 0,0395 | 0,00019 | 0,980 |
| 4 | 2000 | 0,1555 | 0,0443 | 0,919 | 0,0432 | 0,0019 | 0,895 |
| 8 | 2828 | 0,3118 | 0,0865 | 0,470 | 0,0824 | 0,0010 | 0,469 |

**O tamanho escolhido realmente multiplica o trabalho por P.** O tempo do sequencial cresce 1,98×, 3,95× e 7,92× para P = 2, 4 e 8.

**Speedup escalado.** É o tempo do sequencial no N de cada P dividido pelo tempo da versão paralela:

| P | OpenMP | MPI |
|---:|---:|---:|
| 2 | 1,87× | 1,98× |
| 4 | 3,51× | 3,60× |
| 8 | 3,60× | 3,79× |

### O que os números mostram

- **Até 4 threads ou processos, a escalabilidade fraca é boa: eficiência de 0,90 a 0,98.** O tempo quase não muda enquanto o problema e o número de núcleos crescem juntos.
- **A queda com P = 4 vem de dois lugares.** Com os 4 núcleos ocupados, o processador baixa a frequência para caber no limite de potência. No MPI, o `Allgatherv` também cresce: cada processo recebe as posições de todas as N partículas, e N cresceu. A comunicação passa a ser 4,4% do tempo.
- **Com P = 8, a eficiência cai para 0,47.** A máquina tem só 4 núcleos físicos. As 8 threads dividem 4 unidades de ponto flutuante, então a capacidade de conta é a mesma de P = 4. O trabalho dobra e o tempo também (0,0443 → 0,0865 s no OpenMP). Contando só os 4 núcleos físicos, a eficiência equivale a cerca de 0,94.
- **Lei de Gustafson.** Ela diz que, quando o problema cresce com P, o speedup escalado é P − α·(P − 1), onde α é a fração serial. Pelo [perfilamento](../baseline/README.md), α fica abaixo de 0,1%, então a previsão é praticamente P. Os valores medidos até 4 (1,9× a 2,0× com 2 e 3,5× a 3,6× com 4) ficam perto disso. A diferença vem do hardware (frequência e hyper-threading), não do código.
