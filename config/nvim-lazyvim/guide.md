# Panduan belajar konfigurasi Neovim + LazyVim

Panduan ini disesuaikan dengan konfigurasi di `~/.config/nvim` saat ditulis.
Contoh kode di sini **belum diterapkan** ke konfigurasi kamu.

## 1. Mulai dari mana?

| Saya ingin…                                    | Tempat mengaturnya                 |
| ---------------------------------------------- | ---------------------------------- |
| Mengaktifkan/menonaktifkan paket fitur LazyVim | `:LazyExtras`                      |
| Menambah plugin dari GitHub                    | File baru di `lua/plugins/`        |
| Menonaktifkan satu plugin                      | `enabled = false` pada plugin spec |
| Mengubah pengaturan plugin                     | `opts` pada plugin spec            |
| Mengubah nomor baris, tab, atau opsi editor    | `lua/config/options.lua`           |
| Menambah shortcut umum                         | `lua/config/keymaps.lua`           |
| Menjalankan aksi otomatis saat event tertentu  | `lua/config/autocmds.lua`          |
| Melihat plugin terpasang dan statusnya         | `:Lazy`                            |
| Mengelola LSP, formatter, dan linter eksternal | `:Mason`                           |

**Alur aman:** ubah satu hal → simpan → restart Neovim → cek hasilnya.
Sebelum bereksperimen, salin file yang akan diedit ke lokasi cadangan di luar
`lua/plugins/`. Jangan menaruh salinan `.lua` aktif di folder itu karena bisa ikut diimpor.

## 2. Neovim, lazy.nvim, dan LazyVim itu berbeda

- **Neovim**: editornya.
- **lazy.nvim**: pengelola plugin; mengunduh, memuat, dan memperbarui plugin.
- **LazyVim**: kumpulan plugin, keymap, dan konfigurasi siap pakai di atas Neovim.
- **LazyVim Extra**: paket konfigurasi opsional untuk fitur tertentu. Satu Extra
  bisa mengatur beberapa plugin dan tool sekaligus.

Contoh: Extra TypeScript bukan sekadar satu plugin. Ia menyiapkan integrasi
dukungan bahasa; kebutuhan runtime dan dependensi proyek tetap perlu tersedia.

## 3. Peta konfigurasi kamu

```text
~/.config/nvim/
├── init.lua                 # Titik masuk, memanggil config.lazy
├── lazyvim.json             # Pilihan Extras dan metadata LazyVim
├── lazy-lock.json           # Catatan versi/commit plugin
└── lua/
    ├── config/
    │   ├── lazy.lua         # Bootstrap lazy.nvim dan daftar import
    │   ├── options.lua      # Opsi editor dan variabel global
    │   ├── keymaps.lua      # Shortcut umum
    │   └── autocmds.lua     # Event otomatis
    └── plugins/             # Satu file per kelompok fitur
        ├── colorscheme.lua
        ├── discord.lua
        ├── markdown.lua
        ├── orgmode.lua      # Semua plugin, pengaturan, dan fungsi Org
        ├── snacks.lua       # Dashboard dan explorer
        ├── toggleterm.lua
        └── web-dev.lua
```

Di `lua/config/lazy.lua` sudah ada:

```lua
spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  { import = "lazyvim.plugins.extras.ai.copilot" },
  { import = "plugins" },
},
```

Artinya, file spec dalam `lua/plugins/` otomatis ditemukan oleh lazy.nvim.
Tidak perlu menambahkan `require("plugins.nama-file")` ke `init.lua`.
Nama file bebas; identitas plugin ditentukan oleh spec di dalamnya.
LazyVim juga membaca pilihan Extras dari `lazyvim.json`.

> Jangan mengedit kode plugin di direktori data Neovim. Perubahan di sana bisa
> tertimpa saat update. Buat override di `lua/plugins/` saja.

### File yang sudah kamu punya

