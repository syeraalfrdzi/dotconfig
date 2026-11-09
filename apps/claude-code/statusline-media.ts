// macOS Now Playing and ICMP watcher. File formats match statusline-media.ps1.
import { readFileSync, writeFileSync, unlinkSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
const temp = process.env.CLAUDE_STATUSLINE_TMP || tmpdir()
const file = (name: string) => join(temp, `claude-statusline-${name}`)
const pidFile = file('media.pid')
const heartbeat = file('heartbeat.txt')
const mediaFile = file('media.txt')
const pingFile = file('ping.txt')
const clean = (v: unknown) => String(v ?? '').replace(/[|\r\n]/g, ' ').trim()
const run = (args: string[], timeout = 3000) => Bun.spawnSync(args, { stdout: 'pipe', stderr: 'ignore', timeout })
function sampleMedia(): string {
  const result = run(['/opt/homebrew/bin/nowplaying-cli', 'get', '--json', 'title', 'artist', 'duration', 'elapsedTime', 'playbackRate', 'clientBundleIdentifier'])
  if (result.exitCode !== 0) return ''
  const media = JSON.parse(result.stdout.toString())
  if (!media.title) return ''
  const playing = Number(media.playbackRate) > 0
  const bundle = String(media.clientBundleIdentifier ?? '')
  const app = bundle.includes('spotify') ? 'Spotify' : bundle.includes('Music') ? 'Music' : bundle.split('.').at(-1) || 'nowplaying'
  let pos = Math.max(0, Number(media.elapsedTime) || 0)
  // Spotify currently reports elapsedTime=0 through Now Playing. Ask Spotify directly for its
  // position while keeping Now Playing as the source of the active track and playback state.
  if (app === 'Spotify' && playing && pos < 1) {
    const fallback = run(['/usr/bin/osascript', '-e', 'tell application "Spotify" to get player position'], 2000)
    if (fallback.exitCode === 0) pos = Math.max(0, Number(fallback.stdout.toString().trim()) || 0)
  }
  const duration = Math.max(0, Number(media.duration) || 0)
  return [playing ? 'Playing' : 'Paused', clean(app), clean(media.artist), clean(media.title), pos.toFixed(1), Math.round(duration), Date.now()].join('|')
}
function samplePing(): string {
  for (let attempt = 0; attempt < 2; attempt++) {
    const result = run(['/sbin/ping', '-c', '1', '-W', '1000', '1.1.1.1'], 2500)
    const ms = result.stdout.toString().match(/time[=<]([\d.]+)/)?.[1]
    if (ms) return String(Math.round(Number(ms)))
  }
  return 'timeout'
}
writeFileSync(pidFile, String(process.pid))
try {
  let tick = 0
  while (true) {
    const started = Date.now()
    try { writeFileSync(mediaFile, sampleMedia()) } catch { writeFileSync(mediaFile, '') }
    if (tick++ % 10 === 0) {
      try { writeFileSync(pingFile, samplePing()) } catch { writeFileSync(pingFile, 'timeout') }
    }
    try { if (Date.now() - statSync(heartbeat).mtimeMs > 120_000) break } catch { break }
    await Bun.sleep(Math.max(0, 1000 - (Date.now() - started)))
  }
} finally {
  try { unlinkSync(pidFile) } catch {}
}
