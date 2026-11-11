# Compila tudo com: make   (dentro do contêiner da disciplina)
CXX      = g++
CXXFLAGS = -O2

BASE = baseline/06_nbody
OMP  = $(patsubst %.cpp,%,$(wildcard openmp/*.cpp))

.PHONY: all baseline openmp validar schedule clean
all: baseline openmp

baseline: $(BASE)
openmp: $(OMP)

baseline/%: baseline/%.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

openmp/%: openmp/%.cpp
	$(CXX) $(CXXFLAGS) -fopenmp $< -o $@

# Confere o resultado do OpenMP contra o baseline (precisao total)
validar: all
	bash scripts/validar_openmp.sh

# Compara static, dynamic e guided no laco de forcas
schedule: openmp
	bash scripts/comparar_schedule.sh

clean:
	rm -f $(BASE) $(OMP)
