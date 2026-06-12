#!/bin/bash
# =============================================================================
# hyprlock-music.sh — Multi-source music widget for hyprlock
# Works with any MPRIS player: Spotify (spotify-launcher), Zen Browser,
# Firefox, Chromium, VLC, mpv, etc.
#
# Player is detected dynamically each run:
#   1. First Playing player wins
#   2. Falls back to first Paused player
#   3. Widget shows nothing if no player is active
# =============================================================================

# D-Bus session — critical, hyprlock's exec environment often lacks this
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID}/bus"
export XDG_RUNTIME_DIR="/run/user/${UID}"

ART_PATH="${HOME}/.config/hypr/scripts/music.webp"
URL_CACHE="${HOME}/.config/hypr/scripts/.last_art_url"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Scan all MPRIS players and return the best one to display.
# Priority: currently Playing > currently Paused > nothing
get_player() {
    local p status

    # Pass 1 — prefer a Playing player
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        status=$(playerctl -p "$p" status 2>/dev/null)
        [[ "$status" == "Playing" ]] && echo "$p" && return
    done < <(playerctl -l 2>/dev/null)

    # Pass 2 — settle for a Paused player
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        status=$(playerctl -p "$p" status 2>/dev/null)
        [[ "$status" == "Paused" ]] && echo "$p" && return
    done < <(playerctl -l 2>/dev/null)
}

# Map a playerctl instance ID (e.g. "zen.instance12345") to a display label.
# The glob patterns handle suffixed instance IDs automatically.
friendly_name() {
    case "$1" in
        spotify*)                       echo "Spotify" ;;
        zen* | zen-browser*)            echo "Zen Browser" ;;
        firefox*)                       echo "Firefox" ;;
        chromium* | chrome*)            echo "Chromium" ;;
        brave*)                         echo "Brave" ;;
        vlc*)                           echo "VLC" ;;
        mpv*)                           echo "mpv" ;;
        rhythmbox*)                     echo "Rhythmbox" ;;
        *)
            # Strip numeric instance suffix, capitalise first letter
            echo "$1" | sed 's/\.[0-9]*$//' \
                      | awk '{print toupper(substr($0,1,1)) substr($0,2)}'
            ;;
    esac
}

# Download album art from an http/https or file:// URL to $ART_PATH.
# Only re-downloads when the URL has changed (track/source switch).
fetch_art() {
    local URL="$1"
    local CACHED
    CACHED=$(cat "$URL_CACHE" 2>/dev/null)

    [[ "$URL" == "$CACHED" ]] && return   # same track, nothing to do

    if [[ "$URL" == file://* ]]; then
        cp "${URL#file://}" "$ART_PATH" 2>/dev/null
    elif [[ "$URL" == http://* || "$URL" == https://* ]]; then
        curl -sf --max-time 5 "$URL" -o "$ART_PATH" 2>/dev/null
    fi

    echo "$URL" > "$URL_CACHE"
}

# ---------------------------------------------------------------------------
# Resolve the active player once — used by every branch below
# ---------------------------------------------------------------------------
PLAYER=$(get_player)

# ---------------------------------------------------------------------------
# Argument dispatch
# ---------------------------------------------------------------------------
case "$1" in

# --- Album art -------------------------------------------------------------
# Outputs a local file path; hyprlock image widget uses this via reload_cmd.
# Handles Spotify CDN URLs (https://i.scdn.co/…) and YouTube thumbnails
# (https://i.ytimg.com/…) identically — both are just HTTPS downloads.
--art)
    if [[ -n "$PLAYER" ]]; then
        URL=$(playerctl -p "$PLAYER" metadata mpris:artUrl 2>/dev/null)
        [[ -n "$URL" ]] && fetch_art "$URL"
    fi
    [[ -f "$ART_PATH" ]] && echo "$ART_PATH" || echo ""
    ;;

# --- Song / video title ----------------------------------------------------
--title)
    [[ -n "$PLAYER" ]] \
        && playerctl -p "$PLAYER" metadata --format '{{title}}' 2>/dev/null \
        || echo ""
    ;;

# --- Artist / channel name -------------------------------------------------
# For YouTube this is the channel name; for Spotify it's the artist.
--artist)
    [[ -n "$PLAYER" ]] \
        && playerctl -p "$PLAYER" metadata --format '{{artist}}' 2>/dev/null \
        || echo ""
    ;;

# --- Player source label ---------------------------------------------------
# Shows "Spotify", "Zen Browser", etc. in the widget header
--player)
    [[ -n "$PLAYER" ]] && friendly_name "$PLAYER" || echo ""
    ;;

