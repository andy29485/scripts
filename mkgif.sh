#!/bin/bash

e() {
  echo "Error: $1 not installed"
  exit 1
}

help() {
  echo "usage:"
  printf "$0 input.(mkv|mp4) output.gif [[-ss|--start] <start time>]"
  printf " [[-t|--duration] <duration>] [[-r|--rate] RATE] [-w WIDTH]"
  printf " [-c CROP] [-s|--enable-subtitles] [-i|--subtitle-file <sub file>]]"
  printf " [-m|--manual] [-M|--manual-no-wait] [-g|--gif]"
  echo
  echo
  echo "Start:       start time of segment, format \"HH:MM:SS.mmm\""
  echo "Duration:    duration of segment,  format \"S.mmm\""
  echo "Rate:        frame rate to extract, int value, higher -> more frames"
  echo "Width:       output size in pixles, int value, ratio is preserved"
  echo "Crop:        crop extracted segment, cannot be used with width,"
  echo "             format: width:height:startX:startY"
  echo "Enable Subs: extract subs from video and burn into gif"
  echo "Sub File:    use subtitles from specified file instead"
  echo "Manual:      edit frames  manually before adding to gif"
  echo "Gif:         force gif mode (instead of apng)"
}

if which convert 2>&1 > /dev/null ; then
  convert=convert
elif which magick 2>&1 > /dev/null ; then
  convert=magick
else
  e "image magic"
fi

which ffmpeg 2>&1 > /dev/null || e "ffmpeg"

# https://sourceforge.net/projects/apngasm/files/latest/download
which apngasm 2>&1 > /dev/null || e "apngasm"

if [[ $# -lt 2 ]] || [[ $# -gt 13 ]] ; then
  echo insufficent args
  help
  exit 1
fi

INPUT=""
OUTPUT=""
START=""
DURATION=""
RATE="24"
SUBS=""
MANUAL=""
WIDTH="scale=520:-1:flags=lanczos"
CROP=""
GIF=""
DEBUG=""
OPEN=""
#DEBUG="yes"

if which xdg-open 2>&1 > /dev/null ; then
  OPEN="xdg-open"
elif which xdg-open 2>&1 > /dev/null ; then
  OPEN="start"
fi

while [[ $# -gt 0 ]] ; do
  key="$1"

  case $key in
    -h|--help)
      help
      exit
      ;;
    -ss|--start)
      START="$2"
      shift
      ;;
    -ss=*|--start=*)
      START="${i#*=}"
      ;;
    -r|--rate)
      RATE="$2"
      shift
      ;;
    -r=*|--rate=*)
      RATE="${i#*=}"
      ;;
    -w|--width)
      WIDTH="scale=$2:-1:flags=lanczos"
      shift
      ;;
    -w=*|--width=*)
      WIDTH="scale=${i#*=}:-1:flags=lanczos"
      ;;
    -t|--duration)
      DURATION="$2"
      shift
      ;;
    -t=*|--duration=*)
      DURATION="${i#*=}"
      ;;
    -i|--subtitle-file)
      SUBS="$2"
      shift
      ;;
    -i=*|--subtitle-file=*)
      SUBS=",subtitles=${i#*=}"
      ;;
    -s|--enable-subtitles)
      if [[ -z "$SUBS" ]] ; then
        SUBS="INPUT"
      fi
      ;;
    -c|--crop)
      CROP="crop=$2,"
      shift
      ;;
    -m|--manual)
      MANUAL="yes"
      ;;
    -M|--manual-no-wait)
      MANUAL="YES"
      ;;
    -g|--gif)
      GIF="yes"
      ;;
    -v|--verbose)
      DEBUG="yes"
      ;;
    *)
      if [[ -z "$INPUT" ]] ; then
        INPUT="$1"
      elif [[ -z "$OUTPUT" ]] ; then
        OUTPUT="$1"
      elif [[ -z "$START" ]] ; then
        START="$1"
      elif [[ -z "$DURATION" ]] ; then
        DURATION="$1"
      elif [[ -z "$RATE" ]] ; then
        RATE="$1"
      fi
      ;;
  esac
  shift # past argument or value
done

tdir="/tmp/frames_$RANDOM"
mkdir "$tdir"

