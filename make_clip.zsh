#!/usr/bin/env zsh
F_BASE=$(basename $1)
F_NAME="${F_BASE%.*}"
F_CONTAINER="${F_BASE:e}"
F_DIR="${1:h}"
OUTPUT="$F_DIR/Processed/${F_NAME}_${P}_clip.$F_CONTAINER"
ffmpeg -i $1 -ss 210 -to 230 -map 0 -c:s copy -c:a copy $OUTPUT
