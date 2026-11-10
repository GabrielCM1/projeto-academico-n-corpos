# Projeto acadêmico: n-corpos

Projeto da disciplina Programação Paralela (CCO085, IESB 2026/2), Problema 6: simulação de N-corpos.

O programa simula N partículas que se atraem par a par. A cada passo de tempo, ele faz duas coisas:

1. **Calcula as forças:** para cada partícula, soma a força de todas as outras. Custa O(N²) e ocupa 99,9% do tempo.
2. **Move as partículas:** atualiza velocidade e posição de cada uma. Custa O(N).

O objetivo é paralelizar o cálculo de forças com **OpenMP** e comparar com a versão sequencial. No OpenMP, várias threads dividem a mesma memória: cada uma calcula as forças de um pedaço das partículas e só escreve no próprio pedaço, então não há condição de corrida.

---

## Sumário

1. [Estrutura do repositório](#1-estrutura-do-repositório)
2. [Como o ambiente funciona](#2-como-o-ambiente-funciona)
3. [Preparação (só na primeira vez)](#3-preparação-só-na-primeira-vez)
4. [Rotina de cada dia](#4-rotina-de-cada-dia)
5. [Compilar](#5-compilar)
6. [Executar cada versão](#6-executar-cada-versão)
7. [Como medir o tempo](#7-como-medir-o-tempo)
8. [Trabalhando em equipe com git](#8-trabalhando-em-equipe-com-git)
9. [Problemas comuns](#9-problemas-comuns)
10. [Baseline medido (Marco 1)](#10-baseline-medido-marco-1)

---

## 1. Estrutura do repositório

```
projeto-academico-n-corpos/
├── baseline/
│   ├── 06_nbody.cpp            ← código do professor (NÃO ALTERAR)
│   └── 06_nbody_comentado.cpp  ← mesma coisa, comentada para estudo
├── openmp/                     ← versão com threads (06_nbody_openmp.cpp)
├── resultados/                 ← medições em CSV
├── Makefile                    ← compila tudo com o comando "make"
└── README.md                   ← este arquivo
```

> **Regra do professor:** o `baseline/06_nbody.cpp` é a referência oficial. Não mude a lógica nem a entrada dele. A versão paralela fica em um arquivo novo, dentro de `openmp/`.

---

## 2. Como o ambiente funciona

O OpenMP funciona melhor no Linux. Para ninguém precisar configurar isso no Windows, o professor preparou um **contêiner**: um Linux pronto (Ubuntu 24.04 com g++ e OpenMP) que roda dentro do seu Windows pelo Docker. Ele é igual para toda a turma, então os tempos medidos são comparáveis.

Três ideias para entender:

| Peça | O que é |
|---|---|
| **Docker Desktop** | O programa que roda o contêiner. Precisa estar aberto sempre que você for trabalhar. |
| **`ambiente_pp`** | A pasta do professor (vem no zip do Classroom). Ela diz ao Docker como montar o contêiner. |
| **VS Code + Dev Containers** | Abre o VS Code "dentro" do contêiner. O terminal do VS Code vira um terminal Linux. |

**É uma pasta só, vista de dois lados.** A pasta `C:\parallel_programing\ambiente_pp` do Windows aparece dentro do contêiner como `/lab`:

```
Windows                                              Contêiner (Linux)
C:\parallel_programing\ambiente_pp\                  /lab/
└── codigos\                                         └── codigos/
    └── projeto-academico-n-corpos\   ═══ mesma ═══      └── projeto-academico-n-corpos/
```

Por isso este repositório **tem que ficar dentro de `ambiente_pp\codigos\`**. O que você salva de um lado aparece no outro na hora. Se o contêiner for apagado, nada se perde, porque os arquivos moram no Windows.

> ⚠️ Nunca salve código em outra pasta do contêiner (como `/root` ou `/tmp`): o que fica fora de `/lab` some quando o contêiner fecha.

---

## 3. Preparação (só na primeira vez)

Siga na ordem. Cada passo termina com uma verificação.

### 3.1 Instalar o Docker Desktop

1. Baixe em https://www.docker.com/products/docker-desktop e instale.
2. Aceite ativar o **WSL2** quando o instalador pedir e reinicie o computador se necessário.
3. Abra o Docker Desktop e espere o ícone da baleia ficar parado.

✅ **Verificação:** no PowerShell, rode o comando abaixo. Tem que aparecer uma versão.

```powershell
docker --version
```

### 3.2 Instalar o VS Code e as extensões

1. Instale o VS Code: https://code.visualstudio.com
2. No VS Code, tecle `Ctrl+Shift+X`, procure **Dev Containers** (da Microsoft) e instale.
3. Recomendado: instale também a extensão **C/C++** (da Microsoft).

### 3.3 Baixar o ambiente do professor

1. Baixe o `ambiente_pp_CCO085.zip` do Google Classroom.
2. Crie a pasta `C:\parallel_programing`. O caminho não pode ter acento nem espaço.
3. Descompacte o zip dentro dela. Tem que ficar assim:

```
C:\parallel_programing\ambiente_pp\Dockerfile
C:\parallel_programing\ambiente_pp\docker-compose.yml
C:\parallel_programing\ambiente_pp\Makefile
C:\parallel_programing\ambiente_pp\codigos\
C:\parallel_programing\ambiente_pp\.devcontainer\
...
```

> ⚠️ Se aparecer `ambiente_pp\ambiente_pp\`, uma pasta dentro da outra, mova o conteúdo um nível para cima. O `Dockerfile` precisa estar direto em `ambiente_pp`.

### 3.4 Clonar este repositório dentro de `codigos`

No PowerShell:

```powershell
cd C:\parallel_programing\ambiente_pp\codigos
git clone https://github.com/GabrielCM1/projeto-academico-n-corpos.git
```

✅ **Verificação:** a pasta `C:\parallel_programing\ambiente_pp\codigos\projeto-academico-n-corpos\baseline` existe.

### 3.5 Abrir o VS Code dentro do contêiner

1. Com o Docker Desktop aberto, abra o VS Code.
2. **File > Open Folder** e escolha `C:\parallel_programing\ambiente_pp`. Atenção: é a pasta `ambiente_pp`, não a do projeto.
3. Se perguntar se você confia nos autores, clique em **Yes, I trust the authors**.
4. Tecle `F1`, digite **Dev Containers: Reopen in Container** e dê Enter.
5. Espere. Na primeira vez, o Docker monta o contêiner e isso leva alguns minutos.

✅ **Verificação:** no canto inferior esquerdo aparece o selo verde **"Dev Container: Programacao Paralela CCO085"**.

> Se aparecer a pergunta *"Where would you like to create your container configuration"*, você abriu a pasta errada ou o zip foi descompactado errado. Feche com `Esc` e confira os passos 3.3 e 3.5.

### 3.6 Testar se tudo funciona

Abra o terminal do VS Code com `` Ctrl+` ``. O prompt deve ser parecido com `root@...:/lab#`, o que mostra que você está no Linux. Rode:

```bash
cd /lab/codigos/projeto-academico-n-corpos
make baseline
./baseline/06_nbody 2000 10
```

✅ **Verificação:** aparece algo como `N=2000 passos=10  checksum=118000.000000  tempo=0.16 s`. O tempo varia de máquina para máquina, mas o checksum tem que ser `118000.000000`.

---

## 4. Rotina de cada dia

Depois da preparação, o dia a dia é curto:

1. Abra o **Docker Desktop** e espere a baleia ficar parada.
2. Abra o **VS Code**. Se ele não abrir sozinho dentro do contêiner, tecle `F1` e escolha **Dev Containers: Reopen in Container**.
3. Confira o selo verde no canto inferior esquerdo.
4. No terminal, entre na pasta do projeto e puxe as mudanças dos colegas:

```bash
cd /lab/codigos/projeto-academico-n-corpos
git pull
```

5. Edite, compile, rode e meça (seções 5 a 7).
6. Envie o que você fez (seção 8).

Para sair do contêiner e voltar ao Windows normal, tecle `F1` e escolha **Dev Containers: Reopen Folder Locally**.

---

## 5. Compilar

Sempre de dentro da pasta do projeto, no terminal do contêiner:

| Comando | O que faz |
|---|---|
| `make` | Compila tudo (baseline e OpenMP) |
| `make baseline` | Compila só o baseline |
| `make openmp` | Compila os `.cpp` da pasta `openmp/` |
| `make clean` | Apaga os executáveis gerados |

O `make` só recompila o que mudou. Se quiser compilar à mão, os comandos equivalentes são:

```bash
g++ -O2           baseline/06_nbody.cpp       -o baseline/06_nbody        # sequencial
g++ -O2 -fopenmp  openmp/06_nbody_openmp.cpp  -o openmp/06_nbody_openmp   # OpenMP
```

> Sem o `-fopenmp`, o compilador ignora os `#pragma omp` e o programa roda com uma thread só, sem dar erro.

Os executáveis não vão para o GitHub, porque o `.gitignore` os ignora. Cada um compila na própria máquina.

---

## 6. Executar cada versão

### Baseline (sequencial)

```bash
./baseline/06_nbody 2000 10
#                   │    └─ número de passos de tempo (STEPS)
#                   └────── número de partículas (N)
```

### OpenMP

```bash
./openmp/06_nbody_openmp 2000 10 4
#                                └─ número de threads
```

Outra forma de definir o número de threads é pela variável de ambiente:

```bash
OMP_NUM_THREADS=4 ./openmp/06_nbody_openmp 2000 10
```

### O checksum é o teste de correção

Toda versão imprime um `checksum`. Para o mesmo N e STEPS, **o checksum da versão paralela tem que ser igual ao do baseline**. Se for diferente, a paralelização tem erro, por exemplo uma condição de corrida.

| N (STEPS = 10) | Checksum esperado |
|---:|---:|
| 500 | 25750.000000 |
| 1000 | 54000.000000 |
| 2000 | 118000.000000 |
| 4000 | 276000.000000 |

---

## 7. Como medir o tempo

Use o mesmo protocolo do Marco 1, para os números serem comparáveis:

- Rode **4 vezes** cada combinação de N e número de threads (1, 2, 4 e 8).
- **Descarte a 1ª** execução, que é o aquecimento de cache e sistema.
- Reporte a **mediana** das 3 restantes.
- Use `STEPS = 10` e N ∈ {500, 1000, 2000, 4000}.
- Compile sempre com `-O2` (o `make` já faz isso).

Exemplo para rodar as 4 vezes de uma vez:

```bash
for r in 1 2 3 4; do ./openmp/06_nbody_openmp 2000 10 4; done
```

Antes de medir, confira quantos núcleos o contêiner enxerga:

```bash
nproc
```

Se o número for baixo (1 ou 2), o speedup não vai aparecer. Aumente em **Docker Desktop > Settings > Resources > CPUs** e reabra o contêiner.

Salve as medições em `resultados/`, em CSV, no mesmo formato do baseline:

```
n,steps,repeticao,tempo_s,checksum,descartada
```

Para calcular speedup e eficiência:

- **Speedup** = tempo do baseline ÷ tempo da versão paralela
- **Eficiência** = speedup ÷ número de threads

---

## 8. Trabalhando em equipe com git

O git pode ser usado tanto no terminal do contêiner quanto no Windows (PowerShell ou a aba Source Control do VS Code). Os arquivos são os mesmos.

Fluxo recomendado:

```bash
git pull                                   # 1. antes de começar, pegue o que os colegas enviaram
# ... edite, compile, teste ...
git status                                 # 2. veja o que mudou
git add openmp/06_nbody_openmp.cpp         # 3. escolha o que vai no commit
git commit -m "feat: versão OpenMP do cálculo de forças"
git push                                   # 4. envie para o GitHub
```

Boas práticas:

- Combinem quem mexe em qual arquivo, para evitar dois editando o mesmo trecho ao mesmo tempo.
- Faça `git pull` antes de começar e antes de dar `push`.
- Só faça commit de código que compila e cujo checksum bate com o do baseline.
- Para usar o git dentro do contêiner pela primeira vez, configure seu nome e e-mail:

```bash
git config --global user.name  "Seu Nome"
git config --global user.email "seu-email@exemplo.com"
```

---

## 9. Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `docker: command not found` ou erro de conexão | O Docker Desktop está fechado. Abra e espere a baleia ficar parada. |
| Tela *"create container configuration"* | Você abriu a pasta errada no VS Code. Abra `C:\parallel_programing\ambiente_pp`. |
| `make: *** No targets specified and no makefile found` | Você não está na pasta do projeto. Rode `cd /lab/codigos/projeto-academico-n-corpos`. |
| `bash: ./baseline/06_nbody: No such file or directory` | Ainda não compilou. Rode `make` antes. |
| Speedup perto de 1 | O Docker está com poucos núcleos. Veja `nproc` e aumente as CPUs no Docker Desktop. |
| Speedup perto de 1 mesmo com CPUs suficientes | Faltou o `-fopenmp` na compilação. Use `make openmp`. |
| Checksum diferente do baseline | Há um erro na versão paralela, provavelmente uma condição de corrida ou uma partícula esquecida. |
| A primeira abertura do contêiner demora muito | É normal: isso só acontece na primeira vez. |

---

## 10. Baseline medido (Marco 1)

Máquina: Intel Core i7-8550U (4 núcleos / 8 threads), contêiner `iesb/pp-lab:2026.2`, g++ 13.3.0, `-O2`, STEPS = 10. Os dados brutos estão em [`resultados/baseline_06_nbody.csv`](resultados/baseline_06_nbody.csv).

| N | Tempo mediano | Razão para o N anterior |
|---:|---:|---:|
| 500 | 0,011210 s | — |
| 1000 | 0,042036 s | 3,75× |
| 2000 | 0,162749 s | 3,87× |
| 4000 | 0,651698 s | 4,00× |

Dobrar N multiplica o tempo por cerca de 4, o que confirma a complexidade O(N²).

Com a fração paralelizável P ≈ 0,999, a Lei de Amdahl prevê:

| Threads | Speedup teórico | Eficiência teórica |
|---:|---:|---:|
| 2 | 1,998× | 99,9% |
| 4 | 3,988× | 99,7% |
| 8 | 7,944× | 99,3% |
| 16 | 15,761× | 98,5% |
