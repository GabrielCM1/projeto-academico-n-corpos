"""Speedup, eficiencia e graficos (issue #4).

Le os CSVs gerados pelo `make medir` e pelo `make perfil` e gera, em resultados/:
  - speedup_eficiencia.csv   tabela com tempo mediano, speedup, eficiencia e Amdahl
  - grafico_speedup.png      speedup por threads/processos, por N, com ideal e Amdahl
  - grafico_eficiencia.png   eficiencia por threads/processos, por N, com Amdahl
  - grafico_openmp_vs_mpi.png  as duas versoes lado a lado para o maior N
  - grafico_tempo.png        tempo absoluto por threads/processos, com o baseline de cada N
  - escalabilidade_fraca.csv e grafico_escalabilidade_fraca.png
                             N = 1000*sqrt(P) (make fraca): tempo e eficiencia fraca T(1)/T(P)

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


def marca_nucleos(ax, y=0.03):
    ax.axvline(NUCLEOS_FISICOS, color="#999", lw=0.8, ls=":")
    # y em fracao da altura do eixo (padrao: rodape, longe das curvas)
    ax.text(NUCLEOS_FISICOS + 0.1, y, "4 núcleos físicos", transform=ax.get_xaxis_transform(),
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

# Tempo absoluto por threads/processos (escala log: N = 500 e N = 4000 diferem 60x)
fig, (a, b) = plt.subplots(1, 2, figsize=(11, 4.5), sharey=True)
for ax, tempos, titulo, rotulo in ((a, omp, "OpenMP", "Threads"), (b, mpi, "MPI", "Processos")):
    for n in NS:
        ax.plot(UNIDADES, [tempos[(n, p)] for p in UNIDADES], "o-", color=CORES[n], label=f"N = {n}")
        ax.axhline(base[n], color=CORES[n], ls=":", lw=1)
    ax.set_yscale("log")
    ax.set_xticks(UNIDADES)
    ax.set_xlabel(rotulo)
    ax.set_title(titulo)
    ax.grid(alpha=0.3, which="both")
    marca_nucleos(ax)
a.set_ylabel("Tempo do laço de passos (s, escala log)")
a.plot([], [], "k:", lw=1, label="baseline (mesmo N)")
fig.legend(*a.get_legend_handles_labels(), loc="lower center", ncol=5, fontsize=8, frameon=False)
fig.suptitle("Tempo de execução (10 passos, mediana de 3)")
fig.tight_layout(rect=(0, 0.06, 1, 1))  # deixa espaco para a legenda embaixo
fig.savefig(os.path.join(RES, "grafico_tempo.png"), dpi=150)
plt.close(fig)

# Escalabilidade fraca: N = 1000*sqrt(P), trabalho constante por thread/processo
fbase = medianas(ler("fraca_baseline_06_nbody.csv"))
fomp = medianas(ler("fraca_openmp_06_nbody.csv"), "threads")
fmpi = medianas(ler("fraca_mpi_06_nbody.csv"), "processos")
fmpi_comm = medianas(ler("fraca_mpi_06_nbody.csv"), "processos", "comunicacao_s")
FN = {p: n for (n, p) in fomp}  # P -> N usado
with open(os.path.join(RES, "escalabilidade_fraca.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["p", "n", "tempo_baseline_s", "tempo_openmp_s", "eficiencia_fraca_openmp",
                "tempo_mpi_s", "comunicacao_mpi_s", "eficiencia_fraca_mpi"])
    for p in UNIDADES:
        n = FN[p]
        w.writerow([p, n, f"{fbase[n]:.6f}", f"{fomp[(n, p)]:.6f}", f"{fomp[(FN[1], 1)] / fomp[(n, p)]:.3f}",
                    f"{fmpi[(n, p)]:.6f}", f"{fmpi_comm[(n, p)]:.6f}", f"{fmpi[(FN[1], 1)] / fmpi[(n, p)]:.3f}"])

fig, (a, b) = plt.subplots(1, 2, figsize=(11, 4.5))
rot = [f"{p}\n(N={FN[p]})" for p in UNIDADES]
a.plot(UNIDADES, [fbase[FN[p]] for p in UNIDADES], "^:", color="#636363", label="sequencial")
a.plot(UNIDADES, [fomp[(FN[p], p)] for p in UNIDADES], "o-", color="#2171b5", label="OpenMP")
a.plot(UNIDADES, [fmpi[(FN[p], p)] for p in UNIDADES], "s-", color="#e6550d", label="MPI")
a.set_ylabel("Tempo (s)")
a.set_title("Tempo com trabalho constante por unidade")
b.plot(UNIDADES, [1] * 4, "k--", lw=1, label="ideal")
b.plot(UNIDADES, [fomp[(FN[1], 1)] / fomp[(FN[p], p)] for p in UNIDADES], "o-", color="#2171b5", label="OpenMP")
b.plot(UNIDADES, [fmpi[(FN[1], 1)] / fmpi[(FN[p], p)] for p in UNIDADES], "s-", color="#e6550d", label="MPI")
b.set_ylim(0, 1.1)
b.set_ylabel("Eficiência fraca = T(1) ÷ T(P)")
b.set_title("Eficiência fraca")
for ax in (a, b):
    ax.set_xticks(UNIDADES)
    ax.set_xticklabels(rot, fontsize=8)
    ax.set_xlabel("Threads ou processos (P)")
    ax.grid(alpha=0.3)
    marca_nucleos(ax, y=0.55 if ax is a else 0.03)  # no painel do tempo as curvas ficam embaixo
    ax.legend(loc="upper left" if ax is a else "lower left", fontsize=8)
fig.suptitle("Escalabilidade fraca: N = 1000·√P (10 passos, mediana de 3)")
fig.tight_layout()
fig.savefig(os.path.join(RES, "grafico_escalabilidade_fraca.png"), dpi=150)
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
print("Escalabilidade fraca (eficiencia T(1)/T(P)): " + ", ".join(
    f"P={p}: OpenMP {fomp[(FN[1], 1)] / fomp[(FN[p], p)]:.3f} / MPI {fmpi[(FN[1], 1)] / fmpi[(FN[p], p)]:.3f}"
    for p in UNIDADES))
print()
print("Gerados em resultados/: speedup_eficiencia.csv, escalabilidade_fraca.csv, grafico_tempo.png, "
      "grafico_speedup.png, grafico_eficiencia.png, grafico_openmp_vs_mpi.png, grafico_escalabilidade_fraca.png")