| File dalam `lua/plugins/` | Fungsi                                                                                          |
| ------------------------- | ----------------------------------------------------------------------------------------------- |
| `colorscheme.lua`         | Tema Gruvbox dan pilihan colorscheme LazyVim                                                    |
| `discord.lua`             | Discord Rich Presence lewat `vyfor/cord.nvim`                                                   |
| `toggleterm.lua`          | Terminal serta command layout tambahan                                                          |
| `snacks.lua`              | Dashboard dan explorer Snacks di kanan, termasuk hidden/ignored files                           |
| `markdown.lua`            | Mematikan spell dan lint Markdown, serta mengecualikan formatter `markdownlint-cli2`            |
| `web-dev.lua`             | LSP HTML/CSS/Emmet, tool Mason, dan Live Server untuk preview HTML                              |
| `orgmode.lua`             | Semua fitur Org: pengaturan, notifikasi, format, progress, bullets, agenda, pencarian, dan lint |

Tambahkan konfigurasi ke file fitur yang sesuai agar tidak tercecer. Buat file
baru hanya untuk kelompok fitur baru. `example.lua` bawaan sudah dihapus.

### Isi `orgmode.lua`

File ini dibagi menjadi bagian bernomor supaya mudah dicari:

1. **Pengaturan bersama**: folder `~/Documents/org`, pola agenda, inbox, dan status TODO.
2. **Notifikasi**: popup Neovim dan notifikasi macOS.
3. **Format**: command `:OrgSpace`, shortcut `<leader>oF`, dan format saat menyimpan.
4. **Progress**: perhitungan tugas selesai untuk statusline, termasuk cache.
5. **Plugin dan integrasi**: Orgmode, bullets, Treesitter, lualine, Super Agenda,
   pencarian melalui adapter Snacks, dan lint melalui Emacs.

Untuk mengubah folder atau status TODO, edit bagian pertama. Untuk mengatur
plugin pendamping, cari nama repository-nya di bagian kelima. Tidak perlu lagi
mencari `config/org.lua` atau modul `org_*.lua` terpisah.

## 4. Mengelola LazyVim Extras

### Cara paling mudah: `:LazyExtras`

1. Buka Neovim, tekan `Esc`, lalu ketik `:LazyExtras` dan Enter.
2. Gerakkan kursor dengan `j` / `k` ke Extra yang diinginkan.
3. Tekan `x` untuk mengaktifkan atau menonaktifkannya.
4. Pilihannya otomatis disimpan ke `lazyvim.json`.
5. Tutup dan buka ulang Neovim agar perubahan diterapkan.
6. Tunggu instalasi selesai. Jika ada plugin yang belum terpasang, jalankan `:Lazy install`.

Untuk belajar, coba toggle **satu** Extra yang tidak sedang dibutuhkan, restart,
lalu aktifkan kembali. Jangan langsung mematikan banyak Extras.

### Extras yang tercatat di `lazyvim.json` kamu

- Coding: `coding.yanky`.
- Formatting: `formatting.prettier`.
- Bahasa: `lang.docker`, `lang.json`, `lang.markdown`, `lang.prisma`,
  `lang.python`, `lang.rust`, `lang.sql`, `lang.tailwind`, `lang.toml`,
  `lang.typescript`.
- Linting: `linting.eslint`.
- Utilitas: `util.dot`, `util.mini-hipatterns`.

Nama lengkap di JSON memakai awalan `lazyvim.plugins.extras.`, misalnya:

```json
"lazyvim.plugins.extras.lang.python"
```

`lazyvim.json` memakai JSON biasa: jangan menambahkan komentar atau koma terakhir.
Lebih aman mengelolanya lewat `:LazyExtras` daripada mengedit JSON manual.
Jangan mengganti seluruh isi file atau menghapus metadata lainnya.

### Kasus khusus: Copilot kamu diimpor manual

Copilot aktif melalui baris ini di `lua/config/lazy.lua`:

```lua
{ import = "lazyvim.plugins.extras.ai.copilot" },
```

Untuk menonaktifkan Extra tersebut, komentari baris itu:

```lua
-- { import = "lazyvim.plugins.extras.ai.copilot" },
```

