# ==============================
# KXL SYSTEM - WELCOME SYSTEM v2.0
# ==============================
# Rozbudowany panel powitalny z diagnostyką systemu
# Części: header, system info, resources, network, AI, commands, helpers
# ==============================

WELCOME_SCRIPT="$HOME/.zsh/welcome_engine.sh"
WELCOME_WIDTH=${COLUMNS:-60}
[[ $WELCOME_WIDTH -gt 100 ]] && WELCOME_WIDTH=100
[[ $WELCOME_WIDTH -lt 60 ]]  && WELCOME_WIDTH=60

# ==============================
# BOX DRAWING HELPERS
# ==============================

# Rysuje poziomą linię ramki o zadanej szerokości
# Użycie: _w_line "─" "cyan"
_w_line() {
  local char="$1" color="$2" width=${3:-$WELCOME_WIDTH}
  local line=""
  local i
  for ((i=0; i<width-2; i++)); do line+="$char"; done
  print -P "%F{$color}┌${line}┐%f"
}

# Rysuje dolną krawędź ramki
_w_bottom() {
  local char="─" color="${1:-cyan}" width=${2:-$WELCOME_WIDTH}
  local line=""
  local i
  for ((i=0; i<width-2; i++)); do line+="$char"; done
  print -P "%F{$color}└${line}┘%f"
}

# Rysuje nagłówek sekcji: "Tytuł w ramce"
_w_section() {
  local title="$1" color="${2:-cyan}"
  local width=$WELCOME_WIDTH
  local inner=$((width - 2))
  local title_len=${#title}
  # " TYTUL " = title_len + 2 spacje padding
  local left_pad=2
  local right_pad=$((inner - title_len - left_pad - 2))
  [[ $right_pad -lt 0 ]] && right_pad=0
  local lspaces=""
  local rspaces=""
  local i
  for ((i=0; i<left_pad; i++)); do lspaces+="─"; done
  for ((i=0; i<right_pad; i++)); do rspaces+="─"; done
  print -P "%F{$color}┌${lspaces}%F{yellow} ${title} %F{$color}${rspaces}┐%f"
}

# ==============================
# PROGRESS BAR
# ==============================
# Generuje pasek ASCII: "████████░░░░ 73%"
# Użycie: _bar 73 20
#   pct  - procent (0-100)
#   size - liczba znaków paska
_w_bar() {
  local pct=$1 size=${2:-20}
  local filled=$(( (pct * size) / 100 ))
  local empty=$(( size - filled ))
  local color="green"
  [[ $pct -ge 60 && $pct -lt 85 ]] && color="yellow"
  [[ $pct -ge 85 ]] && color="red"
  local i
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  print -P "%F{$color}${bar}%f"
}

# ==============================
# COLOR HELPERS
# ==============================
# Dynamiczny kolor na podstawie procentu
_w_pct_color() {
  local pct=$1
  if [[ $pct -ge 85 ]]; then echo "red"
  elif [[ $pct -ge 60 ]]; then echo "yellow"
  else echo "green"
  fi
}

# ==============================
# DATA COLLECTORS
# ==============================

# Pobiera nazwę dystrybucji z /etc/os-release
_w_os_name() {
  if [[ -r /etc/os-release ]]; then
    local name
    name=$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | head -1 | sed 's/PRETTY_NAME=//;s/"//g')
    echo "${name:-Linux}"
  else
    echo "Linux"
  fi
}

# Kernel wersja (skrócona)
_w_kernel() {
  uname -r | cut -d- -f1
}

# Informacja o CPU: model + liczba rdzeni
_w_cpu_info() {
  local cores=$(nproc 2>/dev/null || echo "?")
  local model
  model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | sed 's/.*: //;s/  */ /g')
  if [[ -z "$model" ]]; then
    model=$(grep -m1 'Hardware' /proc/cpuinfo 2>/dev/null | sed 's/.*: //')
  fi
  if [[ -z "$model" ]]; then
    model=$(uname -m)
  fi
  echo "${cores}c ${model}"
}

# Uptime maszyny (ładne, np. "3 dni, 4h")
_w_uptime() {
  uptime -p 2>/dev/null | sed 's/^up //'
}

