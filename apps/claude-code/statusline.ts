// Claude Code status line, run under Bun (settings.json → statusLine.command).
//
//   > dev/core develop                                  the line before                 09:41
//   ██░░░░░░░░  160.0k/1.0M (16%) | [Opus 5 · High]   ♪ the lyric line playing right now
//   5h: 6% 3h 28m  ·  1w: 62% 11h 58m  ·  ☁  31ms        the line after
//   ▶ Artist - Title  12:34 / 59:59                    and the one after that
//
// Reads the session JSON on stdin. Now-playing comes from statusline-media.ps1, a resident
// PowerShell watcher this script spawns on demand (WinRT is unreachable from Bun, and a
// powershell.exe start per refresh would cost ~570 ms of CPU against Bun's ~30 ms).
import { existsSync, readFileSync, statSync, writeFileSync, openSync, readSync, closeSync } from 'node:fs'
import { spawn } from 'node:child_process'
import { join } from 'node:path'
import { homedir, tmpdir } from 'node:os'

type Window = { used_percentage?: number; resets_at?: number }
type Input = {
  cwd?: string
  transcript_path?: string
  model?: { id?: string; display_name?: string }
  context_window?: { used_percentage?: number; context_window_size?: number }
  rate_limits?: { five_hour?: Window; seven_day?: Window }
}

const CLAUDE_DIR = join(homedir(), '.claude')
const TEMP = tmpdir()
const HEARTBEAT = join(TEMP, 'claude-statusline-heartbeat.txt')
const RIGHT_MARGIN = 4 // the fullscreen frame does not give a row every one of COLUMNS
const LYRIC_LEAD = 0.75 // seconds: a row shown now stays until the next refresh, so match a little ahead

// ---- ANSI ----------------------------------------------------------------------------------------
const ESC = '\x1b'
const paint = (code: string, text: string): string => `${ESC}[${code}m${text}${ESC}[0m`
const dim = (text: string): string => paint('90', text)
const SEP = `  ${dim('·')}  `

