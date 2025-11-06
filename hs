#!/bin/bash

#
# Backend Detection and Configuration
#
detect_backend() {
    # Honor explicit backend choice from environment variable
    if [[ -n "${HS_BACKEND:-}" ]]; then
        if command -v "$HS_BACKEND" >/dev/null 2>&1; then
            echo "$HS_BACKEND"
            return 0
        else
            echo "Error: HS_BACKEND set to '$HS_BACKEND' but command not found" >&2
            return 1
        fi
    fi

    # Auto-detect with preference order: tmux > screen
    if command -v tmux >/dev/null 2>&1; then
        echo "tmux"
        return 0
    fi

    if command -v screen >/dev/null 2>&1; then
        echo "screen"
        return 0
    fi

    echo ""
    return 1
}

# Detect and set backend
BACKEND=$(detect_backend)

if [[ -z "$BACKEND" ]]; then
    echo "Error: No terminal multiplexer found"
    echo "Please install 'tmux' or 'screen'"
    exit 1
fi

# Debug mode (enabled via HS_DEBUG=1)
if [[ "${HS_DEBUG:-0}" == "1" ]]; then
    echo "DEBUG: Backend detected: $BACKEND" >&2
    echo "DEBUG: Backend path: $(command -v "$BACKEND")" >&2
    case "$BACKEND" in
        tmux)
            echo "DEBUG: tmux version: $(tmux -V)" >&2
            echo "DEBUG: \$TMUX = ${TMUX:-<not set>}" >&2
            ;;
        screen)
            echo "DEBUG: screen version: $(screen -v | head -1)" >&2
            echo "DEBUG: \$STY = ${STY:-<not set>}" >&2
            ;;
    esac
    echo "" >&2
fi

# Backend-specific initialization
case "$BACKEND" in
    screen)
        # Set screen socket directory
        SCREENDIR="/var/run/screen/S-$USER"
        [[ ! -d "$SCREENDIR" ]] && SCREENDIR="$HOME/.screen"
        if [[ "${HS_DEBUG:-0}" == "1" ]]; then
            echo "DEBUG: SCREENDIR = $SCREENDIR" >&2
        fi
        ;;
    tmux)
        # tmux doesn't need socket directory for metadata access
        ;;
esac

#
# Get List of Session Names
#
get_sessions() {
    case "$BACKEND" in
        tmux)
            # Check if tmux server is running
            if ! tmux list-sessions -F '#{session_name}' 2>/dev/null; then
                # Return empty if no sessions (tmux exits non-zero)
                return 0
            fi
            ;;
        screen)
            local screen_output
            screen_output=$(screen -ls 2>/dev/null || true)
            if [[ -n "$screen_output" ]]; then
                echo "$screen_output" | grep -oP '\d+\.\K[^\t(]+' | sed 's/[[:space:]]*$//'
            fi
            ;;
    esac
}

#
# Get Current Session Name (if inside one)
#
get_current_session() {
    case "$BACKEND" in
        tmux)
            if [[ -n "$TMUX" ]]; then
                tmux display-message -p '#{session_name}' 2>/dev/null || true
            fi
            ;;
        screen)
            if [[ -n "$STY" ]]; then
                echo "${STY#*.}"
            fi
            ;;
    esac
}

#
# Get Last Activity Timestamp (epoch seconds)
#
get_session_activity() {
    local name="$1"

    case "$BACKEND" in
        tmux)
            # Use format variable to get activity timestamp
            tmux list-sessions -F '#{session_name} #{session_activity}' 2>/dev/null | \
                grep "^$(printf '%q' "$name") " | awk '{print $2}'
            ;;
        screen)
            # Use socket file modification time
            local socket
            socket=$(find "$SCREENDIR" -name "*.$name" 2>/dev/null | head -1)
            if [[ -n "$socket" ]]; then
                stat -c %Y "$socket" 2>/dev/null || true
            fi
            ;;
    esac
}

#
# Get Connection/Client Count
#
get_session_connections() {
    local name="$1"

    case "$BACKEND" in
        tmux)
            # Use format variable to get attachment count
            tmux list-sessions -F '#{session_name} #{session_attached}' 2>/dev/null | \
                grep "^$(printf '%q' "$name") " | awk '{print $2}'
            ;;
        screen)
            # Count screen client processes
            ps -eo cmd | grep -F "screen" | grep -F "$name" | \
                grep -v "SCREEN" | grep -v grep | wc -l
            ;;
    esac
}

