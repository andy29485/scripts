#!/bin/bash

echo Making SCXvid keyframes...
video="$1"
video2="${1%.*}_keframes.log"
ffmpeg -i "$video" -f yuv4mpegpipe -vf scale=640:360 -pix_fmt yuv420p -vsync drop - | scxvid.exe "$video2"
echo Keyframes complete


