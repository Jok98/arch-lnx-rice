Connect to internet
```shell
iwctl
[iwd]# device list
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "SSID"
[iwd]# exit
ping -c3 archlinux.org
```
Find the nvme device
```shell
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
```

### - via curl
```shell
curl -s https://raw.githubusercontent.com/Jok98/arch-lnx-rice/main/installation/arch_install.sh | bash -s -- nvme0n1
```