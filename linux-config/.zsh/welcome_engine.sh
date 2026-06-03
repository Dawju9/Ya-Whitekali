#!/usr/bin/env bash
# ==========================================
# KXL Welcome Engine v3.0
# ==========================================
# Rozbudowany silnik powitalny dla repozytoriów:
# - Czyta .welcome.conf (fallback: auto-detect)
# - Parsuje About.md / README.md / TODO.md / CHANGELOG.md
# - Wyświetla dane projektu w kolorowej formie
# - Auto-detect typu projektu, zależności, komend
# - Health check plików krytycznych
# ==========================================

set -uo pipefail

# ==========================================
# KOLORY ANSI
# ==========================================
C_RST='\033[0m'
C_BLD='\033[1m'
C_DIM='\033[2m'
C_BLU='\033[1;34m'
C_GRN='\033[1;32m'
C_YLW='\033[1;33m'
C_CYN='\033[1;36m'
C_MGN='\033[1;35m'
C_RED='\033[1;31m'
C_GRAY='\033[0;90m'
C_WHT='\033[1;37m'
C_BG_BLUE='\033[44m'
C_BG_GRAY='\033[100m'

# ==========================================
# PASEK POSTĘPU
# ==========================================
_draw_bar() {
  local pct=$1 size=${2:-20}
  local filled=$(( (pct * size) / 100 ))
  local empty=$(( size - filled ))
  local color="${C_GRN}"
  [[ $pct -ge 60 && $pct -lt 85 ]] && color="${C_YLW}"
  [[ $pct -ge 85 ]] && color="${C_RED}"
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "${color}${bar}${C_RST}"
}

_hr() { printf "${C_GRAY}──────────────────────────────────────────────────────${C_RST}\n"; }
_hr_thin() { printf "${C_DIM}──────────────────────────────────────────────────────${C_RST}\n"; }

# ==========================================
# DEFAULTS
# ==========================================
DEFAULT_PROJECT_NAME="Unknown Project"
DEFAULT_VERSION="0.0.0"
DEFAULT_DESC="(brak opisu)"

EXCLUDE_DIRS_DEFAULT=(".git" "node_modules" "__pycache__" "target" "build" "dist" ".venv" "venv" "_site" ".cargo" ".rustup" ".next" ".cache" "logs" "tmp")
EXCLUDE_FILES_DEFAULT=("*.lock" "*.log" "*.pyc" "*.tmp" "*.bak" "*.swp" "*.swo" ".DS_Store")

# ==========================================
# SAFE SOURCE CONFIG
# ==========================================
load_config() {
  local dir="$1"
  local cfg="$dir/.welcome.conf"
  if [[ -f "$cfg" ]]; then
    # source w subshell żeby nie zanieczyścić środowiska
    ( source "$cfg" ) && return 0
  fi
  return 1
}

# Załaduj zmienne .welcome.conf do bieżącego scope
# Używa eval żeby zmienne były widoczne w wywołującym
load_config_vars() {
  local dir="$1"
  local cfg="$dir/.welcome.conf"
  if [[ -f "$cfg" ]]; then
    # Zapisz wartości do pliku tymczasowego i wczytaj
    local tmp=$(mktemp)
    ( source "$cfg" ) >/dev/null 2>&1
    # Wymuś eksport zmiennych przez wypisanie declare -p
    ( source "$cfg"; declare -p 2>/dev/null | sed -n 's/^declare -[^=]*//p' | sed "s/='/='/;s/'$//" ) > "$tmp" 2>/dev/null
    source "$tmp" 2>/dev/null
    rm -f "$tmp"
    return 0
  fi
  return 1
}

# ==========================================
# DATA COLLECTORS
# ==========================================

human_size() { du -sh "$1" 2>/dev/null | cut -f1; }

# build_find_excludes: buduje tablicę argumentów -not -path
# Użycie: build_find_excludes src_array dest_array_name
build_find_excludes() {
  local src_name="$1" dest_name="$2"
  local -n src_ref="$src_name"
  local -n dest_ref="$dest_name"
  dest_ref=()
  for d in "${src_ref[@]}"; do
    dest_ref+=( -not -path "*/$d/*" )
  done
}

