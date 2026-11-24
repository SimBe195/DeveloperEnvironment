# Tool definitions for install.sh.
#
# Each plan_* function checks one tool and offers only what is possible: installing it when missing,
# updating it when a newer stable release exists, or migrating it to the platform's install method.
# Tools installed through yay or brew are not checked for updates; that is left to the package
# manager. Tools installed outside $HOME by someone else are left alone.
#
# The install_* and update functions run as actions, after all questions are answered.

NVM_DIR=$HOME/.nvm

# nvm_run COMMAND [ARGS...]: runs COMMAND with nvm and the default Node version loaded.
nvm_run() {
	bash -c '. "$0/nvm.sh" && nvm use --silent default >/dev/null 2>&1; "$@"' "$NVM_DIR" "$@"
}

nvm_cmd() {
	bash -c '. "$0/nvm.sh" && nvm "$@"' "$NVM_DIR" "$@"
}

# --- Package manager tools, installed user-locally where there is none -----------------------------

# plan_standard KEY COMMAND ARCH_PKG BREW_PKG LOCAL_PLAN...: uses the package (ARCH_PKG or BREW_PKG,
# "-" for none) when the platform has a package manager, and LOCAL_PLAN otherwise.
plan_standard() {
	local key=$1 cmd=$2 pkg=-
	case $PLATFORM in
	arch) pkg=$3 ;;
	macos) pkg=$4 ;;
	esac
	shift 4
	if [[ $pkg == - ]]; then
		"$@"
	else
		plan_package "$key" "$cmd" "$pkg"
	fi
}

plan_package() {
	local key=$1 cmd=$2 pkg=$3 path owner
	path=$(command -v "$cmd") || {
		offer "$key" "Install $key ($PM package $pkg)?" pm_install "$pkg"
		return
	}
	owner=$(pm_owner "$path")
	[[ $owner == "$pkg" ]] && return
	if [[ -n $owner ]]; then
		offer "$key" "Replace $PM package $owner with $pkg (provides $cmd)?" replace_package "$owner" "$pkg"
		return
	fi
	local crate
	crate=$(cargo_crate_of "$cmd")
	if [[ -n $crate ]]; then
		offer "$key" "Replace $path (cargo crate $crate) with $PM package $pkg?" \
			replace_with_package "cargo uninstall $crate" "$pkg"
	elif in_home "$path"; then
		local remove="rm -f $path"
		[[ $key == nvim ]] && remove="$remove && rm -rf $HOME/nvim"
		offer "$key" "Replace $path with $PM package $pkg?" replace_with_package "$remove" "$pkg"
	else
		note "$cmd at $path is not managed by $PM; leaving it alone"
	fi
}

replace_package() {
	pm_remove "$1"
	pm_install "$2"
}

replace_with_package() {
	pm_install "$2"
	eval "$1"
}

# --- User-local installs --------------------------------------------------------------------------

# plan_release KEY COMMAND REPO [VERSION_ARG]: a binary from the GitHub releases of REPO, installed by
# install_KEY VERSION.
plan_release() {
	local key=$1 cmd=$2 repo=$3 version_arg=${4:---version} path latest installed
	path=$(command -v "$cmd")
	if [[ -n $path ]] && ! in_home "$path"; then
		return
	fi
	latest=$(latest_github "$repo") || return 0
	if [[ -z $path ]]; then
		offer "$key" "Install $key $latest?" "install_$key" "$latest"
		return
	fi
	installed=$(version_of "$cmd" "$version_arg")
	if [[ -z $installed ]] || version_lt "$installed" "$latest"; then
		offer "$key" "Update $key ${installed:-?} -> $latest?" "install_$key" "$latest"
	fi
}

# cargo_crate_of COMMAND: the cargo-installed crate providing COMMAND, if any.
cargo_crate_of() {
	command -v cargo >/dev/null || return 0
	cargo install --list 2>/dev/null | awk -v cmd="$1" '
		/^[^ ]/ { crate = $1 }
		/^    / && $1 == cmd { print crate; exit }'
}

# plan_cargo KEY COMMAND CRATE: installed with cargo install.
plan_cargo() {
	local key=$1 cmd=$2 crate=$3 path installed latest
	path=$(command -v "$cmd")
	if [[ -n $path ]] && [[ -z $(cargo_crate_of "$cmd") ]]; then
		in_home "$path" && note "$cmd at $path was not installed with cargo; leaving it alone"
		return
	fi
	if ! available rustup cargo; then
		note "$key needs cargo; install rustup to get it"
		return
	fi
	latest=$(latest_crate "$crate") || return 0
	if [[ -z $path ]]; then
		offer "$key" "Install $key $latest (cargo, builds from source)?" cargo install --locked "$crate"
		return
	fi
	installed=$(cargo install --list | awk -v c="$crate" '$1 == c { sub(/^v/, "", $2); sub(/:$/, "", $2); print $2 }')
	if version_lt "$installed" "$latest"; then
		offer "$key" "Update $key $installed -> $latest (cargo, builds from source)?" cargo install --locked "$crate"
	fi
}