// Terminal columns a character occupies: 2 for CJK/fullwidth and emoji-presentation ranges (the
// weather column's 🌡/💧 icons), 1 for everything else this script prints — including the plain
// symbol glyphs (☀ ☁ ☂ ❄ ▶ ♪ …), which render narrow here and so are deliberately left out.
const WIDE_RANGES: [number, number][] = [
  [0x1100, 0x115f], [0x2e80, 0x303e], [0x3041, 0x33ff], [0x3400, 0x4dbf],
  [0x4e00, 0x9fff], [0xa000, 0xa4cf], [0xac00, 0xd7a3], [0xf900, 0xfaff],
  [0x2614, 0x2615], [0xff00, 0xff60], [0xffe0, 0xffe6], [0x1f300, 0x1faff], [0x20000, 0x3fffd],
]
const ZERO_WIDTH = new Set([0xfe0e, 0xfe0f, 0x200d]) // variation selectors, zero-width joiner
function displayWidth(s: string): number {
  let width = 0
  for (const ch of s) {
    const cp = ch.codePointAt(0)!
    if (ZERO_WIDTH.has(cp)) continue
    width += WIDE_RANGES.some(([lo, hi]) => cp >= lo && cp <= hi) ? 2 : 1
  }
  return width
}
const cellWidth = (s: string): number => displayWidth(s.replace(/\x1b\[[0-9;]*m/g, ''))

const pctColor = (v: number): string => (v >= 80 ? '31' : v >= 60 ? '33' : '32')

// ---- Effort ----------------------------------------------------------------------------------------
// The transcript logs the effort actually used each turn, which reflects a session-only /effort
// override that settings.json never sees. Fall back to the per-model setting, then the global one.
function effortFromTranscript(path?: string): string | null {
  if (!path || !existsSync(path)) return null
  try {
    const size = statSync(path).size
    const tail = Math.min(size, 65536)
    const buf = Buffer.alloc(tail)
    const fd = openSync(path, 'r')
    try { readSync(fd, buf, 0, tail, size - tail) } finally { closeSync(fd) }
    const matches = [...buf.toString('utf8').matchAll(/"effort":"(low|medium|high|xhigh|max)"/g)]
    return matches.at(-1)?.[1] ?? null
  } catch { return null }
}

function effortFromSettings(modelId: string): string | null {
  try {
    const s = JSON.parse(readFileSync(join(CLAUDE_DIR, 'settings.json'), 'utf8'))
    const key = modelId.replace(/\[.*\]$/, '') // "claude-opus-5[1m]" → "claude-opus-5"
    return s.modelSettings?.[key]?.effortLevel ?? s.effortLevel ?? null
  } catch { return null }
}

function effortSegment(input: Input): string {
  const raw = effortFromTranscript(input.transcript_path) ?? effortFromSettings(input.model?.id ?? '') ?? 'high'
  const labels: Record<string, string> = { low: 'Low', medium: 'Medium', high: 'High', xhigh: 'Extra High', max: 'Max' }
  const colors: Record<string, string> = { low: '32', medium: '36', high: '33', xhigh: '35', max: '1;31' }
  return paint(colors[raw] ?? '36', labels[raw] ?? raw)
}

// ---- Location ---------------------------------------------------------------------------------------
// Branch is read from .git/HEAD rather than by spawning git; a worktree's .git is a file that
// points at the real gitdir.
function gitBranch(dir: string): string {
  try {
    let gitDir = join(dir, '.git')
    if (statSync(gitDir).isFile()) {
      gitDir = readFileSync(gitDir, 'utf8').match(/^gitdir:\s*(.+)$/m)?.[1].trim() ?? ''
    }
    return readFileSync(join(gitDir, 'HEAD'), 'utf8').match(/^ref: refs\/heads\/(.+)$/m)?.[1] ?? ''
  } catch { return '' }
}

function locationRow(cwd: string): string {
  const parts = cwd.replace(/\\/g, '/').split('/').filter(Boolean)
  const short = parts.length > 2 ? parts.slice(-2).join('/') : cwd
  const branch = gitBranch(cwd)
  const protectedBranch = ['develop', 'staging', 'main', 'master'].includes(branch)
  const branchSeg = branch ? ' ' + paint(protectedBranch ? '31' : '33', branch) : ''
  return `${paint('36', '>')} ${short}${branchSeg}`
}

// ---- Context ----------------------------------------------------------------------------------------
const fmtTokens = (n: number): string =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M` : n >= 1000 ? `${(n / 1000).toFixed(1)}k` : `${n}`

function contextRow(input: Input, model: string, effort: string): string {
  const used = input.context_window?.used_percentage
  const size = input.context_window?.context_window_size
  // a fresh session has no context figures yet; an empty bar keeps the row the same shape (a row
  // that began with spaces would be trimmed and shift everything beside it)
  const pct = used == null ? 0 : Math.round(used)
  const filled = Math.floor(pct / 10)
  const bar = paint(pctColor(pct), '█'.repeat(filled)) + dim('░'.repeat(10 - filled))
  const info = used == null ? dim('-') : size ? `${fmtTokens(Math.round(size * pct / 100))}/${fmtTokens(size)} (${pct}%)` : `${pct}%`
  return `${bar}  ${info} | ${dim('[')}${paint('35', model)} ${dim('·')} ${effort}${dim(']')}`
}

// ---- Rate limits ------------------------------------------------------------------------------------
function fmtRelative(ts: number): string {
  const diff = ts - Math.floor(Date.now() / 1000)
  if (diff <= 0) return 'now'
  const d = Math.floor(diff / 86400), h = Math.floor((diff % 86400) / 3600), m = Math.floor((diff % 3600) / 60)
  return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`
}

function rateSegments(input: Input): string[] {
  const windows: [string, Window | undefined][] = [['5h', input.rate_limits?.five_hour], ['1w', input.rate_limits?.seven_day]]
  return windows.flatMap(([label, w]) => {
    if (w?.used_percentage == null) return []
    const v = Math.round(w.used_percentage)
    return [paint(pctColor(v), `${label}: ${v}%`) + (w.resets_at ? dim(` ${fmtRelative(w.resets_at)}`) : '')]
  })
}

