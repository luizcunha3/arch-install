#!/bin/bash

info() { echo -e "\e[34m[INFO]\e[0m $1"; }

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

# --- 1. PRIVILÉGIOS ---
cd "$(dirname "$0")"
info "Solicitando permissão de administrador..."
if ! sudo -v; then exit 1; fi
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- 2. DRIVERS NVIDIA ---
info "Instalando drivers Nvidia e suporte Wayland..."
# nvidia-dkms é melhor para evitar quebra em updates de kernel
(sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings egl-wayland > /dev/null 2>&1) &
spinner $!
echo ""

# --- 3. HYPRLAND E FERRAMENTAS ---
info "Instalando Hyprland, Hyprlock e Portals..."
(sudo pacman -S --noconfirm --needed hyprland hyprlock xdg-desktop-portal-hyprland qt5-wayland qt6-wayland > /dev/null 2>&1) &
spinner $!
echo ""

# --- 4. GIT, ZSH E OH MY ZSH ---
info "Instalando Git e ZSH..."
(sudo pacman -S --noconfirm --needed git zsh > /dev/null 2>&1) &
spinner $!
echo ""

info "Configurando Oh My Zsh..."
(sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1) &
spinner $!
echo ""

# --- 5. CONFIGURAÇÃO FINAL ---
info "Definindo ZSH como padrão..."
USER_REAL=$(logname)
sudo chsh -s /usr/bin/zsh "$USER_REAL" > /dev/null 2>&1

info "Ajustando parâmetros de kernel para Nvidia..."
# Isso adiciona o suporte necessário ao KMS para a Nvidia não bugar no Wayland
if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
fi

info "Setup concluído! REINICIE a máquina para carregar os drivers."