#!/usr/bin/env zsh
F_BASE=$(basename $1)
F_NAME="${F_BASE%.*}"
F_CONTAINER="${F_BASE:e}"
F_DIR="${1:h}"
O_N_H264="$F_DIR/Processed/${F_NAME}_NVENC_H264.$F_CONTAINER"
O_N_H265="$F_DIR/Processed/${F_NAME}_NVENC_H265.$F_CONTAINER"
O_C_H264="$F_DIR/Processed/${F_NAME}_CPU_H264.$F_CONTAINER"
O_C_H265="$F_DIR/Processed/${F_NAME}_CPU_H265.$F_CONTAINER"
O_I_H264="$F_DIR/Processed/${F_NAME}_QSV_H264.$F_CONTAINER"
O_I_H265="$F_DIR/Processed/${F_NAME}_QSV_H265.$F_CONTAINER"
# ./fix_video_format.zsh -i $1 -cv h264 -d nvidia -al eng -sl none -p medium -ofs ntsc_film -f -o $O_N_H264
# ./fix_video_format.zsh -i $1 -cv h265 -d nvidia -al eng -sl none -p medium -ofs ntsc_film -f -o $O_N_H265
# ./fix_video_format.zsh -i $1 -cv h264 -d cpu -al eng -sl none -p medium -ofs ntsc_film -f -o $O_C_H264
# ./fix_video_format.zsh -i $1 -cv h265 -d cpu -al eng -sl none -p medium -ofs ntsc_film -f -o $O_C_H265
./fix_video_format.zsh -i $1 -cv h264 -d intel -al eng -sl none -p medium -ofs ntsc_film -f -o $O_I_H264 -v
# ./fix_video_format.zsh -i $1 -cv h265 -d intel -al eng -sl none -p medium -ofs ntsc_film -f -o $O_I_H265