# Uptime sesji shell (sekundy od uruchomienia SHLVL)
_w_session_uptime() {
  local now=$(date +%s)
  if [[ -n "$_WELCOME_START_TIME" ]]; then
    local diff=$((now - _WELCOME_START_TIME))
    if [[ $diff -lt 60 ]]; then echo "${diff}s"
    elif [[ $diff -lt 3600 ]]; then echo "$((diff/60))m $((diff%60))s"
    else echo "$((diff/3600))h $(((diff%3600)/60))m"
    fi
  else
    echo "0s"
  fi
}

# Load average 1/5/15 min
_w_load() {
  awk '{print $1, $2, $3}' /proc/loadavg
}

# Procent użycia CPU (sample 0.5s dla dokładności)
_w_cpu_pct() {
  if command -v top >/dev/null 2>&1; then
    top -bn2 -d 0.5 2>/dev/null | grep -E '^(%Cpu|Cpu)' | tail -1 | awk '{print int(100-$8)}' 2>/dev/null
  else
    echo "?"
  fi
}

# RAM: użyta/całkowita + procent
_w_ram_info() {
  free -h 2>/dev/null | awk '/^Mem:/ {
    used=$3; total=$2; pct=int(($3/$2)*100);
    print used"|"total"|"pct
  }'
}

# Swap info
_w_swap_info() {
  free -h 2>/dev/null | awk '/^Swap:/ {
    if ($2 != "0B" && $2 != "0") {
      used=$3; total=$2; pct=0;
      gsub(/[A-Za-z]/, "", total); gsub(/[A-Za-z]/, "", used);
      if (total+0 > 0) pct=int((used+0)/(total+0)*100);
      print $3"|"$2"|"pct
    } else {
      print "off|off|0"
    }
  }'
}

# Lista dysków fizycznych (bez tmpfs, devtmpfs, overlay, squashfs)
# Zwraca: "mount|size|used|avail|pct|filesystem"
_w_disk_info() {
  df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
  awk 'NR>1 && $1 !~ /^(tmpfs|devtmpfs|overlay| squashfs|udev)/ {
    # pcent ma "%" - obcinam
    p=$5; gsub(/%/, "", p);
    # filtr: pomijamy /run, /dev/shm, /sys, /proc (tmpfs już)
    if ($6 == "/" || $6 ~ /^\/(boot|home|var|opt|usr|data|Development|root)$/) {
      print $1"|"$2"|"$3"|"$4"|"p"|"$6
    }
  }' | sort -t'|' -k5 -nr | head -5
}

# Top 3 katalogi w HOME wg rozmiaru
_w_home_dirs() {
  if [[ -d "$HOME" ]]; then
    # Szybki du z depth=1, max-depth, bez /proc /sys
    du -sh --max-depth=1 "$HOME" 2>/dev/null | \
      sort -hr | head -4 | tail -n +2 | \
      awk '{print $1"|"$2}'
  fi
}

# IP zewnętrzne (z timeout, nie blokuje jeśli brak netu)
_w_ext_ip() {
  timeout 3 curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "n/a"
}

# Lokalne IP (główne interfejsy)
_w_local_ips() {
  ip -4 -o addr show 2>/dev/null | \
    awk '$2 != "lo" {print $2": "$4}' | \
    head -3 | tr '\n' ',' | sed 's/,$//'
}

# Aktywne interfejsy (krótki status)
_w_net_ifaces() {
  if command -v ip >/dev/null 2>&1; then
    ip -br addr show 2>/dev/null | awk '$1 != "lo" {print $1": "$3}' | head -3
  else
    echo "n/a"
  fi
}

# Status i modele Ollama (cache'owany, max 2s timeout)
_w_ollama_status() {
  local code
  code=$(timeout 2 curl -s -o /dev/null -w "%{http_code}" "$OLLAMA_HOST/api/tags" 2>/dev/null)
  echo "$code"
}

_w_ollama_models() {
  timeout 3 curl -s --max-time 3 "$OLLAMA_HOST/api/tags" 2>/dev/null | \
    jq -r '.models[]? | "\(.name)|\(.size)"' 2>/dev/null
}

