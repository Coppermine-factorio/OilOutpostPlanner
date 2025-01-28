#!/bin/bash

cd $(dirname $0)
version=$(jq -r .version info.json)
dirname=$(basename $PWD)
release_name=${dirname}_$version
full_release_path=$HOME/projects/factorio/factorio-mods/$release_name.zip

if [ -e "$full_release_path" ]
then
  printf "Release file '%s' already exists\n" "$full_release_path" >&2
  exit 1
fi

cd ..

swap_files=$(find $dirname -name '*.sw[po]')

zip -r "$full_release_path" $dirname/[^.rT]* ${swap_files:+-x} $swap_files
