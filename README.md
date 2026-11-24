# Developer Environment

Contains dotfiles, git submodules and installation procedures to easily transfer and synchronize terminal development environments between different systems.

Includes:
 - zsh config + oh-my-zsh installation
 - tmux config + tpm installation
 - starship prompt installation and config
 - Basic aliases with option for per-system additions
 - nala installation as apt replacement
 - Neovim installation and config
 - Node.js installation
 - cargo installation
 - tree-sitter cli installation
 - ripgrep installation
 - Lazygit installation
 - gdu diskusage installation
 - Claude Code and Codex config: skills (`config_files/skills`, linked to `~/.agents/skills` and per skill into `~/.claude/skills`) and global instructions (`config_files/CLAUDE.md`, linked to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`). After adding a skill, run `INSTALL_AGENT_CONFIG=yes ./install_configs.sh` so Claude Code picks it up.

Each step is optional and the installations can either be done locally (if not sudo rights are available) or system-wide.
