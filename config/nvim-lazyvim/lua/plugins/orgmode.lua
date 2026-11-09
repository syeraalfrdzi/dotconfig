-- Semua fitur Org dalam satu file: pengaturan, notifikasi, format, progress,
-- Orgmode, bullets, agenda, pencarian, lint, dan integrasi Treesitter/lualine.
-- https://nvim-orgmode.github.io
--
-- Catatan penting soal treesitter:
-- - Orgmode memakai parser treesitter `org` untuk parse, fold, dan indent.
-- - Parser itu BUKAN dari nvim-treesitter. Orgmode build sendiri ke dalam
--   folder `parser/` miliknya pada `setup()` pertama (butuh git + C compiler).
-- - Karena itu JANGAN menambahkan "org" ke `ensure_installed` nvim-treesitter,
--   karena akan ada dua parser `org.so` yang saling bentrok (`:checkhealth orgmode`
--   akan memperingatkan soal ini).
-- - Indentasi org dikelola sendiri oleh `ftplugin/org.lua`, jadi treesitter
--   indent dari LazyVim harus dimatikan untuk filetype org.

-- 1. Pengaturan bersama: folder, agenda, dan status TODO.
local org = {
  dir = vim.fn.expand("~/Documents/org"),
  -- Bagian setelah "|" dianggap selesai. (t)/(n)/(d) adalah fast access key.
  todo_keywords = { "TODO(t)", "NEXT(n)", "|", "DONE(d)" },
}
-- Hanya .org: file .org_archive dan *_archive tidak ikut agenda/progress.
org.agenda_files = org.dir .. "/**/*.org"
org.inbox_file = org.dir .. "/inbox.org"

-- 2. Notifikasi desktop selama Neovim hidup (implementasi di config/org_notifications.lua).
org.deadline_notifications = {
  warning_days = 3, -- hari ini sampai H-3, serta semua deadline yang sudah lewat
  repeat_minutes = 180, -- ingatkan lagi tiap 3 jam selama belum DONE
  check_interval_ms = 60_000,
}

-- 3. Format: :OrgSpace, <leader>oF, dan penambahan jarak saat menyimpan.
local function space_headings()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.bo[buf].modifiable then
    vim.notify("OrgSpace: buffer is not modifiable", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local out = {}
  local inserted = 0
  for i, line in ipairs(lines) do
    local is_heading = line:match("^%*%s") ~= nil
    local prev_blank = i == 1 or lines[i - 1]:match("^%s*$") ~= nil
    if is_heading and not prev_blank then
      out[#out + 1] = ""
      inserted = inserted + 1
    end
    out[#out + 1] = line
  end

  if inserted == 0 then
    vim.notify("OrgSpace: no adjacent headings found; nothing changed")
    return
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.notify(("OrgSpace: inserted %d blank line(s) (save with :w)"):format(inserted))
end

local function setup_org_format()
  vim.api.nvim_create_user_command("OrgSpace", space_headings, {
    desc = "Org: sisip 1 baris kosong antar heading yang rapat",
  })
  vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.org",
    group = vim.api.nvim_create_augroup("OrgFormatOnSave", { clear = true }),
    callback = function()
      space_headings()
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "org",
    group = vim.api.nvim_create_augroup("OrgFormatKeymap", { clear = true }),
    callback = function(event)
      vim.keymap.set("n", "<Leader>oF", space_headings, {
        buffer = event.buf,
        desc = "Org: sisip baris kosong antar heading",
      })
    end,
  })
end

-- 4. Progress lualine: cache jumlah TODO/NEXT/DONE seluruh agenda selama 10 detik.
-- Dibuat ketika lualine dikonfigurasi, bukan ketika file spec diimpor.
local function create_org_progress()
  local cache_ttl_ms = 10_000
  local bar_width = 10
  local cache = nil
  local tracked = {}
  local done_keywords = {}
  local after_separator = false
  for _, entry in ipairs(org.todo_keywords) do
    if entry == "|" then
      after_separator = true
    else
      local name = entry:match("^([^%(]+)") or entry
      tracked[name] = true
      if after_separator then
        done_keywords[name] = true
      end
    end
  end

  local function count_keywords()
    local counts = {}
    for name in pairs(tracked) do
      counts[name] = 0
    end
    -- agenda_files sudah berupa glob penuh; jangan gunakan globpath().
    for _, path in ipairs(vim.fn.glob(org.agenda_files, false, true)) do
      local ok, lines = pcall(vim.fn.readfile, path)
      if ok then
        for _, line in ipairs(lines) do
          local keyword = line:match("^%*+%s+([A-Z]+)")
          if keyword and tracked[keyword] then
            counts[keyword] = counts[keyword] + 1
          end
        end
      end
    end
    return counts
  end

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("org_progress", { clear = true }),
    pattern = { "*.org", "*.org_archive" },
    callback = function()
      cache = nil
    end,
  })

  return function()
    local now = vim.uv.now()
    if not cache or (now - cache.at) > cache_ttl_ms then
      cache = { at = now, counts = count_keywords() }
    end
    local total, done = 0, 0
    for name, count in pairs(cache.counts) do
      total = total + count
      if done_keywords[name] then
        done = done + count
      end
    end
    if total == 0 then
      return ""
    end
    local filled = math.floor(done / total * bar_width + 0.5)
    return ("[%s%s] %d/%d"):format(("█"):rep(filled), ("░"):rep(bar_width - filled), done, total)
  end
