"""Speedup, eficiencia e graficos (issue #4).

Le os CSVs gerados pelo `make medir` e pelo `make perfil` e gera, em resultados/:
  - speedup_eficiencia.csv   tabela com tempo mediano, speedup, eficiencia e Amdahl
  - grafico_speedup.png      speedup por threads/processos, por N, com ideal e Amdahl
  - grafico_eficiencia.png   eficiencia por threads/processos, por N, com Amdahl
  - grafico_openmp_vs_mpi.png  as duas versoes lado a lado para o maior N

Definicoes:
  tempo de cada configuracao = mediana das 3 execucoes com descartada = nao
  speedup     = tempo do baseline (mesma sessao) / tempo da versao paralela
  eficiencia  = speedup / numero de threads ou processos
  Amdahl      S(p) = 1 / ((1 - P) + P / p), com P = (forcas + atualizacao) / tempo do laco
              na repeticao de tempo mediano do perfilamento (resultados/perfil_06_nbody.csv),
              o mesmo calculo do scripts/perfilar.sh

Uso: make graficos   (ou: python3 scripts/graficos.py)
"""
import csv
import os
from statistics import median

import matplotlib

matplotlib.use("Agg")  # gera arquivo, sem abrir janela
import matplotlib.pyplot as plt

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RES = os.path.join(RAIZ, "resultados")
UNIDADES = [1, 2, 4, 8]
NUCLEOS_FISICOS = 4  # i7-8550U da medicao (ver resultados/maquina.txt)


def ler(nome):
    with open(os.path.join(RES, nome), newline="") as f:
        return [linha for linha in csv.DictReader(f) if linha["descartada"] == "nao"]


def medianas(linhas, chave_unidade=None, coluna="tempo_s"):
    """{(n, unidades): mediana} ou {n: mediana} quando nao ha coluna de unidades."""
    grupos = {}
    for l in linhas:
        k = (int(l["n"]), int(l[chave_unidade])) if chave_unidade else int(l["n"])
        grupos.setdefault(k, []).append(float(l[coluna]))
    return {k: median(v) for k, v in grupos.items()}


base = medianas(ler("baseline_06_nbody_mesma_sessao.csv"))
omp = medianas(ler("openmp_06_nbody.csv"), "threads")
mpi = medianas(ler("mpi_06_nbody.csv"), "processos")
mpi_comm = medianas(ler("mpi_06_nbody.csv"), "processos", "comunicacao_s")

# Fracao paralelizavel P por N, como no scripts/perfilar.sh: usa a repeticao de
# tempo mediano e P = (forcas + atualizacao) / tempo do laco nessa repeticao.
perfil = ler("perfil_06_nbody.csv")
P = {}
for n in sorted({int(l["n"]) for l in perfil}):
    ls = sorted((l for l in perfil if int(l["n"]) == n), key=lambda l: float(l["tempo_s"]))
    l = ls[len(ls) // 2]
    P[n] = (float(l["forcas_s"]) + float(l["atualizacao_s"])) / float(l["tempo_s"])


def amdahl(n, p):
    return 1 / ((1 - P[n]) + P[n] / p)


NS = sorted(base)

# ---------- tabela ----------
saida = os.path.join(RES, "speedup_eficiencia.csv")
with open(saida, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["n", "versao", "unidades", "tempo_mediano_s", "tempo_baseline_s",
                "speedup", "eficiencia", "comunicacao_s", "amdahl_speedup", "amdahl_eficiencia"])
    for n in NS:
        for versao, tempos in (("openmp", omp), ("mpi", mpi)):
            for p in UNIDADES:
                t = tempos[(n, p)]
                s = base[n] / t
                comm = f"{mpi_comm[(n, p)]:.6f}" if versao == "mpi" else ""
                w.writerow([n, versao, p, f"{t:.6f}", f"{base[n]:.6f}", f"{s:.3f}", f"{s / p:.3f}",
                            comm, f"{amdahl(n, p):.3f}", f"{amdahl(n, p) / p:.3f}"])

# ---------- graficos ----------
CORES = {500: "#9ecae1", 1000: "#4292c6", 2000: "#2171b5", 4000: "#08306b"}
plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})


