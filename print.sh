#!/bin/bash

PRINT_LINES=" --margins=54::: "
COLOUR=" "
LINES=62

while [[ $# > 0 ]] ; do
  if [[ "$1" == "-n" ]] ; then
    PRINT_LINES="-C 1 -E"
  elif [[ "$1" == "-N" ]] ; then
    PRINT_LINES="--margins=54:::"

  elif [[ "$1" == "-L" ]] || [[ "$1" == "-L" ]] ; then
    LINES="$2"
    shift

  elif [[ "$1" == "-c" ]] ; then
    COLOUR="--color"
  elif [[ "$1" == "-C" ]] ; then
    COLOUR=" "

  elif [ -f "$1" ] ; then
    if [ -f ~/PDF/Enscript_Output.pdf  ] ; then
      mv ~/PDF/Enscript_Output.pdf ~/PDF/.Enscript_Output.pdf
    fi
    filename="`basename "$1"`"
    echo printing $filename

    enscript "$1"  -L "$LINES" $PRINT_LINES $COLOUR -o .tmp.eps > /dev/null 2>&1
    # ls ~/PDF
    lpr -P PDF .tmp.eps
    # ls ~/PDF
    while [ ! -f ~/PDF/Enscript_Output*.pdf ] ; do
      sleep 1
    done
    mv ~/PDF/Enscript_Output*.pdf ~/PDF/"${filename%.*}.pdf"
    rm .tmp.eps

    if [ -f ~/PDF/.Enscript_Output.pdf ] ; then
      mv ~/PDF/.Enscript_Output.pdf  ~/PDF/Enscript_Output.pdf
    fi
  fi
  shift
done
