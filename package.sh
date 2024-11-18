#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "USAGE: $0 <package flavor>"
    exit 1
fi

export VERSION=${GITHUB_REF_NAME:-$(git describe --always --tags --dirty=+ --abbrev=6)}

function do_build () {
    CL_SOURCE_REGISTRY=$(pwd) sbcl --dynamic-space-size 2048 --disable-debugger --quit --load package/build.lisp
}

case $1 in
    linux)
        do_build
        DEPLOY_GTK_VERSION=3 linuxdeploy --appimage-extract-and-run --executable=bin/ecs-tutorial-1 \
                    --custom-apprun=package/AppRun \
                    --icon-file=package/icon.png \
                    --desktop-file=package/ecs-tutorial-1.desktop \
                    --plugin gtk \
                    --appdir=appimage $(find bin -name "lib*" -printf "-l%p ")
        cp bin/ecs-tutorial-1 appimage/usr/bin
        cp -R Resources appimage/usr
        appimagetool --appimage-extract-and-run --comp xz -g appimage "ecs-tutorial-1-${VERSION}.AppImage"
        ;;

    windows)
        do_build
        
        ntldd -R bin/* | grep ucrt64 | awk -F '=> ' '{ print $2 }' | awk '{ print $1 }' | sed 's/\\/\\\\/g' | xargs -I deps cp deps bin
        
        (cd "$TEMP"; convert "$OLDPWD/package/icon.png" -define icon:auto-resize=16,32,48,64,256 icon.ico)
        (cd "$TEMP"; convert -resize 150x57 -extent 150x57 -gravity center -background white -alpha remove -alpha off "$OLDPWD/package/icon.png" BMP2:icon.bmp)
        makensis package/installer.nsi
        ;;

    macos)
        do_build
        bundle="ECS Tutorial 1.app"
        contents=$bundle/Contents
        mkdir -p "$contents/MacOS"
        cp -r Resources "$contents"
        cp package/Info.plist "$contents"
        cp package/icon.png "$contents/Resources"
        for library in bin/*.dylib; do
            dylibbundler -of -cd -b -p '@loader_path' -x "$library" -d "$contents/MacOS"
            cp "$library" "$contents/MacOS"
        done
        mv "$contents"/MacOS/libzstd* "$contents/MacOS/libzstd.1.dylib"

        # https://bugs.launchpad.net/sbcl/+bug/1869401
        replace_fr=$(echo -n  "/opt/local/lib/libzstd.1.dylib" | xxd -ps -c1 | tr -d '\n')
        replace_to=$(echo -en "@loader_path/libzstd.1.dylib\x00\x00" | xxd -ps -c1 | tr -d '\n')
        xxd -ps -c1 bin/ecs-tutorial-1 | tr -d '\n' | sed "s/$replace_fr/$replace_to/" | fold -w 2 | xxd -r -p > "$contents/MacOS/ecs-tutorial-1"
        chmod +x "$contents/MacOS/ecs-tutorial-1"

        hdiutil create -quiet -srcfolder "$bundle" out.dmg
        # NOTE: ULMO = lzma compression = Catalina+ only
        hdiutil convert -quiet out.dmg -format ULMO -o "ecs-tutorial-1-${VERSION}.dmg"
        rm out.dmg
        ;;

    *)
        echo "Uknown package flavor: $1"
        exit 1
        ;;
esac
