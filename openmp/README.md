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

Os dois valores têm que ser idênticos ao baseline em todas as combinações: N = 500, 1000, 2000, 4000 × 1, 2, 4, 8 threads × `static`, `dynamic`, `guided`.

Resultado: **48 de 48 combinações idênticas ao baseline**, bit a bit. Detalhes em [`resultados/validacao_openmp.csv`](../resultados/validacao_openmp.csv).

| N | checksum (precisão total) | `vel` |
|---:|---:|---:|
| 500 | 25750.000000000149 | 7.148812846431134e-08 |
| 1000 | 54000.000000000284 | 1.6058748775060036e-07 |
| 2000 | 118000.00000000125 | 3.3896135882577011e-07 |
| 4000 | 276000.00000000617 | 7.0070927876272649e-07 |

Teste do próprio validador: numa cópia com uma corrida proposital (`parallel for` no laço `j`, com várias threads somando no mesmo `fx[i]`), o script acusou diferença em todas as combinações com mais de uma thread. Nessa versão errada, o checksum de 6 casas continuava `25750.000000` para N = 500.

## Escalonamento do laço de forças (`make schedule`)

O laço de forças usa `schedule(runtime)`, que lê a variável `OMP_SCHEDULE`. Assim, o `scripts/comparar_schedule.sh` compara as políticas sem recompilar: 4 execuções por configuração, a 1ª descartada, mediana das outras 3, resultado em `resultados/schedule_06_nbody.csv`.

**Padrão: `static`.** Sem `OMP_SCHEDULE`, o padrão do GCC para `schedule(runtime)` é `dynamic` com bloco 1. Por isso o programa fixa `static` no início do `main`. A carga é igual para todo `i`, porque cada um percorre os N corpos, então não há desbalanceamento para o `dynamic` corrigir.

Medição preliminar (laço de forças com `#pragma omp parallel for schedule(runtime)`, i7-8550U com 4 núcleos físicos). A tabela será refeita com `make schedule` depois que o laço de forças estiver no repositório:

| N | threads | `static` | `static,1` | `dynamic` (bloco 1) | `dynamic,16` | `dynamic,64` | `guided` |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2000 | 4 | 0,064 s | 0,118 s | 0,759 s | 0,057 s | 0,056 s | 0,060 s |
| 4000 | 4 | 0,237 s | 0,480 s | 3,170 s | 0,244 s | 0,246 s | 0,284 s |

`static`, `dynamic,16/64` e `guided` empatam dentro do ruído. Os que distribuem iterações vizinhas para threads diferentes perdem feio.

**Por que `dynamic` (bloco 1) é cerca de 13× mais lento: *false sharing*.** Com bloco 1, `i` e `i+1` vão para threads diferentes. `fx[i]` e `fx[i+1]` ficam na mesma linha de cache de 64 bytes, que comporta 8 `double`. O laço `j` grava `fx[i]` na memória a cada iteração: o assembly gerado com `-O2` tem duas gravações (`movsd`) dentro do laço, porque o compilador não consegue provar que `fx` não se sobrepõe a `x`. Cada gravação invalida a linha de cache nos outros núcleos. O `static,1` sofre o mesmo efeito (cerca de 2× mais lento) e o `dynamic` ainda soma o custo de distribuir as iterações uma a uma.

Evidência:

- Com bloco 16 (16 × 8 bytes = 2 linhas de cache inteiras por thread), o `dynamic` fica igual ao `static`.
- Numa cópia de teste que acumula a força numa variável local e grava `fx[i]` uma vez só, o `dynamic` com bloco 1 cai de 0,77 s para 0,046 s.
