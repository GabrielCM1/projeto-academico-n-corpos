# Simulação de N-corpos com OpenMP

Simula N partículas que se atraem par a par ao longo de vários passos de tempo. A cada passo, o programa calcula a força de todas as partículas sobre cada uma (custo O(N²)) e depois atualiza velocidades e posições.

O cálculo de forças ocupa quase todo o tempo de execução. Por isso ele é paralelizado com OpenMP e comparado com a versão sequencial.

## Estrutura

```
baseline/     versão sequencial de referência (não alterar)
openmp/       versão paralela com OpenMP
resultados/   medições em CSV
Makefile      compila tudo com "make"
```

## Requisitos

- Linux com `g++` e suporte a OpenMP. No Windows, use o contêiner Docker do ambiente da disciplina.
- `make`

## Usando o contêiner Docker (Windows)

1. Instale o [Docker Desktop](https://www.docker.com/products/docker-desktop) e o [VS Code](https://code.visualstudio.com) com a extensão **Dev Containers**.
2. Clone este repositório dentro da pasta `codigos` do ambiente (`ambiente_pp\codigos\`). O contêiner enxerga essa pasta como `/lab/codigos`.
3. Com o Docker Desktop aberto, abra a pasta `ambiente_pp` no VS Code, tecle `F1` e escolha **Dev Containers: Reopen in Container**.
4. Quando aparecer o selo verde no canto inferior esquerdo, abra o terminal (`` Ctrl+` ``) e entre no projeto:

```bash
cd /lab/codigos/projeto-academico-n-corpos
```

## Compilar

```bash
make            # compila tudo
make baseline   # só a versão sequencial
make openmp     # só a versão OpenMP
make clean      # apaga os executáveis
```

## Executar

```bash
./baseline/06_nbody 2000 10                 # N partículas, passos
./openmp/06_nbody_openmp 2000 10 4          # N partículas, passos, threads
```

O número de threads também pode ser definido com `OMP_NUM_THREADS=4`.

## Conferindo o resultado

Todo programa imprime um `checksum`. Com os mesmos N e passos, a versão OpenMP tem que dar o mesmo checksum da sequencial:

| N (10 passos) | Checksum |
|---:|---:|
| 500 | 25750.000000 |
| 1000 | 54000.000000 |
| 2000 | 118000.000000 |
| 4000 | 276000.000000 |

## Medindo o tempo

- Rode cada configuração 4 vezes, descarte a primeira e use a mediana das outras 3.
- **Speedup** = tempo sequencial ÷ tempo OpenMP
- **Eficiência** = speedup ÷ número de threads

Se o speedup ficar perto de 1, confira quantos núcleos estão disponíveis com `nproc`. No Docker Desktop, esse número se ajusta em *Settings > Resources > CPUs*.
