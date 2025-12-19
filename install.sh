#!/bin/bash

# --- FUNÇÕES DE SUPORTE ---
info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

# Função do Spinner revisada para maior compatibilidade
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

# --- 1. VALIDAÇÃO DE PRIVILÉGIOS ---
info "Solicitando permissão de administrador..."
if ! sudo -v; then
    echo -e "\e[31m[ERRO]\e[0m Senha incorreta ou permissão negada."
    exit 1
fi

# Loop para manter o sudo vivo até o fim do script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- 2. INSTALAÇÃO DE PACOTES (PACMAN) ---
info "Atualizando repositórios e instalando Git..."
(sudo pacman -Syu --noconfirm --needed git > /dev/null 2>&1) &
spinner $!
echo ""

info "Instalando ZSH..."
(sudo pacman -S --noconfirm --needed zsh > /dev/null 2>&1) &
spinner $!
echo ""

# --- 3. OH MY ZSH (MODO NÃO INTERATIVO) ---
info "Instalando Oh My Zsh..."
# --unattended: evita que o script mude o shell ou abra o zsh agora
(sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1) &
spinner $!
echo ""

# --- 4. CONFIGURAÇÃO FINAL ---
info "Definindo ZSH como shell padrão..."
USER_REAL=$(logname)
(sudo chsh -s /usr/bin/zsh "$USER_REAL" > /dev/null 2>&1) &
spinner $!
echo ""

info "------------------------------------------"
info "Setup finalizado com sucesso!"
info "Por favor, reinicie seu terminal ou sessão."
info "------------------------------------------"