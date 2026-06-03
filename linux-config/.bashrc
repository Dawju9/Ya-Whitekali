# --- .bashrc ---
# Use zsh for best experience
if [ -z "$ZSH_VERSION" ] && [ -x /usr/bin/zsh ]; then
    exec zsh
fi

# Cargo
. "$HOME/.cargo/env" 2>/dev/null

# If running in zsh, source .zshrc
if [ -n "$ZSH_VERSION" ]; then
    source "$HOME/.zshrc"
fi

# CityX project venv (bash-only; zsh ma to w commands.sh)
alias venccity="source /Development/projekt/cityx/venv/bin/activate && export CARGO_HOME=/Development/projekt/cityx/.cargo && export RUSTUP_HOME=/Development/projekt/cityx/.rustup"
alias auto-commit='git commit -m "$(gh commit)" || git commit -a -m "$(gh commit)" && git log HEAD...HEAD~1'
