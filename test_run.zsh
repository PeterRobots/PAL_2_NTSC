#!/usr/bin/env zsh
# ffmpeg -y -stats \
# -hwaccel cuda -hwaccel_output_format cuda \
# -i /home/pinzani/Videos/DS9_S4_D2-B1_t01.mkv \
# -map 0:V -map 0:a:m:language:eng \
# -vf "bwdif_cuda=mode=0,setpts=PTS*1.0427083333333333,fps=fps=ntsc_film,scale_cuda=format=yuv420p" \
# -c:v h264_nvenc -preset p6 -cq 20 \
# -r 24000/1001.0 -fps_mode cfr \
# -af "asetrate=0.9590409590409591*48000,aresample=resampler=soxr:osr=48000" \
# -c:a ac3 -b:a 640k \
# "/home/pinzani/Videos/Processed/DS9_S4_D2-B1_t01.mkv"


# ffmpeg \
# -itsscale 1.0427083333333333 \
# -i /home/pinzani/Videos/DS9_S4_D2-B1_t01.mkv \
# -map 0:s \
# -c:s copy \
# /home/pinzani/Videos/subtitles.mkv
# #
# #
# ffmpeg \
# -y -loglevel verbose -stats \
# -hwaccel cuda -hwaccel_output_format cuda \
# -i /home/pinzani/Videos/DS9_S4_D2-B1_t01.mkv \
# -i /home/pinzani/Videos/subtitles.mkv \
# -map 0:v -map 0:a \
# -vf "bwdif_cuda=mode=0,setpts=PTS*1.0427083333333333,fps=fps=ntsc_film" \
# -c:v h264_nvenc -preset p6 -cq 20 \
# -r 24000/1001 -fps_mode cfr \
# -af "asetrate=0.9590409590409591*48000,aresample=resampler=soxr:osr=48000" \
# -c:a ac3 -b:a 640k \
# -map 1:s -c:s copy \
# -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:eng default -disposition:s:0 0 \
# /home/pinzani/Videos/Processed/DS9_S4_D2-B1_t01.mkv

# ffmpeg \
# -itsscale 1.0427083333333333 \
# -i /home/pinzani/Videos/DS9_S4_D2-B1_t01.mkv \
# -map 0:s -c:s copy \
# -map 0:v -c:v copy \
# -map 0:a -filter:a "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" -c:a ac3 \
# -r 24000/1001 \
# /home/pinzani/Videos/test_lossless.mkv

# ffmpeg \
# -y -loglevel verbose -stats \
# -hwaccel cuda -hwaccel_output_format cuda \
# -itsscale 1.0427083333333333 \
# -i /home/pinzani/Videos/DS9_S4_D2-B1_t01.mkv \
# -map 0:v -map 0:a -map 0:s \
# -vf "bwdif_cuda=mode=0,fps=fps=ntsc_film" \
# -c:v h264_nvenc -preset p6 -cq 20 \
# -af "atempo=24000/25025,asetrate=24000/25025*48000,atempo=25025/24000,aresample=resampler=soxr:osr=48000" \
# -c:a ac3 -b:a 640k \
# -c:s copy \
# -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:eng default -disposition:s:0 0 \
# -r 24000/1001 -fps_mode cfr \
# /home/pinzani/Videos/Processed/DS9_S4_D2-B1_t01.mkv

ffmpeg \
-y -loglevel verbose -stats \
-hwaccel cuda -hwaccel_output_format cuda \
-i /home/pinzani/Videos/DS9_S4_D2-B1_t01.mkv \
-map 0:v -map 0:a -map 0:s \
-vf "bwdif_cuda=mode=0,setpts=PTS*1.0427083333333333,fps=fps=ntsc_film" \
-c:v h264_nvenc -preset p6 -cq 20 \
-af "asetrate=24000/25025*48000,aresample=resampler=soxr:osr=48000" \
-c:a ac3 -b:a 640k \
-c:s copy \
-disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:eng default -disposition:s:0 0 \
-r 24000/1001 -fps_mode cfr \
/home/pinzani/Videos/Processed/DS9_S4_D2-B1_t01.mkv
