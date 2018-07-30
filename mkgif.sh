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
  printf " [-m|--manual] [-M|--manual-gui] [-g|--gif]"
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

dialog-box() {
  if which zenity > /dev/null 2>&1 ; then
    zenity \
      --info \
      --text="$2" \
      --title="$1"
  elif which kdialog > /dev/null 2>&1 ; then
    kdialog --title "$1" --msgbox "$2"
  elif which gxmessage  > /dev/null 2>&1 ; then
    gxmessage "$2"
  elif which xmessage > /dev/null 2>&1 ; then
    xmessage -buttons Ok:0,"Not sure":1,Cancel:2 -default Ok -nearmouse "$2"
  elif which mshta > /dev/null 2>&1 ; then
    mshta "javascript:alert('$2');close();"
  else
    echo "sorry, can't do much to pause"
  fi
}

if which magick > /dev/null 2>&1 ; then
  convert=magick
elif which convert > /dev/null 2>&1 ; then
  convert=convert
else
  e "image magic"
fi

which ffmpeg > /dev/null 2>&1 || e "ffmpeg"

# https://github.com/apngasm/apngasm/releases/download/3.1.3/apngasm_3.1-3_AMD64.exe
which apngasm > /dev/null 2>&1 || e "apngasm"

if [[ $# -lt 2 ]] || [[ $# -gt 13 ]] ; then
  echo insufficent args
  help
  exit 1
fi

INPUT=""
OUTPUT=""
START=""
DURATION=""
RATE=""
SUBS=""
MANUAL=""
WIDTH="scale=520:-1:flags=lanczos"
CROP=""
GIF=""
DEBUG=""
OPEN=""
DEBUG=""

if which xdg-open > /dev/null 2>&1 ; then
  OPEN="xdg-open"
elif which start > /dev/null 2>&1 ; then
  OPEN="start" # prob windows
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
    -M|--manual-gui)
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

INPUT="`echo "$INPUT" | sed -E 's/([A-Z]):/\/\1/' | xargs -0 realpath`"
OUTPUT="`echo "$OUTPUT" | sed -E 's/([A-Z]):/\/\1/' | xargs -0 realpath`"
back="`pwd`"

finish() {
  rm -rf "$tdir"
  cd "$back"
}
trap finish EXIT

cd "$tdir"

if [[ ! -z "$START" ]] ; then
  START="-ss $START"
fi
if [[ ! -z "$DURATION" ]] ; then
  DURATION="-t $DURATION"
fi
if [[ ! -z "$RATE" ]] ; then
  RATE="fps=$RATE"
elif [[ ! -z "$GIF" ]] ; then
  RATE="fps=13"
fi

if [ "$SUBS" = "INPUT" ] ; then
  echo extracting subs
  if [[ ! -z "$DEBUG" ]] ; then
    echo ffmpeg $START $DURATION -i \"$INPUT\" -map 0:s:0 \"$tdir/subs.ass\"
  fi
  ffmpeg $START $DURATION -i "$INPUT" -map 0:s:0 "$tdir/subs.ass" 2> /dev/null
  SUBS=",subtitles=subs.ass"
  if [[ $INPUT == *.mkv ]] ; then
    mkdir "$tdir/attach"
    cd "$tdir/attach"
    echo extracting fonts
    if [[ ! -z "$DEBUG" ]] ; then
      echo ffmpeg -dump_attachment:t \"\" -i \"$INPUT\" -y
    fi
    ffmpeg -dump_attachment:t "" -i "$INPUT" -y 2> /dev/null
    cd ../
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
  echo ffmpeg $START $DURATION -i \"$INPUT\" -vf $CROP$WIDTH,\"$RATE$SUBS\" \"$tdir\"/ffout%05d.png
fi
ffmpeg $START $DURATION -i "$INPUT" -vf $CROP$WIDTH,"$RATE$SUBS" "$tdir"/ffout%05d.png 2> /dev/null

if [ -n "$MANUAL" ] ; then
  echo please delete any unneeded images in \"$tdir\"
  if [ -n "$OPEN" ] ; then
    if [[ ! -z "$DEBUG" ]] ; then
      echo $OPEN \"$tdir\" \&
    fi
    $OPEN "$tdir" &
  elif [[ ! -z "$DEBUG" ]] ; then
    echo "DEBUG: not opening dir, OPEN is not defined"
  fi
  if [ "$MANUAL" == "yes" ] ; then # not uppercase
    echo then press return to continue
    read tmp
  elif [ "$MANUAL" == "YES" ] ; then
    dialog-box "APNG/GIF maker thing" "Close this to continue"
  fi
fi

if [ "`echo "$tdir"/ffout*.png`" == "$tdir/ffout*.png" ] ; then
  e "Nothing Frames Found"
fi

echo adding frames to image
if [[ ! -z "$GIF" ]] ; then
  OUTPUT="`dirname "$OUTPUT"`/`basename "$OUTPUT" .gif | xargs -I name basename name .png`.gif"
  if [[ ! -z "$DEBUG" ]] ; then
    echo $convert -delay 0 -loop 0 \"$tdir\"/ffout*.png \"$tdir/out.gif\"
  fi
  $convert -delay 0 -loop 0 "$tdir"/ffout*.png "$tdir/out.gif" > /dev/null 2>&1
  if [[ ! -z "$DEBUG" ]] ; then
    echo mv \"$tdir/out.gif\" "$OUTPUT"
  fi
  mv "$tdir/out.gif" "$OUTPUT"
else
  OUTPUT="`dirname "$OUTPUT"`/`basename "$OUTPUT" .gif | xargs -I name basename name .png`.png"
  if [[ ! -z "$DEBUG" ]] ; then
    echo apngasm "\"$tdir\"/ffout*.png" -o "$tdir/out.png" -l 0
  fi
  apngasm "$tdir"/ffout*.png -o "$tdir/out.png" -l 0 > /dev/null 2>&1
  if [[ ! -z "$DEBUG" ]] ; then
    echo mv \"$tdir/out.png\" "$OUTPUT"
  fi
  mv "$tdir/out.png" "$OUTPUT"
fi

echo done
