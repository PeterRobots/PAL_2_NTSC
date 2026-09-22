#!/usr/bin/env zsh
F_DIR="${1:h}"
OUTPUT="$F_DIR/Processed/$(basename $INPUT)"
# Lossless video and subtitle timestamp changes with audio resampling
# ffmpeg \
# -itsscale 1.0427083333333333 \ # Has to be a float
# -map 0:s -c:s copy \
# -map 0:v -c:v copy \
# -map 0:a -filter:a "atempo=24000/25025" -c:a ac3 \ # No pitch shift
# -map 0:a -filter:a "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" -c:a ac3 \ # Pitch shift
# -r 24000/1001 \

# Cuda
# ffmpeg \
# -y -loglevel verbose -stats \
# -hwaccel cuda -hwaccel_output_format cuda \
# -i "$1" \
# -map 0:v -map 0:a -map 0:s \
# -vf "scale_cuda=format=nv12,bwdif_cuda=mode=0,fps=fps=ntsc_film" \
# -c:v h264_nvenc -preset p6 -cq 20 \
# -af "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" \
# -c:a ac3 -b:a 640k \
# -c:s copy \
# -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:eng default -disposition:s:0 0 \
# -fps_mode passthrough \
# "$OUTPUT"

# Apple
ffmpeg \
-y -loglevel verbose -stats \
-init_hw_device videotoolbox -hwaccel videotoolbox -hwaccel_output_format videotoolbox_vld \
-i "$1" \
-map 0:v -map 0:a \
-vf "hwdownload,format=$PIX_FMT,bwdif=mode=0,fps=fps=ntsc_film,hwupload=videotoolbox" \
-c:v h264_videotoolbox -q:v 92 \
-af "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" \
-c:a ac3 -b:a 224k \
-disposition:a:m:language:eng default -disposition:a:0 0 \
-fps_mode passthrough \
"$OUTPUT"