// ---- Ping ----------------------------------------------------------------------------------------------
// ICMP echo to 1.1.1.1, measured by the media watcher every 10 s (Bun has no raw sockets, and a
// TCP handshake from a cold process read high). A stale file means the watcher is not running.
function pingSegment(): string {
  const file = join(TEMP, 'claude-statusline-ping.txt')
  try {
    if (Date.now() - statSync(file).mtimeMs > 60_000) return ''
    const result = readFileSync(file, 'utf8').trim()
    if (result === 'timeout') return paint('31', '☁  offline')
    const ms = Number(result)
    return paint(ms < 50 ? '32' : ms < 150 ? '33' : '31', `☁  ${ms}ms`)
  } catch { return '' }
}

// ---- Now playing --------------------------------------------------------------------------------------
function ensureWatcher(name: string): void {
  const pidFile = join(TEMP, `claude-statusline-${name}.pid`)
  try {
    process.kill(Number(readFileSync(pidFile, 'utf8').trim()), 0)
    return // alive
  } catch {}
  const script = join(CLAUDE_DIR, `statusline-${name}.sh`)
  spawn('nohup', ['bash', script], { detached: true, stdio: 'ignore' }).unref()
}

const fmtClock = (sec: number): string => {
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60
  const mmss = `${h > 0 ? String(m).padStart(2, '0') : m}:${String(s).padStart(2, '0')}`
  return h > 0 ? `${h}:${mmss}` : mmss
}

// YouTube titles love styled Unicode (𝐛𝐨𝐥𝐝, ｆｕｌｌｗｉｄｔｈ); NFKC folds those to plain letters,
// NFD + \p{M} strips accents, and whatever is still not ASCII is dropped.
function toAscii(text: string): string {
  return text
    .normalize('NFKC').normalize('NFD').replace(/\p{M}/gu, '')
    .replace(/[–—]/g, '-').replace(/[^\x20-\x7e]/g, '')
    .replace(/\s+/g, ' ').trim()
}

function truncate(text: string, width: number): string {
  return text.length <= width ? text : text.slice(0, Math.max(0, width - 3)) + '...'
}

// Word-wraps onto as many lines as it takes; a single word longer than the column is hard-broken
// so it never overflows.
function wrapText(text: string, width: number): string[] {
  if (width <= 0) return [text]
  const out: string[] = []
  let line = ''
  for (let word of text.split(' ')) {
    while (word.length > width) {
      if (line) { out.push(line); line = '' }
      out.push(word.slice(0, width))
      word = word.slice(width)
    }
    const candidate = line ? `${line} ${word}` : word
    if (candidate.length > width && line) { out.push(line); line = word } else { line = candidate }
  }
  if (line) out.push(line)
  return out.length ? out : ['']
}

// Text too long for its slot scrolls through it instead, one cell per refresh (the status line
// re-runs every second), pausing on the head for a few ticks so the start is readable.
const MARQUEE_GAP = '   '
const MARQUEE_HOLD = 3
function marquee(text: string, width: number): string {
  if (text.length <= width) return text
  const loop = text + MARQUEE_GAP
  const tick = Math.floor(Date.now() / 1000) % (loop.length + MARQUEE_HOLD)
  const offset = Math.max(0, tick - MARQUEE_HOLD)
  return (loop + loop).slice(offset, offset + width)
}

type Media = { playing: boolean; app: string; artist: string; title: string; position: number; duration: number }

function readMedia(): Media | null {
  try {
    const [status, app, artist, title, positionSec, durationSec, writtenAtMs] =
      readFileSync(join(TEMP, 'claude-statusline-media.txt'), 'utf8').split('|')
    if (!title) return null
    const playing = status === 'Playing'
    const duration = Number(durationSec)
    // the watcher's position is as of writtenAtMs; keep counting from there while playing
    const elapsed = playing ? (Date.now() - Number(writtenAtMs)) / 1000 : 0
    const position = Math.min(duration || Infinity, Number(positionSec) + elapsed)
    return { playing, app, artist, title, position, duration }
  } catch { return null }
}