# Liczba zainstalowanych modeli
_w_ollama_count() {
  timeout 2 curl -s --max-time 2 "$OLLAMA_HOST/api/tags" 2>/dev/null | \
    jq -r '.models | length' 2>/dev/null
}

# Sprawdza czy GITHUB_TOKEN jest ustawiony (bez pokazywania wartości)
_w_gh_token_status() {
  if [[ -n "$GITHUB_TOKEN" ]]; then
    # Pokaż tylko prefix i długość
    local prefix="${GITHUB_TOKEN:0:4}"
    local len=${#GITHUB_TOKEN}
    echo "set (${prefix}... ${len} chars)"
  else
    echo "not set"
  fi
}

# Aktywna wersja node z NVM
_w_node_info() {
  if command -v node >/dev/null 2>&1; then
    echo "node $(node --version 2>/dev/null | tr -d 'v')"
  elif [[ -d "$NVM_DIR" ]]; then
    echo "nvm available, no default"
  else
    echo "n/a"
  fi
}

# Liczba załadowanych pluginów Zsh (heurystyka: liczba źródeł w .zshrc)
_w_plugin_count() {
  local count=0
  [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && ((count++))
  [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && ((count++))
  echo "$count"
}

# Liczba aliasów w commands.sh
_w_alias_count() {
  if [[ -r "$HOME/.zsh/commands.sh" ]]; then
    grep -cE '^alias ' "$HOME/.zsh/commands.sh" 2>/dev/null
  else
    echo 0
  fi
}

# ==============================
# SECTION RENDERERS
# ==============================

# Sekcja: System Info
_w_render_system() {
  _w_section "💻 SYSTEM" "cyan"
  print -P "%F{cyan}│%f %F{green}OS:%f        %F{white}$(_w_os_name)%f"
  print -P "%F{cyan}│%f %F{green}Kernel:%f    %F{white}$(_w_kernel)%f"
  print -P "%F{cyan}│%f %F{green}CPU:%f       %F{white}$(_w_cpu_info)%f"
  print -P "%F{cyan}│%f %F{green}Uptime:%f    %F{yellow}$(_w_uptime)%f"
  print -P "%F{cyan}│%f %F{green}Session:%f   %F{yellow}$(_w_session_uptime)%f"
  _w_bottom "cyan"
}

# Sekcja: Użytkownik i sesja
_w_render_user() {
  _w_section "👤 SESSION" "blue"
  print -P "%F{blue}│%f %F{green}User:%f      %F{yellow}%n%f@%F{yellow}%m%f"
  print -P "%F{blue}│%f %F{green}Dir:%f       %F{white}%~%f"
  print -P "%F{blue}│%f %F{green}Shell:%f     %F{white}$SHELL (zsh)%f"
  print -P "%F{blue}│%f %F{green}Time:%f      %F{yellow}%D{%H:%M:%S}%f %F{dim}%D{%Y-%m-%d}%f"
  _w_bottom "blue"
}

# Sekcja: Zasoby - CPU + RAM
_w_render_resources() {
  _w_section "📊 RESOURCES" "green"
  local load=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//' | cut -d, -f1)
  print -P "%F{green}│%f %F{cyan}Load:%f      %F{yellow}${load}%f %F{dim}(1m)%f"
  
  local cpu_pct=$(_w_cpu_pct)
  if [[ "$cpu_pct" != "?" ]]; then
    local cpu_color=$(_w_pct_color "$cpu_pct")
    local cpu_bar=$(_w_bar "$cpu_pct" 20)
    print -P "%F{green}│%f %F{cyan}CPU:%f       ${cpu_bar} %F{${cpu_color}}${cpu_pct}%% %f"
  fi
  
  local ram_info=$(_w_ram_info)
  if [[ -n "$ram_info" ]]; then
    local used=$(echo "$ram_info" | cut -d'|' -f1)
    local total=$(echo "$ram_info" | cut -d'|' -f2)
    local pct=$(echo "$ram_info" | cut -d'|' -f3)
    local ram_color=$(_w_pct_color "$pct")
    local ram_bar=$(_w_bar "$pct" 20)
    print -P "%F{green}│%f %F{cyan}RAM:%f       ${ram_bar} %F{${ram_color}}${pct}%% %f %F{dim}(${used}/${total})%f"
  fi
  
  local swap_info=$(_w_swap_info)
  if [[ -n "$swap_info" ]]; then
    local s_used=$(echo "$swap_info" | cut -d'|' -f1)
    local s_total=$(echo "$swap_info" | cut -d'|' -f2)
    if [[ "$s_total" != "off" ]]; then
      print -P "%F{green}│%f %F{cyan}Swap:%f      %F{yellow}${s_used}%f %F{dim}/ ${s_total}%f"
    else
      print -P "%F{green}│%f %F{cyan}Swap:%f      %F{dim}off%f"
    fi
  fi
  
  _w_bottom "green"
}

# Sekcja: Dyski - kolorowe paski
_w_render_disks() {
  local disk_data=$(_w_disk_info)
  if [[ -z "$disk_data" ]]; then
    return 0
  fi
  
  _w_section "💾 DISK USAGE" "yellow"
  while IFS='|' read -r fs size used avail pct mount; do
    [[ -z "$mount" ]] && continue
    local color=$(_w_pct_color "$pct")
    local bar=$(_w_bar "$pct" 18)
    # Skrócona ścieżka dla czytelności
    local display_mount="$mount"
    [[ "$mount" == "/" ]] && display_mount="(root)"
    # 20 znaków na mount
    printf "│ "
    print -P "%F{cyan}$(printf '%-15s' "${display_mount}")%f ${bar} %F{${color}}${pct}%% %f %F{dim}${used}/${size}%f"
  done <<< "$disk_data"
  _w_bottom "yellow"
  print -P "%F{dim}│  Tip: 'dfh' pełna lista, 'server' szybki overview%f"
}

# Sekcja: Top katalogi w HOME
_w_render_home_dirs() {
  local home_data=$(_w_home_dirs)
  if [[ -z "$home_data" ]]; then
    return 0
  fi
  
  print -P ""
  _w_section "🏠 HOME TOP DIRS" "magenta"
  local count=0
  while IFS='|' read -r size path; do
    [[ -z "$path" ]] && continue
    ((count++))
    [[ $count -gt 3 ]] && break
    # Skróć ścieżkę do basename
    local name=$(basename "$path")
    [[ -z "$name" ]] && name="$path"
    # Duże katalogi w żółty, normalne w biały
    local color="white"
    local size_num=$(echo "$size" | sed 's/[^0-9.]//g')
    local size_unit=$(echo "$size" | sed 's/[0-9.]//g' | tr -d ' ')
    # Jeśli >= 1G -> żółty, >= 5G -> czerwony
    if [[ "$size_unit" == "G" || "$size_unit" == "T" ]]; then
      color="yellow"
    fi
    if [[ "$size_unit" == "T" ]]; then
      color="red"
    fi
    printf "│  "
    print -P "%F{green}▸%f %F{cyan}$(printf '%-25s' "$name")%f %F{${color}}$(printf '%8s' "$size")%f"
  done <<< "$home_data"
  _w_bottom "magenta"
}

# Sekcja: Sieć
_w_render_network() {
  _w_section "🌐 NETWORK" "blue"
  local ext_ip=$(_w_ext_ip)
  if [[ "$ext_ip" != "n/a" ]]; then
    print -P "%F{blue}│%f %F{cyan}Ext IP:%f    %F{yellow}${ext_ip}%f"
  else
    print -P "%F{blue}│%f %F{cyan}Ext IP:%f    %F{dim}n/a (offline?)%f"
  fi
  local ifaces=$(_w_net_ifaces)
  if [[ -n "$ifaces" ]]; then
    print -P "%F{blue}│%f %F{cyan}Ifaces:%f    %F{white}${ifaces}%f"
  fi
  _w_bottom "blue"
}

# Sekcja: AI / Ollama
_w_render_ai() {
  _w_section "🤖 AI / OLLAMA" "magenta"
  local ollama_code=$(_w_ollama_status)
  if [[ "$ollama_code" == "200" ]]; then
    local models_data=$(_w_ollama_models)
    local count=$(echo "$models_data" | grep -c '|')
    print -P "%F{magenta}│%f %F{green}Status:%f    %F{green}● running%f %F{dim}($count models)%f"
    print -P "%F{magenta}│%f %F{cyan}Host:%f      %F{white}$OLLAMA_HOST%f"
    print -P "%F{magenta}│%f %F{cyan}Default:%f   %F{yellow}$OLLAMA_MODEL%f"
    print -P "%F{magenta}│%f %F{cyan}Context:%f   %F{white}$OLLAMA_NUM_CTX tokens%f"
    if [[ -n "$models_data" ]]; then
      print -P "%F{magenta}│%f %F{dim}Models:%f"
      echo "$models_data" | head -4 | while IFS='|' read -r name size; do
        local size_gb=$(echo "scale=2; $size / 1024 / 1024 / 1024" | bc 2>/dev/null)
        [[ -z "$size_gb" || "$size_gb" == "0" ]] && size_gb="?"
        print -P "%F{magenta}│%f   %F{green}▸%f %F{white}$(printf '%-25s' "$name")%f %F{yellow}$(printf '%6s' "${size_gb}GB")%f"
      done
      if [[ $count -gt 4 ]]; then
        print -P "%F{magenta}│%f   %F{dim}... +$((count-4)) more (use 'ai-models')%f"
      fi
    fi
  else
    print -P "%F{magenta}│%f %F{green}Status:%f    %F{red}● offline%f"
    print -P "%F{magenta}│%f %F{cyan}Host:%f      %F{dim}$OLLAMA_HOST%f"
    print -P "%F{magenta}│%f %F{dim}Start: 'ollama serve'%f"
  fi
  _w_bottom "magenta"
}

# Sekcja: Konfiguracja/Ścieżki
_w_render_config() {
  _w_section "⚙️ CONFIG" "cyan"
  print -P "%F{cyan}│%f %F{green}Node:%f      %F{white}$(_w_node_info)%f"
  print -P "%F{cyan}│%f %F{green}GH Token:%f  %F{yellow}$(_w_gh_token_status)%f"
  print -P "%F{cyan}│%f %F{green}Editor:%f    %F{white}${EDITOR:-nano}%f"
  print -P "%F{cyan}│%f %F{green}Plugins:%f   %F{white}$(_w_plugin_count) loaded (autosuggestions, syntax)%f"
  print -P "%F{cyan}│%f %F{green}Aliases:%f   %F{white}$(_w_alias_count) defined in commands.sh%f"
  print -P "%F{cyan}│%f %F{green}NVM_DIR:%f   %F{dim}${NVM_DIR:-not set}%f"
  _w_bottom "cyan"
}

# Sekcja: Skróty klawiszowe
_w_render_keys() {
  _w_section "⌨️  KEYBOARD SHORTCUTS" "yellow"
  print -P "%F{yellow}│%f %F{cyan}Ctrl-R%f      %F{dim}│%f %F{white}history search (incremental)%f"
  print -P "%F{yellow}│%f %F{cyan}Ctrl-P / N%f  %F{dim}│%f %F{white}history search (current input)%f"
  print -P "%F{yellow}│%f %F{cyan}Tab%f         %F{dim}│%f %F{white}completion menu%f"
  print -P "%F{yellow}│%f %F{cyan}Ctrl-A/E%f    %F{dim}│%f %F{white}beginning / end of line%f"
  print -P "%F{yellow}│%f %F{cyan}Ctrl-W%f      %F{dim}│%f %F{white}delete word%f"
  print -P "%F{yellow}│%f %F{cyan}Ctrl-L%f      %F{dim}│%f %F{white}clear screen%f"
  _w_bottom "yellow"
}

# Sekcja: Top komendy (pogrupowane)
_w_render_commands() {
  _w_section "🚀 QUICK COMMANDS" "green"
  print -P "%F{green}│%f %F{yellow}AI / Ollama:%f"
  print -P "%F{green}│%f   %F{cyan}ai%f         %F{dim}- zapytaj model (ai \"pytanie\")%f"
  print -P "%F{green}│%f   %F{cyan}aimsg%f      %F{dim}- tryb konwersacyjny%f"
  print -P "%F{green}│%f   %F{cyan}ai-models%f  %F{dim}- lista modeli%f"
  print -P "%F{green}│%f   %F{cyan}ai-bench%f   %F{dim}- benchmark wszystkich modeli%f"
  print -P "%F{green}│%f   %F{cyan}ai-test%f    %F{dim}- health check Ollama%f"
  print -P "%F{green}│%f"
  print -P "%F{green}│%f %F{yellow}System:%f"
  print -P "%F{green}│%f   %F{cyan}server%f     %F{dim}- status systemu%f"
  print -P "%F{green}│%f   %F{cyan}myip%f       %F{dim}- zewnętrzne + lokalne IP%f"
  print -P "%F{green}│%f   %F{cyan}weather%f    %F{dim}- pogoda (default: Warsaw)%f"
  print -P "%F{green}│%f   %F{cyan}dfh%f        %F{dim}- dyski z typami%f"
  print -P "%F{green}│%f   %F{cyan}ports%f      %F{dim}- otwarte porty%f"
  print -P "%F{green}│%f"
  print -P "%F{green}│%f %F{yellow}Files / Git:%f"
  print -P "%F{green}│%f   %F{cyan}fog <dir>%f  %F{dim}- szybki skok do katalogu%f"
  print -P "%F{green}│%f   %F{cyan}mkcd%f       %F{dim}- mkdir + cd%f"
  print -P "%F{green}│%f   %F{cyan}extract%f    %F{dim}- rozpakuj archiwum%f"
  print -P "%F{green}│%f   %F{cyan}gh-*%f       %F{dim}- GitHub manager (gh-help)%f"
  print -P "%F{green}│%f"
  print -P "%F{green}│%f %F{yellow}Info:%f"
  print -P "%F{green}│%f   %F{cyan}help%f       %F{dim}- wszystkie aliasy%f"
  print -P "%F{green}│%f   %F{cyan}h -s <x>%f   %F{dim}- szukaj w historii%f"
  print -P "%F{green}│%f   %F{cyan}h --stats%f  %F{dim}- statystyki%f"
  _w_bottom "green"
}

# Sekcja: Tip z dodatkowymi info
_w_render_tips() {
  print -P ""
  print -P "%F{magenta}💡 TIPS:%f"
  print -P "   %F{green}welcome%f       %F{dim}- wyświetl ten panel ponownie%f"
  print -P "   %F{green}welcome-fast%f   %F{dim}- tylko kluczowe info (szybciej)%f"
  print -P "   %F{green}.welcome.conf%f  %F{dim}- plik konfiguracyjny projektu (auto-detect)%f"
  print -P "   %F{green}welcome_engine%f %F{dim}- skrypt: $WELCOME_SCRIPT%f"
}

# ==============================
# VARIANT: FAST (kluczowe info tylko)
# ==============================
_welcome_fast() {
  print -P ""
  _w_section "⚡ QUICK OVERVIEW" "cyan"
  print -P "%F{cyan}│%f %F{green}User:%f  %F{yellow}%n%f@%F{yellow}%m%f %F{dim}│%f %F{green}Dir:%f %F{white}%~%f"
  print -P "%F{cyan}│%f %F{green}OS:%f    %F{white}$(_w_os_name)%f %F{dim}│%f %F{green}Kernel:%f %F{white}$(_w_kernel)%f"
  
  local cpu_pct=$(_w_cpu_pct)
  local ram_info=$(_w_ram_info)
  local ram_pct="?"
  [[ -n "$ram_info" ]] && ram_pct=$(echo "$ram_info" | cut -d'|' -f3)
  
  local cpu_color=$(_w_pct_color "$cpu_pct")
  local ram_color=$(_w_pct_color "$ram_pct")
  print -P "%F{cyan}│%f %F{green}CPU:%f    %F{${cpu_color}}${cpu_pct}%% %f %F{dim}│%f %F{green}RAM:%f %F{${ram_color}}${ram_pct}%% %f %F{dim}│%f %F{green}Load:%f %F{yellow}$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | tr -d ' ')%f"
  
  local disk_data=$(_w_disk_info)
  if [[ -n "$disk_data" ]]; then
    local root_line=$(echo "$disk_data" | grep -E '\|/\|' | head -1)
    if [[ -n "$root_line" ]]; then
      local r_pct=$(echo "$root_line" | cut -d'|' -f5)
      local r_color=$(_w_pct_color "$r_pct")
      local r_bar=$(_w_bar "$r_pct" 20)
      print -P "%F{cyan}│%f %F{green}Disk /:%f ${r_bar} %F{${r_color}}${r_pct}%% %f"
    fi
  fi
  
  local ai_status=$(_w_ollama_status)
  if [[ "$ai_status" == "200" ]]; then
    local count=$(_w_ollama_count)
    print -P "%F{cyan}│%f %F{green}Ollama:%f %F{green}●%f %F{white}${count} models%f %F{dim}│%f %F{cyan}Default:%f %F{yellow}$OLLAMA_MODEL%f"
  else
    print -P "%F{cyan}│%f %F{green}Ollama:%f %F{red}● offline%f"
  fi
  
  _w_bottom "cyan"
  print -P "%F{magenta}💡%f Pełny panel: %F{green}welcome%f %F{dim}|%f Skróty: %F{green}help%f"
}

# ==============================
# GŁÓWNA FUNKCJA WELCOME
# ==============================
unalias welcome 2>/dev/null
function welcome {
  # Aktualizuj szerokość (terminal mógł się zmienić)
  WELCOME_WIDTH=${COLUMNS:-60}
  [[ $WELCOME_WIDTH -gt 100 ]] && WELCOME_WIDTH=100
  [[ $WELCOME_WIDTH -lt 60 ]]  && WELCOME_WIDTH=60
  
  print -P ""
  print -P "%F{cyan}╔══════════════════════════════════════════════════════════════════╗%f"
  print -P "%F{cyan}║%f  %F{yellow}🚀 KXL SYSTEM - Welcome Dashboard%f                                  %F{cyan}║%f"
  print -P "%F{cyan}╚══════════════════════════════════════════════════════════════════╝%f"
  
  # Sekcje w kolejności
  _w_render_user
  _w_render_system
  _w_render_resources
  _w_render_disks
  _w_render_home_dirs
  _w_render_network
  _w_render_ai
  _w_render_config
  _w_render_commands
  _w_render_keys
  _w_render_tips
  
  print -P ""
}

# Alias dla szybkiej wersji
alias welcome-fast='_welcome_fast'
alias wf='_welcome_fast'

# ==============================
# WELCOME ON CD
# ==============================
# Pojedynczy mechanizm: hook chpwd (czyściej niż override cd)
welcome_on_cd() {
    local dir="${1:-$PWD}"
    if [[ -f "$dir/.welcome.conf" ]]; then
        bash "$WELCOME_SCRIPT" "$dir"
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd welcome_on_cd

# ==============================
# GH WELCOME (CityX/MiastoX)
# ==============================
gh-welcome() {
    echo ""
    print -P "%F{cyan}🏙️ CityX/MiastoX - GitHub Manager%f"
    print -P "   %F{dim}Użyj 'vman' lub 'gh-show' aby zobaczyć wersje%f"
    print -P "   %F{dim}lub 'gh-help' dla pełnej pomocy%f"
    echo ""
}

gh-welcome

# ==============================
# START TIME TRACKER
# ==============================
_WELCOME_START_TIME=$(date +%s)

# ==============================
# ALIASES / FUNCTIONS (poprawione)
# ==============================
# Poprzednio było: alias cdw='cd "$1"...' - BUG ($1 nie działa w alias)
# Teraz: funkcja
cdw() { 
    if [[ -z "$1" ]]; then
        builtin cd && bash "$WELCOME_SCRIPT" "$PWD"
    else
        builtin cd "$1" && bash "$WELCOME_SCRIPT" "$PWD"
    fi
}

# ==============================
# AUTO WELCOME
# ==============================
[[ -o interactive ]] && welcome
