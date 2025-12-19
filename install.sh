#!/bin/bash

# Função do Spinner (Animação)
# Ela recebe o PID (ID do processo) do comando anterior
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Função para mensagens coloridas
info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

info "Preparando ambiente"
sudo -v
# Atualiza o timestamp do sudo enquanto o script estiver rodando
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Instalando o Git
info "Instalando git..."
(sudo pacman -S --noconfirm --needed git > /dev/null 2>&1) & spinner $!

# 3. Instalando o ZSH
info "Instalando zsh..."
(sudo pacman -S --noconfirm --needed zsh > /dev/null 2>&1) & spinner $!

info "Instalando wget"
(sudo pacman -S --noconfirm needed wget > /dev/null 2>&1) & spinner $!

info "Configurando ZSH como shell padrão..."
# Pega o nome do usuário que rodou o script, mesmo que esteja usando sudo
USER_REAL=$(logname)

# Altera o shell silenciosamente
(sudo chsh -s /usr/bin/zsh "$USER_REAL" > /dev/null 2>&1) &
spinner $!

info "Instalando Oh My ZSH" 
sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