function mediaRow(m: Media, maxWidth: number): string {
  const icon = m.playing ? paint('32', '▶') : dim('‖')
  const time = m.duration > 0 ? `${fmtClock(Math.floor(m.position))} / ${fmtClock(m.duration)}` : ''
  const track = [m.artist, m.title].map(toAscii).filter(Boolean).join(' - ')
  const room = maxWidth - cellWidth(`${icon} ${time}`) - 2
  const label = m.playing ? marquee(track, room) : dim(truncate(track, room))
  return `${icon} ${label}${time ? '  ' + dim(time) : ''}`
}

// ---- Lyrics --------------------------------------------------------------------------------------------
// Synced lyrics come from LRCLIB (no key needed). One fetch per track, cached in TEMP; a failed
// fetch is cached too, for 30 s, so an offline machine does not retry every second.
type LyricLine = { at: number; text: string }
type LyricCache = { lines: LyricLine[] } | { failedAt: number }

// An empty timestamped line is the LRC file's own instrumental marker; it renders as "...". The
// one marker added here is for an intro, which Spotify also shows as "..." although LRC files
// rarely carry it; gaps inside the song are left to the file, since Spotify leaves them too.
const INTRO_MIN = 5

function parseLrc(lrc: string): LyricLine[] {
  const lines: LyricLine[] = []
  for (const m of lrc.matchAll(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/gm)) {
    lines.push({ at: Number(m[1]) * 60 + Number(m[2]), text: m[3].trim() })
  }
  lines.sort((a, b) => a.at - b.at)
  if (lines[0] && lines[0].at >= INTRO_MIN && lines[0].text !== '') lines.unshift({ at: 0, text: '' })
  return lines
}

// LRCLIB is asked in order of precision: exact artist + track, then free text, then free text
// with the release suffix ("- Remastered 2023", "- Live") cut off. A browser tab reports the
// channel as the artist and the video title as the title ("Artist - Song (Official Video)"), so
// for those only the free-text queries apply, with the video-ish suffixes stripped.
const VIDEO_NOISE = /\((official|from|lyric|video|audio|music|visuali[sz]er|hd|4k|mv)[^)]*\)|\[[^\]]*\]|\|.*$/gi
const RELEASE_SUFFIX = /\s+-\s+[^-]*$/
const BROWSERS = ['chrome', 'msedge', 'firefox', 'brave', 'opera', 'vivaldi']

function lyricQueries(m: Media): URLSearchParams[] {
  const fromBrowser = BROWSERS.some((b) => m.app.toLowerCase().includes(b))
  const title = fromBrowser ? m.title.replace(VIDEO_NOISE, ' ').replace(/\s+/g, ' ').trim() : m.title
  const free = (q: string) => new URLSearchParams({ q })
  const queries = fromBrowser
    ? [free(title)]
    : [new URLSearchParams({ artist_name: m.artist, track_name: title }), free(`${m.artist} ${title}`)]
  if (RELEASE_SUFFIX.test(title)) queries.push(free(`${fromBrowser ? '' : m.artist} ${title.replace(RELEASE_SUFFIX, '')}`))
  return queries
}

// LRCLIB lists the same song from several releases and uploads, and some are timed against a
// different edit — one track had a whole batch with every line 10 s early, all starting at exactly
// [00:00.00], which real lyrics almost never do. So all synced hits within a few seconds of the
// playing duration are pooled, uploads whose first line sits at 0 are set aside when anything else
// exists, and the one whose first timestamp is closest to the pool's median wins.
const DURATION_SLACK = 4