def marca_nucleos(ax):
    ax.axvline(NUCLEOS_FISICOS, color="#999", lw=0.8, ls=":")
    # y em fracao da altura do eixo: fica no rodape, longe das curvas, em qualquer grafico
    ax.text(NUCLEOS_FISICOS + 0.1, 0.03, "4 núcleos físicos", transform=ax.get_xaxis_transform(),
            fontsize=8, color="#666", va="bottom")


def painel(ax, tempos, titulo, eficiencia):
    for n in NS:
        ys = [base[n] / tempos[(n, p)] / (p if eficiencia else 1) for p in UNIDADES]
        ax.plot(UNIDADES, ys, "o-", color=CORES[n], label=f"N = {n}")
    if eficiencia:
        ax.plot(UNIDADES, [1] * 4, "k--", lw=1, label="ideal")
        ax.plot(UNIDADES, [amdahl(NS[0], p) / p for p in UNIDADES], color="#d62728", ls="-.", lw=1,
                label=f"Amdahl (N = {NS[0]})")
        ax.set_ylim(0, 1.1)
        ax.set_ylabel("Eficiência (speedup ÷ unidades)")
    else:
        ax.plot(UNIDADES, UNIDADES, "k--", lw=1, label="ideal")
        ax.plot(UNIDADES, [amdahl(NS[0], p) for p in UNIDADES], color="#d62728", ls="-.", lw=1,
                label=f"Amdahl (N = {NS[0]})")
        ax.set_ylim(0, 8.5)
        ax.set_ylabel("Speedup")
    ax.set_xticks(UNIDADES)
    ax.set_title(titulo)
    ax.grid(alpha=0.3)
    marca_nucleos(ax)


for eficiencia, nome in ((False, "grafico_speedup.png"), (True, "grafico_eficiencia.png")):
    fig, (a, b) = plt.subplots(1, 2, figsize=(11, 4.5), sharey=True)
    painel(a, omp, "OpenMP", eficiencia)
    painel(b, mpi, "MPI", eficiencia)
    a.set_xlabel("Threads")
    b.set_xlabel("Processos")
    b.set_ylabel("")
    a.legend(loc="upper left" if not eficiencia else "lower left", fontsize=8)
    fig.suptitle(("Eficiência" if eficiencia else "Speedup") + " em relação ao baseline (10 passos)")
    fig.tight_layout()
    fig.savefig(os.path.join(RES, nome), dpi=150)
    plt.close(fig)

# OpenMP x MPI no maior N
n = NS[-1]
fig, ax = plt.subplots(figsize=(6, 4.5))
ax.plot(UNIDADES, UNIDADES, "k--", lw=1, label="ideal")
ax.plot(UNIDADES, [amdahl(n, p) for p in UNIDADES], color="#d62728", ls="-.", lw=1, label="Amdahl")
ax.plot(UNIDADES, [base[n] / omp[(n, p)] for p in UNIDADES], "o-", color="#2171b5", label="OpenMP")
ax.plot(UNIDADES, [base[n] / mpi[(n, p)] for p in UNIDADES], "s-", color="#e6550d", label="MPI")
ax.set_xticks(UNIDADES)
ax.set_ylim(0, 8.5)
ax.set_xlabel("Threads ou processos")
ax.set_ylabel("Speedup")
ax.set_title(f"OpenMP × MPI, N = {n}")
ax.grid(alpha=0.3)
marca_nucleos(ax)
ax.legend(loc="upper left", fontsize=8)
fig.tight_layout()
fig.savefig(os.path.join(RES, "grafico_openmp_vs_mpi.png"), dpi=150)
plt.close(fig)

# ---------- resumo no terminal ----------
print("Fracao paralelizavel (perfil): " + ", ".join(f"N={n}: {P[n]:.5f}" for n in NS))
print()
print(f"{'N':>5} {'versao':>7} " + " ".join(f"{'S(' + str(p) + ')':>7} {'E(' + str(p) + ')':>6}" for p in UNIDADES))
for n in NS:
    for versao, tempos in (("openmp", omp), ("mpi", mpi)):
        cel = " ".join(f"{base[n] / tempos[(n, p)]:>6.2f}x {base[n] / tempos[(n, p)] / p:>6.2f}" for p in UNIDADES)
        print(f"{n:>5} {versao:>7} {cel}")
print()
print("Gerados em resultados/: speedup_eficiencia.csv, grafico_speedup.png, "
      "grafico_eficiencia.png, grafico_openmp_vs_mpi.png")
