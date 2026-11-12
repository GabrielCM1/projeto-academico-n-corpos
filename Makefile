# Compila tudo com: make   (dentro do contêiner da disciplina)
CXX      = g++
MPICXX   = mpicxx
CXXFLAGS = -O2

BASE = baseline/06_nbody
OMP  = $(patsubst %.cpp,%,$(wildcard openmp/*.cpp))
MPI  = $(patsubst %.cpp,%,$(wildcard mpi/*.cpp))

.PHONY: all baseline openmp mpi validar validar-mpi schedule medir clean
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

# Mede baseline e OpenMP (1, 2, 4, 8 threads) e gera os CSVs em resultados/
medir: baseline openmp
	bash scripts/medir_openmp.sh

clean:
	rm -f $(BASE) $(OMP) $(MPI)
