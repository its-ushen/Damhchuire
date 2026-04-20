#!/usr/bin/env bash
#
# Damhchuire macOS bootstrap.
#
# Idempotent: safe to re-run. Each phase checks whether work is already done
# and skips if so. Does not mutate shell rc files — prints any PATH/eval lines
# you need to add yourself.
#
# Usage:
#   bash script/setup-macos.sh           # install + configure
#   bash script/setup-macos.sh --verify  # also run cargo check on examples

set -euo pipefail

# ---------- config ----------
RUBY_VERSION="3.4.4"
ANCHOR_VERSION="0.32.1"
NODE_FORMULA="node@22"

# ---------- pretty output ----------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_DIM='\033[2m'; C_BLUE='\033[34m'
  C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_RED='\033[31m'
else
  C_RESET=''; C_DIM=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi
phase() { printf "\n${C_BLUE}==>${C_RESET} ${1}\n"; }
info()  { printf "    ${1}\n"; }
ok()    { printf "    ${C_GREEN}✓${C_RESET} ${1}\n"; }
warn()  { printf "    ${C_YELLOW}!${C_RESET} ${1}\n"; }
die()   { printf "${C_RED}✗ ${1}${C_RESET}\n" >&2; exit 1; }
need_path_hint() { printf "    ${C_DIM}add to your shell rc:${C_RESET} ${1}\n"; }

# ---------- preflight ----------
[[ "$(uname -s)" == "Darwin" ]] || die "this script is macOS-only"
[[ "$EUID" -ne 0 ]] || die "do not run as root; this script uses your user account"

VERIFY=0
for arg in "$@"; do
  case "$arg" in
    --verify) VERIFY=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $arg" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

# ---------- phase 0: xcode CLI tools ----------
phase "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  ok "already installed ($(xcode-select -p))"
else
  info "launching installer (a GUI dialog will appear)..."
  xcode-select --install || true
  die "re-run this script after the Xcode CLI install dialog finishes"
fi

# ---------- phase 1: homebrew ----------
phase "Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "$(brew --version | head -1)"
  brew_actual="$(brew --prefix)"
  if [[ "$brew_actual" != "$BREW_PREFIX" ]]; then
    die "arch mismatch: detected $ARCH but brew is at $brew_actual (expected $BREW_PREFIX). Reinstall Homebrew for the native arch."
  fi
else
  info "installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
  need_path_hint "eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
fi
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"

# ---------- phase 2: system libs ----------
phase "System libraries (libvips, pkg-config, openssl@3)"
for pkg in libvips pkg-config openssl@3; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    ok "$pkg already installed"
  else
    info "brew install $pkg"
    brew install "$pkg"
  fi
done

# ---------- phase 3: ruby via rbenv ----------
phase "Ruby ${RUBY_VERSION} via rbenv"
for pkg in rbenv ruby-build; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    ok "$pkg already installed"
  else
    info "brew install $pkg"
    brew install "$pkg"
  fi
done
eval "$(rbenv init - bash)"
if rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
  ok "ruby $RUBY_VERSION already installed"
else
  info "rbenv install $RUBY_VERSION (this can take several minutes)..."
  rbenv install -s "$RUBY_VERSION"
fi
if ! grep -q 'rbenv init' "${HOME}/.zshrc" 2>/dev/null \
   && ! grep -q 'rbenv init' "${HOME}/.bashrc" 2>/dev/null \
   && ! grep -q 'rbenv init' "${HOME}/.bash_profile" 2>/dev/null; then
  warn "rbenv is not initialized in your shell rc"
  need_path_hint 'eval "$(rbenv init - zsh)"   # or bash'
fi

# ---------- phase 4: rust via rustup ----------
phase "Rust toolchain (rustup)"
if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
  ok "$(rustc --version)"
else
  info "installing rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
  need_path_hint 'source "$HOME/.cargo/env"'
fi
export PATH="${HOME}/.cargo/bin:$PATH"
info "rust-toolchain.toml in da-solana/da-chain-side will pull 1.89.0 on first build"

# ---------- phase 5: node + yarn ----------
phase "Node.js + Yarn"
if brew list --formula "$NODE_FORMULA" >/dev/null 2>&1; then
  ok "$NODE_FORMULA already installed"
else
  info "brew install $NODE_FORMULA"
  brew install "$NODE_FORMULA"
fi
NODE_BIN="$BREW_PREFIX/opt/$NODE_FORMULA/bin"
if [[ ":$PATH:" != *":$NODE_BIN:"* ]]; then
  export PATH="$NODE_BIN:$PATH"
  need_path_hint "export PATH=\"$NODE_BIN:\$PATH\""
fi
if command -v corepack >/dev/null 2>&1; then
  corepack enable >/dev/null 2>&1 || true
  corepack prepare yarn@stable --activate >/dev/null 2>&1 || true
  ok "yarn ready ($(yarn --version 2>/dev/null || echo 'on first use'))"
else
  warn "corepack not found; yarn will not be available"
fi

# ---------- phase 6: solana CLI (anza) ----------
phase "Solana CLI (Anza)"
if command -v solana >/dev/null 2>&1; then
  ok "$(solana --version)"
