#!/bin/bash

if which emacspeak _name >/dev/null; then
  ESD=`emacspeak --batch --load get-emacspeak-path.el 2> /dev/null | tail -1 | sed 's/"//g'`
else
  ESD=`emacs --batch --load get-emacspeak-path.el 2> /dev/null | tail -1 | sed 's/"//g'`
fi

echo $ESD
