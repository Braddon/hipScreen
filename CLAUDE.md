# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

hip-screen (hs) is a user-friendly wrapper around terminal multiplexers (tmux and GNU Screen) that provides an interactive menu system for managing sessions with human-readable names and metadata.

## Backend Architecture

hip-screen supports multiple terminal multiplexers through a function-based abstraction layer. The design maintains a single-file utility while supporting different backends seamlessly.

### Supported Backends

- **tmux**: Modern terminal multiplexer with advanced features (preferred default)
- **GNU Screen**: Traditional terminal multiplexer with broader compatibility

### Backend Selection

**Automatic detection with preference order:**

1. `$HS_BACKEND` environment variable (if set and valid)
2. tmux (if installed)
3. screen (if installed)
4. Error exit if neither found

**Configuration:**

```bash
# Force specific backend
export HS_BACKEND=screen  # Use screen even if tmux available
export HS_BACKEND=tmux    # Use tmux even if screen available

# Run with temporary override
HS_BACKEND=screen ./hs

# Enable debug mode
HS_DEBUG=1 ./hs
```

Add to `.bashrc` or `.zshrc` for persistence.

### Abstraction Layer

The implementation uses 9 core functions (hs:6-252):

1. `detect_backend()` - Auto-detect or honor `$HS_BACKEND`
2. `get_sessions()` - List session names
3. `get_current_session()` - Detect if running inside session
4. `get_session_activity()` - Get last activity timestamp
5. `get_session_connections()` - Count active connections
6. `validate_session_name()` - Validate name for backend
7. `create_session()` - Create new session
8. `attach_session()` - Attach to existing session
9. `kill_session()` - Terminate session

**Backend-agnostic components** (~67% of codebase):
- Time formatting logic
- Character-by-character input system
- Table display and ANSI formatting
- Terminal width adaptation
- Main loop structure

### Session Naming Conventions

**GNU Screen:**
- Supports all characters including spaces
- No restrictions on session names
- Example: `screen -S "my project name"`

**tmux:**
- **Cannot contain:** `.` (period), `:` (colon), or spaces
- **Recommended:** Use hyphens or underscores
- Example: `tmux new -s my-project-name`

The `validate_session_name()` function enforces these constraints and provides helpful error messages with sanitized suggestions.

### Implementation Details

**Session Discovery (by backend):**

```bash
# tmux - clean output with format variables
get_sessions() {
    tmux list-sessions -F '#{session_name}' 2>/dev/null
}

# screen - regex parsing from screen -ls
get_sessions() {
    screen_output=$(screen -ls 2>/dev/null)
    echo "$screen_output" | grep -oP '\d+\.\K[^\t(]+' | sed 's/[[:space:]]*$//'
}
```

**Metadata Access:**

tmux provides superior metadata access through format variables:
- `#{session_attached}` - Connection count (vs ps + grep for screen)
- `#{session_activity}` - Last activity timestamp (vs socket file stat for screen)
- `#{session_name}` - Clean session name (vs PID.name parsing for screen)

**Current Session Detection:**

```bash
# tmux - uses $TMUX environment variable
if [[ -n "$TMUX" ]]; then
    tmux display-message -p '#{session_name}'
fi

# screen - uses $STY environment variable
if [[ -n "$STY" ]]; then
    echo "${STY#*.}"  # Strip PID prefix
fi
```

## Architecture

This is a single-file bash utility (`hs`) with no dependencies beyond core Unix tools and one of the supported terminal multiplexers.

### Core Functionality

The script operates in four main phases:

1. **Backend Detection** (hs:6-72): Detects available terminal multiplexer (tmux or screen) and initializes backend-specific settings
2. **Session Discovery** (hs:259-266): Uses backend abstraction to list active sessions and count connections
3. **Display & Metadata** (hs:325-376): Retrieves session metadata (last activity, connections) and formats for display
4. **Interactive Menu** (hs:382+): Handles user actions:
   - Numeric input: attach to existing session
   - 'n': create new named session
   - 'k': kill existing session with confirmation

### Key Implementation Details

- Backend abstraction isolates all multiplexer-specific operations in functions
- Session names with spaces fully supported for screen backend
- tmux session names validated to prevent invalid characters
- All session metadata retrieved through backend-specific methods
- Character-by-character input handling for responsive UI

## Development Commands

### Testing

**Backend Detection Testing:**
```bash
# Test with both backends installed
./hs  # Should prefer tmux

# Test backend override
HS_BACKEND=screen ./hs
HS_BACKEND=tmux ./hs

# Test debug mode
HS_DEBUG=1 ./hs

# Test with missing backend
HS_BACKEND=invalid ./hs  # Should show error
```

**Session Operations Testing:**
```bash
# Test with tmux backend
HS_BACKEND=tmux ./hs
# Try creating sessions with various names:
# - "my-project" (should work)
# - "my.project" (should reject)
# - "my project" (should reject)
# - "my_project" (should work)

# Test with screen backend
HS_BACKEND=screen ./hs
# Try creating sessions with spaces:
# - "my project name" (should work)

# Test connection counting (open 2 terminals)
# Terminal 1: hs -> attach to session
# Terminal 2: hs -> attach to same session
# Terminal 3: hs -> verify shows 2 connections
```

**Edge Case Testing:**
```bash
# Test with no sessions (kill all first)
# For tmux:
tmux list-sessions 2>/dev/null | awk '{print $1}' | sed 's/:$//' | xargs -I {} tmux kill-session -t {}
./hs

# For screen:
screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
HS_BACKEND=screen ./hs

# Test with many sessions
for i in {1..15}; do tmux new -d -s "test-$i"; done
./hs

# Test terminal width adaptation
stty cols 40 && ./hs  # Narrow
stty cols 80 && ./hs  # Standard
stty cols 140 && ./hs # Wide
```

**Code Quality:**
```bash
# Syntax check
bash -n hs

# Static analysis
shellcheck hs

# Formatting check (optional)
shfmt -d -i 4 -ci hs
```

### Installation Testing

```bash
# Test installation to /usr/local/bin
chmod +x hs
sudo cp hs /usr/local/bin/
hs

# Test from different directory
cd /tmp && hs

# Verify backend detection
command -v tmux && echo "tmux available"
command -v screen && echo "screen available"
```

### Compatibility Testing

The script requires:
- bash 4.0+ (for mapfile and associative arrays)
- tmux 1.8+ or GNU Screen 4.0+ (one or both)
- Standard Unix tools: find, stat, ps, grep, sed, awk, date, tput

**Test on target systems:**
```bash
# Check bash version
bash --version | head -1

# Check backend versions
tmux -V
screen -v | head -1

# Verify required tools
for cmd in find stat ps grep sed awk date tput; do
    command -v $cmd && echo "$cmd: OK" || echo "$cmd: MISSING"
done
```

## Important Considerations

- The script supports both tmux and GNU Screen via backend abstraction
- Backend auto-detection prefers tmux, but can be overridden with `$HS_BACKEND`
- Session naming restrictions differ between backends (tmux more restrictive)
- Socket directory for screen varies by system - checks `/var/run/screen/S-$USER` first, falls back to `$HOME/.screen`
- tmux uses native format variables for metadata, screen uses socket file stats and ps parsing
