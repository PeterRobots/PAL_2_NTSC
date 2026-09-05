#!/usr/bin/env zsh
# A_FFPROBE_ARR=("${(f)$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels -of default=noprint_wrappers=1 $1)}")
# V_FFPROBE_ARR=("${(f)$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,field_order,r_frame_rate,pix_fmt -of default=noprint_wrappers=1 $1)}")
# # A_FFPROBE_ARR=("${(f)$($(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels -print_format json $1 | jq '.streams'))}")
# # IFS=',' read -r -A FFPROBE_ARR <<< ffprobe -v error -show_format -show_entries stream=codec_name,width,height,field_order,r_frame_rate,sample_rate,pix_fmt,channels -of default=noprint_wrappers=1 $1
# echo $V_FFPROBE_ARR
# echo $A_FFPROBE_ARR
typeset -A A_FFPROBE_DICT
typeset -A V_FFPROBE_DICT
while IFS== read -r key value; do
    A_FFPROBE_DICT[$key]=$value
done < <(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels -of default=noprint_wrappers=1 $1)

while IFS== read -r key value; do
    V_FFPROBE_DICT[$key]=$value
done < <(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,field_order,r_frame_rate,avg_frame_rate,pix_fmt,color_space,color_transfer,color_primaries -of default=noprint_wrappers=1 $1)
echo ${(kv)V_FFPROBE_DICT}
echo ${(kv)A_FFPROBE_DICT}
# ffprobe -v error -select_streams v:0 -show_entries format $1
# ffprobe -v error -select_streams v:0 -show_entries stream $1
# ffprobe -v error -select_streams v:0 -show_entries packet $1
