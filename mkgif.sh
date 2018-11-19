#!/bin/bash

e() {
  echo "Error: $1 "
  exit 1
}

ie() {
  e "$1 not installed"
}

help() {
  echo "usage:"
  printf "$0 "
  printf " [[-r|--rate] RATE] [-w WIDTH] [-c CROP] [-s|--enable-subtitles]"
  printf " [-i|--subtitle-file <sub file>]]"
  printf " [-m|--manual] [-M|--manual-gui]"
  printf " [-G|--gif] [-P|--apng]  [-W|--webm]"
  printf " <input.(mkv|mp4)> <output> [start time] [duration]"
  echo
  echo
  echo "Optional: "
  echo "  Rate:        frame rate to extract, int value, higher -> more frames"
  echo "  Width:       output size in pixles, int value, ratio is preserved"
  echo "  Crop:        crop extracted segment, cannot be used with width,"
  echo "               format: width:height:startX:startY"
  echo "  Enable Subs: extract subs from video and burn into gif"
  echo "               (note: embeded subs don't work with mp4's)"
  echo "  Sub File:    use subtitles from specified file instead"
  echo "  Manual:      edit frames  manually before adding to gif"
  echo "  GIF:         make gif"
  echo "  APNG:        make gif"
  echo "  WEBM:        make webm"
  echo
  echo "Required:"
  echo "  input:       the input video to convert"
  echo "  output:      name of output file to save"
  echo "                  note: if none of -G -P -W specified,"
  echo "                        the extentions will determine output format"
  echo "                        (if no extentions, all formats will be made)"
  echo
  echo "Addition:"
  echo "  (note: if left blank, whole input file will be converted)"
  echo "  Start:       start time of segment, format \"HH:MM:SS.mmm\""
  echo "  Duration:    duration of segment,  format \"S.mmm\""
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

run() {
  if [[ ! -z "$DEBUG" ]] ; then
    printf "%q " "$@"
    echo
  fi
  "$@" > /dev/null 2>&1
}

get_subs() {
  if [ "$SUBS" = "INPUT" ] ; then
    echo extracting subs
    run ffmpeg $START $DURATION -i "$INPUT" -map 0:s:0 "$tdir/subs.ass"
    SUBS=",subtitles=subs.ass:fontsdir='$tdir/attach'"
    if [[ $INPUT == *.mkv ]] && [[] ! -d "$tdir/attach" ]] ; then
      echo extracting fonts
      mkdir "$tdir/attach"
      cd "$tdir/attach"

      run ffmpeg -dump_attachment:t "" -i "$INPUT" -y

      cd ../
    fi
  elif [[ ! -z "$SUBS" ]] ; then
    run ffmpeg $START $DURATION -i "$SUBS" "$tdir/subs.ass"
    cp "$SUBS" "$tdir/subs.ass"
    SUBS=",subtitles=$tdir/subs.ass"
  fi
}

# https://github.com/apngasm/
#    apngasm/releases/download/3.1.3/apngasm_3.1-3_AMD64.exe

INPUT=""
OUTPUT=""
START=""
DURATION=""
RATE="25"
SUBS=""
MANUAL=""
WIDTH="520"
CROP=""
GIF=""
APNG=""
WEBM=""
DEBUG=""
OPEN=""
DEBUG=""

if which xdg-open > /dev/null 2>&1 ; then
  OPEN="xdg-open"
elif which start > /dev/null 2>&1 ; then
  OPEN="start" # prob windows
fi

which ffmpeg > /dev/null 2>&1 || ie "ffmpeg"
which apngasm > /dev/null 2>&1 || ie "apngasm"
if which gm > /dev/null 2>&1 ; then
  convert="gm convert"
elif which magick > /dev/null 2>&1 ; then
  convert=magick
elif which convert > /dev/null 2>&1 ; then
  convert=convert
else
  ie "image magic"
fi

optspec=":hvr:w:c:si:mMGPW"
reset=true
for arg in "$@"
do
  if [ -n "$reset" ]; then
    unset reset
    # this resets the "$@" array so we can rebuild it
    set --
  fi
  case "$arg" in
    --help)               set -- "$@" -h             ;;
    --verbose)            set -- "$@" -v             ;;
    --crop)               set -- "$@" -c             ;;
    --manual)             set -- "$@" -m             ;;
    --manual-gui)         set -- "$@" -M             ;;
    --gif)                set -- "$@" -G             ;;
    --apng)               set -- "$@" -P             ;;
    --webm)               set -- "$@" -W             ;;
    --enable-subtitles)   set -- "$@" -s             ;;
    --rate=*)             set -- "$@" -r "${arg#*=}" ;;
    --rate)               set -- "$@" -r             ;;
    --width=*)            set -- "$@" -w "${arg#*=}" ;;
    --width)              set -- "$@" -w             ;;
    --subtitle-file=*)    set -- "$@" -i "${arg#*=}" ;;
    --subtitle-file)      set -- "$@" -i             ;;
    # pass through anything else
    *) set -- "$@" "$arg" ;;
  esac