plan_not_local() {
	command -v "$2" >/dev/null ||
		note "$1 is not installed and installing it needs root rights; ask an admin to install it"
}

# install_tarball_binary URL BINARY_IN_ARCHIVE NAME: installs one binary from a tarball as ~/bin/NAME.
install_tarball_binary() {
	download "$1" archive
	tar xzf archive
	mkdir -p "$HOME/bin"
	install -m 755 "$2" "$HOME/bin/$3"
}

install_nvim() {
	local os=linux
	[[ $OS == darwin ]] && os=macos
	download "https://github.com/neovim/neovim/releases/download/v$1/nvim-$os-$ARCH.tar.gz" nvim.tar.gz
	tar xzf nvim.tar.gz
	rm -rf "$HOME/nvim"
	mv "nvim-$os-$ARCH" "$HOME/nvim"
	mkdir -p "$HOME/bin"
	ln -sfn "$HOME/nvim/bin/nvim" "$HOME/bin/nv"
}

install_lazygit() {
	install_tarball_binary \
		"https://github.com/jesseduffield/lazygit/releases/download/v$1/lazygit_$1_${OS}_$ARCH.tar.gz" \
		lazygit lazygit
}

install_gdu() {
	install_tarball_binary "https://github.com/dundee/gdu/releases/download/v$1/gdu_${OS}_$GOARCH.tgz" \
		"gdu_${OS}_$GOARCH" gdu
}

install_fzf() {
	install_tarball_binary "https://github.com/junegunn/fzf/releases/download/v$1/fzf-$1-${OS}_$GOARCH.tar.gz" \
		fzf fzf
}

install_starship() {
	install_tarball_binary \
		"https://github.com/starship/starship/releases/download/v$1/starship-$RUST_TRIPLE.tar.gz" \
		starship starship
}

install_tlrc() {
	install_tarball_binary \
		"https://github.com/tldr-pages/tlrc/releases/download/v$1/tlrc-v$1-$RUST_TRIPLE.tar.gz" tldr tldr
}

install_dstask() {
	download "https://github.com/naggie/dstask/releases/download/v$1/dstask-$OS-$GOARCH" dstask
	mkdir -p "$HOME/bin"
	install -m 755 dstask "$HOME/bin/dstask"
}

