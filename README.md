# OpenClaw Auto Installer Ubuntu

Skrip installer otomatis untuk memasang OpenClaw di VPS Ubuntu dengan pendekatan yang lebih aman untuk server produksi.

Repositori ini menyediakan `openclaw-ubuntu-installer.sh` yang melakukan:

- preflight check sebelum instalasi
- validasi distro Ubuntu
- pengecekan akses `sudo`
- pengecekan konektivitas ke host penting
- instalasi dependensi dasar
- instalasi Node.js yang kompatibel
- percobaan installer resmi OpenClaw
- fallback ke `npm` bila installer resmi gagal
- verifikasi hasil instalasi dan `openclaw doctor`
- logging ke file

## Cocok Untuk

- VPS Ubuntu baru
- Server staging
- Server produksi yang ingin menghindari `apt upgrade` otomatis

## Fitur Utama

- Mendukung Ubuntu `22.04`, `24.04`, dan `26.04`
- Default lebih aman: `apt upgrade` tidak dijalankan kecuali diminta
- Bisa dijalankan interaktif atau non-interaktif
- Menyimpan log instalasi
- Bisa reinstall otomatis
- Bisa langsung menjalankan gateway setelah selesai

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

Berikan izin eksekusi:

```bash
chmod +x openclaw-ubuntu-installer.sh
```

Jalankan mode aman default:

```bash
./openclaw-ubuntu-installer.sh
```

## Mode Yang Disarankan

Untuk VPS produksi, gunakan mode default dulu:

```bash
./openclaw-ubuntu-installer.sh
```

Untuk VPS baru yang ingin otomatis tanpa prompt:

```bash
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

- `--yes` untuk mode non-interaktif
- `--reinstall` untuk lanjut reinstall jika OpenClaw sudah ada
- `--upgrade-system` untuk menjalankan `apt upgrade`
- `--start-gateway` untuk langsung menjalankan gateway
- `--log-file PATH` untuk menentukan file log

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

## Catatan Penting

- Default script ini sengaja tidak menjalankan `apt upgrade` supaya lebih aman di VPS produksi.
- Jika OpenClaw sudah terpasang, skrip akan meminta konfirmasi kecuali memakai `--reinstall` atau `--yes`.
- `--yes` menghilangkan prompt, jadi gunakan hanya jika Anda memang siap menerima default action.
- Kegagalan paling umum biasanya berasal dari DNS, firewall, atau repository eksternal yang tidak bisa diakses.

## Troubleshooting

Jika `sudo` gagal:

- pastikan user Anda masuk grup sudo
- cek dengan `sudo -v`

Jika Node.js gagal dipasang:

- pastikan `deb.nodesource.com` bisa diakses
- cek apakah ada konflik paket `nodejs` lama

Jika installer resmi gagal:

- skrip akan mencoba fallback ke `npm`
- cek log untuk melihat error asli

Jika `openclaw doctor` memberi warning:

- baca output doctor
- lanjutkan onboarding dan konfigurasi API key sesuai kebutuhan OpenClaw

## Lisensi

Belum ada file `LICENSE` di repositori ini. Jika repositori akan dipublikasikan lebih luas, sebaiknya tambahkan lisensi resmi.