Lalu restart. Menghapusnya dari `lazyvim.json` saja tidak cukup karena import
manual masih ada. Jika `:LazyExtras` menampilkan **Not managed by LazyExtras
(config)**, periksa import manual seperti ini.

Agar nantinya dikelola lewat UI: hapus/comment import manual, restart, lalu
aktifkan `ai.copilot` lewat `:LazyExtras`. Hindari mengelola Extra yang sama di dua tempat.
Extra yang diwajibkan oleh Extra lain juga perlu ditelusuri ke sumbernya.

### Mengapa plugin/tool masih ada setelah Extra dimatikan?

- Plugin mungkin juga dipakai fitur lain atau ditambahkan oleh file custom.
- File `web-dev.lua` kamu masih meminta beberapa tool seperti `vtsls`,
  `tailwindcss-language-server`, dan `eslint-lsp` dipasang melalui Mason.
- Menghapus Extra tidak otomatis menghapus semua tool eksternal di Mason.
- Plugin yang sudah dimuat dalam sesi berjalan tidak otomatis di-unload; restart dulu.

Jika ingin membersihkan plugin yang tidak lagi digunakan, tinjau daftar pada
`:Lazy clean` sebelum menyetujui penghapusan. Tool eksternal dikelola terpisah lewat `:Mason`.

## 5. Membaca plugin spec

Contoh berikut hanya untuk memahami bentuknya; ToggleTerm sudah ada di konfigurasi kamu:

```lua
return {
  {
    "akinsho/toggleterm.nvim", -- Repository GitHub: pemilik/nama
    cmd = "ToggleTerm",       -- Muat saat command digunakan
    opts = {
      direction = "float",    -- Pengaturan milik plugin
    },
  },
}
```

| Properti                     | Arti                                                                              |
| ---------------------------- | --------------------------------------------------------------------------------- |
| `enabled = false`            | Keluarkan plugin dari konfigurasi aktif                                           |
| `opts = { ... }`             | Pengaturan plugin; digabung dengan opsi spec sebelumnya                           |
| `opts = function(_, opts)`   | Ubah opsi yang sudah ada                                                          |
| `dependencies = { ... }`     | Plugin yang dibutuhkan                                                            |
| `keys = { ... }`             | Shortcut dan pemicu lazy-loading                                                  |
| `cmd = "NamaCommand"`        | Muat saat command dipanggil                                                       |
| `ft = "markdown"`            | Muat saat filetype tersebut dibuka                                                |
| `event = "VeryLazy"`         | Muat pada event tertentu                                                          |
| `lazy = false`               | Muat saat startup, bukan menonaktifkan plugin                                     |
| `config = function(_, opts)` | Setup khusus ketika plugin dimuat                                                 |
| `optional = true`            | Override berlaku hanya jika plugin juga didefinisikan non-optional di tempat lain |

**Penting:** `lazy = true` bukan berarti plugin mati. Di konfigurasi kamu,
`defaults.lazy = false`; plugin custom tanpa pemicu lazy-loading umumnya dimuat saat startup.

Gunakan `opts` terlebih dahulu. lazy.nvim biasanya akan memanggil
`require("modul-plugin").setup(opts)` otomatis; beberapa plugin membutuhkan
`main` atau `config` khusus sesuai dokumentasinya. Mengganti `config` plugin
bawaan bisa menggantikan setup LazyVim, jadi jangan dilakukan tanpa kebutuhan.

## 6. Menambahkan plugin sendiri

Misalnya ingin menambahkan `stevearc/oil.nvim` sebagai editor direktori tambahan.
Buat `~/.config/nvim/lua/plugins/oil.lua`:

```lua
return {
  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    opts = {
      default_file_explorer = false,
      view_options = {
        show_hidden = true,
      },
    },
  },
}
```

Kemudian:

1. Simpan file dan restart Neovim.
2. Tunggu instalasi; gunakan `:Lazy install` bila diperlukan.
3. Jalankan `:Oil` untuk mencobanya.

`default_file_explorer = false` sengaja dipakai agar Oil tidak mengambil alih
explorer Snacks kamu. Menambah plugin tidak selalu berarti harus mengganti fitur bawaan.