# tlrc provides the tldr command. An older tldr client from npm is replaced.
plan_tlrc_local() {
	local path
	path=$(command -v tldr)
	if [[ -n $path ]] && [[ $path == "$NVM_DIR"/* ]]; then
		local latest
		latest=$(latest_github tldr-pages/tlrc) || return 0
		offer tlrc "Replace the npm tldr client with tlrc $latest?" replace_npm_tldr "$latest"
		return
	fi
	plan_release tlrc tldr tldr-pages/tlrc
}

replace_npm_tldr() {
	nvm_run npm uninstall -g tldr
	install_tlrc "$1"
}

# --- Neovim ---------------------------------------------------------------------------------------

# Neovim is called as nv (~/bin/nv), which points to the package manager's nvim or to ~/nvim.
plan_nvim() {
	if [[ $PLATFORM == local ]]; then
		plan_release nvim nv neovim/neovim
		return
	fi
	plan_standard nvim nvim neovim neovim :
	available nvim nvim || return 0
	local target current
	target=$(command -v nvim) || target=$(nvim_package_path)
	current=$(readlink "$HOME/bin/nv")
	[[ $current == "$target" ]] && return
	if [[ -z $current ]] && [[ -e $HOME/bin/nv ]]; then
		note "$HOME/bin/nv is not a symlink; leaving it alone"
	elif [[ $current == "$HOME"/nvim/* ]]; then
		offer nv "Point ~/bin/nv to $target and delete the old Neovim in ~/nvim?" link_nv "$target" "$HOME/nvim"
	elif [[ $current != "$target" ]]; then
		offer nv "Point ~/bin/nv to $target?" link_nv "$target"
	fi
}

nvim_package_path() {
	case $PM in
	yay) echo /usr/bin/nvim ;;
	brew) echo "$(brew --prefix)/bin/nvim" ;;
	esac
}

link_nv() {
	mkdir -p "$HOME/bin"
	ln -sfn "$1" "$HOME/bin/nv"
	if [[ -n ${2:-} ]]; then
		rm -rf "$2"
	fi
}

# --- Tools with their own installer and updater ---------------------------------------------------

# plan_git KEY DIR URL [REQUIRES_KEY REQUIRES]: a git checkout, updated by pulling. Only offered if
# REQUIRES (a path or command) exists or REQUIRES_KEY is planned.
plan_git() {
	local key=$1 dir=$2 url=$3 behind
	if [[ ! -d $dir ]]; then
		if [[ -n ${4:-} ]] && [[ ! -e $5 ]] && ! available "$4" "$5"; then
			return
		fi
		offer "$key" "Install $key?" git clone -q --depth 1 "$url" "$dir"
		return
	fi
	behind=$(git_behind "$dir") || {
		warn "could not check $dir for updates"
		return 0
	}
	if ((behind > 0)); then
		offer "$key" "Update $key ($behind new commits)?" git -C "$dir" pull -q --ff-only
	fi
}

plan_catppuccin_zsh() {
	local file=$HOME/.oh-my-zsh/custom/catppuccin_mocha-zsh-syntax-highlighting.zsh
	[[ -f $file ]] && return
	[[ -d $HOME/.oh-my-zsh ]] || planned oh-my-zsh || return 0
	offer catppuccin-zsh "Install catppuccin theme for zsh-syntax-highlighting?" download \
		https://raw.githubusercontent.com/catppuccin/zsh-syntax-highlighting/main/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh \
		"$file"
}

plan_rustup() {
	local path
	path=$(command -v rustup)
	if [[ -z $path ]]; then
		offer rustup "Install rustup and cargo?" install_rustup
	elif in_home "$path" && [[ $(rustup check 2>/dev/null) == *"Update available"* ]]; then
		offer rustup "Update Rust toolchain and rustup (rustup update)?" rustup update
	fi
}

install_rustup() {
	curl --proto '=https' -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
}

plan_nvm() {
	local latest installed
	latest=$(latest_github nvm-sh/nvm) || return 0
	if [[ ! -s $NVM_DIR/nvm.sh ]]; then
		offer nvm "Install nvm $latest?" install_nvm "$latest"
		return
	fi
	installed=$(nvm_cmd --version)
	if version_lt "$installed" "$latest"; then
		offer nvm "Update nvm $installed -> $latest?" install_nvm "$latest"
	fi
}

# The nvm installer updates an existing installation in place. PROFILE=/dev/null keeps it from
# editing shell startup files; zshrc loads nvm itself.
install_nvm() {
	curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v$1/install.sh" | PROFILE=/dev/null bash
}

plan_node() {
	local installed latest
	if [[ ! -s $NVM_DIR/nvm.sh ]]; then
		planned nvm && offer node "Install the latest Node.js?" install_node latest
		return 0
	fi
	installed=$(nvm_cmd version default)
	latest=$(latest_node)
	if [[ -z $latest ]]; then
		warn "could not look up the latest Node.js version"
		return 0
	fi
	if [[ $installed == N/A ]]; then
		offer node "Install Node.js $latest?" install_node "$latest"
	elif version_lt "${installed#v}" "${latest#v}"; then
		offer node "Update the default Node.js $installed -> $latest (global npm packages are reinstalled)?" \
			update_node "$latest"
	fi
}

# Newest Node.js release that is not a pre-release.
latest_node() {
	nvm_cmd ls-remote --no-colors | awk '$1 ~ /^v[0-9.]+$/ { v = $1 } END { print v }'
}

# install_node VERSION|latest
install_node() {
	if [[ $1 == latest ]]; then
		set -- "$(latest_node)"
		[[ -n $1 ]]
	fi
	nvm_cmd install "$1"
	nvm_cmd alias default "$1"
}

update_node() {
	nvm_cmd install "$1" --reinstall-packages-from=default
	nvm_cmd alias default "$1"
}

plan_codex() {
	local path installed latest
	path=$(nvm_run command -v codex 2>/dev/null) || path=$(command -v codex)
	if [[ -n $path ]] && [[ $path != "$NVM_DIR"/* ]]; then
		return
	fi
	if [[ -z $path ]] && [[ ! -s $NVM_DIR/nvm.sh ]] && ! planned node; then
		note "Codex needs Node.js; install nvm and Node.js to get it"
		return
	fi
	latest=$(latest_npm @openai/codex) || return 0
	if [[ -z $path ]]; then
		offer codex "Install Codex $latest (npm)?" nvm_run npm install -g @openai/codex
		return
	fi
	installed=$(version_of nvm_run codex --version)
	if version_lt "$installed" "$latest"; then
		offer codex "Update Codex $installed -> $latest?" nvm_run npm install -g @openai/codex@latest
	fi
}

plan_claude() {
	local path installed latest
	path=$(command -v claude)
	if [[ -n $path ]] && ! in_home "$path"; then
		return
	fi
	latest=$(curl -fsSL https://downloads.claude.ai/claude-code-releases/latest) || {
		warn "could not look up the latest Claude Code version"
		return 0
	}
	if [[ -z $path ]]; then
		offer claude "Install Claude Code $latest?" install_claude
		return
	fi
	installed=$(version_of claude --version)
	if version_lt "$installed" "$latest"; then
		offer claude "Update Claude Code $installed -> $latest?" claude update
	fi
}

install_claude() {
	curl -fsSL https://claude.ai/install.sh | bash
}

# User-local uv, managed by its standalone installer.
plan_uv_local() {
	local path installed latest
	path=$(command -v uv)
	if [[ -n $path ]] && ! in_home "$path"; then
		return
	fi
	latest=$(latest_github astral-sh/uv) || return 0
	if [[ -z $path ]]; then
		offer uv "Install uv $latest?" install_uv
		return
	fi
	installed=$(version_of uv --version)
	if version_lt "$installed" "$latest"; then
		offer uv "Update uv $installed -> $latest?" uv self update
	fi
}

install_uv() {
	curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
}

plan_juliaup() {
	local path installed latest
	path=$(command -v juliaup)
	if [[ -n $path ]] && [[ $path != "$HOME"/.juliaup/* ]]; then
		return
	fi
	latest=$(latest_github JuliaLang/juliaup) || return 0
	if [[ -z $path ]]; then
		offer juliaup "Install juliaup $latest?" install_juliaup
		return
	fi
	installed=$(version_of juliaup --version)
	if version_lt "$installed" "$latest"; then
		offer juliaup "Update juliaup $installed -> $latest?" juliaup self update
	fi
}

# --add-to-path=no keeps the installer from editing shell startup files; zshrc adds juliaup to PATH.
install_juliaup() {
	curl -fsSL https://install.julialang.org | sh -s -- --yes --add-to-path=no
}

# --- All tools, in installation order -------------------------------------------------------------

plan_tools() {
	local omz=$HOME/.oh-my-zsh
	plan_standard zsh zsh zsh zsh plan_not_local zsh zsh
	plan_git oh-my-zsh "$omz" https://github.com/ohmyzsh/ohmyzsh.git
	plan_git zsh-autosuggestions "$omz/custom/plugins/zsh-autosuggestions" \
		https://github.com/zsh-users/zsh-autosuggestions.git oh-my-zsh "$omz"
	plan_git zsh-syntax-highlighting "$omz/custom/plugins/zsh-syntax-highlighting" \
		https://github.com/zsh-users/zsh-syntax-highlighting.git oh-my-zsh "$omz"
	plan_catppuccin_zsh
	plan_standard tmux tmux tmux tmux plan_not_local tmux tmux
	plan_git tpm "$HOME/.tmux/plugins/tpm" https://github.com/tmux-plugins/tpm tmux tmux
	plan_standard starship starship starship starship plan_release starship starship starship/starship
	plan_rustup
	plan_nvim
	plan_standard lazygit lazygit lazygit lazygit plan_release lazygit lazygit jesseduffield/lazygit
	plan_standard gdu gdu gdu gdu plan_release gdu gdu dundee/gdu
	plan_standard fzf fzf fzf fzf plan_release fzf fzf junegunn/fzf
	plan_standard bat bat bat bat plan_cargo bat bat bat
	plan_standard fd fd fd fd plan_cargo fd fd fd-find
	plan_standard ripgrep rg ripgrep ripgrep plan_cargo ripgrep rg ripgrep
	plan_standard bottom btm bottom bottom plan_cargo bottom btm bottom
	plan_standard tree-sitter tree-sitter tree-sitter-cli tree-sitter-cli \
		plan_cargo tree-sitter tree-sitter tree-sitter-cli
	plan_standard tlrc tldr tlrc tlrc plan_tlrc_local
	plan_standard dstask dstask dstask dstask plan_release dstask dstask naggie/dstask version
	plan_standard uv uv uv uv plan_uv_local
	plan_juliaup
	plan_nvm
	plan_node
	plan_codex
	plan_claude
}
