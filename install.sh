#!/bin/sh
# x-impl installer. POSIX sh. No network, no sudo, no runtime dependencies.
#
#   sh install.sh [--project DIR | --global]
#                 [--harness claude|codex|opencode|openclaw|all]
#                 [--copy] [--bootstrap] [--uninstall] [--dry-run]
#
# Defaults: --project "$PWD", --harness all, symlink mode. A project-scope
# install that includes OpenClaw copies into .agents/skills instead of linking,
# because OpenClaw skips symlinks that leave the workspace.

set -eu

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
MARKER='<!-- x-impl -->'

SCOPE=project
ROOT=$PWD
HARNESS=all
MODE=link
MODE_EXPLICIT=0
BOOTSTRAP=0
UNINSTALL=0
DRYRUN=0

usage() {
	cat <<EOF
x-impl installer

Usage: sh install.sh [options]

  --project DIR   install into DIR (default: current directory)
  --global        install into the per-user skill directories instead
  --harness NAME  claude | codex | opencode | openclaw | all  (default: all)
  --copy          copy the skills instead of symlinking them
                  (forced for .agents/skills in a project-scope OpenClaw
                  install, which is what --harness openclaw and --harness all
                  both are)
  --bootstrap     also install .x-impl/ and add one pointer line to an
                  existing CLAUDE.md or AGENTS.md
  --uninstall     remove what this installer created, and nothing else
  --dry-run       print what would happen, change nothing
  -h, --help      this message
EOF
}

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# run CMD... : execute, or print it under --dry-run
run() {
	if [ "$DRYRUN" -eq 1 ]; then
		printf 'would:'
		for a in "$@"; do printf ' %s' "$a"; done
		printf '\n'
	else
		"$@"
	fi
}

while [ $# -gt 0 ]; do
	case $1 in
	--project)
		[ $# -ge 2 ] || die "--project needs a directory"
		SCOPE=project
		ROOT=$2
		shift 2
		;;
	--global)
		SCOPE=global
		shift
		;;
	--harness)
		[ $# -ge 2 ] || die "--harness needs a value"
		HARNESS=$2
		shift 2
		;;
	--copy) MODE=copy; MODE_EXPLICIT=1; shift ;;
	--bootstrap) BOOTSTRAP=1; shift ;;
	--uninstall) UNINSTALL=1; shift ;;
	--dry-run) DRYRUN=1; shift ;;
	-h | --help) usage; exit 0 ;;
	*) die "unknown option: $1 (try --help)" ;;
	esac
done

case $HARNESS in
claude | codex | opencode | openclaw | all) ;;
*) die "unknown harness: $HARNESS" ;;
esac

if [ "$SCOPE" = project ]; then
	[ -d "$ROOT" ] || die "no such directory: $ROOT"
	ROOT=$(CDPATH= cd -- "$ROOT" && pwd -P)
	CLAUDE_SKILLS=$ROOT/.claude/skills
	AGENTS_SKILLS=$ROOT/.agents/skills
	BOOT_DIR=$ROOT/.x-impl
else
	[ -n "${HOME:-}" ] || die "--global needs HOME to be set"
	ROOT=$HOME
	CLAUDE_SKILLS=$HOME/.claude/skills
	AGENTS_SKILLS=$HOME/.agents/skills
	BOOT_DIR=$HOME/.x-impl
fi

# Which skill directories each harness reads. Codex, OpenCode and OpenClaw
# share .agents/skills; only Claude Code reads .claude/skills.
want_claude=0
want_agents=0
want_openclaw=0
case $HARNESS in
claude) want_claude=1 ;;
codex | opencode) want_agents=1 ;;
openclaw) want_agents=1; want_openclaw=1 ;;
all) want_claude=1; want_agents=1; want_openclaw=1 ;;
esac

# Mode per target directory. OpenClaw ignores a symlink in a project skills
# directory whose target resolves outside the workspace, so a project-scope
# install that includes OpenClaw copies into .agents/skills unless the user
# asked for a mode themselves. .claude/skills and --global are unaffected.
CLAUDE_MODE=$MODE
AGENTS_MODE=$MODE
AGENTS_FORCED_COPY=0
if [ "$want_openclaw" -eq 1 ] && [ "$SCOPE" = project ] && [ "$MODE_EXPLICIT" -eq 0 ]; then
	AGENTS_MODE=copy
	AGENTS_FORCED_COPY=1
