# Developer Environment

Dotfiles and an installer to set up and keep up to date a terminal development environment on Arch
Linux, macOS and Linux servers without root rights.

## Usage

```sh
git clone https://github.com/SimBe195/DeveloperEnvironment.git ~/DeveloperEnvironment
~/DeveloperEnvironment/install.sh
```

`install.sh` checks every tool and config and asks only about what is missing, outdated or installed
differently than this platform's default. It then runs the accepted actions; a failed action does not
stop the others and is listed at the end. Run it again any time to install updates or new configs, for
example after adding a skill.

## Platforms

| Platform | Detected by | Tools are installed with |
| --- | --- | --- |
| Arch Linux | `yay` is installed | `yay` |
| macOS | Darwin; Homebrew is offered if missing | `brew` |
| Any other Linux, or no package manager | fallback | user-local: release binaries in `~/bin`, `cargo install`, official install scripts |

Tools installed by the package manager are not checked for updates; use `yay -Syu` or `brew upgrade`.
Without a package manager, zsh and tmux cannot be installed and are only reported if missing. Tools
found outside `$HOME` that the package manager did not install (e.g. installed by an admin) are left
alone. A tool found in `$HOME` on a platform with a package manager is offered for replacement by the
package.

Some tools use their own installer and updater on every platform: rustup, nvm and Node.js, Codex (npm),
Claude Code, juliaup, and the git checkouts of oh-my-zsh, its plugins and tpm. With a package manager,
uv comes from it; otherwise from its standalone installer.

Neovim is called as `nv`, a link in `~/bin` to the package manager's `nvim` or to a release in `~/nvim`.

## Tools

zsh, oh-my-zsh with zsh-autosuggestions, zsh-syntax-highlighting and its catppuccin theme, tmux and
tpm, starship, Neovim, rustup and cargo, lazygit, gdu, fzf, bat, fd, ripgrep, bottom, tree-sitter CLI,
tlrc (`tldr`), dstask, uv, juliaup, nvm and Node.js, Codex and Claude Code.

## Configs

Configs are symlinked from `config_files`, so changes made on any machine land in this repository.
Files a link would replace are moved to `~/.dotfiles-backup/<timestamp>/`. A config is only offered
when its tool is installed.

| Config | Linked to |
| --- | --- |
| `zshrc` (loads `aliases.zsh` from next to itself) | `~/.zshrc` |
| `tmux.conf` | `~/.tmux.conf` |
| `starship.toml` | `~/.config/starship.toml` |
| `kitty/` | `~/.config/kitty/`, if kitty is installed |
| `skills/` | `~/.agents/skills` (Codex) and one link per skill in `~/.claude/skills` (Claude Code, which keeps skills synced from claude.ai in the same folder) |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` |

The Neovim config is cloned from [SimBe195/nvim_config](https://github.com/SimBe195/nvim_config) to
`~/.config/nvim`.

To make zsh the login shell, run `chsh -s "$(command -v zsh)"`.

## Tests

`tests/container_test.sh` runs `install.sh` in an Ubuntu container as a user without root rights and
checks that it installs everything, asks nothing on a second run, and offers an outdated tool. It needs
docker and network access.
