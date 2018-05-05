#!/bin/bash

location="/mnt/5TB_share/sftp-root/web-share/"
replace="https://andy29485.tk/files"
mode="hash"

find "$location" -maxdepth 2 -type l -mtime +10 -delete
find "$location" -maxdepth 1 -type d -empty -delete


while [[ $# -gt 0 ]] ; do
  if [ $1 = "-h" ] ; then
    mode="hash"
  elif [ $1 = "-n" ] ; then
    mode="name"
  else
    path="`readlink -f "$1"`"

    directory="$location/`echo "$path" | md5sum | cut -c -5`"
    if [ $mode = "hash" ] ; then
      filename="`echo "$path" | sha1sum | cut -c -9`.${1##*.}"
    else
      filename="`basename "$path"`"
    fi

    if [ -f "$directory/$filename" ] ; then
      rm "$directory/$filename"
    fi
    mkdir -p "$directory"
    ln -s "$path" "$directory/$filename"

    echo "${directory/$location/$replace}/$filename"
  fi

  shift
done