Sebelum memasang plugin lain, periksa apakah LazyVim sudah menyediakan fiturnya
atau punya Extra yang sesuai. Ikuti juga kebutuhan versi Neovim, dependency,
dan langkah build pada dokumentasi plugin tersebut.

## 7. Menonaktifkan dan mengaktifkan kembali plugin

### Cara A: ubah spec aslinya

Untuk Discord, tambahkan `enabled = false` di level plugin pada `discord.lua`:

```lua
return {
  {
    "vyfor/cord.nvim",
    enabled = false,
    lazy = false,
    opts = {
      -- Opsi yang sudah ada tetap dipertahankan di sini.
    },
  },
}
```

Ini ilustrasi posisi `enabled`, bukan perintah untuk mengganti seluruh isi file.
**Jangan taruh `enabled = false` di dalam `opts`** jika tujuanmu menghentikan
pemuatan plugin. `opts.enabled` adalah opsi khusus plugin, bukan sakelar lazy.nvim.

Untuk mengaktifkan lagi, hapus `enabled = false` atau ubah menjadi `true`, lalu restart.

### Cara B: kumpulkan plugin yang dimatikan

Buat `lua/plugins/disabled.lua`:

```lua
return {
  { "vyfor/cord.nvim", enabled = false },
  -- Tambahkan plugin lain yang memang ingin dimatikan di sini.
}
```

Nama repository harus cocok dengan plugin yang diatur. Konfigurasi aslinya
tidak perlu dihapus. Untuk mengaktifkan kembali, hapus/comment entri disable
tersebut dan restart. Pilih satu cara agar tidak ada sakelar yang bertentangan
di beberapa file; jika sudah ada `enabled` lain, rapikan di sumbernya.

**Jangan langsung mematikan plugin fondasi** seperti `snacks.nvim`, LSP, atau
Treesitter. Banyak fitur/keymap bisa bergantung padanya. Untuk Orgmode kamu,
ada beberapa plugin pendamping dengan dependency ke `nvim-orgmode/orgmode`;
semuanya sekarang berada di `lua/plugins/orgmode.lua`. Periksa spec bullets,
Super Agenda, dan pencarian sebelum mematikan plugin utamanya.

### Menghentikan seluruh file konfigurasi sementara

Untuk melewati satu file `lua/plugins/*.lua`, kamu bisa menambahkan ini di bagian
paling atas, sebelum kode lain:

```lua
if true then
  return {}
end
```

Ini **melewati isi file**, bukan selalu menonaktifkan plugin: plugin bawaan
LazyVim atau plugin yang didefinisikan file lain bisa tetap aktif.
Hapus blok tersebut untuk mengembalikan isi file. Pola ini juga mencegah kode
di luar `return` ikut berjalan, seperti autocmd pada `markdown.lua` kamu.

## 8. Mengubah opsi tanpa mematikan plugin

### Contoh: mengubah layout terminal

Edit `opts.direction` di `lua/plugins/toggleterm.lua`:

```lua
direction = "float", -- Pilihan lain: "horizontal" atau "vertical"
```

File kamu juga sudah menyediakan `:ToggleTermFloat`, `:ToggleTermHorizontal`,
dan `:ToggleTermVertical` untuk mencoba layout tanpa mengubah default.

### Contoh: mematikan dashboard saja

Di spec `folke/snacks.nvim` pada `lua/plugins/snacks.lua`, tambahkan
`enabled = false` ke tabel `dashboard`, sambil mempertahankan preset yang ada:

```lua
opts = {
  dashboard = {
    enabled = false,
    -- preset yang sudah ada tetap di sini
  },
},
```

Di sini `opts.dashboard.enabled` memang opsi fitur Snacks. Explorer dan fitur
Snacks lain tetap bisa digunakan; tidak perlu `enabled = false` untuk seluruh plugin.

### Menggabungkan opsi vs mengganti opsi

`opts = { ... }` menggabungkan tabel pengaturan, tetapi jangan menganggap semua
list otomatis ditambahkan. Perilaku list juga dapat dipengaruhi `opts_extend`
dari spec plugin. Untuk menambah list secara eksplisit, gunakan fungsi:

