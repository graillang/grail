#!/bin/sh
# Install Grail from an unpacked release tree.
#
#   ./install.sh [PREFIX]
#
# PREFIX defaults to /usr/local; use "$HOME/.local" to install without root.
# DESTDIR is honoured for distribution packaging. The tree keeps the layout the
# compiler expects: PREFIX/bin/grail and PREFIX/lib/grail/{runtime.grl,std/}.
set -eu

prefix=${1:-${PREFIX:-/usr/local}}
destdir=${DESTDIR:-}
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ ! -f "$here/bin/grail" ]; then
    echo "install.sh: bin/grail not found next to $0" >&2
    exit 1
fi
if [ ! -f "$here/lib/grail/runtime.grl" ]; then
    echo "install.sh: lib/grail/runtime.grl not found; unpack the full release archive" >&2
    exit 1
fi

bindir="$destdir$prefix/bin"
libdir="$destdir$prefix/lib/grail"

mkdir -p "$bindir" "$libdir/std"
cp "$here/bin/grail" "$bindir/grail.new"
chmod 0755 "$bindir/grail.new"
mv "$bindir/grail.new" "$bindir/grail"
cp "$here/lib/grail/runtime.grl" "$libdir/runtime.grl"
for module in "$here"/lib/grail/std/*.grl; do
    [ -e "$module" ] || continue
    cp "$module" "$libdir/std/$(basename "$module")"
done
if [ -d "$here/share/doc/grail" ]; then
    mkdir -p "$destdir$prefix/share/doc/grail"
    cp "$here"/share/doc/grail/* "$destdir$prefix/share/doc/grail/"
fi

echo "installed $prefix/bin/grail"
echo "runtime and standard library: $prefix/lib/grail"
echo "building programs still needs clang (assembler) and ld.lld on PATH"
case ":$PATH:" in
    *":$prefix/bin:"*) ;;
    *) echo "add $prefix/bin to PATH to run 'grail'";;
esac
