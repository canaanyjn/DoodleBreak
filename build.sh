#!/bin/zsh
# 一键打包：swift build → 组装 .app → 生成图标 → 本地签名
set -euo pipefail
cd "${0:A:h}"

BIN_NAME="DoodleBreak"
APP="build/Doodle Break.app"

echo "▶ 编译 (release)…"
swift build -c release

echo "▶ 组装 .app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN_NAME" "$APP/Contents/MacOS/$BIN_NAME"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▶ 生成图标…"
if [[ ! -x build/makeicon || Tools/MakeIcon/main.swift -nt build/makeicon || Sources/DoodleBreak/SketchCore.swift -nt build/makeicon ]]; then
  swiftc -O -o build/makeicon Tools/MakeIcon/main.swift Sources/DoodleBreak/SketchCore.swift
fi
build/makeicon "$APP/Contents/Resources/AppIcon.icns" "build/icon-preview.png"

echo "▶ 签名（本地 ad-hoc）…"
codesign --force --deep --sign - "$APP" 2>/dev/null

echo ""
echo "✅ 打包完成：$APP"
echo "   试运行：open \"$APP\""
echo "   安装：  cp -R \"$APP\" /Applications/"
