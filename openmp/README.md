# Versão OpenMP

`06_nbody_openmp.cpp` roda o mesmo algoritmo do baseline, com os laços de cada passo divididos entre threads.

```bash
make openmp
./openmp/06_nbody_openmp 2000 10 4                         # corpos, passos, threads
OMP_SCHEDULE=dynamic ./openmp/06_nbody_openmp 2000 10 4    # outro escalonamento no laço de forças
```

## O que é paralelizado

| Trecho | Custo | Como |
|---|---|---|
| Laço de passos `s` | — | **Sequencial.** O passo `s+1` usa as posições do passo `s`. |
| Laço de forças `i` × `j` | O(N²) (o hotspot) | `#pragma omp parallel for schedule(runtime)` no `i`, com `static` como padrão. |
| Laço de atualização `i` | O(N) | `#pragma omp parallel for schedule(static)` |
| Checksum final | O(N) | **Sequencial**, para manter a mesma ordem de soma do baseline. |

### Por que não há condição de corrida

- **Forças:** a thread que recebe o índice `i` é a única que escreve em `fx[i]` e `fy[i]`. `x`, `y` e `m` são só lidos. Ninguém escreve na mesma posição, então não precisa de `critical`, `atomic` nem `reduction`.
- **Atualização:** cada `i` lê e escreve só as próprias `x[i]`, `y[i]`, `vx[i]`, `vy[i]`.
- **Barreira:** o fim de cada `parallel for` tem uma barreira implícita. Todas as forças ficam prontas antes de qualquer posição mudar. Sem ela, uma thread poderia ler um `x[j]` já atualizado no passo atual.

### Por que o resultado tem que ser idêntico bit a bit

Cada `fx[i]` continua sendo somado com `j` indo de `0` a `N-1`, na mesma ordem do baseline. Só muda *qual thread* faz a conta, não *a ordem* das somas. Se o checksum final usasse `reduction(+:soma)`, cada thread somaria um pedaço e os pedaços seriam juntados em outra ordem. Como a soma em ponto flutuante não é associativa, os últimos dígitos poderiam mudar.

## Validação (`make validar`)

**O checksum de 6 casas não basta.** As forças são minúsculas (G = 6,674·10⁻¹¹), então as posições só mudam por volta da 9ª casa decimal. Um programa com as forças **zeradas** também imprime `checksum=118000.000000` para N = 2000.

Por isso, o `scripts/validar_openmp.sh` compila cópias temporárias do baseline e do OpenMP. Os originais não mudam. As cópias imprimem também:

- o checksum com **precisão total** (`%.17g`, que identifica o `double` exato);
- `vel` = Σ(|vx| + |vy|), que depende diretamente de todas as forças.

Os dois valores têm que ser idênticos ao baseline em todas as combinações: N = 500, 1000, 1414, 2000, 2828, 4000 × 1, 2, 4, 8 threads × `static`, `dynamic`, `guided`. Os tamanhos 1414 e 2828 são os da escalabilidade fraca.

Resultado: **72 de 72 combinações idênticas ao baseline**, bit a bit. Detalhes em [`resultados/validacao_openmp.csv`](../resultados/validacao_openmp.csv).

| N | checksum (precisão total) | `vel` |
|---:|---:|---:|
| 500 | 25750.000000000149 | 7.148812846431134e-08 |
| 1000 | 54000.000000000284 | 1.6058748775060036e-07 |
| 1414 | 78687.000000000393 | 2.3391601313380268e-07 |
| 2000 | 118000.00000000125 | 3.3896135882577011e-07 |
| 2828 | 177562.00000000253 | 4.8859842802585863e-07 |
| 4000 | 276000.00000000617 | 7.0070927876272649e-07 |

Teste do próprio validador: numa cópia com uma corrida proposital (`parallel for` no laço `j`, com várias threads somando no mesmo `fx[i]`), o script acusou diferença em todas as combinações com mais de uma thread. Nessa versão errada, o checksum de 6 casas continuava `25750.000000` para N = 500.

## Escalonamento do laço de forças (`make schedule`)

O laço de forças usa `schedule(runtime)`, que lê a variável `OMP_SCHEDULE`. Assim, o `scripts/comparar_schedule.sh` compara as políticas sem recompilar: 4 execuções por configuração, a 1ª descartada, mediana das outras 3, resultado em `resultados/schedule_06_nbody.csv`.

**Padrão: `static`.** Sem `OMP_SCHEDULE`, o padrão do GCC para `schedule(runtime)` é `dynamic` com bloco 1. Por isso o programa fixa `static` no início do `main`. A carga é igual para todo `i`, porque cada um percorre os N corpos, então não há desbalanceamento para o `dynamic` corrigir.

Mediana de 3 execuções, depois de descartar 1 de aquecimento (i7-8550U: 4 núcleos físicos, 8 threads com hyper-threading). Dados em [`resultados/schedule_06_nbody.csv`](../resultados/schedule_06_nbody.csv):

| N | threads | `static` | `static,1` | `dynamic` (bloco 1) | `dynamic,16` | `dynamic,64` | `guided` |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2000 | 4 | 0,060 s | 0,138 s | 0,778 s | 0,061 s | 0,058 s | 0,063 s |
| 2000 | 8 | 0,067 s | 0,100 s | 0,454 s | 0,064 s | 0,096 s | 0,067 s |
| 4000 | 4 | 0,242 s | 0,343 s | 3,210 s | 0,248 s | 0,252 s | 0,256 s |
| 4000 | 8 | 0,265 s | 0,337 s | 1,886 s | 0,261 s | 0,252 s | 0,259 s |

