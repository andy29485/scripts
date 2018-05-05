if [ "$#" -ne 4 ] ; then
  echo usage $0 IN.mkv OUT.mkv START DURATION
fi
IN="$1"
OUT="$2"
START="$3"
DURATION="$4"
ffmpeg -i "$IN" -ss "$START" -t "$DURATION" -y -threads 16 -preset veryslow -crf 19 -c:v h264 -c:a copy -c:s copy -map 0 "$OUT"