async function fetchLyrics(m: Media): Promise<LyricLine[]> {
  for (const params of lyricQueries(m)) {
    const res = await fetch(`https://lrclib.net/api/search?${params}`,
      { headers: { 'User-Agent': 'claude-statusline' }, signal: AbortSignal.timeout(3000) })
    const hits: { duration: number; syncedLyrics?: string }[] = await res.json()
    const synced = hits.filter((h) => h.syncedLyrics).map((h) => ({ ...h, lines: parseLrc(h.syncedLyrics!) })).filter((h) => h.lines.length)
    if (!synced.length) continue
    const first = (h: typeof synced[number]) => h.lines.find((l) => l.text)?.at ?? h.lines[0].at
    let pool = synced.filter((h) => Math.abs(h.duration - m.duration) <= DURATION_SLACK)
    if (!pool.length) pool = [synced.sort((a, b) => Math.abs(a.duration - m.duration) - Math.abs(b.duration - m.duration))[0]]
    const timed = pool.filter((h) => first(h) > 0.5)
    if (timed.length) pool = timed
    const firsts = pool.map(first).sort((a, b) => a - b)
    const median = firsts[Math.floor(firsts.length / 2)]
    return pool.sort((a, b) =>
      Math.abs(first(a) - median) - Math.abs(first(b) - median) ||
      Math.abs(a.duration - m.duration) - Math.abs(b.duration - m.duration))[0].lines
  }
  return []
}

async function lyricLines(m: Media): Promise<LyricLine[]> {
  const key = Bun.hash(`${m.artist}|${m.title}|${m.duration}`).toString(16)
  const cache = join(TEMP, `claude-statusline-lyrics-${key}.json`)
  try {
    const cached: LyricCache = JSON.parse(readFileSync(cache, 'utf8'))
    if ('lines' in cached) return cached.lines
    if (Date.now() - cached.failedAt < 30_000) return []
  } catch {}
  let entry: LyricCache
  try { entry = { lines: await fetchLyrics(m) } } catch { entry = { failedAt: Date.now() } }
  try { writeFileSync(cache, JSON.stringify(entry)) } catch {}
  return 'lines' in entry ? entry.lines : []
}

// The line playing now normally sits on the second row, with the one before it above and the
// ones after below, so the lyrics scroll upward through a fixed slot. A current line too long
// for the width wraps onto extra rows instead of being cut off with "…", borrowing rows from the
// ones after it first and, if that is not enough, from the one before. Rows with no line to show
// stay blank. Every row is padded to the full width so a refresh overwrites the previous frame.
async function lyricsColumn(m: Media, rows: number, width: number): Promise<string[]> {
  const lines = await lyricLines(m)
  if (!lines.length) return []
  const index = lines.findLastIndex((l) => l.at <= m.position + LYRIC_LEAD)
  const blank = ' '.repeat(width)
  const plain = (text: string) => `  ${dim(truncate(text, width - 2).padEnd(width - 2))}`

  const current = wrapText(toAscii(lines[index]?.text ?? '') || '...', width - 2).slice(0, rows)
    .map((text) => `${paint('35', '♪')} ${paint('1', text.padEnd(width - 2))}`)

  let remaining = rows - current.length
  let before: string | null = null
  if (remaining > 0) {
    const line = lines[index - 1]
    before = line ? plain(toAscii(line.text) || '...') : blank
    remaining -= 1
  }

  const after: string[] = []
  for (let i = 1; after.length < remaining; i++) {
    const line = lines[index + i]
    after.push(line ? plain(toAscii(line.text) || '...') : blank)
  }

  const out = [...(before != null ? [before] : []), ...current, ...after]
  while (out.length < rows) out.push(blank)
  return out.slice(0, rows)
}

// ---- Today's calendar --------------------------------------------------------------------------------
// Events come from statusline-calendar.ps1, a resident watcher that pulls iCloud over CalDAV every
// five minutes. Up to four rows: the event running now bright, the ones still to come plain,
// and past ones dim only when nothing else is left to show.
type Event = { start: Date; end: Date; allDay: boolean; summary: string }
const CALENDAR_ROWS = 4

function readCalendar(): Event[] | null {
  try {
    return readFileSync(join(TEMP, 'claude-statusline-calendar.txt'), 'utf8').split('\n').filter(Boolean).map((line) => {
      const [start, end, allDay, summary] = line.split('|')
      return { start: new Date(start), end: new Date(end), allDay: allDay === '1', summary }
    })
  } catch { return null }
}