done
while getopts "$optspec" optchar; do
  case "${optchar}" in
    h) help ; exit 2                     ;;
    v) DEBUG="true"                      ;;
    r) RATE="$OPTARG"                    ;;
    w) WIDTH="$OPTARG"                   ;;
    i) SUBS="$OPTARG"                    ;;
    s) [[ -z "$SUBS" ]] && SUBS="INPUT"  ;;
    c) CROP="$OPTARG"                    ;;
    m) MANUAL="cli"                      ;;
    M) MANUAL="gui"                      ;;
    G) GIF="true"                        ;;
    P) APNG="true"                       ;;
    W) WEBM="true"                       ;;
  esac
done
shift $((OPTIND-1))

if [[ $# -lt 2 ]] ; then
  e "Insufficent arguments, see help"
elif [[ $# -gt 4 ]] ; then
  e "Too many arguments, see help"
elif [[ $# -eq 4 ]] ; then
  DURATION="$4"
  PAT="^([0-9]+\\.?[0-9]*)$"
  [[ $DURATION =~ $PAT ]] || e "Invalid duration format"
fi

if [[ $# -gt 2 ]] ; then
  START="$3"
  PAT="^((([0-9]+):)?([0-9]+):)?([0-9]+)(\\.[0-9]+)?$"
  if [[ $3 =~ $PAT ]] ; then
    H=$((BASH_REMATCH[3]))
    M=$((H*60 + BASH_REMATCH[4]))
    S=$((M*60 + BASH_REMATCH[5]))
    START="${S}${BASH_REMATCH[6]}"
  else
    e "Invalid start time format"
  fi
fi
INPUT="$1"
OUTPUT="$2"

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

DELAY=$((1000/${RATE}))
if [[ ! -z "$RATE" ]] ; then
  RATE="fps=$RATE"
else
  RATE="fps=13"
fi

PAT="=([0-9]+):"
if [[ $CROP =~ $PAT ]] ; then
  crop_tmp=${BASH_REMATCH[1]}
  if [[ WIDTH -gt crop_tmp ]] ; then
    WIDTH=$crop_tmp
  fi
fi
WIDTH="scale=${WIDTH}:-1:flags=lanczos,"

if [ -z "$GIF$APNG$WEBM" ] ; then
  case "${OUTPUT#*.}" in
    gif|GIF)
      GIF="true"
      ;;
    png|PNG|apng|APNG)
      APNG="true"
      ;;
    webm|WEBM)
      WEBM="true"
      ;;
    *)
      GIF="true"
      APNG="true"
      WEBM="true"
      ;;
  esac
  if [[ ! -z "$DEBUG" ]] ; then
    echo gif=$GIF \| apng=$APNG \| webm=$WEBM
  fi
fi
OUTPUT="${OUTPUT%.*}"

OSUBS="$SUBS"
get_subs

echo extracting frames
run ffmpeg $START $DURATION -i "$INPUT" \
           -vf $CROP$WIDTH"$RATE$SUBS" "$tdir"/ffout%05d.png

if [ -n "$MANUAL" ] ; then
  echo please delete any unneeded images in \"$tdir\"
  if [ -n "$OPEN" ] ; then
    run $OPEN "$tdir" &
  elif [[ ! -z "$DEBUG" ]] ; then
    echo "DEBUG: not opening dir, OPEN is not defined"
  fi
  if [ "$MANUAL" == "cli" ] ; then # not uppercase
    echo then press return to continue
    read tmp
  elif [ "$MANUAL" == "gui" ] ; then
    dialog-box "APNG/GIF maker thing" "Close this to continue"
  fi

  cd "$tdir"
  frst=`ls ffout*.png | head -1 | grep -o '[1-9][0-9]*'`
  last=`ls ffout*.png | tail -1 | grep -o '[1-9][0-9]*'`
  s_off=$(( (frst-1) * DELAY ))
  e_off=$(( (last-1) * DELAY - s_off ))

  START=`echo ${START} | grep -o '[0-9\.]*'`
  TMP=$([[ $START == *.* ]] && echo ${START#*.}000 || echo 000)
  START=${START%.*}${TMP:0:3}

  START="-ss `echo 000$((START+s_off)) | sed 's/...$/.&/' | sed 's/^0*//'`"
  DURATION="-t `echo 000$e_off | sed 's/...$/.&/' | sed 's/^0*//'`"
fi

if [ "`echo "$tdir"/ffout*.png`" == "$tdir/ffout*.png" ] ; then
  e "Nothing Frames Found"
fi

mkdir "$tdir/out"
BASE="$tdir/out/`basename "$OUTPUT"`"
ODIR="`dirname "$OUTPUT"`"

if [[ ! -z "$APNG" ]] ; then
  echo adding frames to apng
  run apngasm "$tdir"/ffout*.png -o "$BASE".png -d $DELAY -l 0
fi
if [[ ! -z "$GIF" ]] ; then
  echo adding frames to gif
  if [[ ! -z "$APNG" ]] &&  which apng2gif > /dev/null 2>&1 ; then
    run apng2gif "$BASE".png "$BASE".gif
  else
    run $convert -delay $DELAY/0 -loop 0 "$tdir"/ffout*.png "$BASE".gif
  fi
fi
if [[ ! -z "$WEBM" ]] ; then
  echo creating webm
  SUBS="$OSUBS"
  get_subs
  run ffmpeg $START $DURATION -i "$INPUT" -vf $CROP"$RATE$SUBS" \
      -map 0:v:0 -map 0:a:0 "$BASE".webm
fi
run mv "$tdir/out"/* "$ODIR"

echo done
