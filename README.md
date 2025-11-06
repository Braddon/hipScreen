# hip-screen (hs)

**Terminal multiplexers for cool kids with bad memories**

## Why?

tmux and Screen are powerful but clunky, and remembering session names does not make me fun at parties.  And that's why i made `hip-screen`.   You too can change your life with this one command line tool.

Thankfully `hip-screen` makes it dead simple:

- **Named sessions you'll actually remember** - "Big Jim's little bug" beats "23847.pts-2.hostname"
- **See everything at a glance** - what's running, when you last touched it, how many connections
- **Quick attach/detach** - perfect for remote work sessions
- **Works with tmux or screen** - use whichever you prefer (or both!)

**Real-world scenario:** I run Claude Code on remote servers, because that's how i roll.  I even use termius on my phone so i can monitor them - yes life is really that amazing.  When i need a latte but I don't want to lose my place, it really bugs me to reconnect to the sessions on remote.  That's why i created hip-screen - and now I'm sharing it so you can go grab a latte too!

## Installation

### Requirements

- bash 4.0 or later
- One or both of:
  - tmux 1.8+ (recommended)
  - GNU Screen 4.0+
- Standard Unix tools (find, stat, ps, grep, sed, awk, date, tput)

### Quick Install

```bash
# Download
curl -O https://raw.githubusercontent.com/Braddon/hip-screen/main/hs
# Or just copy the script

# Make executable and install
chmod +x hs
sudo mv hs /usr/local/bin/

# Done! The tool will automatically detect tmux or screen
hs
```

### Installing tmux or screen

```bash
# Ubuntu/Debian
sudo apt install tmux

# macOS
brew install tmux

# RHEL/CentOS
sudo yum install tmux
```

## Usage

### Basic Usage

```bash
$ hs
hip-screen (tmux) - 3 session(s) running:

#    Name                      Last Active  Connections
──────────────────────────────────────────────────────────
1.   development^              2 mins       1            <--- you are already in here
2.   production                15 hrs       2
3.   testing                   3 days       0

Select session number, 'n' for new, 'k' to kill:
```

Type a number to attach, `n` to create a new named session, or `k` to kill an old one. Press ESC to exit anytime.

### Backend Selection

By default, hip-screen auto-detects and prefers tmux if available. You can override this:

```bash
# Force screen backend
HS_BACKEND=screen hs

# Force tmux backend
HS_BACKEND=tmux hs

# Make permanent (add to ~/.bashrc or ~/.zshrc)
export HS_BACKEND=screen
```

### Session Naming

**tmux:**
- Cannot use periods (`.`), colons (`:`), or spaces
- Use hyphens or underscores instead
- Example: `my-project-name`

**GNU Screen:**
- Supports all characters including spaces
- Example: `my project name`

### Debug Mode

```bash
# Show backend detection info
HS_DEBUG=1 hs
```

## Troubleshooting

### "No terminal multiplexer found"

Install tmux or screen:

```bash
# Ubuntu/Debian
sudo apt install tmux

# macOS
brew install tmux

# RHEL/CentOS
sudo yum install tmux
```

### Invalid session name errors (tmux)

tmux session names cannot contain periods, colons, or spaces. Use hyphens or underscores instead.

### Want to use screen instead of tmux?

Set the backend preference:
```bash
export HS_BACKEND=screen
```

## Contributing

Found a bug? Want to make it more hip??? PRs welcome!
