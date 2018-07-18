#!/bin/bash

if [ $# -lt 1 ] || [ $# -gt 3 ] ; then
  echo "usage:"
  echo "$0 <filename> [title=Opening] [season=1]"
  exit 1
elif [ $# -eq 2 ] ; then
  title="$2"
  season=1
elif [ $# -eq 3 ] ; then
  title="$2"
  season="$3"
else
  title=Opening
  season=1
fi

filename="$1"
ep_num=`echo $filename | grep -Po "(?<=00x)\d{3}"`
nfo_filename="${filename%.*}.nfo"
thumb_filename="${filename%.*}-thumb.jpg"

if [ -z "$ep_num" ] ; then
  echo "invalid filename (should be in form 00xNUM)"
  echo $filename
  exit 2
fi

ffmpeg -y -i "$filename" -vf scale=640:360 -frames:v 1 "$thumb_filename" > /dev/null 2>&1

echo "﻿<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?>
<episodedetails>
  <plot />
  <outline />
  <lockdata>true</lockdata>
  <title>$title</title>
  <credits>Ozawa Kaoru</credits>
  <isuserfavorite>false</isuserfavorite>
  <playcount>0</playcount>
  <watched>false</watched>
  <episode>$ep_num</episode>
  <season>0</season>
  <airsafter_season>$season</airsafter_season>
  <epbookmark>0.000000</epbookmark>
  <top250>0</top250>
  <uniqueid></uniqueid>
  <status></status>
  <code></code>
</episodedetails>
" > $nfo_filename
