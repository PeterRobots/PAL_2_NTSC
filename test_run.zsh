#!/usr/bin/env zsh
# ffmpeg -y -stats \
# -hwaccel cuda -hwaccel_output_format cuda \
# -i /home/user/Videos/DS9_S4_D2-B1_t01.mkv \
# -map 0:V -map 0:a:m:language:eng \
# -vf "bwdif_cuda=mode=0,setpts=PTS*1.0427083333333333,fps=fps=ntsc_film,scale_cuda=format=yuv420p" \
# -c:v h264_nvenc -preset p6 -cq 20 \
# -r 24000/1001.0 -fps_mode cfr \
# -af "asetrate=0.9590409590409591*48000,aresample=resampler=soxr:osr=48000" \
# -c:a ac3 -b:a 640k \
# "/home/user/Videos/Processed/DS9_S4_D2-B1_t01.mkv"
# -vf "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film,bwdif_cuda[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"
# -vf "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"

# With outputfile
#     if [[ $(uname) == "Darwin" ]]; then
#         ffmpeg -y -loglevel error -stats -i $F -filter_complex "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film[vout];[0:a:0]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]" -map "[vout]" -map "[aout]" -aspect 4:3 -r:v $rate -vsync cfr -c:v hevc_videotoolbox -q:v 80 -c:a aac -b:a 320k -profile:v main -tag:v hvc1 $OUTPUT/$FN_RESAMPLED
#     else; then
# NVENC is just the encoder and doesn't care a tonne about the rest e.g. -c:v nvenc_hevc -preset slow -b:v 5M
# CUDA is a modern implementation of the gpu acceleration for filters and processing.
# CUVID is the old deprecated version
# You have to input as a cuda stream or upload to the gpu in the filter to use.
# ffmpeg -hwaccel cuda -hwaccel_output_format cuda -i input output
# cuda uses NVDEC to decode the input
# If file has size and is greater than 8.54GB (Dual layer Single Sided DVD-9 standard, max of a common DVD size) =  BLURAY
# if [ $(stat -f%z "$F" 2>/dev/null || stat -c%s "$F") -lt $MAX_DVD_SIZE ]; then
# echo file is not bluray
#         ffmpeg -y -loglevel error -stats -hwaccel cuda -hwaccel_output_format cuda -i $F -filter_complex "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]" -map "[vout]" -map "[aout]" -aspect 4:3 -r:v $rate -vsync cfr -c:v hevc_nvenc -b:v 5M -preset slow -c:a ac3 -b:a 640k $OUTPUT/$FN_RESAMPLED
#         Want to use aac codec -b:a 320k, but ac3 has better surround support. (phone also won't play aac)
#         Example of raw input to cuda for nvidia accelerated split filter
#         ffmpeg -y -vsync 0 -pix_fmt yuv420p -s 1920x1080 -i input.yuv -filter_complex "[0:v]hwupload_cuda,split=4[o1][o2][o3][o4]" -map "[o1]" -c:v h264_nvenc -b:v 8M output1.mp4 -map "[o2]" -c:v h264_nvenc -b:v 10M output2.mp4 -map "[o3]" -c:v h264_nvenc -b:v 12M output3.mp4 -map "[o4]" -c:v h264_nvenc -b:v 14M output4.mp4
# ffmpeg \
# -itsscale 1.0427083333333333 \
# -i \
# -map 0:s \
# -c:s copy \
#
# #
# #
# ffmpeg \
# -y -loglevel verbose -stats \
# -hwaccel cuda -hwaccel_output_format cuda \
# -i /home/user/Videos/DS9_S4_D2-B1_t01.mkv \
# -i /home/user/Videos/subtitles.mkv \
# -map 0:v -map 0:a \
# -vf "bwdif_cuda=mode=0,setpts=PTS*1.0427083333333333,fps=fps=ntsc_film" \
# -c:v h264_nvenc -preset p6 -cq 20 \
# -r 24000/1001 -fps_mode cfr \
# -af "asetrate=0.9590409590409591*48000,aresample=resampler=soxr:osr=48000" \
# -c:a ac3 -b:a 640k \
# -map 1:s -c:s copy \
# -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:eng default -disposition:s:0 0 \
# /home/user/Videos/Processed/DS9_S4_D2-B1_t01.mkv

