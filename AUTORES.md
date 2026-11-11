# Autores

Projeto Acadêmico de Programação Paralela (CCO085), 2026/2, turma CCODM3B.
Problema 6: Simulação de N-corpos.

| Integrante | GitHub | Frente técnica |
|---|---|---|
| João Pedro Gonçalves Campos Silva | [@joaopedrocampos1](https://github.com/joaopedrocampos1) | Baseline e Perfilamento |
| Henrique Amorim da Silva | [@113nr1qu3](https://github.com/113nr1qu3) | Versão OpenMP (memória compartilhada) |
| Gabriel Castagnaro Macêdo | [@GabrielCM1](https://github.com/GabrielCM1) | Versão MPI (memória distribuída) |

## O que cada frente cobre

- **Baseline e Perfilamento:** análise de complexidade do código sequencial, perfilamento dos trechos, tempo de referência, fração paralelizável e speedup previsto pela Lei de Amdahl, protocolo de medição.
- **Versão OpenMP:** paralelização em memória compartilhada, tratamento de condições de corrida, comparação de escalonamentos e curva de speedup por threads.
- **Versão MPI:** decomposição entre processos, operação coletiva, overhead de comunicação e curva de speedup por processos.

## Divisão das tarefas do Marco 2

As tarefas estão nas [issues do repositório](https://github.com/GabrielCM1/projeto-academico-n-corpos/issues):

| Issue | Tarefa | Responsáveis |
|---|---|---|
| #1 | Paralelizar o código com OpenMP | Gabriel (argumentos e saída), Henrique (laço de forças), João Pedro (laço de atualização e escalonamento) |
| #2 | Validar o resultado do OpenMP contra o baseline | João Pedro, Gabriel |
| #3 | Medir os tempos da versão OpenMP | Gabriel |
| #4 | Calcular speedup e eficiência e fazer os gráficos | a definir |
| #5 | Relatório e apresentação do Marco 2 | Gabriel |
| #6 | Versão MPI | a definir |

Cada integrante responde pela própria frente, e todos revisam o trabalho dos outros para poder explicar qualquer parte do projeto.
