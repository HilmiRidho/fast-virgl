Bangun deb (SEMUA patch 0001-0003) di cloud GitHub, tanpa PC/NDK:

1. Buat repo baru di github.com (boleh private).
2. Upload SEMUA file di zip ini ke root repo (Add file > Upload files).
   - Folder tersembunyi .github sering tidak ikut terupload dari HP. Kalau begitu:
     Add file > Create new file > nama: .github/workflows/build-deb.yml
     lalu tempel isi file build-deb.yml.
3. Tab Actions > "Build virglrenderer deb" > Run workflow (atau otomatis jalan saat upload).
4. Tunggu selesai (~5-10 menit) > buka run-nya > Artifacts > virglrenderer-android-deb.
5. Unzip, lalu di Termux:  pkg install ./virglrenderer-android_1.3.0-3_aarch64.deb

Belum pernah dijalankan di GitHub oleh pembuatnya. Kalau step ada yang merah,
kirim log step yang gagal (teks error-nya) supaya bisa diperbaiki.
