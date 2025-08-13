## Base

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