end

-- 5. Plugin dan integrasi Org. Tambahkan enabled = false pada plugin yang ingin dimatikan.
return {
  {
    "nvim-orgmode/orgmode",
    -- WAJIB: load sebelum deteksi filetype untuk file .org.
    -- Kalau hanya "VeryLazy", ftplugin/org.lua tidak pernah di-source saat
    -- `nvim file.org` dijalankan dari startup, sehingga semua mapping
    -- buffer-local <Leader>o... (ot, oid, ois, oi., oxi, dst.) hilang.
    event = { "BufReadPre *.org", "BufNewFile *.org", "VeryLazy" },
    config = function()
      require("orgmode").setup({
        -- File yang dipindai agenda + lokasi capture/refile default.
        org_agenda_files = org.agenda_files,
        org_default_notes_file = org.inbox_file,

        -- Template capture. `\n` tambahan di akhir `template` membuat satu
        -- baris kosong setelah tiap item baru, supaya antar todo tidak rapat.
        org_capture_templates = {
          t = {
            description = "Task",
            template = "* TODO %?\n  SCHEDULED: %^t\n",
          },
        },

        -- Tampilan: indentasi virtual (HANYA visual, tidak mengubah isi file).
        -- Otomatis aktif saat membuka file .org ("Org indent mode").
        -- Toggle on/off per buffer pakai `:Org indent_mode`.
        org_startup_indented = true,

        -- Matikan auto-indentasi spasi pada baris baru di bawah heading.
        -- Secara default (true), setiap Enter di bawah heading akan memberi spasi/indent,
        -- sehingga jika mengetik `** TODO` menjadi `  ** TODO` (tidak dianggap headline oleh Orgmode).
        org_adapt_indentation = false,

        -- Kata kunci TODO beserta fast access key untuk `org_todo`.
        org_todo_keywords = org.todo_keywords,
        org_todo_keyword_faces = {
          TODO = ":foreground #F7768E",
          NEXT = ":foreground #7AA2F7",
        },

        -- Timer bawaan hanya mencocokkan menit tertentu, tidak menyusulkan overdue.
        -- Diganti pemeriksaan berkala di bawah; jangan aktifkan keduanya (duplikat).
        notifications = {
          enabled = false,
          cron_enabled = false,
        },

        -- LSP orgmode (masih eksperimental, sesuai dokumentasi resmi).
        -- Memberi autocompletion + diagnostics.
      })

      require("config.org_notifications").setup(org.deadline_notifications)

      vim.lsp.enable("org")

      -- Command :OrgSpace — sisip baris kosong antar heading yang rapat.
      setup_org_format()

      -- Alias <Leader>oT untuk mengganti status TODO (maju).
      -- Karena fast access key aktif (`TODO(t)`, `NEXT(n)`, `DONE(d)`), aksi ini
      -- menampilkan prompt `[t] TODO [n] NEXT [d] DONE` dulu, tinggal tekan
      -- salah satu huruf. Sama persis dengan default orgmode (`cit`).
      -- Dipasang buffer-local supaya hanya aktif di file .org dan buffer agenda.
      local function set_todo_alias(buf)
        local action
        if vim.bo[buf].filetype == "org" then
          action = "org_mappings.todo_next_state"
        elseif vim.bo[buf].filetype == "orgagenda" then
          action = "agenda.change_todo_state"
        else
          return
        end
        vim.keymap.set("n", "<Leader>oT", function()
          require("orgmode").action(action)
        end, { buffer = buf, desc = "Org: next TODO state" })
      end

      -- File yang sudah keburu dibuka sebelum plugin ini dimuat (event VeryLazy).
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          set_todo_alias(buf)
          if vim.bo[buf].filetype == "org" then
            require("orgmode.ui.virtual_indent"):new(buf):attach()
          end
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "org", "orgagenda" },
        group = vim.api.nvim_create_augroup("OrgTodoAlias", { clear = true }),
        callback = function(event)
          set_todo_alias(event.buf)
        end,
      })
    end,
  },

  -- Bullet unicode yang pretty untuk heading org (https://github.com/nvim-orgmode/org-bullets.nvim).
  -- Plugin ini menimpa bintang `*` heading memakai extmark (bukan conceal),
  -- jadi hanya visual, isi file tetap `*`, dan tidak butuh `conceallevel`.
  -- Syaratnya treesitter parser `org` aktif — itu sudah dibangun oleh orgmode.
  -- Untuk menonaktifkan plugin ini, tambahkan enabled = false pada spec-nya.
  {
    "nvim-orgmode/org-bullets.nvim",
    dependencies = { "nvim-orgmode/orgmode" },
    ft = "org",
    opts = {
      -- Defaultnya cuma menimpa bintang heading.
      -- Kalau `true`, kursor di baris heading menampilkan bintang asli.
      concealcursor = false,
      -- Bisa juga: "ascii", "dash", "vim", atau tabel simbol per level
      -- (mis. { { "◉", "MyBulletL1" }, ... }) plus highlight group sendiri.
      symbols = {
        list = "•",
        headlines = { "◉", "○", "✸", "✿" },
        -- Highlight pakai capture treesitter bawaan orgmode (lihat
        -- lua/orgmode/colors/highlights.lua): @org.checkbox[.checked/.halfchecked],
        -- @org.keyword.todo, @org.keyword.done.
        checkboxes = {
          half = { "⊜", "@org.checkbox.halfchecked" },
          done = { "✔", "@org.checkbox.checked" },
          todo = { "❍", "@org.checkbox.unchecked" },
        },
      },
    },
  },

  -- Jangan set indentexpr treesitter untuk org; orgmode ftplugin sudah
  -- mengurus indent-nya sendiri (https://nvim-orgmode.github.io/troubleshoot).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      indent = { disable = { "org" } },
    },
  },

  -- Progress bar rasio DONE/total di statusline, khusus buffer org.
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, {
        create_org_progress(),
        cond = function()
          return vim.bo.filetype == "org"
        end,
      })
    end,
  },

  -- Agenda tambahan: <leader>og dan <leader>oG.
  {
    "hamidi-dev/org-super-agenda.nvim",
    dependencies = { "nvim-orgmode/orgmode" },
    cmd = { "OrgSuperAgenda" },
    keys = {
      { "<leader>og", "<cmd>OrgSuperAgenda<cr>", desc = "Org Super Agenda" },
      { "<leader>oG", "<cmd>OrgSuperAgenda!<cr>", desc = "Org Super Agenda (fullscreen)" },
    },
    config = function()
      require("org-super-agenda").setup({
        keymaps = {
          filter_reset = "oa",
          toggle_other = "oo",
          filter = "of",
          filter_fuzzy = "oz",
          filter_query = "oq",
          undo = "u",
          reschedule = "cs",
          set_deadline = "cd",
          cycle_todo = "t",
          set_state = "s",
          reload = "r",
          refile = "R",
          hide_item = "x",
          preview = "K",
          clock_in = "I",
          clock_out = "O",
          clock_cancel = "X",
          clock_goto = "gI",
          reset_hidden = "gX",
          fold_all = "zM",
          unfold_all = "zR",
          toggle_duplicates = "D",
          cycle_view = "ov",
          bulk_mark = "m",
          bulk_unmark_all = "M",
          bulk_reselect = "gv",
          bulk_action = "b",
          open_view = "V",
        },
        groups = {
          {
            name = "Today",
            matcher = function(i)
              return i.scheduled and i.scheduled:is_today()
            end,
            sort = { by = "scheduled_time", order = "asc" },
          },
          {
            name = "Tomorrow",
            matcher = function(i)
              return i.scheduled and i.scheduled:days_from_today() == 1
            end,
            sort = { by = "scheduled_time", order = "asc" },
          },
          {
            name = "Deadlines",
            matcher = function(i)
              return i.deadline and i.todo_state ~= "DONE" and not i:has_tag("personal")
            end,
            sort = { by = "deadline", order = "asc" },
          },
          {
            name = "Important",
            matcher = function(i)
              return i.priority == "A" and (i.deadline or i.scheduled)
            end,
            sort = { by = "date_nearest", order = "asc" },
          },
          {
            name = "Overdue",
            matcher = function(i)
              return i.todo_state ~= "DONE"
                and ((i.deadline and i.deadline:is_past()) or (i.scheduled and i.scheduled:is_past()))
            end,
            sort = { by = "date_nearest", order = "asc" },
          },
          {
            name = "Personal",
            matcher = function(item)
              return item:has_tag("personal")
            end,
          },
          {
            name = "Work",
            matcher = function(item)
              return item:has_tag("work")
            end,
          },
          {
            name = "Upcoming",
            matcher = function(it)
              local days = (require("org-super-agenda.config").get().upcoming_days or 10)
              local d1 = it.deadline and it.deadline:days_from_today()
              local d2 = it.scheduled and it.scheduled:days_from_today()
              local ok1 = d1 and d1 >= 0 and d1 <= days
              local ok2 = d2 and d2 >= 0 and d2 <= days
              return ok1 or ok2
            end,
            sort = { by = "date_nearest", order = "asc" },
          },
        },
        window = {
          width = 0.8,
          height = 0.7,
          border = "rounded",
          title = "Org Super Agenda",
          title_pos = "center",
        },
        upcoming_days = 10,
        hide_empty_groups = true,
        show_other_group = false,
        show_tags = true,
        show_filename = true,
        view_mode = "classic",
        debug = false,
      })
    end,
  },

  -- Pencarian, refile, dan link Org; memakai adapter Snacks, bukan Telescope.
  {
    "nvim-orgmode/telescope-orgmode.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-orgmode/orgmode", "folke/snacks.nvim" },
    opts = { adapter = "snacks" },
    keys = {
      {
        "<leader>fh",
        function()
          require("telescope-orgmode").search_headings()
        end,
        desc = "Org headlines",
      },
      {
        "<leader>ft",
        function()
          require("telescope-orgmode").search_tags()
        end,
        desc = "Org tags",
      },
      {
        "<leader>r",
        function()
          require("telescope-orgmode").refile_heading()
        end,
        desc = "Org refile",
      },
      {
        "<leader>li",
        function()
          require("telescope-orgmode").insert_link()
        end,
        desc = "Org insert link",
      },
    },
    config = function(_, opts)
      require("telescope-orgmode").setup(opts)
    end,
  },

  -- Diagnostics Org melalui org-lint bawaan Emacs; membutuhkan executable emacs.
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.org = { "org_lint" }
      opts.linters = opts.linters or {}
      opts.linters.org_lint = {
        cmd = "emacs",
        stdin = false,
        args = {
          "-Q",
          "--batch",
          "--eval",
          [=[(progn
            (require 'org)
            (require 'org-lint)
            (let ((file (car (last command-line-args-left))))
              (with-temp-buffer
                (insert-file-contents file)
                (org-mode)
                (dolist (report (org-lint))
                  (let ((row (cadr report)))
                    (princ (format "%s:%s\n" (aref row 0) (aref row 2)))))))))]=],
          "--",
        },
        ignore_exitcode = true,
        stream = "stdout",
        parser = require("lint.parser").from_pattern(
          "^(%d+):(.*)$",
          { "lnum", "message" },
          nil,
          { source = "org-lint", severity = vim.diagnostic.severity.WARN },
          { lnum_offset = -1, end_col_offset = 0 }
        ),
      }
    end,
  },
}
