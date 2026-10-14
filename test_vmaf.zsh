#!/usr/bin/env zsh
F_BASE=$(basename $1)
F_NAME="${F_BASE%.*}"

REF_BASE=$(basename $2)
REF_NAME="${F_BASE%.*}"
REF_DIR="${2:h}"

local CWD="${0:A:h}"

OUTPUT_LOG="$REF_DIR/vmaf_logs/${F_NAME}_vs_ref_${REF_NAME}_vmaf.json"
# echo $OUTPUT_LOG
mkdir -p "$(dirname $OUTPUT_LOG)"
# ffmpeg -i encoded.mp4 -i reference.mp4 -filter_complex "[0:v][1:v]libvmaf=log_fmt=json:log_path=vmaf_output.json:model=version=vmaf_v0.6.1" -f null -
# Default is 1080p model, but version=vmaf_4k_v0.6.1 is 4k
ffmpeg -hide_banner -y -loglevel fatal -i "$1" -i "$2" -filter_complex "[0:v]format=yuv420p10le,setpts=PTS-STARTPTS,fps=ntsc_film[dist];[1:v]format=yuv420p10le,setpts=PTS-STARTPTS,fps=ntsc_film[ref];[dist][ref]libvmaf=feature='name=motion|name=psnr|name=float_ssim|name=float_ms_ssim|name=ciede':log_fmt=json:log_path=$OUTPUT_LOG:n_threads=8:model='path="$CWD"/vmaf_v1.0.16_3d0h.json'" -f null -

