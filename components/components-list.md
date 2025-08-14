## Base

| Pacchetto                       | Descrizione                                             |
|---------------------------------|---------------------------------------------------------|
| **hyprland**                    | Window manager dinamico per Wayland.                    |
| **xdg-desktop-portal-hyprland** | Integrazione portali desktop con Hyprland.              |
| **xdg-desktop-portal**          | Portali per funzioni desktop (file picker, screenshot). |
| **waybar**                      | Barra di stato/pannello per Wayland.                    |
| **hyprpaper**                   | Gestore di sfondi per Hyprland.                         |
| **rofi-wayland**                | Launcher/app switcher per Wayland.                      |
| **kitty**                       | Terminale moderno e veloce.                             |
| **alacritty**                   | Terminale GPU-accelerato.                               |
| **firefox**                     | Browser web.                                            |

## Extra

| Component                 | Description        |
|---------------------------|--------------------|
| yay                       | Aur Helper         |
| fastfetch                 | System Information |
| [pipewire](#pipewire)     | Audio + gui        |
| [bluez](#bluez)           | Bluetooth + gui    |
| [gsimplecal](#gsimplecal) | Calendar           |
| [nerdfont](#nerdfont)     | Font               |

---

## Dowloads

### pipewire
```shell
sudo pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol
```

### bluez
```shell
sudo pacman -S bluez bluez-utils blueman
```

```shell
sudo systemctl enable --now bluetooth
```

### gsimplecal
```shell
sudo pacman -S gsimplecal
```

### nerdfont
```shell
sudo pacman -S ttf-nerd-fonts-symbols-mono
```

### grim slurp swappy wl-clipboard
```shell
sudo pacman --noconfirm -S grim slurp swappy wl-clipboard
```
```shell
mkdir ~/Pictures
```