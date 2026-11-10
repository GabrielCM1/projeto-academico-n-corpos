# Versão MPI

Aqui vai o `06_nbody_mpi.cpp`: cada processo calcula as forças e move só o seu bloco de partículas e, ao fim de cada passo, todos trocam as posições atualizadas com `MPI_Allgather`, porque toda partícula precisa da posição de todas as outras.

```bash
make mpi
mpirun -np 4 ./mpi/06_nbody_mpi 2000 10
```
