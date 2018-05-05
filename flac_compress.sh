#!/bin/bash

tmp_flac="/tmp/compressed_$RANDOM$RANDOM.flac"
export tmp_flac

f_c() {
  printf "$1 - "
  flac "$1" --verify --best --exhaustive-model-search -f -o "$tmp_flac" 2> /dev/null

  ORG_SIZE=`du -sb "$1" | awk '{ print $1 }'`
  NEW_SIZE=`du -sb "$tmp_flac" | awk '{ print $1 }'`

  if [ "$ORG_SIZE" -gt "$NEW_SIZE" ] ; then
    echo replacing
    mv "$tmp_flac" "$1"
  else
    echo ignoring
    rm "$tmp_flac"
  fi
}

export -f f_c

if [ "$#" -eq 0 ] ; then
  find ~/Music/ -name "*.flac" -exec bash -c 'f_c "{}"' \;
fi
while [ "$#" -gt 0 ] ; do
  find "$1" -name "*.flac" -exec bash -c 'f_c "{}"' \;
  shift
done
