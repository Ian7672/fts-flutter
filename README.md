# fts – FadeTail UI

FadeTail adalah aplikasi Flutter untuk membantu menormalkan bagian akhir audio secara batch.

## Tombol Bantuan Tanda Tanya

- Ikon `?` pada AppBar membuka dialog bantuan kontekstual yang menjelaskan fungsi teknis setiap menu.
- Semua teks dialog sudah memakai sistem lokalisasi aplikasi, jadi otomatis mengikuti bahasa yang dipilih pengguna.
- Penjelasan mencakup: kartu Pengaturan, Pengaturan Lanjutan, tombol pemrosesan, serta bagian Tema, Bahasa, Donasi, dan Kredit pada menu samping.

## Ikon Aplikasi

![Icon Flutter](https://raw.githubusercontent.com/Ian7672/fts-flutter/main/assets/icon/icon.png)

Sumber ikon: [Flaticon – Wave Icon](https://www.flaticon.com/free-icon/wave_11710770?term=audio&page=1&position=31&origin=search&related_id=11710770)

### Cara Menggunakan
1. Jalankan aplikasi seperti biasa dan buka halaman utama FadeTail.
2. Ketuk ikon `?` di pojok kanan atas kapan pun Anda perlu mengetahui arti kontrol tertentu.
3. Baca ringkasan per bagian, lalu tutup dialog dengan tombol *Close* untuk kembali bekerja.
4. Ubah bahasa melalui menu samping bila ingin melihat penjelasan dalam bahasa lain.

Dialog bantuan ini bersifat read-only sehingga aman dipanggil kapan pun tanpa menghentikan proses rendering yang sedang berjalan.
