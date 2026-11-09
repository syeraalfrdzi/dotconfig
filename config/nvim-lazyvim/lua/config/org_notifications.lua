-- Pengingat deadline macOS: tidak bergantung pada menit saat Neovim dibuka.
local M = {}
local settings
local timer
local running = false
local generation = 0
local last_sent = {}
local active = {}
local warned = false

local function escape(value)
  return (value:gsub("[\r\n]+", " "):gsub("\\", "\\\\"):gsub('"', '\\"'))
end

function M.notify(title, subtitle, message, on_error)
  local script = ('display notification "%s" with title "%s" subtitle "%s"'):format(
    escape(message),
    escape(title),
    escape(subtitle)
  )
  vim.system({ "osascript", "-e", script }, {}, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        if on_error then
          on_error()
        end
        if not warned then
          warned = true
          vim.notify("Org deadline: notifikasi macOS gagal: " .. result.stderr, vim.log.levels.WARN)
        end
      end)
    end
  end)
end

-- Gunakan parser Orgmode, bukan regex: hormati keyword per-file, tag ARCHIVE,
-- planning drawer, dan perubahan buffer yang belum disimpan.
function M.collect(files, now, warning_days)
  return require("orgmode.utils.promise").async(function()
    files:load(true):await()
    local tasks = {}
    for _, file in ipairs(files:all()) do
      if not file:is_archive_file() then
        file:parse_async():await()
        for _, headline in ipairs(file:get_headlines()) do
          local deadline = headline:get_deadline_date()
          if deadline and deadline:is_deadline() and headline:is_todo() and not headline:is_archived() then
            -- Tanpa jam = masih boleh diselesaikan sepanjang tanggal tersebut.
            local due = deadline:has_time() and deadline or deadline:end_of("day")
            local days = deadline:diff(now, "day")
            local minutes = due:diff(now, "minute")
            if days <= warning_days then
              local phase = minutes < 0 and "overdue" or (days == 0 and "today" or "upcoming")
              local status
              if phase == "overdue" then
                status = days < 0 and ("Terlambat %d hari"):format(-days) or ("Terlambat %d menit"):format(-minutes)
              elseif phase == "today" then
                status = "Deadline hari ini"
              else
                status = ("Deadline %d hari lagi"):format(days)
              end
              local title = vim.trim(headline:get_title())
              local key = table.concat({ file.filename, headline:get_outline_path(), title, due.timestamp }, "\n")
              tasks[#tasks + 1] = {
                key = key,
                phase = phase,
                due = due.timestamp,
                title = ("%s: %s"):format(headline:get_todo(), title),
                subtitle = "Org · " .. status,
                message = ("%s · DEADLINE: <%s>"):format(headline:get_category(), deadline:to_string()),
              }
            end
          end
        end
        require("orgmode.utils.promise").yield():await()
      end
    end
    table.sort(tasks, function(a, b)
      return a.due < b.due or (a.due == b.due and a.key < b.key)
    end)
    return tasks
  end)
end

function M.check(force, verbose)
  if running then
    return
  end
  running = true
  local current_generation = generation
  local now = require("orgmode.objects.date").now()
  return M.collect(require("orgmode").files, now, settings.warning_days)
    :next(function(tasks)
      if generation ~= current_generation then
        return
      end
      active = {}
      local count = 0
      for _, task in ipairs(tasks) do
        active[task.key] = task.phase
        local previous = last_sent[task.key]
        if
          force
          or not previous
          or previous.phase ~= task.phase
          or os.time() - previous.at >= settings.repeat_minutes * 60
        then
          local record = { at = os.time(), phase = task.phase }
          last_sent[task.key] = record
          -- Beri jarak agar banyak task tidak muncul bertumpuk pada saat startup.
          local notification = task
          vim.defer_fn(function()
            if generation == current_generation and active[notification.key] == notification.phase then
              M.notify(notification.title, notification.subtitle, notification.message, function()
                if last_sent[notification.key] == record then
                  last_sent[notification.key] = nil
                end
              end)
            end
          end, count * 2000)
          count = count + 1
        end
      end
      for key in pairs(last_sent) do
        if not active[key] then
          last_sent[key] = nil
        end
      end
      if verbose then
        vim.notify(("Org: %d deadline dekat/terlewat; %d notifikasi dijadwalkan."):format(#tasks, count))
      end
      return tasks
    end)
    :catch(function(err)
      vim.notify("Org deadline: pemeriksaan gagal: " .. tostring(err), vim.log.levels.ERROR)
    end)
    :finally(function()
      running = false
    end)
end

function M.stop()
  generation = generation + 1
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

function M.setup(opts)
  M.stop()
  settings = vim.tbl_extend("force", {
    warning_days = 3,
    repeat_minutes = 180,
    check_interval_ms = 60_000,
  }, opts or {})
  local group = vim.api.nvim_create_augroup("OrgDeadlineNotifications", { clear = true })
  vim.api.nvim_create_user_command("OrgDeadlineCheck", function(cmd)
    M.check(cmd.bang, true)
  end, { bang = true, desc = "Org: cek deadline (! = abaikan jeda 3 jam)" })
  vim.api.nvim_create_user_command("OrgDeadlineTest", function()
    M.notify("TODO: Contoh tugas Org", "Org · Deadline besok", "Notifikasi desktop Orgmode aktif.")
  end, { desc = "Org: tes notifikasi desktop macOS" })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.stop })

  -- Headless (lint/test/cron) jangan mengirim notifikasi otomatis.
  if #vim.api.nvim_list_uis() == 0 then
    return
  end
  if vim.fn.executable("osascript") ~= 1 then
    vim.notify("Org deadline: osascript tidak tersedia.", vim.log.levels.WARN)
    return
  end
  timer = vim.uv.new_timer()
  timer:start(
    3000,
    settings.check_interval_ms,
    vim.schedule_wrap(function()
      M.check()
    end)
  )
  -- Setelah laptop bangun/kembali ke Neovim, cek tanpa menunggu menit berikutnya.
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      M.check()
    end,
  })
end

return M
