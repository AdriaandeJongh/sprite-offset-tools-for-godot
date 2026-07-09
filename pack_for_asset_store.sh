#!/usr/bin/env bash
cd "$(dirname "$0")"
zip -r sprite_offset_tools.zip addons -x "*.DS_Store" -x "*__MACOSX"
