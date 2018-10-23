#!/bin/bash

# create temp dir, and ensure it gets removed on exit
tdir="/tmp/apng2gif_$RANDOM"
mkdir "$tdir"
finish() {
  rm -rf "$tdir"
  cd "$back"
}
trap finish EXIT

# extract frames
apngasm -D "$1" -o "$tdir" -x "$tdir/out.xml"

# Get num loops and the delay
LOOPS=`cat "$tdir/out.xml" | grep -Po "(?<=loops=\")\\d+(?=\")"`
DELAY=` cat "$tdir/out.xml" | grep -Po "(?<=delay=\")\\d+/\\d+(?=\")" | head -1`

# compute the output name of the gif
if [[ -z "$2" ]]; then
  OUT="`dirname "$1"`/`basename "$1 .png".gif`"
elif [ -d "$2" ]; then
  OUT="$2/`basename "$1 .png".gif`"
else
  OUT="$2"
fi

# create the gif
cd "$tdir"
convert -delay $DELAY -loop 0 `ls *png | sort -n` "$tdir/out.gif"

# move the gif to the final output location
mv "$tdir/out.gif" "$OUT"

