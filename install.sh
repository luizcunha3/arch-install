#!/bin/bash

# Funções de suporte
info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Início do processo
info "Autenticando..."
sudo -v

# Instalações Pacman
info "Instalando git..."
(sudo pacman -S --noconfirm --needed git > /dev/null 2>&1) &
spinner $!
echo ""

info "Instalando zsh..."
(sudo pacman -S --noconfirm --needed zsh > /dev/null 2>&1) &
spinner $!
echo ""

# Oh My Zsh
info "Configurando Oh My Zsh..."
# --unattended: evita que o instalador faça perguntas ou mude o shell sozinho
(sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1) &
spinner $!
echo ""

# Shell Padrão
info "Definindo ZSH como shell padrão..."
USER_REAL=$(logname)
(sudo chsh -s /usr/bin/zsh "$USER_REAL" > /dev/null 2>&1) &
spinner $!
echo ""

info "Setup concluído com sucesso!"