# --- Play / Pause icon -----------------------------------------------------
--status)
    if [[ -n "$PLAYER" ]]; then
        STATUS=$(playerctl -p "$PLAYER" status 2>/dev/null)
        [[ "$STATUS" == "Playing" ]] && echo "󰏤" || echo "󰐊"
    else
        echo "󰐊"
    fi
    ;;

# --- Current position (M:SS) -----------------------------------------------
--position)
    if [[ -n "$PLAYER" ]]; then
        POS=$(playerctl -p "$PLAYER" position 2>/dev/null)
        if [[ -n "$POS" ]]; then
            SEC=${POS%.*}
            printf "%d:%02d\n" $((SEC / 60)) $((SEC % 60))
        else
            echo "0:00"
        fi
    else
        echo "0:00"
    fi
    ;;

# --- Total track / video length (M:SS) ------------------------------------
--length)
    if [[ -n "$PLAYER" ]]; then
        US=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null)
        if [[ -n "$US" && "$US" -gt 0 ]]; then
            SEC=$((US / 1000000))
            printf "%d:%02d\n" $((SEC / 60)) $((SEC % 60))
        else
            echo "0:00"
        fi
    else
        echo "0:00"
    fi
    ;;

# --- Progress percentage (0–100) ------------------------------------------
--progress)
    if [[ -n "$PLAYER" ]]; then
        POS=$(playerctl -p "$PLAYER" position 2>/dev/null)
        US=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null)
        if [[ -n "$POS" && -n "$US" && "$US" -gt 0 ]]; then
            POS_US=$(awk "BEGIN { printf \"%d\", $POS * 1000000 }")
            echo $((POS_US * 100 / US))
        else
            echo "0"
        fi
    else
        echo "0"
    fi
    ;;

# --- Pango coloured progress bar ------------------------------------------
--progress-bar)
    TOTAL=17
    FILLED_N=0

    if [[ -n "$PLAYER" ]]; then
        POS=$(playerctl -p "$PLAYER" position 2>/dev/null)
        US=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null)
        if [[ -n "$POS" && -n "$US" && "$US" -gt 0 ]]; then
            POS_US=$(awk "BEGIN { printf \"%d\", $POS * 1000000 }")
            FILLED_N=$((POS_US * TOTAL / US))
            (( FILLED_N > TOTAL )) && FILLED_N=$TOTAL
            (( FILLED_N < 0    )) && FILLED_N=0
        fi
    fi

    EMPTY_N=$(( TOTAL - FILLED_N ))
    FILLED="" ; for (( i=0; i<FILLED_N; i++ )); do FILLED+="━"; done
    EMPTY=""  ; for (( i=0; i<EMPTY_N;  i++ )); do EMPTY+="━";  done

    echo "<span foreground='#d8dee9'>${FILLED}</span><span foreground='#4c566a'>${EMPTY}</span>"
    ;;

# --- Playback controls (called by onclick= in hyprlock.conf) --------------
# Routing through this script ensures D-Bus env is set before playerctl runs.
# Controls always target whichever player is currently active.
--prev)
    [[ -n "$PLAYER" ]] && playerctl -p "$PLAYER" previous 2>/dev/null
    ;;

--toggle)
    [[ -n "$PLAYER" ]] && playerctl -p "$PLAYER" play-pause 2>/dev/null
    ;;

--next)
    [[ -n "$PLAYER" ]] && playerctl -p "$PLAYER" next 2>/dev/null
    ;;

# --- Usage ----------------------------------------------------------------
*)
    echo "Usage: $(basename "$0") {--art|--title|--artist|--player|--status|--position|--length|--progress|--progress-bar|--prev|--toggle|--next}"
    exit 1
    ;;
esac
