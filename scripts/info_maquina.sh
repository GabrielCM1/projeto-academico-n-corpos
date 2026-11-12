# Funcao compartilhada pelos scripts de medicao: descreve a maquina e o ambiente.
# Uso: source scripts/info_maquina.sh; info_maquina > resultados/maquina_xxx.txt
# A variavel AMBIENTE, se definida, substitui a deteccao automatica do ambiente
# (ex.: AMBIENTE="conteiner iesb/pp-lab:2026.2").

_lscpu_campo() { lscpu | sed -nE "s/^$1:[[:space:]]+//p" | head -1; }

_ambiente() {
    if [[ -n ${AMBIENTE:-} ]]; then echo "$AMBIENTE"
    elif [[ -f /.dockerenv ]]; then echo "conteiner Docker"
    elif [[ -f /run/.containerenv ]]; then
        local img; img=$(sed -nE 's/^image="(.*)"/\1/p' /run/.containerenv)
        echo "conteiner podman${img:+ $img}"
    else echo "direto no sistema"; fi
}

info_maquina() {
    echo "data:       $(date '+%Y-%m-%d %H:%M')"
    echo "nproc:      $(nproc)"
    echo "cpu:        $(_lscpu_campo 'Model name')"
    echo "nucleos:    $(_lscpu_campo 'Core\(s\) per socket') fisicos por soquete, $(_lscpu_campo 'Thread\(s\) per core') threads por nucleo, $(_lscpu_campo 'Socket\(s\)') soquete(s)"
    echo "memoria:    $(free -h | awk '/^Mem:/ {print $2}')"
    echo "so:         $(sed -nE 's/^PRETTY_NAME="(.*)"/\1/p' /etc/os-release), kernel $(uname -r)"
    echo "ambiente:   $(_ambiente)"
    echo "energia:    $(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -1 | sed 's/1/na tomada/; s/0/na bateria/' || echo desconhecido)"
    echo "carga:      $(cut -d' ' -f1-3 /proc/loadavg) (media de 1, 5 e 15 min antes de medir)"
    echo "compilador: $(g++ --version | head -1)"
}

# Temperatura do processador em graus C (sensor x86_pkg_temp), ou vazio se nao houver.
temperatura_cpu() {
    local z
    for z in /sys/class/thermal/thermal_zone*; do
        if [[ $(cat "$z/type" 2>/dev/null) == x86_pkg_temp ]]; then
            echo $(( $(cat "$z/temp") / 1000 )); return
        fi
    done
}

# Espera o processador esfriar ate ESFRIAR graus (padrao 55), no maximo ESPERA_MAX
# segundos (padrao 180); imprime a temperatura de partida.
esfria() {
    local t i limite=${ESFRIAR:-55} max=${ESPERA_MAX:-180}
    t=$(temperatura_cpu)
    [[ -z $t ]] && { echo "sem sensor"; return; }
    for (( i = 0; i < max && t > limite; i += 5 )); do sleep 5; t=$(temperatura_cpu); done
    echo "${t}C apos ${i} s de espera"
}