`static`, `dynamic,16/64` e `guided` empatam dentro do ruído. Os que distribuem iterações vizinhas para threads diferentes perdem feio.

**Por que `dynamic` (bloco 1) é 7× a 13× mais lento: *false sharing*.** Com bloco 1, `i` e `i+1` vão para threads diferentes. `fx[i]` e `fx[i+1]` ficam na mesma linha de cache de 64 bytes, que comporta 8 `double`. O laço `j` grava `fx[i]` na memória a cada iteração: o assembly gerado com `-O2` tem duas gravações (`movsd`) dentro do laço, porque o compilador não consegue provar que `fx` não se sobrepõe a `x`. Cada gravação invalida a linha de cache nos outros núcleos. O `static,1` sofre o mesmo efeito (1,3× a 2,3× mais lento) e o `dynamic` ainda soma o custo de distribuir as iterações uma a uma.

Evidência:

- Com bloco 16 (16 × 8 bytes = 2 linhas de cache inteiras por thread), o `dynamic` fica igual ao `static`.
- Numa cópia de teste que acumula a força numa variável local e grava `fx[i]` uma vez só, o `dynamic` com bloco 1 cai de 0,77 s para 0,046 s.

## Medições (`make medir`)

O `scripts/medir.sh` mede o baseline, o OpenMP e o MPI **na mesma sessão**, para os speedups compararem tempos tirados nas mesmas condições. Os resultados do MPI estão em [`mpi/README.md`](../mpi/README.md).

Protocolo:

- 4 execuções por configuração, a 1ª descartada (aquecimento), mediana das outras 3. N = 500, 1000, 2000, 4000. 10 passos. 1, 2, 4 e 8 threads.
- Antes de cada N, o script espera o processador esfriar até 55 °C. Dentro do mesmo N, ele roda a 1ª execução de todas as configurações, depois a 2ª, e assim por diante.
- Uma thread por núcleo físico (`OMP_PLACES=cores OMP_PROC_BIND=spread`). A 2ª thread de hardware de cada núcleo só entra com 8 threads.

Ambiente ([`resultados/maquina.txt`](../resultados/maquina.txt)): contêiner oficial da disciplina (`iesb/pp-lab:2026.2`), Intel i7-8550U (4 núcleos físicos, `nproc` = 8), g++ 13.3, na tomada. Dados brutos em [`resultados/openmp_06_nbody.csv`](../resultados/openmp_06_nbody.csv) e [`resultados/baseline_06_nbody_mesma_sessao.csv`](../resultados/baseline_06_nbody_mesma_sessao.csv). O `baseline_06_nbody.csv` do Marco 1 foi medido em outro dia e não entra no cálculo do speedup.

Medianas (em segundos):

| N | baseline | 1 thread | 2 threads | 4 threads | 8 threads |
|---:|---:|---:|---:|---:|---:|
| 500 | 0,0100 | 0,0103 | 0,0057 | 0,0037 | 0,0034 |
| 1000 | 0,0395 | 0,0408 | 0,0209 | 0,0117 | 0,0114 |
| 2000 | 0,1543 | 0,1598 | 0,0866 | 0,0438 | 0,0439 |
| 4000 | 0,6146 | 0,6771 | 0,3613 | 0,1861 | 0,1903 |

As 64 execuções do OpenMP deram o checksum do baseline. A dispersão típica entre as 3 repetições válidas foi de 2%.

### O que os tempos mostram

- **1 thread é 3% a 10% mais lento que o baseline.** É o custo do OpenMP sem nenhum paralelismo: abrir e fechar 2 regiões paralelas por passo e distribuir o laço com `schedule(runtime)`. O MPI com 1 processo não tem esse custo e empata com o baseline.
- **Com 4 threads, o tempo cai 3,3× a 3,5× a partir de N = 1000.** Não chega a 4× por causa do custo acima, das 2 barreiras por passo e da frequência do processador, que cai quando mais núcleos trabalham ao mesmo tempo.
- **8 threads empatam com 4.** A máquina tem só 4 núcleos físicos. A 5ª à 8ª threads dividem a mesma unidade de ponto flutuante com as 4 primeiras, e o laço de forças é praticamente só conta de ponto flutuante.
- **N = 500 rende menos (2,7× com 4 threads).** O programa inteiro roda em cerca de 10 ms, então os custos fixos pesam mais.

### Problemas de medição encontrados (e corrigidos)

As duas primeiras rodadas deram números inconsistentes. Os três ajustes do protocolo vieram delas:

1. **Temperatura.** Medindo o OpenMP inteiro e depois o MPI, o MPI pegava o processador quente e com a frequência reduzida. Com N = 500, o MPI de 1 processo chegou a sair 2× mais lento que o baseline. Por isso o script espera o processador esfriar antes de cada N e intercala as configurações.
2. **Afinidade.** Sem fixar as threads, o sistema às vezes põe duas no **mesmo** núcleo físico. Essas duas andam na metade da velocidade, e as outras esperam por elas na barreira. Com N = 1000 e 10 repetições, 2 das 10 execuções de 4 threads saíram cerca de 2× mais lentas sem afinidade, e nenhuma com afinidade. No MPI com 4 processos foram 6 de 10, a ponto de a mediana de 3 pegar o valor errado.
3. **Outros programas abertos.** Numa medição com o Discord aberto, 8 threads chegaram a ficar 8× mais lentas que 4 em N = 500.

Para reproduzir os números à mão, use a mesma afinidade: `OMP_PLACES=cores OMP_PROC_BIND=spread ./openmp/06_nbody_openmp 4000 10 4`.
