# Arch Linux Rice

## [Install Arch](installation/arch_install.sh)
On the command line after the first booting :
### 1. connect to internet
```shell
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "SSID"
[iwd]# exit
ping -c3 archlinux.org
```
### 2. Find the nvme device
```shell
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
```

### 3. Run [arch_install.sh](installation/arch_install.sh) script
```shell
curl -s https://raw.githubusercontent.com/Jok98/arch-lnx-rice/main/installation/arch_install.sh | bash -s nvme0n1
```

---

## [Config Arch](installation/arch_conf.sh)
After the reboot caused by [arch_install.sh](installation/arch_install.sh) script, u'll land on hyprland env.

### 1. Run Kitty
`SUPER, Return` or `SUPER, D`

### 2. Clone [arch-lnx-rice](https://github.com/Jok98/arch-lnx-rice) repo
```shell
git clone https://github.com/Jok98/arch-lnx-rice.git
```

### 3. Install Dev tools
This script also contains zsh plugins installation required by oh-my-zsh.
`arch-lnx-rice/installation`
```shell
chmod +x arch_conf.sh
./arch_conf.sh
```

### 4. Apply Arch dotfiles
`arch-lnx-rice/script`
```shell
chmod +x export-config.sh
./export-config.sh
```

### 5.Apply ZSH conf
`arch-lnx-rice/script`
```shell
chmod +x apply-zsh-config.sh
./apply-zsh-config.sh
```