```lua
return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "stylua") then
        table.insert(opts.ensure_installed, "stylua")
      end
    end,
  },
}
```

Fungsi itu mengubah opsi yang ada. Sebaliknya, `opts = function() return { ... } end`
menggantikan opsi sebelumnya. Hindari pola penggantian total jika hanya ingin
mengubah satu pengaturan. `web-dev.lua` kamu sudah mengatur Mason, jadi untuk
perubahan tool web sebaiknya mulai dari file itu agar mudah dilacak.

## 9. Opsi editor, shortcut, dan tool bahasa

### Opsi editor

Edit `lua/config/options.lua`, misalnya:

```lua
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
```

Opsi khusus filetype, EditorConfig, atau formatter bisa menimpa pengaturan
indentasi. Konfigurasi kamu saat ini memakai nomor baris biasa dan
`vim.g.lazyvim_ts_lsp = "vtsls"`.

### Shortcut

`<leader>` default LazyVim adalah **Space**. Misalnya `<leader>og` berarti
tekan Space, lalu `o`, lalu `g` dalam normal mode.

Untuk shortcut umum, tambahkan ke `lua/config/keymaps.lua`:

```lua
vim.keymap.set("n", "<leader>ug", "<cmd>LazyExtras<cr>", {
  desc = "Kelola LazyVim Extras",
})
```

Cek dahulu apakah kombinasi tersebut sudah dipakai dengan
`:verbose nmap <leader>ug`. Untuk shortcut plugin yang perlu memicu lazy-loading,
lebih cocok gunakan `keys` di spec plugin. Shortcut custom kamu yang sudah ada:
`;` membuka command line, Tab/Shift-Tab berpindah buffer, dan Ctrl-X keluar
dari terminal mode.

### LSP, formatter, dan linter bukan hal yang sama

- **LSP**: completion, navigasi, rename, dan bisa menyediakan diagnostics.
- **Formatter**: merapikan format kode; di LazyVim umumnya lewat Conform.
- **Linter**: memeriksa masalah kode; bisa lewat nvim-lint atau integrasi lain.
- **Mason**: memasang banyak executable tool; bukan pengganti konfigurasi integrasinya.

Untuk bahasa baru, mulai dari `:LazyExtras` → pilih `lang.*` → restart → buka
file bahasanya → periksa `:Mason` dan `:checkhealth vim.lsp`.
Tool tertentu memerlukan Node.js, Python, compiler, atau dependency proyek.
Pastikan juga project root dikenali; terpasang di Mason belum tentu berarti LSP sudah attach.

### Go Live untuk HTML/CSS/JavaScript

Plugin `barrettruth/live-server.nvim` dikonfigurasi di `lua/plugins/web-dev.lua`.
Tidak memerlukan executable `live-server` atau instalasi npm tambahan.

1. Setelah konfigurasi berubah, restart Neovim dan tunggu instalasi plugin.
   Jika belum terpasang, jalankan `:Lazy install`.
2. Buka file HTML yang sudah disimpan, misalnya `index.html`.
3. Jalankan `:LiveServerStart` atau tekan **Space → c → G** untuk toggle Go Live.
4. Browser otomatis terbuka; port awalnya `5500`. Simpan perubahan dengan `:w`
   agar browser memperbarui tampilan.
5. Hentikan dengan `:LiveServerStop` atau **Space → c → X**.

Secara default folder file yang sedang dibuka menjadi root server. Jika HTML ada
di subfolder atau kamu berpindah file, gunakan root yang eksplisit:

```vim
:LiveServerStart ~/projects/website
:LiveServerStop ~/projects/website
```

Port dan pembukaan browser otomatis bisa diubah lewat `vim.g.live_server`
di bagian `init` plugin tersebut. Ini untuk website statis; proyek React/Next.js
tetap memakai dev server framework, misalnya `npm run dev`.

## 10. Perintah penting dan troubleshooting

