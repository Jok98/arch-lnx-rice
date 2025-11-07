## 1
```shell
powerprofilesctl set performance
```

## 2
```shell
sudo nano /boot/loader/entries/arch.conf
```
```text
options root=UUID=0e744881-d4b1-41ad-81f3-cc4cfdbc840e rw rootflags=subvol=@ i915.enable_psr=0 i915.enable_fbc=1
```
```shell
systemctl reboot
```

---

### Firefox
```properties
media.ffmpeg.vaapi.enabled = true
media.rdd-ffmpeg.enabled = true
media.navigator.mediadatadecoder_h264_enabled = true
widget.dmabuf.force-enabled = true
```