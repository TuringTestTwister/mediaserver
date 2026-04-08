{ config, lib, pkgs, ... }:
let
  cfg = config.mediaserver;

  # Chromium with Widevine DRM support (required for Spotify web player)
  chromiumWV = pkgs.chromium.override { enableWideVine = true; };

  # Calculate compositor scale factor from screen dimensions and resolution.
  # Target: ~110 effective DPI for comfortable touch on small screens.
  # Nix has no sqrt, so approximate diagonal: d ≈ max(w,h) * 1.1
  w = cfg.touchUIScreenWidth * 1.0;
  h = cfg.touchUIScreenHeight * 1.0;
  maxDim = if w > h then w else h;
  approxDiagonalPixels = maxDim * 1.1;
  actualDpi = approxDiagonalPixels / cfg.touchUIScreenSize;
  targetDpi = 85.0;
  rawScale = actualDpi / targetDpi;
  scaleFactor = let
    rounded = builtins.floor (rawScale * 4.0 + 0.5) / 4.0;
  in
    if rounded < 0.5 then 0.5
    else if rounded > 3.0 then 3.0
    else rounded;
  scaleStr = toString scaleFactor;

  chromiumFlags = lib.concatStringsSep " " [
    "--ozone-platform=wayland"
    "--no-first-run"
    "--enable-gpu-rasterization"
    "--enable-zero-copy"
    "--enable-features=TouchpadOverscrollHistoryNavigation"
    "--disable-pinch"
    "--overscroll-history-navigation=disabled"
    "--remote-debugging-port=9222"
    "--disable-features=StatusBubble"
  ];

  launcherUrl = "file://${launcherPage}/launcher.html";
  chromiumUrl = "--app=${launcherUrl}";

  # SoundCloud login flow:
  # 1. If already logged in (cookie exists in Chromium), navigate Chromium to soundcloud.com
  # 2. If not logged in, open Firefox for one-time login, then transfer cookies to Chromium
  soundcloudCookieScript = pkgs.writeShellScript "soundcloud-open" ''
    CURL="${pkgs.curl}/bin/curl"
    GREP="${pkgs.gnugrep}/bin/grep"
    SED="${pkgs.gnused}/bin/sed"
    WEBSOCAT="${pkgs.websocat}/bin/websocat"
    SQLITE="${pkgs.sqlite}/bin/sqlite3"

    CDP="http://localhost:9222"
    SC_URL="https://soundcloud.com"
    FF_COOKIES="/home/${cfg.username}/.mozilla/firefox/kiosk/cookies.sqlite"

    # Get Chromium CDP websocket
    WS_URL=$($CURL -s $CDP/json/list | tr ',' '\n' | $GREP 'webSocketDebuggerUrl' | head -1 | $SED 's/.*"webSocketDebuggerUrl":\s*"//;s/".*//')

    # Check if Chromium already has a SoundCloud session cookie
    RESULT=$(echo '{"id":1,"method":"Network.getCookies","params":{"urls":["https://soundcloud.com"]}}' | $WEBSOCAT -n1 "$WS_URL" 2>/dev/null)
    HAS_SESSION=$(echo "$RESULT" | $GREP -o '"name":"oauth_token"' || true)

    # Function to launch SoundCloud in its own --app Chromium window
    launch_sc_chromium() {
      # Kill existing SoundCloud Chromium if any
      ${pkgs.procps}/bin/pkill -f 'app=https://soundcloud.com' 2>/dev/null || true
      sleep 0.5
      PULSE_SINK=BrowserFifo ${chromiumWV}/bin/chromium ${chromiumFlags} "--app=$SC_URL" &
    }

    if [ -n "$HAS_SESSION" ]; then
      # Already logged in — launch SoundCloud in app mode
      launch_sc_chromium
    elif [ -f "$FF_COOKIES" ]; then
      # Firefox cookies exist — transfer them, then launch
      COOKIES=$($SQLITE "$FF_COOKIES" "SELECT name, value, host, path, isSecure, expiry FROM moz_cookies WHERE host LIKE '%soundcloud.com%' AND name != 'datadome';" 2>/dev/null)
      if [ -n "$COOKIES" ]; then
        echo "$COOKIES" | while IFS='|' read -r name value host path secure expiry; do
          secure_bool="false"
          [ "$secure" = "1" ] && secure_bool="true"
          echo '{"id":99,"method":"Network.setCookie","params":{"name":"'"$name"'","value":"'"$value"'","domain":"'"$host"'","path":"'"$path"'","secure":'"$secure_bool"',"expires":'"''${expiry:-0}"'}}' | $WEBSOCAT -n1 "$WS_URL" > /dev/null 2>&1
        done
        launch_sc_chromium
      else
        # Firefox cookies empty — open Firefox for login
        MOZ_ENABLE_WAYLAND=1 ${pkgs.firefox}/bin/firefox --profile /home/${cfg.username}/.mozilla/firefox/kiosk "$SC_URL" &
      fi
    else
      # No Firefox cookies yet — open Firefox for one-time login
      mkdir -p /home/${cfg.username}/.mozilla/firefox/kiosk
      MOZ_ENABLE_WAYLAND=1 ${pkgs.firefox}/bin/firefox --profile /home/${cfg.username}/.mozilla/firefox/kiosk "$SC_URL" &
    fi
  '';

  # Script to navigate existing Chromium tab to launcher and bring it to front
  navigateHome = pkgs.writeShellScript "navigate-home" ''
    # Kill any other apps so Chromium launcher is visible
    ${pkgs.procps}/bin/pkill -x soundcloud-desktop 2>/dev/null || true
    ${pkgs.procps}/bin/pkill -x firefox 2>/dev/null || true
    ${pkgs.procps}/bin/pkill -x .firefox-Wrappe 2>/dev/null || true
    ${pkgs.procps}/bin/pkill -f 'app=https://soundcloud.com' 2>/dev/null || true

    # Navigate Chromium to the launcher page via CDP
    WS_URL=$(${pkgs.curl}/bin/curl -s http://localhost:9222/json/list | tr ',' '\n' | ${pkgs.gnugrep}/bin/grep 'webSocketDebuggerUrl' | head -1 | ${pkgs.gnused}/bin/sed 's/.*"webSocketDebuggerUrl":\s*"//;s/".*//')
    if [ -n "$WS_URL" ]; then
      echo '{"id":1,"method":"Page.navigate","params":{"url":"${launcherUrl}"}}' | ${pkgs.websocat}/bin/websocat -n1 "$WS_URL"
    fi
  '';

  # labwc: no decorations, auto-maximize
  labwcRc = pkgs.writeText "labwc-rc.xml" ''
    <?xml version="1.0"?>
    <labwc_config>
      <core>
        <decoration>server</decoration>
        <gap>0</gap>
      </core>
      <theme>
        <titlebar>
          <height>0</height>
        </titlebar>
        <border>
          <width>0</width>
        </border>
        <osd>
          <border>
            <width>0</width>
          </border>
        </osd>
      </theme>
      <placement>
        <policy>automatic</policy>
      </placement>
      <windowRules>
        <windowRule identifier="chrom*">
          <serverDecoration>no</serverDecoration>
          <action name="Maximize"/>
        </windowRule>
        <windowRule identifier="soundcloud*">
          <serverDecoration>no</serverDecoration>
          <action name="Maximize"/>
        </windowRule>
      </windowRules>
      <focus>
        <followMouse>no</followMouse>
        <raiseOnFocus>no</raiseOnFocus>
      </focus>
      <cursor>
        <theme>default</theme>
        <size>1</size>
        <hide>yes</hide>
      </cursor>
      <libinput>
        <device category="touch">
          <tap>yes</tap>
          <naturalScroll>yes</naturalScroll>
        </device>
      </libinput>
    </labwc_config>
  '';

  labwcAutostart = pkgs.writeShellScript "labwc-autostart" ''
    # Set Firefox as default browser (for SoundCloud Desktop OAuth login etc.)
    export BROWSER=${pkgs.firefox}/bin/firefox

    # Set compositor output scale
    sleep 1
    OUTPUT=$(${pkgs.wlr-randr}/bin/wlr-randr | ${pkgs.gawk}/bin/awk '/^[A-Z]/{print $1; exit}')
    if [ -n "$OUTPUT" ]; then
      ${pkgs.wlr-randr}/bin/wlr-randr --output "$OUTPUT" --scale ${scaleStr} || true
    fi

    # Clear Chromium session state to prevent "Restore pages?" dialogs, but preserve login cookies
    rm -f /home/${cfg.username}/.config/chromium/Default/Preferences
    rm -f /home/${cfg.username}/.config/chromium/Default/Current\ Session
    rm -f /home/${cfg.username}/.config/chromium/Default/Current\ Tabs
    rm -f /home/${cfg.username}/.config/chromium/Default/Last\ Session
    rm -f /home/${cfg.username}/.config/chromium/Default/Last\ Tabs
    rm -rf /home/${cfg.username}/.config/chromium/Singleton*

    # Set Firefox as default browser for xdg-open (used by SoundCloud Desktop for OAuth)
    mkdir -p /home/${cfg.username}/.config
    cat > /home/${cfg.username}/.config/mimeapps.list << 'MIME'
    [Default Applications]
    x-scheme-handler/http=firefox.desktop
    x-scheme-handler/https=firefox.desktop
    text/html=firefox.desktop
    MIME

    # On-screen keyboard (hidden by default, toggled via SIGRTMIN)
    ${pkgs.util-linux}/bin/flock -n /tmp/wvkbd.lock \
      ${pkgs.wvkbd}/bin/wvkbd-mobintl -L 300 --hidden &

    # HTTP listener to open SoundCloud (handles login flow)
    ${pkgs.util-linux}/bin/flock -n /tmp/soundcloud-launch.lock \
      ${pkgs.writeShellScript "soundcloud-launch-server" ''
        while true; do
          echo -e "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK" | \
            ${pkgs.socat}/bin/socat - TCP-LISTEN:8788,reuseaddr
          ${soundcloudCookieScript}
        done
      ''} &

    # Always-visible toolbar at bottom with Home + Keyboard buttons
    mkdir -p /tmp/waybar-kiosk
    cat > /tmp/waybar-kiosk/config.jsonc << 'WBCONF'
    {
      "layer": "top",
      "position": "bottom",
      "height": 48,
      "exclusive": true,
      "modules-center": ["custom/home", "custom/keyboard"],
      "custom/home": {
        "format": "\u2302 Home",
        "on-click": "${navigateHome}",
        "tooltip": false
      },
      "custom/keyboard": {
        "format": "\u2328 Keyboard",
        "on-click": "${pkgs.procps}/bin/pkill -RTMIN wvkbd-mobintl",
        "tooltip": false
      }
    }
    WBCONF
    cat > /tmp/waybar-kiosk/style.css << 'WBCSS'
    * { font-family: sans-serif; font-size: 16px; }
    window#waybar { background: #1a1a1a; }
    #custom-home, #custom-keyboard {
      background: #333;
      color: #fff;
      border: 1px solid #555;
      border-radius: 8px;
      padding: 4px 20px;
      margin: 4px 8px;
    }
    #custom-home:active, #custom-keyboard:active { background: #555; }
    WBCSS
    ${pkgs.util-linux}/bin/flock -n /tmp/waybar.lock \
      ${pkgs.waybar}/bin/waybar -c /tmp/waybar-kiosk/config.jsonc -s /tmp/waybar-kiosk/style.css &

    # Screen blanking after idle timeout
    ${lib.optionalString (cfg.touchUIIdleTimeout > 0) ''
    ${pkgs.swayidle}/bin/swayidle -w \
      timeout ${idleTimeoutSeconds} '${pkgs.wlopm}/bin/wlopm --off \*' \
      resume '${pkgs.wlopm}/bin/wlopm --on \*' &
    ''}

    # Launch Chromium with audio routed to BrowserFifo (not the default hardware sink)
    PULSE_SINK=BrowserFifo ${chromiumWV}/bin/chromium ${chromiumFlags} ${chromiumUrl} &
  '';

  labwcConfigDir = pkgs.linkFarm "labwc-config" [
    { name = "rc.xml"; path = labwcRc; }
    { name = "autostart"; path = labwcAutostart; }
  ];

  launcherPage = pkgs.writeTextDir "launcher.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>Media Server</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          background: #121212;
          color: #fff;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 40px;
          user-select: none;
          -webkit-user-select: none;
          touch-action: manipulation;
        }
        h1 { font-size: 2.5rem; font-weight: 300; opacity: 0.8; }
        .buttons {
          display: flex;
          flex-direction: column;
          gap: 30px;
          width: 80%;
          max-width: 500px;
        }
        .btn {
          display: flex;
          align-items: center;
          justify-content: center;
          color: #fff;
          font-size: 2rem;
          font-weight: 600;
          padding: 40px 20px;
          border: none;
          border-radius: 20px;
          transition: transform 0.1s, opacity 0.1s;
          min-height: 120px;
          cursor: pointer;
          width: 100%;
        }
        .btn:active { transform: scale(0.97); opacity: 0.8; }
        .spotify { background: #1DB954; }
        .soundcloud { background: #FF5500; }
        .snapcast {
          background: #333;
          font-size: 1.4rem;
          min-height: 80px;
          padding: 25px 20px;
        }
      </style>
    </head>
    <body>
      <h1>${cfg.hostname}</h1>
      <div class="buttons">
        <button class="btn spotify" onclick="window.location.href='https://open.spotify.com'">Spotify</button>
        <button class="btn soundcloud" onclick="fetch('http://localhost:8788/launch').catch(function(){})">SoundCloud</button>
        <button class="btn snapcast" onclick="window.location.href='http://localhost:1780'">Snapcast</button>
      </div>
    </body>
    </html>
  '';

  idleTimeoutSeconds = toString cfg.touchUIIdleTimeout;
in
lib.mkIf cfg.touchUI {
  hardware.graphics.enable = true;

  services.pipewire.enable = false;

  environment.systemPackages = with pkgs; [
    cage
    chromiumWV
    firefox
    labwc
    socat
    sqlite
    squeekboard
    swayidle
    waybar
    websocat
    wl-clipboard
    wlopm
    wlr-randr
    wvkbd
  ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.labwc}/bin/labwc -C ${labwcConfigDir} -s ${labwcAutostart}";
        user = cfg.username;
      };
    };
  };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # PulseAudio pipe sink for browser audio -> Snapcast
  # Loaded via systemd oneshot that stays active and watches for the module
  systemd.services.snapcast-browser-sink = {
    wantedBy = [ "snapserver.service" ];
    after = [ "snapserver.service" "pulseaudio.service" ];
    bindsTo = [ "snapserver.service" ];
    path = with pkgs; [ pulseaudio ];
    script = ''
      # Wait for snapserver pipe to exist
      while [ ! -p /run/snapserver/browser ]; do sleep 1; done

      # Load the pipe sink module
      pactl load-module module-pipe-sink file=/run/snapserver/browser sink_name=BrowserFifo format=s16le rate=44100 channels=2

      # Ensure hardware remains the default sink (not BrowserFifo)
      DEFAULT_HW_SINK=$(pactl list sinks short | grep -v Fifo | head -1 | cut -f2)
      if [ -n "$DEFAULT_HW_SINK" ]; then
        pactl set-default-sink "$DEFAULT_HW_SINK"
      fi

      # Keep running: reload module if dropped, and route Chromium audio to BrowserFifo
      BROWSER_SINK_ID=$(pactl list sinks short | grep BrowserFifo | cut -f1)
      while true; do
        sleep 5
        if ! pactl list sinks short | grep -q BrowserFifo; then
          pactl load-module module-pipe-sink file=/run/snapserver/browser sink_name=BrowserFifo format=s16le rate=44100 channels=2 2>/dev/null || true
          BROWSER_SINK_ID=$(pactl list sinks short | grep BrowserFifo | cut -f1)
        fi
        # Move any Chromium sink-inputs to BrowserFifo
        for si in $(pactl list sink-inputs short | grep -v "^$" | while read idx sink rest; do
          app=$(pactl list sink-inputs | grep -A30 "Sink Input #$idx" | grep 'application.name' | head -1)
          if echo "$app" | grep -qi 'chrom'; then
            [ "$sink" != "$BROWSER_SINK_ID" ] && echo "$idx"
          fi
        done); do
          pactl move-sink-input "$si" BrowserFifo 2>/dev/null || true
        done
      done
    '';
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      User = cfg.username;
      Restart = "always";
      RestartSec = 5;
    };
  };

  mediaserver._snapcastExtraSources = [
    "pipe:///run/snapserver/browser?name=browser"
  ];
  mediaserver._snapcastExtraMetaNames = [ "browser" ];
}