INPUT="`realpath "$INPUT"`"
OUTPUT="`realpath "$OUTPUT"`"
back="`pwd`"

finish() {
  rm -rf "$tdir"
  cd "$back"
}
trap finish EXIT

if [[ ! -z "$START" ]] ; then
  START="-ss $START"
fi
if [[ ! -z "$DURATION" ]] ; then
  DURATION="-t $DURATION"
fi

if [ "$SUBS" = "INPUT" ] ; then
  echo extracting subs
  if [[ ! -z "$DEBUG" ]] ; then
    echo ffmpeg $START $DURATION -i \"$INPUT\" -map 0:s:0 \"$tdir/subs.ass\"
  fi
  ffmpeg $START $DURATION -i "$INPUT" -map 0:s:0 "$tdir/subs.ass" 2> /dev/null
  SUBS=",subtitles=$tdir/subs.ass"
  if [[ $INPUT == *.mkv ]] ; then
    mkdir "$tdir/attach"
    cd "$tdir/attach"
    echo extracting fonts
    if [[ ! -z "$DEBUG" ]] ; then
      echo ffmpeg -dump_attachment:t \"\" -i \"$INPUT\" -y
    fi
    ffmpeg -dump_attachment:t "" -i "$INPUT" -y 2> /dev/null
  fi
elif [[ ! -z "$SUBS" ]] ; then
  if [[ ! -z "$DEBUG" ]] ; then
    ffmpeg $START $DURATION -i "$SUBS" "$tdir/subs.ass" 2> /dev/null
  fi
  cp "$SUBS" "$tdir/subs.ass"
  SUBS=",subtitles=$tdir/subs.ass"
fi

echo extracting frames
if [[ ! -z "$DEBUG" ]] ; then
  echo ffmpeg $START $DURATION -i \"$INPUT\" -vf $CROP$WIDTH,fps=\"$RATE$SUBS\" \"$tdir\"/ffout%05d.png
fi
ffmpeg $START $DURATION -i "$INPUT" -vf $CROP$WIDTH,fps="$RATE$SUBS" "$tdir"/ffout%05d.png 2> /dev/null

if [ -n "$MANUAL" ] ; then
  echo please delete any unneeded images in \"$tdir\"
  if [ -n "$OPEN" ] ; then
    if [[ ! -z "$DEBUG" ]] ; then
      echo $OPEN \"$tdir\"
    fi
    $OPEN "$tdir"
  elif [[ ! -z "$DEBUG" ]] ; then
    echo "DEBUG: not opening dir, OPEN is not defined"
  fi
  if [ "$MANUAL" == "yes" ] ; then # not uppercase
    echo then press return to continue
    read tmp
  fi
fi

if [ "`echo "$tdir"/ffout*.png`" == "$tdir/ffout*.png" ] ; then
  e "Nothing Frames Found"
fi

echo adding frames to gif
if [[ ! -z "$GIF" ]] ; then
  OUTPUT="`dirname "$OUTPUT"`/`basename "$OUTPUT" .gif | xargs -I name basename name .png`.gif"
  if [[ ! -z "$DEBUG" ]] ; then
    echo $convert -delay 0 -loop 0 -layers optimize \"$tdir\"/ffout*.png \"$tdir/out.gif\"
  fi
  $convert -delay 0 -loop 0 -layers optimize "$tdir"/ffout*.png "$tdir/out.gif" 2>&1 1> /dev/null
  if [[ ! -z "$DEBUG" ]] ; then
    echo mv \"$tdir/out.gif\" "$OUTPUT"
  fi
  mv "$tdir/out.gif" "$OUTPUT"
else
  OUTPUT="`dirname "$OUTPUT"`/`basename "$OUTPUT" .gif | xargs -I name basename name .png`.png"
  if [[ ! -z "$DEBUG" ]] ; then
    echo apngasm \"$tdir\"/ffout*.png -o "$tdir/out.png" -l 0
  fi
  apngasm "$tdir"/ffout*.png -o "$tdir/out.png" -l 0 2>&1 1> /dev/null
  if [[ ! -z "$DEBUG" ]] ; then
    echo mv \"$tdir/out.png\" "$OUTPUT"
  fi
  mv "$tdir/out.png" "$OUTPUT"
fi

echo done
