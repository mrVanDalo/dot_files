#!/usr/bin/env bash

#set -x

function symlink(){
    local source=$1
    local target=$2

    my_path=`dirname $0`
    real_path=`realpath ${my_path}`

    if [[ -d ${source} ]]
    then
        rm -rf ${source}
    elif [[ -L ${source} ]]
    then
        rm -f ${source}
    elif [[ -e ${source} ]]
    then
        rm -f ${source}
    fi
  
    echo "link ${source} -> ${target}"
    ln -s ${real_path}/${target} ${source}
}

symlink ~/.xprofile   x11/Xprofile
symlink ~/.Xresources x11/Xresources
symlink ~/.Xdefaults  x11/Xdefaults
symlink ~/.xmodmap    x11/Xmodmap
symlink ~/.dmenu      dmenu
symlink ~/.spacemacs  spacemacs
symlink ~/.xmonad     xmonad
symlink ~/.irbrc      irbrc
symlink ~/.xmobarrc   xmobarrc
symlink ~/.wallpapers wallpapers


