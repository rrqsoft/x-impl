#!/bin/sh
# x-impl release preflight. POSIX sh, no dependencies beyond git, grep, awk,
# sed, find and coreutils. Run it before tagging:
#
#   sh scripts/release-check.sh
#
# Every check prints a line. Any failure exits non-zero with a readable
# message, after running the rest, so one run shows every problem.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$ROOT"

FAILED=0
SMOKE_DIR=''

pass() { printf 'ok    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*" >&2; FAILED=1; }
note() { printf '      %s\n' "$*" >&2; }

cleanup() {
	[ -n "$SMOKE_DIR" ] && [ -d "$SMOKE_DIR" ] && rm -rf "$SMOKE_DIR"
	return 0
}
trap cleanup EXIT HUP INT TERM

# Files we ship or keep in the repo. .git and dist/ are never scanned.
repo_files() {
	find . \
		-path ./.git -prune -o \
		-path ./dist -prune -o \
		-type f -print | sed 's|^\./||' | sort
}

# --- 1. the installer parses ----------------------------------------------

if sh -n install.sh 2>/tmp/x-impl-shn.$$; then
	pass "install.sh parses"
else
	fail "install.sh does not parse"
	note "$(cat /tmp/x-impl-shn.$$)"
fi
rm -f /tmp/x-impl-shn.$$

# --- 2. skill frontmatter --------------------------------------------------

skill_count=0
for dir in skills/x-*; do
	[ -d "$dir" ] || continue
	skill_count=$((skill_count + 1))
	name=$(basename "$dir")
	file=$dir/SKILL.md

	if [ ! -f "$file" ]; then
		fail "$dir has no SKILL.md"
		continue
	fi

	# Read the first frontmatter block: --- / key: value / ---
	fm_name=$(awk '
		NR == 1 { if ($0 != "---") exit; next }
		/^---[[:space:]]*$/ { exit }
		/^name:[[:space:]]/ { sub(/^name:[[:space:]]*/, ""); print; exit }
	' "$file")
	fm_desc=$(awk '
		NR == 1 { if ($0 != "---") exit; next }
		/^---[[:space:]]*$/ { exit }
		/^description:[[:space:]]/ { sub(/^description:[[:space:]]*/, ""); print; exit }
	' "$file")

	if [ "$fm_name" = "$name" ]; then
		pass "$file name: $name"
	else
		fail "$file name is '${fm_name:-<missing>}' but the directory is '$name'"
	fi

	desc_len=$(printf '%s' "$fm_desc" | awk '{ n += length($0) } END { print n + 0 }')
	if [ "$desc_len" -ge 1 ] && [ "$desc_len" -le 1024 ]; then
		pass "$file description: $desc_len chars"
	else
		fail "$file description is $desc_len chars; must be 1..1024"
	fi
done

if [ "$skill_count" -gt 0 ]; then
	pass "found $skill_count skills"
else
	fail "no skills found under skills/"
fi

# --- 3. forbidden names ----------------------------------------------------
# Built from fragments on purpose, so this file does not match its own check.

FORBIDDEN="super""powers|ob""ra|prime""radiant|je""sse"

hits=$(repo_files | xargs grep -lniE "$FORBIDDEN" 2>/dev/null || true)
if [ -z "$hits" ]; then
	pass "no forbidden names"
else
	fail "forbidden names appear in:"
	note "$hits"
fi

# --- 4. no URLs ------------------------------------------------------------
# .github/ is scanned too: the workflow must use bare action refs, never links.
#
# One exception: the one-liner installer has to name its own release host, so
# install.sh and README.md may carry x-impl's own github.com and
# raw.githubusercontent.com URLs, literal or $REPO-templated. Any other URL,
# in any file, still fails.

# URLs belonging to this project, in literal and templated form.
OWN_URL='^https?://(github\.com|raw\.githubusercontent\.com)/(rrqsoft/x-impl|\$REPO|\$\{REPO\}|\$X_IMPL_REPO|\$\{X_IMPL_REPO[^}]*\})([/?#].*)?$'

url_report=$(mktemp "${TMPDIR:-/tmp}/x-impl-urls.XXXXXX")
while IFS= read -r file; do
	urls=$(grep -ohE 'https?://[^][(){}<>"'"'"'`[:space:],;]+' "$file" 2>/dev/null |
		sed 's/[.,:]*$//' | sort -u || true)
	[ -n "$urls" ] || continue

	case $file in
	install.sh | README.md)
		stray=$(printf '%s\n' "$urls" | grep -vE "$OWN_URL" || true)
		;;
	*)
		stray=$urls
		;;
	esac

	if [ -n "$stray" ]; then
		{
			printf '%s:\n' "$file"
			printf '%s\n' "$stray" | sed 's/^/  /'
		} >>"$url_report"
	fi
done <<EOF
$(repo_files)
EOF

url_offenders=$(cat "$url_report")
rm -f "$url_report"

if [ -z "$url_offenders" ]; then
	pass "no http(s) URLs outside x-impl's own release URLs in install.sh and README.md"
else
	fail "disallowed http(s) URLs:"
	note "$url_offenders"
fi

# --- 5. relative references from SKILL.md resolve --------------------------
# Only backticked paths that are relative file references: prompts/..,
# references/.., ../other-skill/... Output paths and <placeholders> are not.

ref_total=0
for dir in skills/x-*; do
	[ -d "$dir" ] || continue
	file=$dir/SKILL.md
	[ -f "$file" ] || continue

	refs=$(grep -oE '`(\.\./[A-Za-z0-9._/-]+|prompts/[A-Za-z0-9._/-]+|references/[A-Za-z0-9._/-]+)`' "$file" |
		tr -d '`' | sort -u || true)
	for ref in $refs; do
		ref_total=$((ref_total + 1))
		if [ -e "$dir/$ref" ]; then
			pass "$file -> $ref"
		else
			fail "$file references $ref, which does not exist"
		fi
	done
done
pass "checked $ref_total relative references"

# --- 6. installer smoke test ----------------------------------------------

SMOKE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/x-impl-smoke.XXXXXX")
smoke_log=$SMOKE_DIR/log

smoke() {
	proj=$SMOKE_DIR/project
	mkdir -p "$proj"
	cd "$proj"

	git init -q .
	printf '# AGENTS\n' >AGENTS.md
	printf '# CLAUDE\n' >CLAUDE.md

	sh "$ROOT/install.sh" --harness all --bootstrap >>"$smoke_log" 2>&1 || return 1

	[ -d .claude/skills/x-impl ] || { echo "no .claude/skills/x-impl" >>"$smoke_log"; return 1; }
	[ -d .agents/skills/x-impl ] || { echo "no .agents/skills/x-impl" >>"$smoke_log"; return 1; }
	[ -f .x-impl/x-impl.md ] || { echo "no .x-impl/x-impl.md" >>"$smoke_log"; return 1; }
	grep -qF '<!-- x-impl -->' CLAUDE.md || { echo "no pointer in CLAUDE.md" >>"$smoke_log"; return 1; }
	grep -qF '<!-- x-impl -->' AGENTS.md || { echo "no pointer in AGENTS.md" >>"$smoke_log"; return 1; }

	before=$(find .claude .agents .x-impl -print | sort)
	claude_md_before=$(cat CLAUDE.md)
	agents_md_before=$(cat AGENTS.md)

	sh "$ROOT/install.sh" --harness all --bootstrap >>"$smoke_log" 2>&1 || return 1

	after=$(find .claude .agents .x-impl -print | sort)
	[ "$before" = "$after" ] || { echo "second install changed the tree" >>"$smoke_log"; return 1; }
	[ "$claude_md_before" = "$(cat CLAUDE.md)" ] || { echo "CLAUDE.md gained a second pointer" >>"$smoke_log"; return 1; }
	[ "$agents_md_before" = "$(cat AGENTS.md)" ] || { echo "AGENTS.md gained a second pointer" >>"$smoke_log"; return 1; }

	sh "$ROOT/install.sh" --harness all --bootstrap --uninstall >>"$smoke_log" 2>&1 || return 1

	for leftover in .claude/skills/x-impl .agents/skills/x-impl .x-impl/x-impl.md; do
		if [ -e "$leftover" ]; then
			echo "$leftover survived uninstall" >>"$smoke_log"
			return 1
		fi
	done
	for md in CLAUDE.md AGENTS.md; do
		if grep -qF '<!-- x-impl -->' "$md"; then
			echo "pointer survived in $md" >>"$smoke_log"
			return 1
		fi
	done

	return 0
}

if smoke; then
	cd "$ROOT"
	pass "installer smoke test: install, re-install idempotent, uninstall clean"
else
	cd "$ROOT"
	fail "installer smoke test failed"
	note "$(cat "$smoke_log" 2>/dev/null || echo '(no log)')"
fi

# --- verdict ---------------------------------------------------------------

if [ "$FAILED" -eq 0 ]; then
	printf '\nrelease-check: all checks passed.\n'
	exit 0
fi

printf '\nrelease-check: FAILED. Fix the items above before tagging.\n' >&2
exit 1
