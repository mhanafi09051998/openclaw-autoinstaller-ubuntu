# OpenClaw Auto Installer Ubuntu

Skrip installer otomatis untuk memasang OpenClaw di VPS Ubuntu dengan pendekatan yang lebih aman untuk server produksi.

Repositori ini menyediakan `openclaw-ubuntu-installer.sh` yang melakukan:

- pemeriksaan awal sebelum instalasi
- validasi distro Ubuntu
- pengecekan akses `sudo`
- pengecekan konektivitas ke host penting
- instalasi dependensi dasar
- instalasi Node.js yang kompatibel
- mencoba installer resmi OpenClaw
- beralih ke `npm` bila installer resmi gagal
- verifikasi hasil instalasi dengan `openclaw doctor`
- pencatatan log ke file

## Cocok Untuk

- VPS Ubuntu baru
- Server percobaan (staging)
- Server produksi yang ingin menghindari `apt upgrade` otomatis

## Fitur Utama

- Mendukung Ubuntu `22.04`, `24.04`, dan `26.04`
- Default lebih aman: `apt upgrade` tidak dijalankan kecuali diminta
- Bisa dijalankan interaktif atau non-interaktif
- Output berwarna: banner, perintah, dan prompt pilihan tampil dengan warna berbeda
- Menyimpan log instalasi ke file
- Bisa pasang ulang secara otomatis
- Bisa langsung menjalankan gateway setelah selesai
- Menampilkan hint slash commands yang valid setelah onboarding

## Prasyarat

- Ubuntu
- User dengan akses `sudo`
- Koneksi internet aktif

Host yang sebaiknya dapat diakses:

- `openclaw.ai`
- `deb.nodesource.com`
- `registry.npmjs.org`
- `github.com`

## Cara Pakai

Clone repositori:

```bash
git clone https://github.com/mhanafi09051998/openclaw-autoinstaller-ubuntu.git
cd openclaw-autoinstaller-ubuntu
```

Setelah `git clone`, nama `openclaw-autoinstaller-ubuntu` adalah folder repositori.
File yang harus dijalankan adalah:

```bash
openclaw-ubuntu-installer.sh
```

Berikan izin eksekusi:

```bash
chmod +x openclaw-ubuntu-installer.sh
```

Jalankan mode aman default:

```bash
./openclaw-ubuntu-installer.sh
```

Contoh lengkap di VPS jika repo di-clone ke home directory:

```bash
cd ~/openclaw-autoinstaller-ubuntu
chmod +x openclaw-ubuntu-installer.sh
./openclaw-ubuntu-installer.sh
```

Jangan jalankan folder repo seperti ini karena itu direktori, bukan file:

```bash
./openclaw-autoinstaller-ubuntu/
```

## Memperbarui Instalasi yang Sudah Ada

Jika OpenClaw sudah terpasang sebelumnya (baik lewat installer ini maupun cara lain), jalankan
installer ulang dengan flag `--reinstall`:

```bash
cd ~/openclaw-autoinstaller-ubuntu
git pull
chmod +x openclaw-ubuntu-installer.sh
./openclaw-ubuntu-installer.sh --reinstall
```

Skrip akan mendeteksi instalasi lama secara otomatis, melewati konfirmasi, lalu menjalankan ulang
seluruh proses — mulai dari pemeriksaan awal, pembaruan dependensi, hingga verifikasi akhir.

Jika ingin sepenuhnya otomatis tanpa prompt apapun:

```bash
./openclaw-ubuntu-installer.sh --yes
```

> **Catatan:** `--reinstall` dan `--yes` keduanya membuat installer melewati konfirmasi pasang ulang.
> Perbedaannya, `--yes` juga menjawab **ya** untuk semua prompt lain (termasuk "Mulai gateway sekarang?").

## Mode yang Disarankan

Untuk VPS produksi, gunakan mode default dulu:

```bash
./openclaw-ubuntu-installer.sh
```

Untuk VPS baru yang ingin otomatis tanpa prompt:

```bash
./openclaw-ubuntu-installer.sh --yes --reinstall
```

Contoh lengkap:

```bash
cd ~/openclaw-autoinstaller-ubuntu
chmod +x openclaw-ubuntu-installer.sh
./openclaw-ubuntu-installer.sh --yes --reinstall
```

Jika memang ingin sekalian upgrade paket sistem:

```bash
./openclaw-ubuntu-installer.sh --upgrade-system
```