| Perintah                                                         | Kegunaan                                                     |
| ---------------------------------------------------------------- | ------------------------------------------------------------ |
| `:Lazy`                                                          | Melihat status dan detail plugin                             |
| `:LazyExtras`                                                    | Toggle paket fitur LazyVim                                   |
| `:Lazy install`                                                  | Memasang plugin yang belum terpasang                         |
| `:Lazy update`                                                   | Memperbarui plugin                                           |
| `:Lazy clean`                                                    | Membersihkan plugin yang tidak lagi digunakan; tinjau dulu   |
| `:Lazy sync`                                                     | Gabungan install, clean, dan update; bukan sekadar reload    |
| `:Lazy restore`                                                  | Mengembalikan versi plugin sesuai `lazy-lock.json` saat ini  |
| `:Mason`                                                         | Mengelola tool eksternal                                     |
| `:ConformInfo`                                                   | Memeriksa formatter jika Conform aktif                       |
| `:lua vim.print(require("lint").linters_by_ft[vim.bo.filetype])` | Melihat daftar linter filetype saat ini jika nvim-lint aktif |
| `:messages`                                                      | Melihat pesan error sebelumnya                               |
| `:checkhealth`                                                   | Memeriksa kesehatan konfigurasi dan dependency               |
| `:verbose nmap <leader>og`                                       | Melacak asal shortcut normal mode                            |
| `:set filetype?`                                                 | Melihat filetype buffer saat ini                             |
| `:echo stdpath('config')`                                        | Memastikan direktori konfigurasi yang digunakan              |

`lazy-lock.json` bukan daftar sakelar plugin. Jangan mengeditnya untuk mematikan
plugin. Cadangkan sebelum update jika ingin bisa kembali ke versi sebelumnya;
`:Lazy restore` memakai lockfile yang tersedia, bukan otomatis riwayat lama.

### Perubahan tidak terlihat

1. Pastikan mengedit konfigurasi yang benar: `:echo stdpath('config')`.
2. Simpan file dan restart penuh, bukan hanya `:source init.lua`.
3. Lihat `:messages` untuk error Lua.
4. Cek `:Lazy`: plugin belum dimuat bisa saja menunggu command/filetype, bukan rusak.
5. Cari spec lain atau import Extra yang masih mengaktifkan fitur tersebut.

### Neovim gagal dibuka setelah mengedit konfigurasi

Buka file bermasalah dari terminal tanpa memuat konfigurasi:

```sh
nvim --clean ~/.config/nvim/lua/plugins/disabled.lua
```

Ganti path sesuai file yang baru diubah, perbaiki perubahan terakhir atau pulihkan
salinan cadangannya, simpan, lalu buka Neovim normal. Kesalahan umum: lupa koma,
kurung kurawal tidak berpasangan, atau menaruh `enabled` di dalam `opts`.
Tidak perlu langsung menghapus seluruh folder konfigurasi atau data plugin.

## 11. Latihan bertahap

1. Ubah `relativenumber` di `options.lua`, restart, lalu kembalikan.
2. Matikan Discord dengan `enabled = false`, cek di `:Lazy`, lalu aktifkan lagi.
3. Buka `:LazyExtras`, toggle satu Extra yang tidak dibutuhkan, lalu pulihkan.
4. Tambahkan Oil dari contoh, coba `:Oil`, lalu nonaktifkan dengan `enabled = false`.
5. Ubah layout default ToggleTerm dan coba command layout yang sudah tersedia.

Setelah tiap latihan, pastikan konfigurasi kembali stabil sebelum lanjut.
Tidak ada perubahan pada plugin yang diperlukan hanya untuk membaca panduan ini.

## Referensi resmi

- [Konfigurasi plugin LazyVim](https://www.lazyvim.org/configuration/plugins)
- [Daftar LazyVim Extras](https://www.lazyvim.org/extras)
- [Pengaturan umum LazyVim](https://www.lazyvim.org/configuration/general)
- [Plugin spec lazy.nvim](https://lazy.folke.io/spec)
- [Perintah lazy.nvim](https://lazy.folke.io/usage)
