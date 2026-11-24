# shellcheck shell=bash
# Helpers shared by install.sh. Kept compatible with bash 3.2, the version macOS ships.

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

warn() {
	printf 'warning: %s\n' "$*" >&2
}

# Something the user has to handle themselves; listed, not asked.
note() {
	printf 'note: %s\n' "$*"
}

# ask QUESTION: returns 0 for yes. Fails loudly when there is no answer to read, so a run that is
# expected to have nothing to ask (stdin closed) cannot silently skip a question.
ask() {
	local answer
	printf '%s [y/N] ' "$1"
	read -r answer || {
		echo
		die "no answer to \"$1\" (stdin closed)"
	}
	[[ $answer == [yY]* ]]
}

# Accepted actions, run in order after all questions are answered.
ACTION_DESCS=()
ACTION_CMDS=()
PLANNED=" "

# offer KEY QUESTION COMMAND [ARGS...]: asks QUESTION and, if accepted, schedules COMMAND and marks
# KEY as planned, so later offers can depend on it.
offer() {
	local key=$1 question=$2 cmd
	shift 2
	ask "$question" || return 0
	printf -v cmd '%q ' "$@"
	ACTION_DESCS+=("$question")
	ACTION_CMDS+=("$cmd")
	PLANNED="$PLANNED$key "
}

planned() {
	[[ $PLANNED == *" $1 "* ]]
}

# available KEY CMD: CMD is installed or KEY is scheduled for installation.
available() {
	command -v "$2" >/dev/null || planned "$1"
}

# Runs every accepted action in its own subshell and temporary directory, so a failure stops only
# that action. Returns 1 if any action failed.
run_actions() {
	local i tmp failures=()
	for i in "${!ACTION_CMDS[@]}"; do
		printf '\n==> %s\n' "${ACTION_DESCS[i]}"
		tmp=$(mktemp -d)
		# Not "if ! ( ... )": in a condition, set -e has no effect inside the subshell.
		(
			set -e
			cd "$tmp"
			eval "${ACTION_CMDS[i]}"
		)
		# shellcheck disable=SC2181
		if [[ $? -ne 0 ]]; then
			failures+=("${ACTION_DESCS[i]}")
		fi
		rm -rf "$tmp"
	done
	if [[ ${#failures[@]} -gt 0 ]]; then
		printf '\nFailed:\n'
		printf '  %s\n' "${failures[@]}"
		return 1
	fi
	printf '\nDone.\n'
}

# Platform: PLATFORM is arch, macos or local (user-local installs without root). PM is the package
# manager used for PLATFORM, empty for local.
# shellcheck disable=SC2034 # the variables set here are used in tools.sh and configs.sh
detect_platform() {
	case "$(uname -s)" in
	Darwin) OS=darwin ;;
	Linux) OS=linux ;;
	*) die "unsupported OS $(uname -s)" ;;
	esac
	case "$(uname -m)" in
	x86_64 | amd64) ARCH=x86_64 GOARCH=amd64 RUSTARCH=x86_64 ;;
	arm64 | aarch64) ARCH=arm64 GOARCH=arm64 RUSTARCH=aarch64 ;;
	*) die "unsupported CPU architecture $(uname -m)" ;;
	esac
	if [[ $OS == linux ]]; then
		RUST_TRIPLE=$RUSTARCH-unknown-linux-musl
	else
		RUST_TRIPLE=$RUSTARCH-apple-darwin
	fi

	PLATFORM=local PM=
	if [[ $OS == darwin ]]; then
		if ! command -v brew >/dev/null && ask "Homebrew is not installed. Install it (otherwise tools are installed user-locally)?"; then
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
				die "Homebrew installation failed"
			eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
		fi
		command -v brew >/dev/null && PLATFORM=macos PM=brew
	elif command -v yay >/dev/null; then
		PLATFORM=arch PM=yay
	elif command -v pacman >/dev/null; then
		note "Arch Linux without yay: installing tools user-locally. Install yay to use packages instead."
	fi
}

pm_install() {
	case $PM in
	yay) yay -S --needed --noconfirm "$@" ;;
	brew) brew install "$@" ;;
	*) die "no package manager" ;;
	esac
}

pm_remove() {
	case $PM in
	yay) yay -R --noconfirm "$@" ;;
	brew) brew uninstall "$@" ;;
	*) die "no package manager" ;;
	esac
}

# pm_owner PATH: prints the package that installed PATH, nothing if no package did.
pm_owner() {
	local real
	real=$(realpath "$1") || return 0
	case $PM in
	yay) pacman -Qoq "$real" 2>/dev/null || true ;;
	brew)
		if [[ $real == "$(brew --prefix)"/Cellar/* ]]; then
			real=${real#"$(brew --prefix)"/Cellar/}
			echo "${real%%/*}"
		fi
		;;
	esac
}

# in_home PATH: PATH is inside $HOME, i.e. installed by the user rather than the system.
in_home() {
	[[ $(realpath "$1") == "$HOME"/* ]]
}

# version_of COMMAND [ARGS...]: the first version number in the command's output.
version_of() {
	"$@" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1
}

# version_lt A B: version A is older than version B.
version_lt() {
	local IFS=. i x y
	local -a a b
	read -r -a a <<<"$1"
	read -r -a b <<<"$2"
	for i in 0 1 2; do
		x=${a[i]:-0} y=${b[i]:-0}
		((10#$x < 10#$y)) && return 0
		((10#$x > 10#$y)) && return 1
	done
	return 1
}

# Latest stable release of a GitHub repository, without a leading "v". Reads the redirect of the
# releases/latest page, which is not subject to the API rate limit.
latest_github() {
	local url
	url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest") &&
		[[ $url == */releases/tag/* ]] || {
		warn "could not look up the latest release of $1"
		return 1
	}
	url=${url##*/}
	echo "${url#v}"
}

# json_field NAME: the first string value of field NAME in the JSON on stdin.
json_field() {
	grep -oE "\"$1\":\"[^\"]+\"" | sed -n '1s/.*:"\(.*\)"/\1/p'
}

latest_crate() {
	local json version
	json=$(curl -fsSL -A DeveloperEnvironment-installer "https://crates.io/api/v1/crates/$1") &&
		version=$(json_field max_stable_version <<<"$json") && [[ -n $version ]] || {
		warn "could not look up the latest version of crate $1"
		return 1
	}
	echo "$version"
}

latest_npm() {
	local json version
	json=$(curl -fsSL "https://registry.npmjs.org/$1/latest") &&
		version=$(json_field version <<<"$json") && [[ -n $version ]] || {
		warn "could not look up the latest version of npm package $1"
		return 1
	}
	echo "$version"
}

download() {
	curl -fsSL -o "$2" "$1"
}

# git_behind DIR: number of upstream commits DIR is missing; fails if DIR has no upstream.
git_behind() {
	git -C "$1" fetch -q 2>/dev/null && git -C "$1" rev-list --count 'HEAD..@{u}' 2>/dev/null
}
