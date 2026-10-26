#!/bin/env zsh
F_BASE=$(basename $1)
F_NAME="${F_BASE%.*}"
F_CONTAINER="${F_BASE:e}"
F_DIR="${1:h}"
mkdir -p "$F_DIR/Processed"
OUTPUT="$F_DIR/Processed/${F_NAME}_clip_call_test.$F_CONTAINER"
# Working libplacebo with vulkan filter
# ffmpeg -hide_banner -y -stats -init_hw_device vulkan=vk:0,disable_multiplane=1 -init_hw_device cuda=cuda@vk -hwaccel cuda -hwaccel_output_format cuda -extra_hw_frames 3 -filter_hw_device vk -itsscale 1.0427083333333333 -i "$1" -map 0:v -map a:m:language:eng -map a:m:language:fre -map s:m:language:eng -map s:m:language:fre -vf "hwupload=derive_device=vulkan,format=vulkan,libplacebo=format=yuv420p:w=1920:h=1080:force_original_aspect_ratio=decrease:normalize_sar=true:extra_opts='upscaler=custom\:upscaler_preset=ewa_lanczos':downscaler=ewa_lanczos,hwupload=derive_device=cuda" -c:v h264_nvenc -preset p6 -b:v 2065060 -maxrate:v 4130121 -bufsize:v 0 -tune hq -rc-lookahead 40 -bf 3 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -rc vbr -cq 21 -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" -c:a ac3 -c:s copy -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:none default -disposition:s:0 0 -r 24000/1001.0 -fps_mode cfr "$OUTPUT"

# nlmeans_vulkan working, remove sar normalize which changed the aspect ratio
# ffmpeg -hide_banner -y -stats -init_hw_device vulkan=vk:0,disable_multiplane=1 -init_hw_device cuda=cuda@vk -hwaccel cuda -hwaccel_output_format cuda -extra_hw_frames 3 -filter_hw_device vk -itsscale 1.0427083333333333 -i "$1" -map 0:v -map a:m:language:eng -map a:m:language:fre -map s:m:language:eng -map s:m:language:fre -vf "hwupload=derive_device=vulkan,format=vulkan,nlmeans_vulkan,libplacebo=format=yuv420p:w=1920:h=1080:force_original_aspect_ratio=decrease:extra_opts='upscaler=custom\:upscaler_preset=ewa_lanczos':downscaler=ewa_lanczos,hwupload=derive_device=cuda" -c:v h264_nvenc -preset p6 -b:v 2065060 -maxrate:v 4130121 -bufsize:v 0 -tune hq -rc-lookahead 40 -bf 3 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -rc vbr -cq 21 -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" -c:a ac3 -c:s copy -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:none default -disposition:s:0 0 -r 24000/1001.0 -fps_mode cfr "$OUTPUT"

# bwdif_vulkan, nlmeans, libplacebo
# ffmpeg -hide_banner -y -stats -init_hw_device vulkan=vk:0,disable_multiplane=1 -init_hw_device cuda=cuda@vk -hwaccel cuda -hwaccel_output_format cuda -extra_hw_frames 3 -filter_hw_device vk -itsscale 1.0427083333333333 -ss 500 -to 510 -i "$1" -map 0:v -map a:m:language:eng -map a:m:language:fre -map s:m:language:eng -map s:m:language:fre -vf "hwupload=derive_device=vulkan,format=vulkan,bwdif_vulkan=mode=send_frame,nlmeans_vulkan=s=1.0,libplacebo=format=yuv420p:w=1920:h=1080:force_original_aspect_ratio=decrease:extra_opts='upscaler=custom\:upscaler_preset=ewa_lanczos':downscaler=ewa_lanczos,hwupload=derive_device=cuda" -c:v h264_nvenc -preset p6 -b:v 2065060 -maxrate:v 4130121 -bufsize:v 0 -tune hq -rc-lookahead 40 -bf 3 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -rc vbr -cq 21 -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" -c:a ac3 -c:s copy -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:none default -disposition:s:0 0 -r 24000/1001.0 -fps_mode cfr "$OUTPUT"

