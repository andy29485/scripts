#!/bin/bash

# for error messages
e() {
  echo "Error: $1 not installed"
  exit 1
}

# help message with usage
help() {
  echo "usage:"
  echo "$0 apng_file.png [dest]"
  echo
  echo "  apng_file.png - an animated png file"
  echo "  dest          - either a dir or filename"
}

# check if everything needed is installed
#   also figure out which imagemagik to use
which apngasm > /dev/null 2>&1 || e "apngasm"
if which magick > /dev/null 2>&1 ; then
  convert=magick
elif which convert > /dev/null 2>&1 ; then
  convert=convert
else
  e "image magic"
fi

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]] ; then
  echo insufficent args
  help
  exit 1
fi

# remember current location
back="`pwd`"

# create temp dir, and ensure it gets removed on exit
tdir="/tmp/apng2gif_$RANDOM"
mkdir "$tdir"
finish() {
  rm -rf "$tdir"
  cd "$back"
}
trap finish EXIT

# extract frames
echo extracting frames
echo apngasm -D \"$1\" -o \"$tdir\" -x \"$tdir/out.xml\"
apngasm -D "$1" -o "$tdir" -x "$tdir/out.xml" > /dev/null 2>&1

# Get num loops and the delay
LOOPS=`cat "$tdir/out.xml" | grep -Po "(?<=loops=\")\\d+(?=\")" `
DELAY=`cat "$tdir/out.xml" | grep -Po "(?<=delay=\")\\d+/\\d+(?=\")" | head -1 `

# compute the output name of the gif
if [[ -z "$2" ]]; then
  OUT="`dirname "$1"`/`basename "$1 .png".gif`"
elif [ -d "$2" ]; then
  OUT="$2/`basename "$1 .png".gif`"
else
  OUT="$2"
fi
OUT="`realpath "$OUT"`"

# create the gif
cd "$tdir"
echo creating gif
echo \"$convert\" -delay \"$DELAY\" -loop 0 \`ls "$tdir"/\*png \| sort -n \` \"$tdir/out.gif\"
"$convert" -delay "$DELAY" -loop 0 `ls "$tdir"/*png | sort -n ` "$tdir/out.gif" > /dev/null 2>&1

# move the gif to the final output location
echo mv "$tdir/out.gif" "$OUT"
mv "$tdir/out.gif" "$OUT"
echo done

