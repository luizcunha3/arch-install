#!/bin/bash

# --- FUNÇÕES DE SUPORTE ---
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

# --- 1. AMBIENTE E PRIVILÉGIOS ---
cd "$(dirname "$0")"
info "Solicitando permissão de administrador..."
if ! sudo -v; then exit 1; fi
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

USER_REAL=$(logname)

# --- 2. DEPENDÊNCIAS DE COMPILAÇÃO E BASE ---
info "Instalando dependências de sistema (base-devel, git, zsh)..."
(sudo pacman -S --noconfirm --needed base-devel git zsh > /dev/null 2>&1) &
spinner $!
echo ""

# --- 3. INSTALAÇÃO DO YAY (AUR HELPER) ---
if ! command -v yay &> /dev/null; then
    info "Instalando o yay-bin..."
    sudo -u "$USER_REAL" bash <<EOF
        cd /tmp
        git clone https://aur.archlinux.org/yay-bin.git > /dev/null 2>&1
        cd yay-bin
        makepkg -si --noconfirm > /dev/null 2>&1
EOF
else
    info "Yay já instalado."
fi

# --- 4. DRIVERS NVIDIA E HYPRLAND ---
info "Instalando Drivers Nvidia e Hyprland..."
# Adicionado dkms e pacotes de suporte wayland/qt
(sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland hyprland hyprlock xdg-desktop-portal-hyprland qt6-wayland ghostty > /dev/null 2>&1) &
spinner $!
echo ""

info "Instalando Walker (via yay)..."
(sudo -u "$USER_REAL" yay -S --noconfirm walker > /dev/null 2>&1) &
spinner $!
echo ""

# --- 5. CORREÇÃO DO ERRO HYPRLAND (KMS & GRUB) ---
info "Configurando Kernel Mode Setting (KMS) para Nvidia..."

# Adiciona módulos ao mkinitcpio.conf
sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf

# Gera novamente a imagem do kernel (Essencial para Nvidia no Wayland)
(sudo mkinitcpio -P > /dev/null 2>&1) &
spinner $!
echo ""

info "Configurando flags do GRUB..."
if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
fi

# --- 6. OH MY ZSH E AUTO-START ---
info "Configurando Oh My Zsh..."
(sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1) &
spinner $!
echo ""

# Define ZSH como padrão
sudo chsh -s /usr/bin/zsh "$USER_REAL" > /dev/null 2>&1

# Injeção para auto-start do Hyprland no TTY1
info "Configurando auto-start no TTY1..."
cat <<EOF >> "/home/$USER_REAL/.zshrc"

# Iniciar Hyprland automaticamente no TTY1
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    exec dbus-run-session Hyprland
fi
EOF

# --- 7. CONFIGURAÇÃO HYPRLAND ---
info "Gerando hyprland.conf (Nvidia optimize)..."
mkdir -p "/home/$USER_REAL/.config/hypr"
cat <<EOF > "/home/$USER_REAL/.config/hypr/hyprland.conf"
# VARIAVEIS NVIDIA
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

# MONITOR & INPUT
monitor=,preferred,auto,1
input { kb_layout = br }

# KEYBINDINGS
\$mainMod = SUPER
bind = \$mainMod, Q, exec, ghostty
bind = \$mainMod, R, exec, walker
bind = \$mainMod, C, killactive, 
bind = \$mainMod, M, exit, 
EOF

# Ajusta permissões finais
chown -R "$USER_REAL:$USER_REAL" "/home/$USER_REAL/.config"
chown "$USER_REAL:$USER_REAL" "/home/$USER_REAL/.zshrc"

info "----------------------------------------------------"
info "Setup concluído! REINICIE O SISTEMA AGORA."
info "----------------------------------------------------"