# Compila tudo com: make   (dentro do contêiner da disciplina)
CXX      = g++
MPICXX   = mpicxx
CXXFLAGS = -O2

BASE = baseline/06_nbody
PERFIL = baseline/06_nbody_perfil
OMP  = $(patsubst %.cpp,%,$(wildcard openmp/*.cpp))
MPI  = $(patsubst %.cpp,%,$(wildcard mpi/*.cpp))

.PHONY: all baseline openmp mpi validar validar-mpi schedule medir fraca perfil clean
all: baseline openmp mpi

baseline: $(BASE)
openmp: $(OMP)
mpi: $(MPI)

baseline/%: baseline/%.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

openmp/%: openmp/%.cpp
	$(CXX) $(CXXFLAGS) -fopenmp $< -o $@

mpi/%: mpi/%.cpp
	$(MPICXX) $(CXXFLAGS) $< -o $@

# Confere o resultado do OpenMP contra o baseline (precisao total)
validar: baseline openmp
	bash scripts/validar_openmp.sh

# Confere o resultado do MPI contra o baseline (precisao total)
validar-mpi: baseline mpi
	bash scripts/validar_mpi.sh

# Compara static, dynamic e guided no laco de forcas
schedule: openmp
	bash scripts/comparar_schedule.sh

# Mede baseline, OpenMP (1, 2, 4, 8 threads) e MPI (1, 2, 4, 8 processos) na mesma
# sessao, intercalados, e gera os CSVs em resultados/ (sem MPI instalado, mede so os dois primeiros)
medir:
	bash scripts/medir.sh

# Escalabilidade fraca: N = 1000*sqrt(P) com P = 1, 2, 4, 8 (trabalho constante por thread/processo)
fraca:
	bash scripts/medir.sh fraca

# Perfilamento do baseline: tempo de cada trecho e estimativa de Amdahl
perfil: $(BASE) $(PERFIL)
	bash scripts/perfilar.sh

clean:
	rm -f $(BASE) $(PERFIL) $(OMP) $(MPI)
