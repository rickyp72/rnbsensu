#!/bin/sh
if [ -f '/tmp/file' ]
then
  echo "The file is there"
  exit 0
else
  echo "File Missing!"
  exit 2
fi