#
# Validate Session Name for Backend
#
validate_session_name() {
    local name="$1"

    # Check for empty name
    if [[ -z "$name" ]]; then
        echo "Error: Session name cannot be empty" >&2
        return 1
    fi

    # Warn about long names (display may truncate at 25 chars)
    if [[ ${#name} -gt 25 ]]; then
        echo "Warning: Session name is ${#name} characters (display truncates at 25)" >&2
        echo -n "Continue anyway? (y/N): " >&2
        read -r confirm
        if [[ "$confirm" != "y" ]]; then
            return 1
        fi
    fi

    case "$BACKEND" in
        tmux)
            # tmux doesn't allow periods, colons, or spaces
            if [[ "$name" =~ [.:\ ] ]]; then
                echo "" >&2
                echo "Error: tmux session names cannot contain '.', ':', or spaces" >&2
                echo "Suggestion: Use hyphens or underscores instead" >&2
                # Provide auto-sanitized suggestion
                local suggestion="${name//[ .]/-}"
                suggestion="${suggestion//:/-}"
                echo "Example: '$suggestion'" >&2
                return 1
            fi
            ;;
        screen)
            # Screen allows all characters including spaces
            ;;
    esac

    return 0
}

#
# Create New Session
#
create_session() {
    local name="$1"

    # Validate name for backend
    if ! validate_session_name "$name"; then
        return 1
    fi

    case "$BACKEND" in
        tmux)
            tmux new-session -s "$name"
            ;;
        screen)
            screen -S "$name"
            ;;
    esac
}

#
# Attach to Session
#
attach_session() {
    local name="$1"

    case "$BACKEND" in
        tmux)
            tmux attach-session -t "$name"
            ;;
        screen)
            screen -x "$name"
            ;;
    esac
}

#
# Kill Session
#
kill_session() {
    local name="$1"

    case "$BACKEND" in
        tmux)
            tmux kill-session -t "$name"
            ;;
        screen)
            screen -S "$name" -X quit
            ;;
    esac
}

# Get current session using abstraction
CURRENT_SESSION=$(get_current_session)

