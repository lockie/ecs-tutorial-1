#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "USAGE: $0 <package flavor>"
    exit 1
fi

export VERSION=${GITHUB_REF_NAME:-$(git describe --always --tags --dirty=+ --abbrev=6)}

function do_build () {
    sbcl --dynamic-space-size 2048 --disable-debugger --quit --load package/build.lisp
}

case $1 in
    linux)
        do_build
        linuxdeploy --appimage-extract-and-run --executable=bin/ecs-tutorial-1 \
                    --custom-apprun=package/AppRun \
                    --icon-file=package/icon.png \
                    --desktop-file=package/ecs-tutorial-1.desktop \
                    --appdir=appimage $(find bin -name "lib*" -printf "-l%p ")
        cp bin/ecs-tutorial-1 appimage/usr/bin
        cp -R Resources appimage/usr
        appimagetool --appimage-extract-and-run --comp xz -g appimage "ecs-tutorial-1-${VERSION}.AppImage"
        ;;

    windows)
        if ! command -v mingw-ldd > /dev/null 2>&1
        then
            echo "Missing mingw-ldd helper binary"
            exit 1
        fi
        do_build
        for binary in bin/*; do
            echo -n "${PATH}" | tr ';' '\0' | \
                xargs -t0 mingw-ldd "$binary" --disable-multiprocessing --dll-lookup-dirs | \
                { grep -v -e 'not found' -e 'system32' || test $? = 1; } | \
                awk -F '=> ' '{ print $2 }' | xargs -I deps cp deps bin/
        done
        makensis package/installer.nsi
        ;;

    *)
        echo "Uknown package flavor: $1"
        exit 1
        ;;
esac
