#!/usr/bin/env bash

#set -x

function install_spacemacs(){

    if [[ -d ~/.emacs.d ]]
    then
        if [[ `git -C ~/.emacs.d rev-parse 2> /dev/null ` -ne 0 ]]
        then
            rm -rf ~/.emacs.d
        elif [[ `git -C ~/.emacs.d config --get remote.origin.url ` != "https://github.com/syl20bnr/spacemacs" ]]
        then
            rm -rf ~/.emacs.d
        fi
    fi

    if [[ ! -d ~/.emacs.d ]]
    then
        git clone \
            --depth 1 \
            https://github.com/syl20bnr/spacemacs \
            ~/.emacs.d
    fi
}

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
symlink ~/.xmodmap    x11/Xmodmap
symlink ~/.dmenu      dmenu
symlink ~/.xmonad     xmonad
symlink ~/.irbrc      irbrc
symlink ~/.xmobarrc   xmobarrc
symlink ~/.wallpapers wallpapers
symlink ~/.mplayer    mplayer
symlink ~/.config/mimeapps.list    mimeapps.list
symlink ~/.config/Code/User/settings.json vscode/settings.json

install_spacemacs
symlink ~/.spacemacs  spacemacs
