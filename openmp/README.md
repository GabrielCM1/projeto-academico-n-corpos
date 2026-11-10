# Versão OpenMP

Aqui vai o `06_nbody_openmp.cpp`: o mesmo algoritmo do baseline, com o laço de cálculo de forças dividido entre threads (`#pragma omp parallel for`).

Cada thread cuida de um pedaço das partículas e só escreve em `fx[i]`/`fy[i]` do próprio pedaço, então não há condição de corrida.

```bash
make openmp
./openmp/06_nbody_openmp 2000 10 4   # corpos, passos, threads
```
