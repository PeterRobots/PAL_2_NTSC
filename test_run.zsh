#!/usr/bin/env zsh
F_BASE=$(basename $1)
F_NAME="${F_BASE%.*}"
F_CONTAINER="${F_BASE:e}"
F_DIR="${1:h}"

OUTPUT_ARR=()
mkdir -p "$F_DIR/Processed"
# DEVICES=(nvidia amd intel apple cpu)
# ENCODERS=(h264 h265)
# PRESETS=(low medium high)

DEVICES=(nvidia)
ENCODERS=(h264)
PRESETS=(medium)

for E in $ENCODERS; do
    for D in $DEVICES; do
        for P in $PRESETS; do
            OUTPUT="$F_DIR/Processed/${F_NAME}_${P}_${D}_${E}.$F_CONTAINER"
            COMMON_ARGS=(-i "$1" -al eng -sl none -kla eng,fra -kls eng,fra -p "$P" -ofs ntsc_film -f)
            ./fix_video_format.zsh $COMMON_ARGS -cv $E -d $D -o $OUTPUT
            OUTPUT_ARR+=($OUTPUT)
        done
    done
done