# ffmpeg \
# -itsscale 1.0427083333333333 \
# -i /home/user/Videos/DS9_S4_D2-B1_t01.mkv \
# -map 0:s -c:s copy \
# -map 0:v -c:v copy \
# -map 0:a -filter:a "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" -c:a ac3 \
# -r 24000/1001 \
# /home/user/Videos/test_lossless.mkv

# ffmpeg \
# -y -loglevel verbose -stats \
# -hwaccel cuda -hwaccel_output_format cuda \
# -itsscale 1.0427083333333333 \
# -i /home/user/Videos/DS9_S4_D2-B1_t01.mkv \
# -map 0:v -map 0:a -map 0:s \
# -vf "bwdif_cuda=mode=0,fps=fps=ntsc_film" \
# -c:v h264_nvenc -preset p6 -cq 20 \
# -af "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" \
# -c:a ac3 -b:a 640k \
# -c:s copy \
# -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:eng default -disposition:s:0 0 \
# -r 24000/1001 -fps_mode cfr \
# /home/user/Videos/Processed/DS9_S4_D2-B1_t01.mkv
# PRESET_COMMANDS=(-c:v hevc_nvenc -preset p7 -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -cq $QUALITY)
# PRESET_COMMANDS=(-c:v libx265 -preset medium -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -crf $QUALITY)
# PRESET_COMMANDS=(-c:v ffv1 -level 3)
# VA-API example of transcope with deinterlace (intel/amd option)
# ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i input.mp4 -vf 'deinterlace_vaapi=rate=field:auto=1,scale_vaapi=w=1280:h=720' -c:v hevc_vaapi -b:v 5M output.mp4

# echo "ffmpeg -y -loglevel $LOG -stats $HW_DECODE_ARGS -i $F ${V_FILTER_ARGS} ${A_FILTER_ARGS} $FRAMERATE_ARGS $V_ENCODE_ARGS $PIX_FMT_ARGS $A_ENCODE_ARGS $OUTPUT"
# ffmpeg \
# -itsscale $((FPS_CORRECTION)) \
# -i "$F" \
# -map 0:s \
# -c:s copy \
# $F_SUBTITLES
# ffmpeg -y -loglevel $LOG -stats $HW_DECODE_ARGS -i "$F" $MAP_ARGS $V_FILTER_ARGS $V_ENCODE_ARGS $FRAMERATE_ARGS $A_FILTER_ARGS $A_ENCODE_ARGS $S_ENCODE_ARGS $DISPOSITION_ARGS "$OUTPUT"

# Lossless video and subtitle timestamp changes with audio resampling
# ffmpeg \
# -itsscale 1.0427083333333333 \ # Has to be a float
# -map 0:s -c:s copy \
# -map 0:v -c:v copy \
# -map 0:a -filter:a "atempo=24000/25025" -c:a ac3 \ # No pitch shift
# -map 0:a -filter:a "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" -c:a ac3 \ # Pitch shift
# -r 24000/1001 \
ffmpeg \
-y -loglevel verbose -stats \
-hwaccel cuda -hwaccel_output_format cuda \
-i /home/user/Videos/DS9_S4_D2-B1_t01.mkv \
-map 0:v -map 0:a -map 0:s \
-vf "bwdif_cuda=mode=0,setpts=PTS*1.0427083333333333,fps=fps=ntsc_film" \
-c:v h264_nvenc -preset p6 -cq 20 \
-af "asetrate=24000/25025*48000,aresample=resampler=soxr:osr=48000" \
-c:a ac3 -b:a 640k \
-c:s copy \
-disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:eng default -disposition:s:0 0 \
-r 24000/1001 -fps_mode cfr \
/home/user/Videos/Processed/DS9_S4_D2-B1_t01.mkv
