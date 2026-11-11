# Simulação de N-corpos com OpenMP

Simula N partículas que se atraem par a par ao longo de vários passos de tempo. A cada passo, o programa calcula a força de todas as partículas sobre cada uma (custo O(N²)) e depois atualiza velocidades e posições.

O cálculo de forças ocupa quase todo o tempo de execução. Por isso ele é paralelizado com OpenMP e comparado com a versão sequencial.

```
baseline/     versão sequencial de referência (não alterar)
openmp/       versão paralela com OpenMP
scripts/      validação e comparação de escalonamento
resultados/   medições em CSV
Makefile      compila tudo com "make"
```

---

## Como funciona o ambiente

O código roda num **contêiner Docker**: um Linux pronto, com `g++` e OpenMP, que roda dentro do Windows. Você não precisa instalar compilador nenhum.

O detalhe mais importante: **a pasta `ambiente_pp` do Windows e a pasta `/lab` do contêiner são a mesma pasta**. O que você salva de um lado aparece do outro na hora. Por isso o projeto precisa ficar dentro de `ambiente_pp\codigos\`.

```
Windows                                     Contêiner (Linux)
C:\parallel_programing\ambiente_pp\    ═    /lab/
  └── codigos\                                └── codigos/
        └── projeto-academico-n-corpos\             └── projeto-academico-n-corpos/
```

---

## Primeira vez

**1. Instale os programas**

- [Docker Desktop](https://www.docker.com/products/docker-desktop): aceite ativar o WSL2 durante a instalação.
- [VS Code](https://code.visualstudio.com) com a extensão **Dev Containers** (`Ctrl+Shift+X`, busque e instale).

**2. Coloque o ambiente no lugar**

Descompacte o `ambiente_pp` em `C:\parallel_programing\`. O `Dockerfile` tem que ficar direto em `C:\parallel_programing\ambiente_pp\`, não numa pasta dentro de outra.

**3. Clone o projeto dentro de `codigos`**

No PowerShell:

```powershell
cd C:\parallel_programing\ambiente_pp\codigos
git clone https://github.com/GabrielCM1/projeto-academico-n-corpos.git
```

**4. Abra o VS Code dentro do contêiner**

1. Abra o Docker Desktop e espere a baleia parar de se mexer.
2. No VS Code: **File > Open Folder** e escolha a pasta `ambiente_pp` (não a pasta do projeto).
3. Tecle `F1` e escolha **Dev Containers: Reopen in Container**.
4. Espere. Na primeira vez demora alguns minutos.

✅ Deu certo quando aparece um **selo verde no canto inferior esquerdo** do VS Code.

**5. Teste**

Abra o terminal do VS Code (`` Ctrl+` ``) e rode:

```bash
cd /lab/codigos/projeto-academico-n-corpos
make
./baseline/06_nbody 2000 10
```

✅ Deu certo se aparecer `checksum=118000.000000`.

---

## No dia a dia

1. Abra o Docker Desktop.
2. Abra o VS Code. Se não aparecer o selo verde, tecle `F1` e escolha **Dev Containers: Reopen in Container**.
3. No terminal:

```bash
cd /lab/codigos/projeto-academico-n-corpos
git pull     # pega o que a equipe enviou
make         # compila
```

---

## Rodando

```bash
./baseline/06_nbody 2000 10          # sequencial
./openmp/06_nbody_openmp 2000 10 4   # OpenMP
OMP_SCHEDULE=dynamic ./openmp/06_nbody_openmp 2000 10 4   # outro escalonamento no laço de forças (padrão: static)
```

Os números são, nessa ordem:

| Argumento | Significado |
|---|---|
| `2000` | quantidade de partículas |
| `10` | quantidade de passos de tempo |
| `4` | quantidade de threads (só no OpenMP) |

A saída mostra o `checksum` e o `tempo`.

### O resultado está certo?

Com os mesmos argumentos, **o checksum do OpenMP tem que ser igual ao do sequencial**. Se for diferente, tem bug na paralelização.

Atenção: com 6 casas, o checksum quase não muda mesmo se as forças estiverem erradas. A conferência completa, com precisão total, é feita por:

```bash
make validar   # compara OpenMP × sequencial em todas as combinações
```

| Partículas (10 passos) | Checksum esperado |
|---:|---:|
| 500 | 25750.000000 |
| 1000 | 54000.000000 |
| 2000 | 118000.000000 |
| 4000 | 276000.000000 |

### Ficou mais rápido?

- **Speedup** = tempo sequencial ÷ tempo OpenMP. Com 4 threads, o ideal é chegar perto de 4.
- Para medir, rode cada configuração 4 vezes, ignore a primeira e use a mediana das outras 3.

---

## Comandos do `make`

| Comando | O que faz |
|---|---|
| `make` | compila tudo |
| `make baseline` | compila só o sequencial |
| `make openmp` | compila só o OpenMP |
| `make validar` | confere o OpenMP contra o sequencial com precisão total |
| `make schedule` | compara `static`, `dynamic` e `guided` no laço de forças |
| `make clean` | apaga os executáveis |

---

## Deu problema?

| Problema | Solução |
|---|---|
| `docker: command not found` | O Docker Desktop está fechado. Abra e espere. |
| O VS Code pergunta *"create container configuration"* | Você abriu a pasta errada. Abra a `ambiente_pp`. |
| `No makefile found` | Você não está na pasta do projeto. Rode o `cd /lab/codigos/projeto-academico-n-corpos`. |
| `No such file or directory` ao executar | Ainda não compilou. Rode `make`. |
| O OpenMP não ficou mais rápido | Rode `nproc`. Se der 1 ou 2, aumente as CPUs no Docker Desktop, em *Settings > Resources*. |
