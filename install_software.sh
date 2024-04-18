#!/usr/bin/env bash

# Functions to install software
install_software() {
	local name=$1
	local install_type=$2
	local install_cmd=$3

	if [[ $install_type == "yes" ]]; then
		echo "Installing $name..."
		eval $install_cmd
	else
		echo "Skipping $name installation."
	fi
}

install_catppuccin_zsh() {
	curl -LO "https://raw.githubusercontent.com/catppuccin/zsh-syntax-highlighting/main/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh"
	mv catppuccin_mocha-zsh-syntax-highlighting.zsh $HOME/.oh-my-zsh/custom/
}

install_neovim() {
	curl -LO "https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
	chmod u+x nvim.appimage
	./nvim.appimage --appimage-extract
	mv squashfs-root $HOME/nvim
	ln -s $HOME/nvim/AppRun $HOME/bin/nv
}

install_lazygit() {
	LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
	curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
	tar xf lazygit.tar.gz lazygit
	install lazygit $HOME/bin
	rm -r lazygit lazygit.tar.gz
}

install_gdu() {
	curl -L "https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz" | tar xz
	chmod +x gdu_linux_amd64
	mv gdu_linux_amd64 $HOME/bin/gdu
}

install_software "Homebrew" $INSTALL_HOMEBREW "/bin/bash -c $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
install_software "Nala" $INSTALL_NALA "sudo apt install nala"

PKGMGR="sudo apt"
if command -v brew &>/dev/null; then
	PKGMGR="brew"
fi
if command -v nala &>/dev/null; then
	PKGMGR="sudo nala"
fi

PATH=$HOME/bin:$PATH

install_software "zsh" $INSTALL_ZSH "$PKGMGR install zsh"
install_software "oh-my-zsh" $INSTALL_OHMYZSH "sh -c $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
install_software "Catppuccin zsh-syntax-highlighting" $INSTALL_CATPPUCCIN_ZSH "install_catppuccin_zsh"
install_software "tmux" $INSTALL_TMUX "$PKGMGR install tmux"
install_software "tmux plugin manager (tpm)" $INSTALL_TPM "git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm"
install_software "starship" $INSTALL_STARSHIP "mkdir -p $HOME/bin && curl -sS https://starship.rs/install.sh | sh -s -- -b $HOME/bin"
install_software "NeoVim" $INSTALL_NVIM "install_neovim"
install_software "Cargo" $INSTALL_CARGO "curl https://sh.rustup.rs -sSf | sh && source $HOME/.cargo/env"
install_software "Node.js" $INSTALL_NODE "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && nvm install node"
install_software "TLDR" $INSTALL_TLDR "npm install -g tldr"
install_software "LazyGit" $INSTALL_LAZYGIT "install_lazygit"
install_software "GDU" $INSTALL_GDU "install_gdu"
install_software "Bottom" $INSTALL_BOTTOM "cargo install bottom"
install_software "RipGrep" $INSTALL_RG "cargo install ripgrep"
install_software "TreeSitter" $INSTALL_TS "cargo install tree-sitter-cli"

echo ""
echo "========================================================="
echo "All requested software installations have been completed."
echo "========================================================="