const hhmm = (d: Date): string => `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`

// Exactly CALENDAR_ROWS rows in day order beside the clock (three rows tall, so the fourth row
// sits under it). The second row is the "now" slot with the ">" marker: the event running at this
// moment, or blank during a gap between events, so the next one up stays below it rather than
// jumping into the slot early. The one before sits above, the ones after below. Past events are
// dim. Each row is padded to the width so the rows share a left edge inside a right-aligned block.
// Time left until an event starts, for the now-slot during a gap: "-12 minutes", "-1h 05m".
function countdown(e: Event | undefined, now: number): string {
  if (!e) return ''
  const mins = Math.max(0, Math.ceil((e.start.getTime() - now) / 60_000))
  if (mins < 60) return `-${mins} minute${mins === 1 ? '' : 's'}`
  return `-${Math.floor(mins / 60)}h ${String(mins % 60).padStart(2, '0')}m`
}

function calendarRows(events: Event[] | null, width: number, clockRows = 3, wideWidth = width): string[] {
  if (events && !events.length) return [dim('  Tidak ada agenda hari ini'.padEnd(width)), ...Array(CALENDAR_ROWS - 1).fill(' '.repeat(width))]
  if (!events?.length) return Array(CALENDAR_ROWS).fill(' '.repeat(width))
  const now = Date.now()
  const isPast = (e: Event) => e.end.getTime() <= now
  const running = events.findIndex((e) => e.start.getTime() <= now && now < e.end.getTime())
  let next = events.findIndex((e) => e.start.getTime() > now) // -1 once the day is done
  if (next < 0) next = events.length
  const slots: (Event | undefined)[] = running >= 0
    ? [events[running - 1], events[running], events[running + 1], events[running + 2]]
    : [events[next - 1], undefined, events[next], events[next + 1]]
  return slots.slice(0, CALENDAR_ROWS).map((e, row) => {
    const w = row < clockRows ? width : wideWidth // rows under the clock may run beneath it
    if (!e) return row === 1 ? dim(`> ${countdown(events[next], now)}`.padEnd(w)) : ' '.repeat(w)
    const when = e.allDay ? 'Seharian   ' : `${hhmm(e.start)}-${hhmm(e.end)}`
    const text = `${row === 1 ? '>' : ' '} ${when}  ${truncate(toAscii(e.summary), w - 15)}`.padEnd(w)
    return row === 1 ? paint('1;32', text) : isPast(e) ? dim(text) : text
  })
}

// ---- Weather ---------------------------------------------------------------------------------------
// Current conditions from Open-Meteo (no key); refreshed every ten minutes and cached in TEMP, a
// failed fetch waits five minutes before trying again. The coordinates are personal, so they are
// not in this file: put {"latitude": 0.0, "longitude": 0.0} in ~/.claude/statusline-location.json
// (git-ignored). Without that file the weather column simply stays empty.
type Location = { latitude: number; longitude: number }
function readLocation(): Location | null {
  try {
    const { latitude, longitude } = JSON.parse(readFileSync(join(CLAUDE_DIR, 'statusline-location.json'), 'utf8'))
    return Number.isFinite(latitude) && Number.isFinite(longitude) ? { latitude, longitude } : null
  } catch { return null }
}
type Weather = { code: number; day: boolean; temp: number; feels: number; humidity: number; rain?: number }
type WeatherCache = { at: number; weather?: Weather }

// WMO weather codes → a one-cell glyph and a short English label.
function describeWeather(code: number, day: boolean): [string, string] {
  if (code === 0) return day ? ['☀', 'Clear'] : ['☾', 'Clear']
  if (code <= 2) return day ? ['☀', 'Partly cloudy'] : ['☾', 'Partly cloudy']
  if (code === 3) return ['☁', 'Overcast']
  if (code <= 48) return ['≡', 'Fog']
  if (code <= 57) return ['☂', 'Drizzle']
  if (code <= 67) return ['☂', 'Rain']
  if (code <= 77) return ['❄', 'Snow']
  if (code <= 82) return ['☂', 'Showers']
  return ['ϟ', 'Thunderstorm']
}

