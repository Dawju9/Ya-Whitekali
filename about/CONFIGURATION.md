**✅ Pełny opis konfiguracji powłoki (Zsh + Bash)**

Oto kompleksowe, uporządkowane podsumowanie Twojej konfiguracji shellowej.

---

### **1. Cel i filozofia konfiguracji**

Twoja konfiguracja to zaawansowany, produkcyjny framework shellowy z naciskiem na:
- **Szybkość i wygodę** codziennej pracy
- **Automatyczne powitania projektów** (`.welcome.conf`)
- **Bogaty toolkit AI** (Ollama)
- **Nawigację i produktywność**
- **Estetykę i informacje kontekstowe**

---

### **2. Co robi system welcome**

**Główne zadanie:**
- Wyświetlenie pięknego banera powitalnego przy starcie sesji
- Automatyczne wyświetlanie informacji o projekcie przy wejściu do katalogu zawierającego plik `.welcome.conf`

**Kluczowe elementy banera:**
- Użytkownik / Host / Katalog / Data i godzina
- Obciążenie systemu (Load + RAM)
- Status Ollama + lista załadowanych modeli (z rozmiarem w GB)
- Losowa rada (`help`)

---

### **3. Mechanizmy auto-welcome**

Dwa równoległe mechanizmy (obecnie się dublują → **bug**):

1. **Hook `chpwd`** poprzez `add-zsh-hook`
2. **Override funkcji `cd()`** – wrapper wokół builtin `cd`

```bash
cd() {
    builtin cd "$@" || return
    if [[ -f "$PWD/.welcome.conf" ]]; then
        bash "$WELCOME_SCRIPT" "$PWD"
    fi
}
```

**Rekomendacja:** Usunąć jeden z mechanizmów (najlepiej zostawić hook `chpwd`).

---

### **4. Struktura plików konfiguracyjnych**

| Plik              | Przeznaczenie                              | Uwagi |
|-------------------|-------------------------------------------|-------|
| `.zshenv`         | Najwcześniejsze ładowanie (nawet non-interactive) | Tylko Cargo |
| `.zshrc`          | Główna konfiguracja Zsh                   | Rdzeń |
| `.bashrc`         | Fallback dla Bash                         | Minimalistyczny + przekierowanie do Zsh |
| `.profile`        | Login shell                               | Standard |
| `commands.sh`     | Wszystkie własne funkcje i komendy        | Najważniejszy plik |
| `welcome.sh`      | Logika powitań                            | - |
| `welcome_engine.sh` | Silnik generowania banerów             | - |

---

### **5. Konfiguracja Zsh (.zshrc) – kluczowe sekcje**

- **Safety**: `NO_NOMATCH`, `GLOB_DOTS`
- **History**: 50k w sesji, 100k w pliku, z deduplikacją i sharingiem
- **Prompt**: Kolorowy z `vcs_info` (branch git) + emoji
- **Completion**: Menu select, case-insensitive, kolory
- **Keybindings**: emacs + Ctrl+R, Ctrl+P/N
- **Plugins**: autosuggestions + syntax-highlighting
- **Environment**: OLLAMA, NVM, GITHUB_TOKEN (⚠️ problem)
- **Lazy NVM**
- **Sourcing**: `commands.sh`, `welcome.sh`, `site-status.sh`

---

### **6. AI Toolkit (`commands.sh`)**

Bardzo rozbudowany zestaw komend Ollama:

- `ai <pytanie>` – pojedyncze zapytanie
- `aimsg` – tryb konwersacyjny
- `ai-models` – lista modeli z rozmiarem
- `ai-bench` – benchmark wszystkich modeli
- `ai-test` – test połączenia i latency
- `ai-fast`, `ai-big` – szybkie przełączanie modeli
- `ai-tokens` – statystyki tokenów

Wszystkie komendy używają bezpośredniego REST API Ollama.

---

### **7. Najważniejsze własne komendy**

**Nawigacja:**
- `..`, `...`, `....`
- `fog <nazwa>` – fuzzy jump po katalogach
- `mkcd`, `cdp`

**System:**
- `server` – podsumowanie zasobów
- `weather [miasto]`
- `myip`
- `extract` – uniwersalny extractor
- `backup`

**Project-specific:**
- `schemat <plik.xml>`
- `gh-show/update/push/log/status` – wrappery version managera

**Inne:**
- Zaawansowany `command-not-found` handler
- `help` – dynamiczna lista aliasów i funkcji
- Pomiar czasu komend (>1s pokazuje `⌛`)

---

### **8. Znalezione problemy (do naprawy)**

**Krytyczne:**
1. **GITHUB_TOKEN** w plaintext w `.zshrc` → **poważne ryzyko bezpieczeństwa**
2. Podwójne wywoływanie welcome (`chpwd` + `cd` override)
3. Alias `cdw` nie działa (`$1` w aliasie)

**Poważne:**
4. Błąd w `who()` – `awk '{2}'`
5. Problemy z parsowaniem streamu w `ai()`
6. Brak `exec zsh` w `.bashrc` mimo komentarza

**Mniejsze:**
- `nvm use default` na końcu `.zshrc` spowalnia start
- Kilka mniejszych bugów w parsowaniu

---

### **9. Mocne strony konfiguracji**

- Bardzo dobra modularność
- Unikalny i użyteczny system `.welcome.conf`
- Zaawansowany toolkit AI
- Dobra obsługa historii i completion
- Estetyczny prompt + informacje kontekstowe
- Dużo dbałości o UX

---

---

### **10. Zastosowane poprawki (Wersja Spójna)**

W ramach najnowszej aktualizacji wprowadzono następujące usprawnienia:

1.  **NVM (Lazy Loading):** Zoptymalizowano ładowanie NVM. Zamiast spowalniać start powłoki przy każdym uruchomieniu, NVM ładuje się teraz dopiero przy pierwszym wywołaniu komend `node`, `npm` lub `nvm`.
2.  **Fix `who()`:** Naprawiono błąd parsowania `awk`, który uniemożliwiał poprawne wyświetlanie informacji o użytkownikach.
3.  **Fix `cdw`:** Naprawiono alias `cdw`, zamieniając go na funkcję obsługującą argumenty.
4.  **Optymalizacja Welcome:** Usunięto dublujące się mechanizmy powitalne, pozostawiając czystszy hook `chpwd`.
5.  **Bash-to-Zsh:** Dodano `exec zsh` do pliku `.bashrc`, aby zapewnić automatyczne przejście do preferowanej powłoki Zsh.
6.  **Bezpieczeństwo:** `GITHUB_TOKEN` został zamaskowany w publicznym repozytorium.

---

**Podsumowanie:**
Masz teraz jedną, spójną i zoptymalizowaną wersję konfiguracji, która rozwiązuje wcześniej zidentyfikowane problemy techniczne i wydajnościowe.