fi

skill_dirs() {
	# prints the source skill directories, one per line
	for d in "$SRC"/skills/x-*; do
		[ -d "$d" ] || continue
		printf '%s\n' "$d"
	done
}

# --- install one skill into one target directory ---------------------------

install_skill() {
	src=$1
	destdir=$2
	name=$(basename "$src")
	dest=$destdir/$name
	refreshed=0

	if [ -e "$dest" ] || [ -L "$dest" ]; then
		if [ -L "$dest" ]; then
			current=$(readlink "$dest" 2>/dev/null || printf '')
			if [ "$MODE" = link ] && [ "$current" = "$src" ]; then
				say "ok       $dest (already linked)"
				return 0
			fi
			run rm -f "$dest"
		elif [ -d "$dest" ] && [ -f "$dest/.x-impl-copy" ]; then
			# our own copy: replace it wholesale, so a re-run picks up
			# every source change and drops files we no longer ship
			run rm -rf "$dest"
			refreshed=1
		else
			say "SKIP     $dest exists and was not created by x-impl; leaving it alone"
			return 0
		fi
	fi

	if [ "$MODE" = link ]; then
		run ln -s "$src" "$dest"
		[ "$DRYRUN" -eq 1 ] || say "linked   $dest"
	else
		run cp -R "$src" "$dest"
		if [ "$DRYRUN" -eq 0 ]; then
			printf 'created by x-impl install.sh; safe to delete\n' >"$dest/.x-impl-copy"
			if [ "$refreshed" -eq 1 ]; then
				say "refreshed $dest"
			else
				say "copied   $dest"
			fi
		fi
	fi
}

