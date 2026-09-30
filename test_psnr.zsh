#!/usr/bin/env zsh
F_BASE=$(basename $1)
F_NAME="${F_BASE%.*}"

REF_BASE=$(basename $2)
REF_NAME="${F_BASE%.*}"
REF_DIR="${2:h}"

OUTPUT_LOG="$REF_DIR/psnr_logs/${F_NAME}_vs_ref_${REF_NAME}_psnr.txt"
ffmpeg -hide_banner -y -loglevel fatal -i $1 -i $2 -lavfi "psnr=stats_file=$OUTPUT_LOG" -f null -
