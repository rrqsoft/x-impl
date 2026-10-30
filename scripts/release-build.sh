#!/bin/sh
# x-impl release build. POSIX sh, no dependencies beyond git, gzip and a
# sha256 tool. Works the same on macOS (BSD) and Ubuntu (GNU).
#
#   sh scripts/release-build.sh v1.2.3
#
# Writes into dist/:
#   x-impl-<tag>.tar.gz   the shipped tree under a x-impl-<tag>/ top directory
#   NOTES.md              release notes: commits since the previous v* tag
#   SHA256SUMS            checksums of both, verifiable from inside dist/
#
# Reproducibility: the tarball comes from `git archive`, which walks the tree
# in sorted order and stamps every entry with the tag commit's own date, with
# uid/gid 0 and no names. gzip -n keeps the timestamp out of the gzip header.
# The same tag therefore produces a byte-identical tarball on either platform.

set -eu

TAG=${1:-}
[ -n "$TAG" ] || { echo "usage: sh scripts/release-build.sh <tag>" >&2; exit 1; }

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$ROOT"

# What ships. Not .github/, not scripts/, not dist/.
SHIP='README.md LICENSE x-impl.md install.sh adapters docs skills'

# The commit the tag points at; fall back to HEAD when building an untagged
# tree by hand.
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
	REF=refs/tags/$TAG
else
	echo "note: no tag $TAG in this repo; building from HEAD" >&2
	REF=HEAD
fi
SHA=$(git rev-parse --short "$REF^{commit}")

DIST=$ROOT/dist
rm -rf "$DIST"
mkdir -p "$DIST"

TARBALL=x-impl-$TAG.tar.gz

# --- tarball ---------------------------------------------------------------

# shellcheck disable=SC2086
git archive --format=tar --prefix="x-impl-$TAG/" "$REF" -- $SHIP >"$DIST/x-impl-$TAG.tar"
gzip -n -9 "$DIST/x-impl-$TAG.tar"
echo "built dist/$TARBALL"

# --- notes -----------------------------------------------------------------

PREV=$(git describe --tags --abbrev=0 --match 'v*' "$REF^" 2>/dev/null || true)

{
	printf '## x-impl %s\n\n' "$TAG"
	if [ -n "$PREV" ]; then
		printf 'Changes since `%s` (commit `%s`):\n\n' "$PREV" "$SHA"
		git log --no-merges --pretty='- %s (%h)' "$PREV..$REF"
	else
		printf 'First release (commit `%s`).\n\n' "$SHA"
		git log --no-merges --pretty='- %s (%h)' "$REF"
	fi
	printf '\n### Install\n\n'
	printf 'Unpack the tarball and run `sh install.sh --harness all --bootstrap`\n'
	printf 'inside the project you want the skills in.\n\n'
	printf 'Verify the download with `shasum -a 256 -c SHA256SUMS`.\n'
} >"$DIST/NOTES.md"
echo "built dist/NOTES.md${PREV:+ (since $PREV)}"

# --- checksums -------------------------------------------------------------

if command -v sha256sum >/dev/null 2>&1; then
	SHACMD='sha256sum'
elif command -v shasum >/dev/null 2>&1; then
	SHACMD='shasum -a 256'
else
	echo "error: neither sha256sum nor shasum is available" >&2
	exit 1
fi

( cd "$DIST" && $SHACMD "$TARBALL" NOTES.md >SHA256SUMS )
echo "built dist/SHA256SUMS"

echo
cat "$DIST/SHA256SUMS"
