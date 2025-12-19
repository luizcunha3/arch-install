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

# --- 2. DETECÇÃO DE HARDWARE ---
IS_VM=$(systemd-detect-virt)
HAS_NVIDIA=$(lspci | grep -i nvidia)

if [ "$IS_VM" != "none" ]; then
    info "Ambiente Virtual detectado ($IS_VM). Otimizando para VM."
else
    info "Hardware Real detectado. Otimizando para Nvidia."
fi

# --- 3. INSTALAÇÃO DE PACOTES ---
info "Instalando base do sistema e drivers..."
(sudo pacman -Syu --noconfirm --needed base-devel git zsh nvidia-dkms nvidia-utils egl-wayland hyprland hyprlock xdg-desktop-portal-hyprland qt6-wayland ghostty > /dev/null 2>&1) &
spinner $!
echo ""

# --- 4. YAY E WALKER ---
if ! command -v yay &> /dev/null; then
    info "Instalando yay-bin..."
    sudo -u "$USER_REAL" bash <<EOF
        cd /tmp && git clone https://aur.archlinux.org/yay-bin.git > /dev/null 2>&1
        cd yay-bin && makepkg -si --noconfirm > /dev/null 2>&1
EOF
fi

info "Instalando Walker..."
(sudo -u "$USER_REAL" yay -S --noconfirm walker > /dev/null 2>&1) &
spinner $!
echo ""

# --- 5. CONFIGURAÇÃO DE KERNEL (SÓ SE NÃO FOR VM) ---
if [ "$IS_VM" == "none" ]; then
    info "Configurando KMS para Nvidia..."
    sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    (sudo mkinitcpio -P > /dev/null 2>&1) &
    spinner $!
    echo ""

    info "Configurando GRUB..."
    if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
    fi
fi

# --- 6. OH MY ZSH E AUTO-START ---
info "Configurando Oh My Zsh e Auto-start..."
(sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1) &
spinner $!
echo ""

sudo chsh -s /usr/bin/zsh "$USER_REAL" > /dev/null 2>&1

# Injetar auto-start apenas se o arquivo for novo para não duplicar
if ! grep -q "Hyprland" "/home/$USER_REAL/.zshrc" 2>/dev/null; then
cat <<EOF >> "/home/$USER_REAL/.zshrc"
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    exec dbus-run-session Hyprland
fi
EOF
fi

# --- 7. CONFIGURAÇÃO HYPRLAND DINÂMICA ---
info "Gerando hyprland.conf inteligente..."
mkdir -p "/home/$USER_REAL/.config/hypr"

# Criamos o arquivo base
cat <<EOF > "/home/$USER_REAL/.config/hypr/hyprland.conf"
# --- VARIAVEIS DE AMBIENTE ---
env = XDG_SESSION_TYPE,wayland
env = WLR_NO_HARDWARE_CURSORS,1
EOF

# Se for hardware real com Nvidia, adicionamos as variáveis que dão crash na VM
if [ "$IS_VM" == "none" ] && [ ! -z "$HAS_NVIDIA" ]; then
cat <<EOF >> "/home/$USER_REAL/.config/hypr/hyprland.conf"
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
EOF
fi

# Adicionamos o restante da config
cat <<EOF >> "/home/$USER_REAL/.config/hypr/hyprland.conf"

monitor=,preferred,auto,1
input { kb_layout = br }

\$mainMod = SUPER
bind = \$mainMod, Q, exec, ghostty
bind = \$mainMod, R, exec, walker
bind = \$mainMod, C, killactive, 
bind = \$mainMod, M, exit, 
EOF

chown -R "$USER_REAL:$USER_REAL" "/home/$USER_REAL/.config"
chown "$USER_REAL:$USER_REAL" "/home/$USER_REAL/.zshrc"

info "Setup concluído! Pode reiniciar."