# Używa globalnej tablicy _FIND_EXCLUDES (do użycia po build_find_excludes)
count_files() {
  local dir="$1"
  if [[ ${#_FIND_EXCLUDES[@]} -gt 0 ]]; then
    find "$dir" "${_FIND_EXCLUDES[@]}" -type f 2>/dev/null | wc -l
  else
    find "$dir" -type f 2>/dev/null | wc -l
  fi
}

count_dirs() {
  local dir="$1"
  if [[ ${#_FIND_EXCLUDES[@]} -gt 0 ]]; then
    find "$dir" "${_FIND_EXCLUDES[@]}" -type d 2>/dev/null | wc -l
  else
    find "$dir" -type d 2>/dev/null | wc -l
  fi
}

count_lines() {
  local dir="$1"
  local excl_args=("${_FIND_EXCLUDES[@]}")
  # Licz linie kodu w znanych rozszerzeniach, max 30s (timeout na read)
  if [[ ${#_FIND_EXCLUDES[@]} -eq 0 ]]; then
    timeout 20 find "$dir" \
      \( -name "*.lua" -o -name "*.luau" -o -name "*.js" -o -name "*.ts" \
         -o -name "*.py" -o -name "*.rb" -o -name "*.rs" -o -name "*.java" \
         -o -name "*.go" -o -name "*.php" -o -name "*.html" -o -name "*.css" \
         -o -name "*.scss" \) \
      -type f -exec cat {} + 2>/dev/null | wc -l
  else
    timeout 20 find "$dir" "${excl_args[@]}" \
      \( -name "*.lua" -o -name "*.luau" -o -name "*.js" -o -name "*.ts" \
         -o -name "*.py" -o -name "*.rb" -o -name "*.rs" -o -name "*.java" \
         -o -name "*.go" -o -name "*.php" -o -name "*.html" -o -name "*.css" \
         -o -name "*.scss" \) \
      -type f -exec cat {} + 2>/dev/null | wc -l
  fi
}

git_branch()  { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; }
git_changes() { git -C "$1" status --short 2>/dev/null | wc -l; }
git_remote()  {
  local url=$(git -C "$1" config --get remote.origin.url 2>/dev/null)
  # Maskuj tokeny w URL (https://user:TOKEN@github.com -> https://user:***@github.com)
  if [[ "$url" =~ ^https://[^:]+:[^@]+@ ]]; then
    echo "$url" | sed -E 's#(https://[^:]+:)[^@]+(@)#\1***\2#'
  else
    echo "$url"
  fi
}
git_last_commit() { git -C "$1" log -1 --pretty=format:'%h %s (%ar)' 2>/dev/null; }
git_commit_count() { git -C "$1" rev-list --count HEAD 2>/dev/null; }
git_uncommitted() {
  local dir="$1"
  local modified=$(git -C "$dir" diff --name-only 2>/dev/null | wc -l)
  local staged=$(git -C "$dir" diff --cached --name-only 2>/dev/null | wc -l)
  local untracked=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | wc -l)
  echo "${modified}|${staged}|${untracked}"
}

# ==========================================
# AUTO-DETECT PROJECT TYPE
# ==========================================
detect_project_type() {
  local dir="$1"
  # Schematics (Python + XML)
  [[ -f "$dir/SchematicAgent.py" || -f "$dir/city_engine.py" ]] && echo "Schematics/Python" && return
  # Rust
  [[ -f "$dir/Cargo.toml" ]] && echo "Rust" && return
  # Roblox/Luau
  [[ -f "$dir/wally.toml" || -f "$dir/default.project.json" || -f "$dir/.luarc.json" ]] && echo "Roblox/Luau" && return
  # Flutter/Dart
  [[ -f "$dir/pubspec.yaml" ]] && echo "Flutter/Dart" && return
  # Python
  [[ -f "$dir/requirements.txt" || -f "$dir/setup.py" || -f "$dir/pyproject.toml" ]] && echo "Python" && return
  # Node.js
  [[ -f "$dir/package.json" ]] && echo "Node.js" && return
  # Go
  [[ -f "$dir/go.mod" ]] && echo "Go" && return
  # Jekyll
  [[ -f "$dir/Gemfile" || -f "$dir/_config.yml" ]] && echo "Jekyll/Ruby" && return
  # PHP
  [[ -f "$dir/composer.json" ]] && echo "PHP" && return
  # Static website
  [[ -f "$dir/index.html" || -f "$dir/index-app.html" ]] && echo "Static Web" && return
  # AI/Agent
  [[ -d "$dir/agents" || -d "$dir/.pydantic-deep" ]] && echo "AI/Agent" && return
  echo "Generic"
}

# ==========================================
# DEPENDENCY INFO
# ==========================================
get_dependencies() {
  local dir="$1"
  local deps=()
  
  # Python requirements
  if [[ -f "$dir/requirements.txt" ]]; then
    deps+=("Python:$(head -10 "$dir/requirements.txt" | grep -v '^#' | grep -v '^$' | wc -l) packages")
  fi
  
  # Node packages
  if [[ -f "$dir/package.json" ]]; then
    local deps_count=$(jq -r '.dependencies // {} | keys | length' "$dir/package.json" 2>/dev/null)
    local dev_count=$(jq -r '.devDependencies // {} | keys | length' "$dir/package.json" 2>/dev/null)
    deps+=("Node:${deps_count:-0} deps, ${dev_count:-0} dev")
  fi
  
  # Rust crates
  if [[ -f "$dir/Cargo.toml" ]]; then
    local crate_count=$(grep -c '^\[\[package\]\]' "$dir/Cargo.toml" 2>/dev/null)
    [[ $crate_count -eq 0 ]] && crate_count=$(grep -cE '^[a-z_-]+ = ' "$dir/Cargo.toml" 2>/dev/null)
    deps+=("Rust:${crate_count:-0} crates")
  fi
  
  # Wally (Roblox)
  if [[ -f "$dir/wally.toml" ]]; then
    local wally_count=$(grep -cE '^[a-z_-]+ = ' "$dir/wally.toml" 2>/dev/null)
    deps+=("Wally:${wally_count:-0} packages")
  fi
  
  printf '%s\n' "${deps[@]}"
}

# ==========================================
# ENTRY POINTS
# ==========================================
detect_main_entry() {
  local dir="$1"
  # Python
  for f in "main.py" "bot.py" "app.py" "SchematicAgent.py" "city_engine.py" "build_master.py"; do
    [[ -f "$dir/$f" ]] && echo "Python:$f" && return
  done
  # Rust
  [[ -f "$dir/src/main.rs" ]] && echo "Rust:src/main.rs" && return
  # Node
  for f in "index.js" "index.ts" "server.js" "app.js"; do
    [[ -f "$dir/$f" ]] && echo "Node:$f" && return
  done
  # Roblox
  [[ -f "$dir/default.project.json" ]] && echo "Roblox:default.project.json" && return
  # HTML
  for f in "index.html" "index-app.html" "site/website/index.html"; do
    [[ -f "$dir/$f" ]] && echo "Web:$f" && return
  done
  echo ""
}

# ==========================================
# MARKDOWN PARSER
# ==========================================
# Wyciąga z markdown:
# - Pierwszy akapit (opis)
# - Tytuł
# - Sekcje po nazwie
# Użycie: parse_markdown_section "## Tech" README.md
md_get_title() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  # Pierwszy nagłówek H1
  head -1 "$file" | sed -E 's/^#\s*//;s/^#+ //;s/[📦🏙️🤖🎮⚪🟢🔴🟡🔵🎯📦🌟💎🌐]*//g;s/  */ /g' | head -c 200
}

md_get_description() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  # Pierwszy paragraf po tytule (pomijamy cytaty > i nagłówki)
  awk 'BEGIN{p=0; lines=0}
       /^>/{next}  # pomiń cytaty
       /^#/{next}  # pomiń nagłówki
       /^!\[/{next}  # pomiń obrazy
       /^\s*$/{if(p>0 && lines>0) exit; next}
       {if(p==0) {p=1; print; lines++} else if(p==1) {print; lines++}}
       lines>=2{exit}' "$file" | head -2 | tr '\n' ' ' | sed 's/  */ /g;s/^ //;s/ $//' | head -c 300
}

# Wyciąga zawartość sekcji (## Nazwa) - zwraca do końca sekcji lub pliku
# Użycie: md_get_section "## Tech" "README.md" | head -20
md_get_section() {
  local pattern="$1" file="$2"
  [[ ! -f "$file" ]] && return
  awk -v pat="$pattern" '
    BEGIN{in_section=0}
    {
      # Sprawdź czy linia zaczyna sekcję
      if ($0 ~ "^"pat"[[:space:]]*$" || $0 ~ "^"pat" ") {
        in_section=1
        next
      }
      # Nowa sekcja (inny nagłówek) zamyka
      if (in_section && /^#+ /) { exit }
      if (in_section) { print }
    }' "$file"
}

# Wyciąga listę itemów z sekcji (linie zaczynające się od - lub *)
# md_get_items "## Features" README.md
md_get_items() {
  local pattern="$1" file="$2"
  md_get_section "$pattern" "$file" | \
    grep -E '^\s*[-*]\s+' | \
    sed -E 's/^\s*[-*]\s+//' | \
    sed -E 's/\[([^]]+)\]\([^)]+\)/\1/g' | \
    sed -E 's/[*_`]//g' | \
    head -20
}

# Wyciąga tabele markdown - zwraca jako listy "kol:wart"
# Użycie: md_get_table "## Tech" "README.md" | head -5
md_get_table() {
  local pattern="$1" file="$2"
  md_get_section "$pattern" "$file" | \
    awk 'NR==1 {next} /^\|.*\|$/ {gsub(/^\|/,""); gsub(/\|$/,""); print}' | \
    awk -F'|' '{gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$2); if($1!="---" && $1!="") print $1"→"$2}' | \
    head -20
}

# Wyciąga bloki kodu (``` ... ```)
md_get_code_blocks() {
  local pattern="$1" file="$2"
  md_get_section "$pattern" "$file" | \
    awk '/^```/{c++; next} c%2==1' | \
    head -30
}

# Specjalny extractor dla Tech Stack
# Próbuje znaleźć sekcję Tech/Stack/Technologie
md_get_tech_stack() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  # Szukaj sekcji: Tech Stack / Technologie / Stack / Technology
  local result=""
  for pat in "## Tech Stack" "## 🛠️ Tech Stack" "## Technologie" "## 🛠️ Technologie" "## Stack" "## Technology" "## Technologies"; do
    local sec=$(md_get_section "$pat" "$file" 2>/dev/null)
    if [[ -n "$sec" ]]; then
      result=$(echo "$sec" | head -20)
      break
    fi
  done
  echo "$result"
}

# ==========================================
# SUBST PLACEHOLDERS
# ==========================================
subst() {
  local msg="$1" dir="$2"
  msg="${msg//\{PROJECT_NAME\}/${PROJECT_NAME:-${DEFAULT_PROJECT_NAME}}}"
  msg="${msg//\{PROJECT_SHORT\}/${PROJECT_SHORT:-}}"
  msg="${msg//\{VERSION\}/${VERSION:-${DEFAULT_VERSION}}}"
  msg="${msg//\{VERSION_DATE\}/${VERSION_DATE:-}}"
  msg="${msg//\{DIR\}/${dir}}"
  msg="${msg//\{GITHUB_REPO\}/${GITHUB_REPO:-}}"
  msg="${msg//\{GITHUB_BRANCH\}/${GITHUB_BRANCH:-}}"
  msg="${msg//\{PROJECT_DESC\}/${PROJECT_DESC:-}}"
  msg="${msg//\{PROJECT_TYPE\}/${PROJECT_TYPE:-$(detect_project_type "$dir")}}"
  msg="${msg//\{ENTRY\}/${MAIN_ENTRY:-}}"
  echo "$msg"
}

# ==========================================
# HELPER: ARRAY SAFE JOIN
# ==========================================
join_array() {
  local IFS="${1:-|}"
  shift
  echo "$*"
}

# ==========================================
# MAIN: SHOW PROJECT INFO (z .welcome.conf)
# ==========================================
show_project_info() {
  local dir="$1"
  
  # --- LOAD CONFIG ---
  local has_conf=0
  if [[ -f "$dir/.welcome.conf" ]]; then
    # Source w bieżącym shellu (nie subshell) żeby zmienne były dostępne
    source "$dir/.welcome.conf" 2>/dev/null || true
    has_conf=1
  fi
  
  # --- DEFAULTS ---
  local project_name="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"
  local project_short="${PROJECT_SHORT:-}"
  local version="${VERSION:-$DEFAULT_VERSION}"
  local version_date="${VERSION_DATE:-}"
  local desc="${PROJECT_DESC:-$DEFAULT_DESC}"
  local github="${GITHUB_REPO:-}"
  local branch="${GITHUB_BRANCH:-}"
  local type="${PROJECT_TYPE:-}"
  
  # --- AUTO-DETECT JESIĆ BRAK ---
  if [[ -z "$type" ]]; then
    type=$(detect_project_type "$dir")
  fi
  
  # --- BUILD EXCLUDES ---
  local excludes=("${EXCLUDE_DIRS[@]:-${EXCLUDE_DIRS_DEFAULT[@]}}")
  _FIND_EXCLUDES=()
  build_find_excludes excludes _FIND_EXCLUDES
  
  # --- COLLECT STATS ---
  local files=$(count_files "$dir")
  local dirs_count=$(count_dirs "$dir")
  local loc=$(count_lines "$dir")
  local size=$(human_size "$dir")
  local g_branch=$(git_branch "$dir")
  local g_remote=$(git_remote "$dir")
  local g_changes=$(git_changes "$dir")
  local g_last=$(git_last_commit "$dir")
  local g_count=$(git_commit_count "$dir")
  
  # --- HEADER ---
  echo
  printf "${C_BG_GRAY}${C_WHT} %-50s ${C_RST}\n" "$project_name v$version"
  echo
  printf "${C_CYN}  📦 %s${C_RST}\n" "$project_name"
  [[ -n "$project_short" ]] && printf "${C_DIM}     alias: %s${C_RST}\n" "$project_short"
  printf "${C_DIM}     %s${C_RST}\n" "$type"
  [[ -n "$version_date" ]] && printf "${C_DIM}     build: %s${C_RST}\n" "$version_date"
  echo
  
  # --- DESCRIPTION ---
  if [[ -n "$desc" && "$desc" != "$DEFAULT_DESC" ]]; then
    printf "${C_YLW}  📜 Opis:${C_RST}\n"
    # Zawijanie do 70 znaków
    echo "$desc" | fold -w 70 -s | sed 's/^/     /'
    echo
  fi
  
  # --- MARKDOWN DATA (jeśli istnieją) ---
  local about_file=""
  for f in "About.md" "about.md" "README.md" "readme.md"; do
    if [[ -f "$dir/$f" ]]; then
      about_file="$f"
      break
    fi
  done
  
  if [[ -n "$about_file" ]]; then
    printf "${C_MGN}  📖 Źródła markdown:${C_RST} ${C_DIM}%s${C_RST}\n" "$about_file"
    
    # Wyciągnij tech stack z markdown jeśli TECH_STACK nie ustawiony
    local _ts_count=${#TECH_STACK[@]}
    if [[ -z "${TECH_STACK[*]:-}" || $_ts_count -eq 0 ]]; then
      local md_tech=$(md_get_tech_stack "$dir/$about_file")
      if [[ -n "$md_tech" ]]; then
        # Spróbuj sparsować różne formaty
        local extracted=$(echo "$md_tech" | \
          grep -oE '\*\*[^*]+\*\*' | sed 's/\*//g' | head -8 | tr '\n' '|')
        if [[ -z "$extracted" ]]; then
          extracted=$(echo "$md_tech" | \
            grep -oE '\| [A-Za-z0-9 .+#-]+' | head -8 | sed 's/^|//;s/  */ /g' | tr '\n' '|')
        fi
        if [[ -n "$extracted" ]]; then
          # Konwersja z bash array
          IFS='|' read -ra NEW_STACK <<< "$extracted"
          # Filtuj puste
          local clean_stack=()
          for s in "${NEW_STACK[@]}"; do
            s="${s#"${s%%[![:space:]]*}"}"  # trim left
            s="${s%"${s##*[![:space:]]}"}"  # trim right
            [[ -n "$s" && "$s" != "|" ]] && clean_stack+=("$s")
          done
          TECH_STACK=("${clean_stack[@]}")
        fi
      fi
    fi
    
    # Features
    local md_features=$(md_get_items "## Features" "$dir/$about_file")
    [[ -z "$md_features" ]] && md_features=$(md_get_items "## 🎮 Funkcje" "$dir/$about_file")
    [[ -z "$md_features" ]] && md_features=$(md_get_items "## Capabilities" "$dir/$about_file")
    if [[ -n "$md_features" && -z "${FEATURES[*]:-}" ]]; then
      FEATURES=()
      while IFS= read -r line; do
        FEATURES+=("$line")
      done <<< "$md_features"
    fi
    
    echo
  fi
  
  # --- TECH STACK ---
  if [[ -n "${TECH_STACK[*]:-}" ]]; then
    printf "${C_MGN}  🛠️  Tech Stack:${C_RST}\n"
    local stack_str=$(printf '%s, ' "${TECH_STACK[@]}")
    stack_str="${stack_str%, }"
    # Zawijanie bez utraty pierwszej linii
    local wrapped=$(echo "     $stack_str" | fold -w 70 -s)
    if [[ $(echo "$wrapped" | wc -l) -gt 1 ]]; then
      echo "$wrapped" | sed 's/^/     /'
    else
      echo "     $stack_str"
    fi
    echo
  fi
  
  # --- FEATURES (z markdown lub conf) ---
  if [[ -n "${FEATURES[*]:-}" && "${#FEATURES[@]}" -gt 0 ]]; then
    printf "${C_YLW}  ⭐ Features:${C_RST}\n"
    local i=0
    for f in "${FEATURES[@]}"; do
      [[ $i -ge 8 ]] && break
      [[ -z "$f" || "$f" =~ ^[[:space:]]*$ ]] && continue
      printf "     ${C_GRN}•${C_RST} %s\n" "$(echo "$f" | head -c 90)"
      ((i++))
    done
    echo
  fi

  # --- STATISTICS ---
  _hr
  printf "${C_CYN}  📊 Statystyki${C_RST}\n"
  printf "     ${C_DIM}Files:${C_RST}  %s\n" "$files"
  printf "     ${C_DIM}Dirs:${C_RST}   %s\n" "$dirs_count"
  printf "     ${C_DIM}LOC:${C_RST}    %s\n" "$loc"
  printf "     ${C_DIM}Size:${C_RST}   %s\n" "$size"
  _hr
  echo
  
  # --- DEPENDENCIES ---
  if [[ "${SHOW_DEPS:-1}" == "1" ]]; then
    local deps=$(get_dependencies "$dir")
    if [[ -n "$deps" ]]; then
      printf "${C_MGN}  📦 Zależności:${C_RST}\n"
      while IFS= read -r d; do
        [[ -z "$d" ]] && continue
        local name="${d%%:*}"
        local val="${d#*:}"
        printf "     ${C_GRN}▸${C_RST} ${C_CYN}%-10s${C_RST} %s\n" "$name" "$val"
      done <<< "$deps"
      echo
    fi
  fi
  
  # --- ENTRY POINT ---
  local entry=$(detect_main_entry "$dir")
  if [[ -n "$entry" ]]; then
    local e_type="${entry%%:*}"
    local e_file="${entry#*:}"
    printf "${C_YLW}  🚀 Entry:${C_RST} ${C_DIM}%s${C_RST} %s\n" "$e_type" "$e_file"
    echo
  fi
  
  # --- GIT INFO ---
  if [[ "${SHOW_GIT:-1}" == "1" && -d "$dir/.git" ]]; then
    printf "${C_CYN}  🔀 Git${C_RST}\n"
    if [[ -n "$g_branch" ]]; then
      printf "     ${C_DIM}Branch:${C_RST}   %s\n" "$g_branch"
    fi
    if [[ -n "$g_last" ]]; then
      printf "     ${C_DIM}Last:${C_RST}     %s\n" "$g_last"
    fi
    if [[ -n "$g_count" ]]; then
      printf "     ${C_DIM}Commits:${C_RST}  %s\n" "$g_count"
    fi
    if [[ -n "$g_remote" ]]; then
      printf "     ${C_DIM}Remote:${C_RST}   %s\n" "$g_remote"
    fi
    if [[ "$g_changes" -gt 0 ]]; then
      printf "     ${C_YLW}Changes:${C_RST}  %s uncommitted${C_RST}\n" "$g_changes"
    else
      printf "     ${C_GRN}Status:${C_RST}   clean${C_RST}\n"
    fi
    echo
  fi
  
  # --- HEALTH CHECK ---
  if [[ -n "${HEALTH_CHECK_FILES[*]:-}" && "${#HEALTH_CHECK_FILES[@]}" -gt 0 ]]; then
    printf "${C_CYN}  🏥 Health Check${C_RST}\n"
    local all_ok=true
    local f
    for f in "${HEALTH_CHECK_FILES[@]}"; do
      if [[ -e "$dir/$f" ]]; then
        printf "     ${C_GRN}✓${C_RST} %s\n" "$f"
      else
        printf "     ${C_RED}✗${C_RST} %s ${C_DIM}(brak)${C_RST}\n" "$f"
        all_ok=false
      fi
    done
    if $all_ok; then
      printf "     ${C_GRN}→ All critical files present${C_RST}\n"
    else
      printf "     ${C_RED}→ Some files missing!${C_RST}\n"
    fi
    echo
  fi
  
  # --- PROJECT MODULES ---
  if [[ -n "${PROJECT_MODULES[*]:-}" && "${#PROJECT_MODULES[@]}" -gt 0 ]]; then
    printf "${C_MGN}  🧩 Moduły${C_RST}\n"
    local mod
    for mod in "${PROJECT_MODULES[@]}"; do
      if [[ "$mod" == *:* ]]; then
        local m_name="${mod%%:*}"
        local m_desc="${mod#*:}"
        local exists="✗"
        [[ -e "$dir/$m_name" ]] && exists="✓"
        local color="${C_RED}"
        [[ "$exists" == "✓" ]] && color="${C_GRN}"
        printf "     ${color}${exists}${C_RST} ${C_CYN}%-35s${C_RST} ${C_DIM}%s${C_RST}\n" "$m_name" "$m_desc"
      else
        printf "     ${C_DIM}• %s${C_RST}\n" "$mod"
      fi
    done
    echo
  fi
  
  # --- CUSTOM COMMANDS ---
  if [[ -n "${CUSTOM_COMMANDS[*]:-}" && "${#CUSTOM_COMMANDS[@]}" -gt 0 ]]; then
    printf "${C_GRN}  ⚡ Komendy Projektu${C_RST}\n"
    local cmd
    for cmd in "${CUSTOM_COMMANDS[@]}"; do
      if [[ "$cmd" == *:* ]]; then
        local c_name="${cmd%%:*}"
        local c_desc="${cmd#*:}"
        printf "     ${C_YLW}%-25s${C_RST} ${C_DIM}→${C_RST} %s\n" "$c_name" "$c_desc"
      else
        printf "     ${C_DIM}• %s${C_RST}\n" "$cmd"
      fi
    done
    echo
  fi
  
  # --- GITHUB LINK ---
  if [[ -n "$github" ]]; then
    if [[ "$github" == http* ]]; then
      printf "${C_DIM}  🌐 %s${C_RST}\n" "$github"
    else
      printf "${C_DIM}  🌐 https://github.com/%s${C_RST}\n" "$github"
    fi
    echo
  fi
  
  # --- WELCOME MESSAGE (z template) ---
  if [[ -n "${WELCOME_MESSAGE:-}" ]]; then
    subst "$WELCOME_MESSAGE" "$dir"
    echo
  fi
  
  # --- TODO / ROADMAP (z pliku TODO.md) ---
  for todo_file in "TODO.md" "todo.md" "ROADMAP.md"; do
    if [[ -f "$dir/$todo_file" ]]; then
      printf "${C_YLW}  📋 TODO/Roadmap (z %s):${C_RST}\n" "$todo_file"
      local todos=$(md_get_items "## " "$dir/$todo_file" 2>/dev/null | head -5)
      if [[ -n "$todos" ]]; then
        echo "$todos" | sed 's/^/     • /'
      else
        head -10 "$dir/$todo_file" | sed 's/^/     /'
      fi
      echo
      break
    fi
  done
  
  # --- CHANGELOG (skrót) ---
  for chg_file in "CHANGELOG.md" "CHANGES.md" "HISTORY.md"; do
    if [[ -f "$dir/$chg_file" ]]; then
      printf "${C_DIM}  📜 %s: %s${C_RST}\n" "$chg_file" "$(head -1 "$dir/$chg_file" | head -c 100)"
      break
    fi
  done
  
  _hr
  echo
}

# ==========================================
# BASIC INFO (gdy brak .welcome.conf)
# ==========================================
show_basic_info() {
  local dir="$1"
  local type=$(detect_project_type "$dir")
  local size=$(human_size "$dir")
  local files=$(count_files "$dir" "")
  local branch=$(git_branch "$dir")
  local remote=$(git_remote "$dir")
  
  echo
  printf "${C_BG_GRAY}${C_WHT} %-50s ${C_RST}\n" "$type project"
  echo
  printf "${C_CYN}  📂 %s${C_RST}\n" "$(realpath "$dir" 2>/dev/null || echo "$dir")"
  printf "${C_GRN}  💾 Size:${C_RST}  %s\n" "$size"
  printf "${C_YLW}  📊 Files:${C_RST} %s\n" "$files"
  [[ -n "$branch" ]] && printf "${C_CYN}  🔀 Git:${C_RST}   %s\n" "$branch"
  [[ -n "$remote" ]] && printf "${C_DIM}  🌐 %s${C_RST}\n" "$remote"
  echo
  printf "${C_DIM}  💡 Tip: Stwórz .welcome.conf w tym katalogu dla pełnego info${C_RST}\n"
  echo
  _hr
  echo
}

# ==========================================
# ENTRY POINT
# ==========================================
show_welcome() {
  local dir="${1:-$PWD}"
  # Rozwiń do absolutnej ścieżki
  dir=$(realpath "$dir" 2>/dev/null || echo "$dir")
  
  if [[ -f "$dir/.welcome.conf" ]]; then
    show_project_info "$dir"
  else
    show_basic_info "$dir"
  fi
}

# ==========================================
# SELF-GENERATE .welcome.conf (helper)
# ==========================================
generate_welcome_conf() {
  local dir="${1:-$PWD}"
  local conf="$dir/.welcome.conf"
  
  if [[ -f "$conf" ]]; then
    echo ".welcome.conf już istnieje w $dir"
    return 1
  fi
  
  local type=$(detect_project_type "$dir")
  local name=$(basename "$dir")
  local entry=$(detect_main_entry "$dir")
  
  cat > "$conf" << CONF_EOF
# Welcome Configuration - $name
# Auto-generated by welcome_engine.sh
# Data: $(date '+%Y-%m-%d %H:%M')

PROJECT_NAME="$name"
PROJECT_SHORT="$name"
PROJECT_DESC="TODO: dodaj opis projektu"
PROJECT_TYPE="$type"

VERSION="0.1.0"
VERSION_DATE="$(date '+%Y-%m-%d')"

# GITHUB_REPO="user/$name"
# GITHUB_BRANCH="main"

TECH_STACK=()

EXCLUDE_DIRS=(".git" "node_modules" "__pycache__" "target" "build" "dist" ".venv" "venv")
EXCLUDE_FILES=("*.lock" "*.log" "*.pyc")

SHOW_GIT=1
SHOW_SIZE=1
SHOW_FILES=1
SHOW_MODULES=1
SHOW_DEPS=1

CUSTOM_COMMANDS=()

WELCOME_MESSAGE="
📦 {PROJECT_NAME} v{VERSION}
{PROJECT_DESC}
"
CONF_EOF
  
  echo "✓ Wygenerowano: $conf"
  echo "💡 Edytuj PROJECT_DESC i TECH_STACK"
}

# ==========================================
# RUN (jeśli wywołane bezpośrednio)
# ==========================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    "")
      show_welcome "${2:-.}"
      ;;
    --generate|-g)
      generate_welcome_conf "${2:-.}"
      ;;
    --help|-h)
      cat << HELP_EOF
KXL Welcome Engine v3.0

Użycie:
  welcome_engine.sh                     # Pokaż info o bieżącym katalogu
  welcome_engine.sh /ścieżka/do/repo    # Pokaż info o konkretnym repo
  welcome_engine.sh --generate           # Wygeneruj szablon .welcome.conf
  welcome_engine.sh --help               # Ta pomoc

Wymaga: .welcome.conf w katalogu repozytorium (lub auto-detect)
HELP_EOF
      ;;
    *)
      show_welcome "$1"
      ;;
  esac
fi