async function fetchWeather(where: Location): Promise<Weather> {
  const url = new URL('https://api.open-meteo.com/v1/forecast')
  url.searchParams.set('latitude', `${where.latitude}`)
  url.searchParams.set('longitude', `${where.longitude}`)
  url.searchParams.set('current', 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,is_day')
  url.searchParams.set('hourly', 'precipitation_probability')
  url.searchParams.set('forecast_hours', '3')
  url.searchParams.set('timezone', 'auto')
  const res = await fetch(url, { signal: AbortSignal.timeout(3000) })
  const body = await res.json()
  const c = body.current
  // chance of rain over the next three hours, the worst of them
  const rain = Math.max(...((body.hourly?.precipitation_probability ?? []) as number[]).filter((p) => p != null))
  return { code: c.weather_code, day: c.is_day === 1, temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m, rain: Number.isFinite(rain) ? rain : undefined }
}

// Its own column, left of the schedule block: condition on row 1, temperature (🌡, a wide
// emoji — see `displayWidth`) on row 2, humidity (💧) on row 3, rain chance (☔) on row 4, so it
// stays narrow and leaves the
// lyrics column the room. Left unpadded; the column's own left-alignment fills the rest.
async function weatherRows(rows: number): Promise<string[]> {
  const where = readLocation()
  if (!where) return Array(rows).fill('')
  const cache = join(TEMP, 'claude-statusline-weather.json')
  let entry: WeatherCache | null = null
  try { entry = JSON.parse(readFileSync(cache, 'utf8')) } catch {}
  const age = entry ? Date.now() - entry.at : Infinity
  if (!entry || (entry.weather ? age > 600_000 : age > 300_000)) {
    try { entry = { at: Date.now(), weather: await fetchWeather(where) } } catch { entry = { at: Date.now(), weather: entry?.weather } }
    try { writeFileSync(cache, JSON.stringify(entry)) } catch {}
  }
  const w = entry.weather
  if (!w) return Array(rows).fill('')
  const [glyph, label] = describeWeather(w.code, w.day)
  // U+FE0F forces the thermometer into emoji presentation, so it is two cells wide like 💧 and
  // like `displayWidth` counts it; without it the terminal draws it narrow and the row shifts.
  const lines = [`${glyph}  ${label}`, `🌡️ ${w.temp.toFixed(1)}°C (${Math.round(w.feels)}°)`, `💧 ${w.humidity}%`, `☔ ${w.rain ?? '-'}%`]
  return Array.from({ length: rows }, (_, i) => lines[i] ?? '')
}

// ---- Clock -----------------------------------------------------------------------------------------
// HH:mm in three-row block digits, each glyph three cells wide with one cell between glyphs. The
// bottom row uses full and lower-half blocks so the digits sit on the row's baseline.
const GLYPHS: Record<string, [string, string, string]> = {
  '0': ['█▀█', '█ █', '█▄█'],
  '1': ['▄█ ', ' █ ', '▄█▄'],
  '2': ['▀▀█', '█▀▀', '█▄▄'],
  '3': ['▀▀█', '▀▀█', '▄▄█'],
  '4': ['█ █', '▀▀█', '  █'],
  '5': ['█▀▀', '▀▀█', '▄▄█'],
  '6': ['█▀▀', '█▀█', '█▄█'],
  '7': ['▀▀█', '  █', '  █'],
  '8': ['█▀█', '█▀█', '█▄█'],
  '9': ['█▀█', '▀▀█', '▄▄█'],
  ':': [' ', '▄', '▄'],
}

function clockRows(): string[] {
  const now = new Date()
  const text = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
  return [0, 1, 2].map((row) => paint('1', [...text].map((ch) => GLYPHS[ch][row]).join(' ')))
}

// ---- Layout ------------------------------------------------------------------------------------------
// Up to four columns: session rows on the left, lyrics in the middle, weather, then schedule
// beside the clock on the right. Each column starts at a fixed cell so nothing shifts between
// refreshes (widths account for double-width characters — see `displayWidth`). Claude Code trims
// leading whitespace off a row, which would shove an all-space left cell to column 0; a braille
// blank (U+2800) is not whitespace to it and renders as nothing.
type Column = { rows: string[]; width: number; align: 'left' | 'right' }

function layout(columns: Column[], gap: number): string[] {
  const height = Math.max(...columns.map((c) => c.rows.length))
  return Array.from({ length: height }, (_, i) =>
    columns.map((c, ci) => {
      const cell = c.rows[i] ?? ''
      const fill = ' '.repeat(Math.max(0, c.width - cellWidth(cell)))
      const padded = c.align === 'right' ? fill + cell : cell + fill
      return ci === 0 && !cell ? '⠀' + padded.slice(1) : padded
    }).join(' '.repeat(gap)).trimEnd(),
  )
}

// ---- Main -------------------------------------------------------------------------------------------
const input: Input = JSON.parse((await Bun.stdin.text()) || '{}')
const cwd = input.cwd ?? process.cwd()
const model = input.model?.display_name || 'Unknown'
const columns = (Number(process.env.COLUMNS ?? 0) || 120) - RIGHT_MARGIN
const GAP = 3
const SCHEDULE_WIDTH = 36
const CLOCK_WIDTH = 17 // four 3-wide digits, a 1-wide colon, four 1-wide gaps
const WEATHER_WIDTH = 16 // condition / 🌡 temp / 💧 humidity, stacked narrow to leave lyrics the room
const SCHEDULE_CLOCK_WIDTH = SCHEDULE_WIDTH + 2 + CLOCK_WIDTH // today's schedule beside the clock
const RIGHT_WIDTH = WEATHER_WIDTH + GAP + SCHEDULE_CLOCK_WIDTH // weather, then schedule beside the clock

try { writeFileSync(HEARTBEAT, '') } catch {}
ensureWatcher('media')
const calendarEnabled = existsSync(join(CLAUDE_DIR, 'statusline-icloud.json'))
if (calendarEnabled) ensureWatcher('calendar')
const media = readMedia()
const events = calendarEnabled ? readCalendar() : null

const session = [
  locationRow(cwd),
  contextRow(input, model, effortSegment(input)),
  [...rateSegments(input), pingSegment()].filter(Boolean).join(SEP),
]

// The left column is as wide as its widest session row, rounded up to a multiple of 8 so the
// other columns do not creep as "3h 28m" becomes "3h 9m"; the lyrics take whatever is left
// between it and the right block, and only open when that is real room.
const leftWidth = Math.max(48, Math.ceil(Math.max(...session.map(cellWidth)) / 8) * 8)
const lyricsWidth = columns - leftWidth - GAP - RIGHT_WIDTH - GAP
const showLyrics = media != null && lyricsWidth >= 24
const bodyWidth = showLyrics ? leftWidth : columns - RIGHT_WIDTH - GAP

const left = [...session, ...(media ? [mediaRow(media, bodyWidth)] : [])]
const clock = clockRows()
const schedule = calendarRows(events, SCHEDULE_WIDTH, clock.length, SCHEDULE_CLOCK_WIDTH)
const scheduleClock = schedule.map((row, i) => (clock[i] ? `${row}  ${clock[i]}` : row))
const weather = await weatherRows(scheduleClock.length)
const height = Math.max(left.length, scheduleClock.length)
const lyrics = showLyrics ? await lyricsColumn(media, height, lyricsWidth) : []

const plan: Column[] = [{ rows: left, width: bodyWidth, align: 'left' }]
if (showLyrics) plan.push({ rows: lyrics, width: lyricsWidth, align: 'left' })
plan.push({ rows: weather, width: WEATHER_WIDTH, align: 'left' })
plan.push({ rows: scheduleClock, width: SCHEDULE_CLOCK_WIDTH, align: 'left' })
process.stdout.write(layout(plan, GAP).join('\n') + '\n')
