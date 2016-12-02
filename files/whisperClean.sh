#!/bin/bash
d=$1
now=$(date +%s)

# MINRET=86400
MINRET=120

if [ -z "$d" ]; then
  echo "Must specify a directory to clean"
  exit 1
fi

find $d -name '*.wsp' | while read w; do
   age=$((now - $(stat -c '%Y' "$w")))
   if [ $age -gt $MINRET ]; then
    #  retention=$(whisper-info.py $w maxRetention)
     retention=$(whisper-info $w maxRetention)
   if [ $age -gt $retention ]; then
     echo "Removing $w ($age > $retention)"
     rm $w
   fi
 fi
done

find $d -empty -type d -delete
