#!/bin/bash

# Função para mensagens coloridas
info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

info "Instalando git"
sudo pacman -S --noconfirm --needed git

info "Instalando zsh"
sudo pacman -S --noconfirm --needed zsh