Jika ingin start gateway otomatis:

```bash
./openclaw-ubuntu-installer.sh --start-gateway
```

Jika ingin menyimpan log ke lokasi tertentu:

```bash
./openclaw-ubuntu-installer.sh --log-file /var/log/openclaw-installer.log
```

## Opsi CLI

```bash
./openclaw-ubuntu-installer.sh --help
```

Opsi yang tersedia:

- `--yes` untuk mode non-interaktif (jawab semua konfirmasi dengan ya)
- `--reinstall` untuk melanjutkan pemasangan ulang jika OpenClaw sudah terpasang
- `--upgrade-system` untuk menjalankan `apt upgrade` sebelum instalasi
- `--start-gateway` untuk langsung menjalankan gateway setelah instalasi selesai
- `--log-file PATH` untuk menentukan lokasi file log

## Lokasi Log

Secara default log disimpan di:

```bash
~/.openclaw-installer/logs/
```

## Alur Instalasi

Skrip akan melakukan langkah berikut:

1. Memastikan `sudo` tersedia dan valid.
2. Membaca `/etc/os-release`.
3. Memastikan distro adalah Ubuntu.
4. Memberi peringatan jika versi Ubuntu di luar daftar yang diuji.
5. Mengecek command dasar yang dibutuhkan.
6. Mengecek konektivitas ke host penting.
7. Menjalankan `apt update`.
8. Menjalankan `apt upgrade` hanya jika `--upgrade-system` dipakai.
9. Memasang dependensi dasar.
10. Memastikan Node.js minimal kompatibel.
11. Menginstal OpenClaw.
12. Menjalankan verifikasi `openclaw --version`.
13. Menjalankan `openclaw doctor`.

## Slash Commands OpenClaw

OpenClaw mendukung dua sistem perintah dalam sesi chat:

- **Commands** — pesan mandiri yang diawali `/`, dieksekusi langsung
- **Directives** — modifier persisten yang mengubah perilaku respons (misalnya `/think`, `/fast`)

Daftar slash commands yang didukung:

| Kategori | Perintah |
|---|---|
| Session & Status | `/help`, `/commands`, `/status`, `/whoami` (`/id`), `/session` |
| Model & Pemrosesan | `/model <nama>`, `/think`, `/fast`, `/verbose`, `/reasoning`, `/elevated` |
| Tools & Skills | `/tools [compact\|verbose]`, `/skill <nama>` |
| Manajemen Sesi | `/reset`, `/new`, `/export-session`, `/btw <pertanyaan>` |
| Konfigurasi (owner) | `/config show\|set\|unset`, `/debug show\|set`, `/mcp`, `/plugins` |
| Lanjutan | `/subagents`, `/acp`, `/focus`, `/unfocus`, `/bash <perintah>` |

> **Catatan:** Perintah di luar daftar di atas (misalnya `/dream`) tidak dikenal oleh server OpenClaw dan akan ditolak. Gunakan `/help` atau `/commands` di dalam sesi untuk melihat daftar lengkap yang tersedia.

## Catatan Penting

- Default script ini sengaja tidak menjalankan `apt upgrade` supaya lebih aman di VPS produksi.
- Jika OpenClaw sudah terpasang, skrip akan meminta konfirmasi kecuali memakai `--reinstall` atau `--yes`.
- `--yes` menghilangkan semua prompt, jadi gunakan hanya jika Anda memang siap menerima tindakan bawaan.
- Kegagalan paling umum biasanya berasal dari DNS, firewall, atau repository eksternal yang tidak bisa diakses.

## Troubleshooting

Jika `sudo` gagal:

- pastikan pengguna Anda terdaftar dalam grup sudo
- periksa dengan perintah `sudo -v`

Jika Node.js gagal dipasang:

- pastikan `deb.nodesource.com` dapat diakses
- periksa apakah ada konflik dengan paket `nodejs` versi lama

Jika installer resmi gagal:

- skrip akan secara otomatis beralih ke `npm`
- periksa log untuk melihat pesan kesalahan asli

Jika `openclaw doctor` memberikan peringatan:

- baca output dari perintah tersebut dengan teliti
- lanjutkan proses onboarding dan konfigurasi API key sesuai kebutuhan OpenClaw

## Lisensi

Belum ada file `LICENSE` di repositori ini. Jika repositori akan dipublikasikan secara lebih luas, sebaiknya tambahkan lisensi resmi.
