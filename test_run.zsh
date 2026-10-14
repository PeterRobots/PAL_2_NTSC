#!/usr/bin/env zsh
F_BASE=$(basename $1)
F_NAME="${F_BASE%.*}"
F_CONTAINER="${F_BASE:e}"
F_DIR="${1:h}"
PRESETS=(low medium high)
OUTPUT_ARR=()
mkdir -p "$F_DIR/Processed"

for P in $PRESETS; do
    O_N_H264="$F_DIR/Processed/${F_NAME}_${P}_NVENC_H264.$F_CONTAINER"
    O_N_H265="$F_DIR/Processed/${F_NAME}_${P}_NVENC_H265.$F_CONTAINER"
    O_C_H264="$F_DIR/Processed/${F_NAME}_${P}_CPU_H264.$F_CONTAINER"
    O_C_H265="$F_DIR/Processed/${F_NAME}_${P}_CPU_H265.$F_CONTAINER"
    O_I_H264="$F_DIR/Processed/${F_NAME}_${P}_QSV_H264.$F_CONTAINER"
    O_I_H265="$F_DIR/Processed/${F_NAME}_${P}_QSV_H265.$F_CONTAINER"
    O_A_H264="$F_DIR/Processed/${F_NAME}_${P}_AMF_H264.$F_CONTAINER"
    O_A_H265="$F_DIR/Processed/${F_NAME}_${P}_AMF_H265.$F_CONTAINER"

    COMMON_ARGS=(-i "$1" -al eng -sl none -kla eng,fra -kls eng,fra -p "$P" -ofs ntsc_film)

    ./fix_video_format.zsh $COMMON_ARGS -cv h264 -d nvidia -o $O_N_H264
    ./fix_video_format.zsh $COMMON_ARGS -cv h265 -d nvidia -o $O_N_H265
    ./fix_video_format.zsh $COMMON_ARGS -cv h264 -d intel -o $O_I_H264
    ./fix_video_format.zsh $COMMON_ARGS -cv h265 -d intel -o $O_I_H265
    ./fix_video_format.zsh $COMMON_ARGS -cv h264 -d amd -o $O_A_H264
    ./fix_video_format.zsh $COMMON_ARGS -cv h265 -d amd -o $O_A_H265
    ./fix_video_format.zsh $COMMON_ARGS -cv h264 -d cpu -o $O_C_H264
    ./fix_video_format.zsh $COMMON_ARGS -cv h265 -d cpu -o $O_C_H265

    OUTPUT_ARR+=($O_N_H264 $O_N_H265 $O_C_H264 $O_C_H265 $O_I_H264 $O_I_H265)
done
# REF
O_REF="$F_DIR/Processed/${F_NAME}_REF.$F_CONTAINER"
./fix_video_format.zsh $COMMON_ARGS -cv lossless -d cpu -o $O_REF

echo $OUTPUT_ARR
echo $O_REF

for O in $OUTPUT_ARR; do
    if [[ -f $O ]]; then
        ./test_vmaf.zsh $O $O_REF
    fi
done