# Main loop - return here after killing a session
while true; do
    # Get session list using backend abstraction
    mapfile -t sessions < <(get_sessions)

    # Get connection counts for each session using backend abstraction
    declare -A conn_counts
    for session_name in "${sessions[@]}"; do
        conn_counts["$session_name"]=$(get_session_connections "$session_name")
    done

    if [ ${#sessions[@]} -eq 0 ]; then
    echo "No active screens."
    echo -n "Create new session - Name: "
    name=""
    while true; do
        IFS= read -n 1 -s char
        if [[ "$char" == $'\e' ]]; then
            echo ""
            exit 0
        fi
        if [[ "$char" == $'\n' || "$char" == "" ]]; then
            echo ""
            break
        fi
        if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [[ -n "$name" ]]; then
                name="${name%?}"
                echo -ne '\b \b'
            fi
            continue
        fi
        echo -n "$char"
        name="${name}${char}"
    done
    [[ -n "$name" ]] && create_session "$name" || echo "Cancelled."
    exit 0
fi

echo "hip-screen ($BACKEND) - ${#sessions[@]} session(s) running:"
echo ""

# Get terminal width with fallback
term_width=$(tput cols 2>/dev/null || echo 80)

# Validate term_width is a number
if ! [[ "$term_width" =~ ^[0-9]+$ ]]; then
    term_width=80
fi

# Calculate if inline note will fit (base table width ~86 + note text ~30 = ~116)
use_footnote=false
footnote_text=""
if [[ $term_width -lt 116 ]]; then
    use_footnote=true
fi

# ANSI formatting codes
BOLD='\033[1m'
RESET='\033[0m'
# Using cyan background which works well in both light and dark themes
HIGHLIGHT='\033[1;46;30m'  # Bold + Cyan background + Black text

printf "${BOLD}%-4s %-25s %-12s %-12s${RESET}\n" "#" "Name" "Last Active" "Connections"
# printf "%-4s %-25s %-20s %-20s %-12s\n" "#" "Name" "Last Active" "Created" "Connections"
echo "──────────────────────────────────────────────────────────"
# echo "─────────────────────────────────────────────────────────────────────────────────"

for i in "${!sessions[@]}"; do
    name="${sessions[$i]}"
    # Get last activity timestamp using backend abstraction
    modified_epoch=$(get_session_activity "$name")
    if [[ -n "$modified_epoch" ]]; then
        # created=$(stat -c %w "$socket" 2>/dev/null | cut -d. -f1)
        # [[ "$created" == "-" ]] && created=$(stat -c %y "$socket" 2>/dev/null | cut -d. -f1)

        # Calculate time since last active
        current_epoch=$(date +%s)
        seconds_ago=$((current_epoch - modified_epoch))

        if [[ $seconds_ago -lt 60 ]]; then
            time_ago="${seconds_ago} secs"
        elif [[ $seconds_ago -lt 3600 ]]; then
            minutes_ago=$((seconds_ago / 60))
            time_ago="${minutes_ago} mins"
        elif [[ $seconds_ago -lt 86400 ]]; then
            hours_ago=$((seconds_ago / 3600))
            time_ago="${hours_ago} hrs"
        elif [[ $seconds_ago -lt 2592000 ]]; then
            days_ago=$((seconds_ago / 86400))
            time_ago="${days_ago} days"
        else
            weeks_ago=$((seconds_ago / 604800))
            time_ago="${weeks_ago} wks"
        fi
    else
        time_ago="unknown"
        # created="unknown"
    fi
    conns="${conn_counts[$name]:-0}"

    # Check if this is the current session
    display_name="$name"
    note=""
    row_prefix=""
    row_suffix=""
    if [[ "$name" == "$CURRENT_SESSION" ]]; then
        display_name="${name}^"
        row_prefix="$HIGHLIGHT"
        row_suffix="$RESET"
        if $use_footnote; then
            footnote_text="^ [you are already in '$name']"
        else
            note="<--- you are already in here"
        fi
    fi

    printf "${row_prefix}%-4s %-25s %-12s %-12s %s${row_suffix}\n" "$((i+1))." "$display_name" "$time_ago" "$conns" "$note"
    # printf "%-4s %-25s %-20s %-20s %-12s %s\n" "$((i+1))." "$display_name" "$modified" "$created" "$conns" "$note"
done

# Display footnote if needed
if [[ -n "$footnote_text" ]]; then
    echo ""
    echo "$footnote_text"
fi

echo ""
echo -n "Select session number, 'n' for new, 'k' to kill: "

# Read input character by character to handle ESC immediately
choice=""
while true; do
    IFS= read -n 1 -s char

    # Check for ESC
    if [[ "$char" == $'\e' ]]; then
        echo ""
        exit 0
    fi

    # Check for Enter/Return
    if [[ "$char" == $'\n' || "$char" == "" ]]; then
        echo ""
        break
    fi

    # Check for backspace/delete
    if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
        if [[ -n "$choice" ]]; then
            # Remove last character from string
            choice="${choice%?}"
            # Move cursor back, print space, move back again
            echo -ne '\b \b'
        fi
        continue
    fi

    # Echo the character and add to choice
    echo -n "$char"
    choice="${choice}${char}"
done

    if [[ -z "$choice" ]]; then
        # Empty input - show extended prompt with quit option
        echo -n "Select session number, 'n' for new, 'k' to kill, 'q' to quit: "
        # Re-read input
        choice=""
        while true; do
            IFS= read -n 1 -s char
            if [[ "$char" == $'\e' ]]; then
                echo ""
                exit 0
            fi
            if [[ "$char" == $'\n' || "$char" == "" ]]; then
                echo ""
                break
            fi
            if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                if [[ -n "$choice" ]]; then
                    choice="${choice%?}"
                    echo -ne '\b \b'
                fi
                continue
            fi
            echo -n "$char"
            choice="${choice}${char}"
        done
    fi

    if [[ "$choice" == "q" || "$choice" == "exit" ]]; then
        exit 0
    elif [[ "$choice" == "n" ]]; then
        echo -n "Name: "
        name=""
        while true; do
            IFS= read -n 1 -s char
            if [[ "$char" == $'\e' ]]; then
                echo ""
                exit 0
            fi
            if [[ "$char" == $'\n' || "$char" == "" ]]; then
                echo ""
                break
            fi
            if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                if [[ -n "$name" ]]; then
                    name="${name%?}"
                    echo -ne '\b \b'
                fi
                continue
            fi
            echo -n "$char"
            name="${name}${char}"
        done
        [[ -n "$name" ]] && create_session "$name" || echo "Cancelled."
        exit 0
    elif [[ "$choice" == "k" ]]; then
        echo -n "Kill session number: "
        num=""
        while true; do
            IFS= read -n 1 -s char
            if [[ "$char" == $'\e' ]]; then
                echo ""
                exit 0
            fi
            if [[ "$char" == $'\n' || "$char" == "" ]]; then
                echo ""
                break
            fi
            if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                if [[ -n "$num" ]]; then
                    num="${num%?}"
                    echo -ne '\b \b'
                fi
                continue
            fi
            echo -n "$char"
            num="${num}${char}"
        done
        idx=$((num-1))
        if [[ $idx -ge 0 && $idx -lt ${#sessions[@]} ]]; then
            echo -n "Kill session $num [${sessions[$idx]}]? (y/N): "
            confirm=""
            while true; do
                IFS= read -n 1 -s char
                if [[ "$char" == $'\e' ]]; then
                    echo ""
                    exit 0
                fi
                if [[ "$char" == $'\n' || "$char" == "" ]]; then
                    echo ""
                    break
                fi
                if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
                    if [[ -n "$confirm" ]]; then
                        confirm="${confirm%?}"
                        echo -ne '\b \b'
                    fi
                    continue
                fi
                echo -n "$char"
                confirm="${confirm}${char}"
            done
            if [[ "$confirm" == "y" ]]; then
                kill_session "${sessions[$idx]}" && echo "Killed."
                echo ""
            fi
        fi
        # Continue loop to show updated session list
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#sessions[@]} ]]; then
        attach_session "${sessions[$((choice-1))]}"
        exit 0
    fi
done
