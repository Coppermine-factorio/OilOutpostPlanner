#!/bin/bash

cd $(dirname $0)
release_name=$(basename $PWD)
full_release_path=$HOME/projects/factorio/factorio-mods/$release_name.zip

if [ -e "$full_release_path" ]
then
  printf "Release file already exists\n" >&2
  exit 1
fi

cd ..

swap_files=$(find $release_name -name '*.sw[po]')

zip -r "$full_release_path" $release_name/[^.rT]* ${swap_files:+-x} $swap_files
