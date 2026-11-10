# Projeto acadêmico: n-corpos

Projeto da disciplina de Programação Paralela (CCO085, IESB 2026/2).

Simula N partículas (no nosso caso, átomos) interagindo par a par por força bruta, com custo O(N²) a cada passo de tempo. O objetivo é paralelizar essa simulação e medir o ganho de desempenho em relação ao baseline sequencial.

## Arquivos

- `06_nbody.cpp`: baseline sequencial original. É a entrega oficial do Marco 1 e não deve ter lógica nem entrada alteradas.
- `06_nbody_comentado.cpp`: cópia comentada do baseline, só para estudo.

## Compilar e executar

```bash
g++ -O2 -o 06_nbody 06_nbody.cpp
./06_nbody 2000 10   # número de corpos, número de passos
```

A saída mostra o checksum (para conferir se o resultado está correto) e o tempo de execução.