else
  info "installing Solana CLI from release.anza.xyz..."
  sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
  # The Anza installer writes its PATH export into ~/.profile and ~/.zprofile
  # itself — only print a hint if neither file references it.
  solana_path_str='solana/install/active_release/bin'
  if ! grep -q "$solana_path_str" "${HOME}/.profile" 2>/dev/null \
     && ! grep -q "$solana_path_str" "${HOME}/.zprofile" 2>/dev/null; then
    need_path_hint 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
  else
    ok "PATH export already in ~/.profile or ~/.zprofile (added by installer)"
  fi
fi
export PATH="${HOME}/.local/share/solana/install/active_release/bin:$PATH"

# ---------- phase 7: anchor via AVM ----------
phase "Anchor ${ANCHOR_VERSION} via AVM"
if command -v avm >/dev/null 2>&1; then
  ok "avm present ($(avm --version 2>&1 | head -1))"
else
  info "cargo install avm (this may take a few minutes)..."
  cargo install --git https://github.com/coral-xyz/anchor avm --force
fi
if avm list 2>/dev/null | grep -qE "^${ANCHOR_VERSION}( |$)"; then
  ok "anchor $ANCHOR_VERSION installed"
else
  info "avm install $ANCHOR_VERSION..."
  avm install "$ANCHOR_VERSION"
fi
avm use "$ANCHOR_VERSION" >/dev/null
ok "anchor active: $(anchor --version)"

# ---------- phase 8: solana dev keypair ----------
phase "Solana dev keypair + cluster config"
SOLANA_KEYPAIR="${HOME}/.config/solana/id.json"
if [[ -f "$SOLANA_KEYPAIR" ]]; then
  ok "keypair exists at $SOLANA_KEYPAIR"
else
  info "generating new dev keypair (no BIP39 passphrase)..."
  solana-keygen new --no-bip39-passphrase --silent --outfile "$SOLANA_KEYPAIR"
fi
solana config set --url localhost --keypair "$SOLANA_KEYPAIR" >/dev/null
ok "cluster set to localhost"

# ---------- phase 9: backend bundle + DB ----------
phase "Backend: bundle install + db:prepare"
pushd "$REPO_ROOT/da-backend" >/dev/null
if [[ ! -f .ruby-version ]] || [[ "$(cat .ruby-version)" != "$RUBY_VERSION" ]]; then
  warn ".ruby-version mismatch; expected $RUBY_VERSION"
fi
rbenv shell "$RUBY_VERSION"
if ! gem list -i bundler >/dev/null 2>&1; then
  info "installing bundler..."
  gem install bundler --no-document
fi
info "running da-backend/bin/setup --skip-server..."
bin/setup --skip-server
ok "backend ready"
popd >/dev/null

# ---------- phase 10: seed action library ----------
phase "Backend: seed action library"
pushd "$REPO_ROOT/da-backend" >/dev/null
rbenv shell "$RUBY_VERSION"
bin/rails action_oracle:install_library
ok "library installed"
popd >/dev/null

# ---------- phase 11: example contract deps ----------
phase "Example contracts: yarn install"
pushd "$REPO_ROOT/example-anchor-contract" >/dev/null
if [[ -d node_modules ]]; then
  ok "node_modules present (run 'yarn install' manually to refresh)"
else
  yarn install
  # Recent yarn auto-migrates package.json (sorts keys, etc.) on first run.
  # Surface the diff so the user knows to commit (or revert) it.
  if ! git diff --quiet -- package.json yarn.lock 2>/dev/null \
     || [[ -n "$(git status --porcelain -- .yarnrc.yml 2>/dev/null)" ]]; then
    warn "yarn modified package.json / yarn.lock / .yarnrc.yml — review with 'git diff' and commit if intended"
  fi
fi
popd >/dev/null

# ---------- phase 12: optional verify ----------
if [[ "$VERIFY" -eq 1 ]]; then
  phase "Verify: cargo check on example workspace"
  pushd "$REPO_ROOT/example-anchor-contract" >/dev/null
  cargo check -p minimal-action-client
  cargo check -p action-signal-client
  ok "cargo check passed"
  popd >/dev/null
fi

# ---------- done ----------
printf "\n${C_GREEN}==> Setup complete.${C_RESET}\n\n"
cat <<EOF
Next steps:

  # 1. Start the backend
  cd da-backend && bin/rails server

  # 2. (in another terminal) Generate the Rust SDK from the running backend
  cd da-sdk && ./bin/generate_rust_sdk.rb \\
    --catalog-url http://127.0.0.1:3000/sdk/catalog.json \\
    --output ./rust/src/generated/actions.rs

  # 3. Build the on-chain Anchor program (first build is slow)
  cd da-solana/da-chain-side && anchor build

  # 4. Sanity-check the example contracts
  cd example-anchor-contract && cargo check -p minimal-action-client

If any "add to your shell rc" hints appeared above, add them to ~/.zshrc
(or ~/.bashrc) and open a new shell before continuing.
EOF
