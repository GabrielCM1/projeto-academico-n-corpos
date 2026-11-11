# Versão MPI

Aqui vai o `06_nbody_mpi.cpp`: o mesmo algoritmo do baseline, com as partículas divididas entre processos.

- Cada processo calcula as forças e move só o seu bloco de partículas.
- Ao fim de cada passo, todos trocam as posições atualizadas com `MPI_Allgatherv`, porque toda partícula precisa da posição de todas as outras.
- O plano completo está na issue #6.

```bash
make mpi
mpirun -np 4 ./mpi/06_nbody_mpi 2000 10   # processos, partículas, passos
```