# Only deinterlace interlaced frames SLOW, all seems a lot quicker
# ffmpeg -hide_banner -y -stats -init_hw_device vulkan=vk:0,disable_multiplane=1 -init_hw_device cuda=cuda@vk -hwaccel cuda -hwaccel_output_format cuda -extra_hw_frames 3 -filter_hw_device vk -itsscale 1.0427083333333333 -ss 500 -to 510 -i "$1" -map 0:v -map a:m:language:eng -map a:m:language:fre -map s:m:language:eng -map s:m:language:fre -vf "hwupload=derive_device=vulkan,format=vulkan,bwdif_vulkan=mode=send_frame:deint=interlaced,nlmeans_vulkan=s=1.0,libplacebo=format=yuv420p:w=1920:h=1080:force_original_aspect_ratio=decrease:extra_opts='upscaler=custom\:upscaler_preset=ewa_lanczos4sharpest':downscaler=ewa_lanczos,hwupload=derive_device=cuda" -c:v h264_nvenc -preset p6 -b:v 2065060 -maxrate:v 4130121 -bufsize:v 0 -tune hq -rc-lookahead 40 -bf 3 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -rc vbr -cq 21 -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" -c:a ac3 -c:s copy -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:none default -disposition:s:0 0 -r 24000/1001.0 -fps_mode cfr "$OUTPUT"

# No deint, looks very similar to deint, much faster.
# ffmpeg -hide_banner -y -stats -init_hw_device vulkan=vk:0,disable_multiplane=1 -init_hw_device cuda=cuda@vk -hwaccel cuda -hwaccel_output_format cuda -extra_hw_frames 3 -filter_hw_device vk -itsscale 1.0427083333333333 -ss 500 -to 510 -i "$1" -map 0:v -map a:m:language:eng -map a:m:language:fre -map s:m:language:eng -map s:m:language:fre -vf "hwupload=derive_device=vulkan,format=vulkan,nlmeans_vulkan=s=1.0,libplacebo=format=yuv420p:w=1920:h=1080:force_original_aspect_ratio=decrease:extra_opts='upscaler=custom\:upscaler_preset=ewa_lanczos4sharpest':downscaler=ewa_lanczos,hwupload=derive_device=cuda" -c:v h264_nvenc -preset p6 -b:v 2065060 -maxrate:v 4130121 -bufsize:v 0 -tune hq -rc-lookahead 40 -bf 3 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -rc vbr -cq 21 -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" -c:a ac3 -c:s copy -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:none default -disposition:s:0 0 -r 24000/1001.0 -fps_mode cfr "$OUTPUT"

# No deint, finer nlmeans
# ffmpeg -hide_banner -y -stats -init_hw_device vulkan=vk:0,disable_multiplane=1 -init_hw_device cuda=cuda@vk -hwaccel cuda -hwaccel_output_format cuda -extra_hw_frames 3 -filter_hw_device vk -itsscale 1.0427083333333333 -ss 500 -to 510 -i "$1" -map 0:v -map a:m:language:eng -map a:m:language:fre -map s:m:language:eng -map s:m:language:fre -vf "hwupload=derive_device=vulkan,format=vulkan,nlmeans_vulkan=s=1.0:p=5:r=9,libplacebo=format=yuv420p:w=1920:h=1080:force_original_aspect_ratio=decrease:extra_opts='upscaler=custom\:upscaler_preset=ewa_lanczos4sharpest':downscaler=ewa_lanczos,hwupload=derive_device=cuda" -c:v h264_nvenc -preset p6 -b:v 2065060 -maxrate:v 4130121 -bufsize:v 0 -tune hq -rc-lookahead 40 -bf 3 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -rc vbr -cq 21 -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" -c:a ac3 -c:s copy -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:none default -disposition:s:0 0 -r 24000/1001.0 -fps_mode cfr "$OUTPUT"

