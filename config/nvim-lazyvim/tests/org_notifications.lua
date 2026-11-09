-- Jalankan: nvim --headless -u NONE -l tests/org_notifications.lua
vim.opt.runtimepath:append(vim.fn.expand("~/.config/nvim"))
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/orgmode")

local Date = require("orgmode.objects.date")
local Promise = require("orgmode.utils.promise")
local OrgFile = require("orgmode.files.file")
local notifications = require("config.org_notifications")
require("orgmode.config"):extend({
  org_agenda_files = {},
  org_todo_keywords = { "TODO", "NEXT", "|", "DONE", "CANCELLED" },
})
require("orgmode").instance()

local function fixture(lines, filename)
  return OrgFile:new({ filename = filename or "/virtual/reminders.org", lines = lines })
end

local file = fixture({
  "* TODO Overdue",
  "DEADLINE: <2026-11-05 Thu>",
  "* NEXT Due today without a time",
  "DEADLINE: <2026-11-06 Fri>",
  "* TODO Due tomorrow",
  "DEADLINE: <2026-11-07 Sat>",
  "* TODO Three days away",
  "DEADLINE: <2026-11-09 Mon>",
  "* TODO Too far away",
  "DEADLINE: <2026-11-10 Tue>",
  "* DONE Finished",
  "DEADLINE: <2026-11-05 Thu>",
  "* CANCELLED Cancelled task",
  "DEADLINE: <2026-11-05 Thu>",
  "* TODO Archived :ARCHIVE:",
  "DEADLINE: <2026-11-05 Thu>",
  "* TODO Scheduled only",
  "SCHEDULED: <2026-11-05 Thu>",
  "* TODO Timed overdue",
  "DEADLINE: <2026-11-06 Fri 09:00>",
  "* TODO Inactive deadline",
  "DEADLINE: [2026-11-05 Thu]",
})
local archive = fixture({ "* TODO Archived file", "DEADLINE: <2026-11-05 Thu>" }, "/virtual/a.org_archive")
local forced_reload = false
local files = {
  load = function(self, force)
    forced_reload = force
    return Promise.resolve(self)
  end,
  all = function()
    return { file, archive }
  end,
}
local now = Date.from_string("2026-11-06 Fri 12:00")
local tasks = notifications.collect(files, now, 3):wait(10000)
assert(forced_reload, "Must refresh agenda files, including external changes")
assert(#tasks == 5, "Expected five tasks, got " .. #tasks)
local by_title = {}
for _, task in ipairs(tasks) do
  by_title[task.title] = task
end
assert(by_title["TODO: Overdue"].phase == "overdue")
assert(by_title["NEXT: Due today without a time"].phase == "today")
assert(by_title["NEXT: Due today without a time"].due == Date.from_string("2026-11-06 Fri 23:59").timestamp)
assert(by_title["TODO: Timed overdue"].phase == "overdue")
assert(by_title["TODO: Due tomorrow"].phase == "upcoming")
assert(by_title["TODO: Three days away"].phase == "upcoming")
assert(tasks[1].title == "TODO: Overdue", "Oldest overdue should be sent first")
assert(by_title["TODO: Overdue"].message:find("DEADLINE:", 1, true))
print("PASS: real Org parser, date-only/timed deadlines, TODO/NEXT, DONE/CANCELLED/archive filters")

local tomorrow = notifications.collect(files, Date.from_string("2026-11-07 Sat 00:00"), 3):wait(10000)
for _, task in ipairs(tomorrow) do
  if task.title == "NEXT: Due today without a time" then
    assert(task.phase == "overdue", "Date-only deadline becomes overdue the following day")
  end
end
print("PASS: date-only deadline changes to overdue at the next midnight")

-- Deterministic clock/scheduler: no desktop notifications or three-hour waits.
notifications.setup({ repeat_minutes = 180 })
local selected = { vim.deepcopy(tasks[1]) }
notifications.collect = function()
  return Promise.resolve(selected)
end
local queued, sent = {}, {}
local real_defer, real_time = vim.defer_fn, os.time
local clock = 100000
os.time = function(opts)
  return opts and real_time(opts) or clock
end
vim.defer_fn = function(callback)
  queued[#queued + 1] = callback
end
notifications.notify = function(title, subtitle, message)
  sent[#sent + 1] = { title, subtitle, message }
end
local function check(force)
  notifications.check(force):wait(10000)
  local callbacks = queued
  queued = {}
  for _, callback in ipairs(callbacks) do
    callback()
  end
end
check()
assert(#sent == 1, "Must catch up overdue tasks immediately")
check()
assert(#sent == 1, "Must not repeat every minute")
clock = clock + 179 * 60
check()
assert(#sent == 1, "Must honor the three-hour cooldown")
clock = clock + 60
check()
assert(#sent == 2, "Must remind again after three hours")
selected[1].phase = "today"
check()
assert(#sent == 3, "A change in urgency must bypass the cooldown")
check(true)
assert(#sent == 4, "Manual forced check must bypass the cooldown")
selected = {}
check()
assert(#sent == 4, "Completed or deleted tasks must stop notifying")
selected = { vim.deepcopy(tasks[1]) }
check()
assert(#sent == 5, "Reopened tasks must notify again")
notifications.check(true):wait(10000)
notifications.stop()
for _, callback in ipairs(queued) do
  callback()
end
assert(#sent == 5, "Stopping must cancel queued notifications")
vim.defer_fn, os.time = real_defer, real_time
assert(vim.fn.exists(":OrgDeadlineCheck") == 2)
assert(vim.fn.exists(":OrgDeadlineTest") == 2)
print("PASS: catch-up, cooldown, repeat, urgency transition, manual check, completion, stop")

-- Exercise the actual repeating timer without sending desktop notifications.
local real_uis, real_check = vim.api.nvim_list_uis, notifications.check
local ticks = 0
vim.api.nvim_list_uis = function()
  return { {} }
end
notifications.check = function()
  ticks = ticks + 1
end
notifications.setup({ check_interval_ms = 20 })
assert(
  vim.wait(5000, function()
    return ticks >= 2
  end, 10),
  "Startup and periodic timer must run in an interactive session"
)
notifications.stop()
local stopped_at = ticks
vim.wait(100, function()
  return false
end, 10)
assert(ticks == stopped_at, "Timer must stop cleanly")
vim.api.nvim_list_uis, notifications.check = real_uis, real_check
print("PASS: interactive startup timer, periodic timer, timer cleanup")
print("All Org deadline notification tests passed (no desktop notifications sent).")