uninstall_skill() {
	destdir=$1
	name=$2
	dest=$destdir/$name

	if [ -L "$dest" ]; then
		target=$(readlink "$dest" 2>/dev/null || printf '')
		case $target in
		"$SRC"/skills/*)
			run rm -f "$dest"
			[ "$DRYRUN" -eq 1 ] || say "removed  $dest"
			;;
		*)
			say "SKIP     $dest is a symlink to something else; leaving it alone"
			;;
		esac
	elif [ -d "$dest" ] && [ -f "$dest/.x-impl-copy" ]; then
		run rm -rf "$dest"
		[ "$DRYRUN" -eq 1 ] || say "removed  $dest"
	elif [ -e "$dest" ]; then
		say "SKIP     $dest was not created by x-impl; leaving it alone"
	fi
}

# --- bootstrap -------------------------------------------------------------

# append_pointer FILE LINE : add LINE + marker once, idempotently
append_pointer() {
	file=$1
	line=$2

	if [ -f "$file" ] && grep -qF "$MARKER" "$file" 2>/dev/null; then
		say "ok       $file already has the x-impl pointer"
		return 0
	fi

	if [ "$DRYRUN" -eq 1 ]; then
		say "would:   append '$line $MARKER' to $file"
		return 0
	fi

	# keep a blank line between the pointer and whatever came before
	if [ -s "$file" ]; then
		printf '\n' >>"$file"
	fi
	printf '%s %s\n' "$line" "$MARKER" >>"$file"
	say "appended pointer to $file"
}

strip_pointer() {
	file=$1
	[ -f "$file" ] || return 0
	grep -qF "$MARKER" "$file" 2>/dev/null || return 0

	if [ "$DRYRUN" -eq 1 ]; then
		say "would:   remove the x-impl pointer line from $file"
		return 0
	fi

	tmp=$file.x-impl.tmp
	grep -vF "$MARKER" "$file" >"$tmp"
	mv "$tmp" "$file"
	say "removed  pointer from $file"
}

install_bootstrap() {
	run mkdir -p "$BOOT_DIR"
	run cp "$SRC/x-impl.md" "$BOOT_DIR/x-impl.md"
	run rm -rf "$BOOT_DIR/adapters"
	run cp -R "$SRC/adapters" "$BOOT_DIR/adapters"
	[ "$DRYRUN" -eq 1 ] || say "installed $BOOT_DIR"

	claude_md=$ROOT/CLAUDE.md
	agents_md=$ROOT/AGENTS.md
	claude_line='@.x-impl/x-impl.md'
	agents_line='Read .x-impl/x-impl.md for the x-impl workflow skills.'

	print_claude=0
	print_agents=0

	if [ "$want_claude" -eq 1 ]; then
		if [ -f "$claude_md" ]; then
			append_pointer "$claude_md" "$claude_line"
		elif [ -f "$agents_md" ]; then
			append_pointer "$agents_md" "$agents_line"
			say "note     no CLAUDE.md here, so the pointer went into AGENTS.md."
			say "note     Claude Code reads AGENTS.md only while no CLAUDE.md exists."
		else
			print_claude=1
		fi
	fi

	# Codex, OpenCode and OpenClaw all read AGENTS.md. OpenClaw never reads
	# CLAUDE.md, so AGENTS.md is the only place its pointer can go.
	if [ "$want_agents" -eq 1 ]; then
		if [ -f "$agents_md" ]; then
			append_pointer "$agents_md" "$agents_line"
		else
			print_agents=1
		fi
	fi

	if [ "$print_claude" -eq 1 ] || [ "$print_agents" -eq 1 ]; then
		say ""
		say "This installer does not create instruction files. Add the line below"
		say "to the one you use:"
		say ""
		if [ "$print_claude" -eq 1 ]; then
			say "  $claude_line $MARKER        (CLAUDE.md)"
		fi
		if [ "$print_agents" -eq 1 ]; then
			say "  $agents_line $MARKER   (AGENTS.md)"
		fi
		say ""
	fi
}

uninstall_bootstrap() {
	strip_pointer "$ROOT/CLAUDE.md"
	strip_pointer "$ROOT/AGENTS.md"

	if [ -d "$BOOT_DIR" ]; then
		if [ -f "$BOOT_DIR/x-impl.md" ]; then
			run rm -rf "$BOOT_DIR/adapters"
			run rm -f "$BOOT_DIR/x-impl.md"
			# only remove the directory if nothing else lives there
			if [ "$DRYRUN" -eq 1 ]; then
				say "would:   rmdir $BOOT_DIR if empty"
			else
				rmdir "$BOOT_DIR" 2>/dev/null && say "removed  $BOOT_DIR" || \
					say "kept     $BOOT_DIR (not empty)"
			fi
		else
			say "SKIP     $BOOT_DIR was not created by x-impl; leaving it alone"
		fi
	fi
}

# --- main ------------------------------------------------------------------

targets=''
if [ "$want_claude" -eq 1 ]; then targets="$targets $CLAUDE_SKILLS"; fi
if [ "$want_agents" -eq 1 ]; then targets="$targets $AGENTS_SKILLS"; fi

if [ "$UNINSTALL" -eq 1 ]; then
	say "x-impl uninstall  root=$ROOT  harness=$HARNESS"
	for destdir in $targets; do
		[ -d "$destdir" ] || continue
		skill_dirs | while IFS= read -r src; do
			uninstall_skill "$destdir" "$(basename "$src")"
		done
		# tidy up the directories we created, but only while they are empty
		if [ "$DRYRUN" -eq 0 ]; then
			rmdir "$destdir" 2>/dev/null && say "removed  $destdir" || true
			rmdir "$(dirname "$destdir")" 2>/dev/null || true
		fi
	done
	uninstall_bootstrap
	say "done."
	exit 0
fi

say "x-impl install  root=$ROOT  harness=$HARNESS  mode=$MODE"

if [ "$AGENTS_FORCED_COPY" -eq 1 ]; then
	say "note     copying into $AGENTS_SKILLS: OpenClaw ignores symlinks there"
	say "note     that point outside the workspace. Pass --copy to silence this."
fi

count=$(skill_dirs | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || die "no skills found under $SRC/skills"

for destdir in $targets; do
	if [ "$destdir" = "$AGENTS_SKILLS" ]; then
		MODE=$AGENTS_MODE
	else
		MODE=$CLAUDE_MODE
	fi
	run mkdir -p "$destdir"
	skill_dirs | while IFS= read -r src; do
		install_skill "$src" "$destdir"
	done
done

if [ "$BOOTSTRAP" -eq 1 ]; then
	install_bootstrap
fi

say "done. $count skills."
