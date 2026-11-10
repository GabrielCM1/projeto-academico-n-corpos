# Compila tudo com: make   (dentro do contêiner da disciplina)
CXX      = g++
MPICXX   = mpicxx
CXXFLAGS = -O2

BASE = baseline/06_nbody
OMP  = $(patsubst %.cpp,%,$(wildcard openmp/*.cpp))
MPI  = $(patsubst %.cpp,%,$(wildcard mpi/*.cpp))

.PHONY: all baseline openmp mpi clean
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

clean:
	rm -f $(BASE) $(OMP) $(MPI)