# Making a clip without filters
# ffmpeg -hide_banner -y -stats -itsscale 1.0427083333333333 -ss 500 -to 510 -i "$1" -map 0:v -map a:m:language:eng -map a:m:language:fre -map s:m:language:eng -map s:m:language:fre -c:v copy -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" -c:a ac3 -c:s copy -disposition:a:m:language:eng default -disposition:a:0 0 -disposition:s:m:language:none default -disposition:s:0 0 -r 24000/1001.0 -fps_mode cfr "$OUTPUT"

# get idet pattern
ffmpeg -hide_banner -y -stats -i "$1" -map 0:v -vf "idet,metadata=mode=print" -af "atempo=0.9590409590409591,asetrate=0.9590409590409591*48000,atempo=1.0427083333333333,aresample=resampler=soxr:osr=48000" "$OUTPUT"
# [Parsed_idet_0 @ 0x7f41c8003180] Repeated Fields: Neither:130540 Top:    58 Bottom:    77
# [Parsed_idet_0 @ 0x7f41c8003180] Single frame detection: TFF:  9674 BFF:  6495 Progressive: 99655 Undetermined: 14851
# [Parsed_idet_0 @ 0x7f41c8003180] Multi frame detection: TFF: 11459 BFF:  5435 Progressive:113764 Undetermined:    17
# [out#0/matroska @ 0x555775aa8fc0] video:559068KiB audio:0KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: 0.170787%
# frame=130675 fps=536 q=-1.0 Lsize=  560023KiB time=01:27:06.92 bitrate= 877.7kbits/s speed=21.4x elapsed=0:04:03.96
# [libx264 @ 0x555775a33a40] frame I:1806  Avg QP:20.84  size: 20280
# [libx264 @ 0x555775a33a40] frame P:36257 Avg QP:23.54  size:  7933
# [libx264 @ 0x555775a33a40] frame B:92612 Avg QP:25.07  size:  2680
# [libx264 @ 0x555775a33a40] consecutive B-frames:  4.4%  2.2%  3.5% 89.9%
# [libx264 @ 0x555775a33a40] mb I  I16..4: 14.4% 81.0%  4.6%
# [libx264 @ 0x555775a33a40] mb P  I16..4:  4.2% 11.4%  0.7%  P16..4: 52.2% 11.0%  6.9%  0.0%  0.0%    skip:13.5%
# [libx264 @ 0x555775a33a40] mb B  I16..4:  0.3%  0.9%  0.0%  B16..8: 42.6%  2.9%  0.4%  direct: 3.8%  skip:49.1%  L0:45.5% L1:51.1% BI: 3.4%
# [libx264 @ 0x555775a33a40] 8x8 transform intra:72.0% inter:91.1%
# [libx264 @ 0x555775a33a40] coded y,uvDC,uvAC intra: 56.8% 82.3% 32.4% inter: 15.6% 34.9% 1.3%
# [libx264 @ 0x555775a33a40] i16 v,h,dc,p: 31% 25%  5% 39%
# [libx264 @ 0x555775a33a40] i8 v,h,dc,ddl,ddr,vr,hd,vl,hu: 22% 18% 25%  5%  6%  7%  6%  7%  6%
# [libx264 @ 0x555775a33a40] i4 v,h,dc,ddl,ddr,vr,hd,vl,hu: 26% 29% 14%  4%  7%  6%  6%  5%  3%
# [libx264 @ 0x555775a33a40] i8c dc,h,v,p: 50% 19% 22%  8%
# [libx264 @ 0x555775a33a40] Weighted P-Frames: Y:5.3% UV:3.7%
# [libx264 @ 0x555775a33a40] ref P L0: 53.0% 12.0% 24.7%  9.8%  0.5%
# [libx264 @ 0x555775a33a40] ref B L0: 86.6% 10.6%  2.7%
# [libx264 @ 0x555775a33a40] ref B L1: 95.0%  5.0%
# [libx264 @ 0x555775a33a40] kb/s:876.20
