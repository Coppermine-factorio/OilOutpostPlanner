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

exclude_files="$(find $dirname -name '*.sw[po]' -printf '-x %p\n')"
exclude_files+="$(
  find $dirname -maxdepth 1 -name '*.png' -a -not -name thumbnail.png \
  -printf '-x %p\n')"

zip -r "$full_release_path" $dirname/[^.rT]* $exclude_files
