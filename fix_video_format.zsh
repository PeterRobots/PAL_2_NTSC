#!/usr/bin/env zsh
INPUT=""
OUTPUT=""
DEVICE="cpu"
TYPE="auto"
LOG="fatal"
PRESET="medium"
V_CODEC="h264"
A_CODEC="aac"
DEINTERLACE=false

# ARG INPUT
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      INPUT="$2"
      shift 2 # Past argument only (flag)
      ;;
    -o)
      OUTPUT="$2"
      shift 2
      ;;
    -p|--preset)
      PRESET="$2"
      shift 2
      ;;
    -cv|--video-codec)
      V_CODEC="$2"
      shift 2
      ;;
    -ca|--audio-codec)
      A_CODEC="$2"
      shift 2
      ;;
    -d|--device)
      DEVICE="$2"
      shift 2
      ;;
    -t|--type)
      TYPE="$2"
      shift 2
      ;;
    -v|--log-level)
      if (((quiet panic fatal error warning info verbose debug trace)[(e)$2])); then
        LOG="$2"
        shift 2
      else
        LOG="verbose"
        shift 1
      fi
      ;;
      --deinterlace)
        DEINTERLACE=true
        shift 1
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "  -i                    Set input and container type"
      echo "  -o,                   Set output file, path and container (default </Processed/<input_file>)"
      echo "  -p, --preset          Set quality (higher quality = lower compression) preset: l|low, m|medium, h|high, u|uncompressed  (default: medium)"
      echo "  -cv, --video-codec    Set video codec: h266|vvc, h265|hevc, h264|avc, vp9, av1, av2, ffv1|lossless (default: h264)"
      echo "  -ca, --audio-codec    Set audio codec: HQ: aac, ac3|dolby, eac3|dolbyplus, opus, vorbis ; Lossless: lpcm|pcm|none, flac, alac, truehd ; Legacy: mp3 (default: aac)"
      echo "  -d, --device          Set device: cpu, gpu (autodetect: amd, cuda, intel, mac) (default: cpu)"
      echo "  -t, --type            Set type: auto (if > 10GB => br), (DVD) ntsc, (DVD) pal or (BLURAY) br (default: auto)"
      echo "  -v, --log-level       Set the log level: quiet, panic, fatal, error, warning, info, verbose, debug, trace  (default: fatal)"
      echo "  --deinterlace         Set whether to deinterlace or not: default (off)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done
echo "Converting: "
DIR=$1
echo "$INPUT"
# cd $INPUT

if [ -z "$INPUT" ]; then
    echo "\$INPUT is empty"
    # FILES=(*.mkv)
else
    # echo "\$INPUT is NOT empty"
    if [ -d "$INPUT" ]; then
        FILES=($INPUT/*.mkv)
        echo "grabbing files"
    elif [ -f "$INPUT " ]; then
        FILES=($INPUT)
    else
        echo "$INPUT is NOT a folder"
        return 1 2> /dev/null || exit 1 # exit if seperate process, return if run in source (source or . script.sh)
    fi

fi

# PLATFORM
case "$OSTYPE" in
  darwin*)
    GPU=$(system_profiler SPDisplaysDataType)
    ;;
  linux*)
    GPU=$(lspci | grep -i --color 'vga\|3d\|2d')
    ;;
  msys*)
    GPU=$(wmic path win32_VideoController get caption)
    ;;
  *)
    echo "Unknown platform: $OSTYPE"
    ;;
esac

# Interlaced
INTERLACED=$(ffmpeg -i $INPUT -vf "idet" -f null - 2>&1 | grep "Multi frame")
BFF= $(sed -nE 's/.*BFF: (\d+).*/\1/p' $INTERLACED)
TFF= $(sed -nE 's/.*TFF: (\d+).*/\1/p' $INTERLACED)
# If deinterlace and BFF or TFF found
if [[ $DEINTERLACE ]] && (( $BFF > 0 || $TFF > 0 )); then
  DEINTERLACE_FILTER="bwdif"
else
  DEINTERLACE_FILTER=""
fi

# Quality
case "$PRESET" in
    l|low)
    QUALITY=25
    ;;
    m|medium)
    QUALITY=21
    ;;
    h|high)
    QUALITY=18
    ;;
    u|uncompresssed)
    QUALITY=0
    ;;
    *)
    echo "Unknown preset: $PRESET"
    exit 2
    ;;
esac

# Video Codec quality adjustments
case "$V_CODEC" in
    h266|vvc)
    QUALITY=$((QUALITY+3))
    ;;
    h265|hevc)
    QUALITY=$((QUALITY+2))
    ;;
    h264|avc)
    pass
    ;;
    vp9)
    pass
    ;;
    av1)
    QUALITY=$((QUALITY+2))
    ;;
    av2)
    QUALITY=$((QUALITY+3))
    ;;
    ffv1|lossless)
    QUALITY=0
    ;;
    *)
    echo "Unknown Video codec: $V_CODEC"
    exit 2
    ;;
esac

# Device based codecs
case "$DEVICE" in
  cpu)
    HW_ACCEL=""
    DEINTERLACE_FILTER=()
  ;;
  gpu)
    HW_ACCEL=(-hwaccel vulkan)
    if [ -z $DEINTERLACE_FILTER ]; then
      DEINTERLACE_FILTER=$((DEINTERLACE_FILTER"_vulkan"))
    fi
    case "$GPU" in
      nvidia)
        HW_ACCEL=(-hwaccel cuda)
        if [ -z $DEINTERLACE_FILTER ]; then
          DEINTERLACE_FILTER=$((DEINTERLACE_FILTER"_cuda"))
        fi
      ;;
      amd)
      HW_ACCEL=(-hwaccel vulkan)
        if [ -z $DEINTERLACE_FILTER ]; then
          DEINTERLACE_FILTER=$((DEINTERLACE_FILTER"_vulkan"))
        fi

      ;;
      intel)
        HW_ACCEL=(-hwaccel vaapi)
      ;;
      mac)
        HW_ACCEL=(-hwaccel videotoolbox)
      ;;
    esac
  ;;
  *)
  echo "Unknown device: $DEVICE"
  exit 2
  ;;
esac
# PRESET_COMMANDS=(-c:v hevc_nvenc -preset p7 -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -cq $QUALITY)
# PRESET_COMMANDS=(-c:v libx265 -preset medium -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -crf $QUALITY)
# PRESET_COMMANDS=(-c:v ffv1 -level 3)

# FILTER
if [[ $TYPE == "gif" ]]; then
  arr=("$SETPTS" "$MINTERPOLATE" "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse")
elif [[ $TYPE == "mp4" ]]; then
  arr=("$SETPTS" "$MINTERPOLATE")
else
  arr=("$SETPTS" "$MINTERPOLATE")
fi
# for s in "${arr[@]}"; do
#   [[ -n "$s" ]] && filtered+=($S)
# done
FILTER=$(IFS=","; echo ""${arr:#}"")
if [[ ! -z "$FILTER" ]]; then
  FILTER=(-filter:v $FILTER)
fi


# -vf "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film,bwdif_cuda[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"
# -vf "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"
LOG_DIR="$PROCESSED_DIR/Logs"

mkdir -p $PROCESSED_DIR
mkdir -p $LOG_DIR
# echo $OUTPUT
counter=1
for F in $FILES; do
  echo "iteration = $counter"
  echo "file = $F"

  BASE_FILE=$(basename $INPUT)
  F_NAME="${BASE_FILE%.*}"
  F_CONTAINER="${BASE_FILE#.*}"
  F_PATH="${DIR#*$BASE_FILE}"
  if [ -z $OUTPUT ]; then
      OUTPUT="$F_PATH/Processed/$F_NAME$F_CONTAINER"
  F_CHAPTERS="${OUTPUT%.*}_chapters.txt"

  # 2^x/12
  echo "Resampling audio and video"
  SAMPLERATE=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 $F)
  FPS=$((ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate "$INPUT"))
  CORRECTION=$(( 24000/25025.0 ))
  INVERSE_CORRECTION=$(( 1.0/$factor ))
  CORRECT_SAMPLERATE=$((24000.0/1001.0))
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

#         ffmpeg -y -loglevel error -stats -hwaccel cuda -hwaccel_output_format cuda -i $F -filter_complex "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]" -map "[vout]" -map "[aout]" -aspect 4:3 -r:v $rate -vsync cfr -c:v hevc_nvenc -b:v 5M -preset slow -c:a ac3 -b:a 640k $OUTPUT/$FN_RESAMPLED
#         Want to use aac codec -b:a 320k, but ac3 has better surround support. (phone also won't play aac)
#         Example of raw input to cuda for nvidia accelerated split filter
#         ffmpeg -y -vsync 0 -pix_fmt yuv420p -s 1920x1080 -i input.yuv -filter_complex "[0:v]hwupload_cuda,split=4[o1][o2][o3][o4]" -map "[o1]" -c:v h264_nvenc -b:v 8M output1.mp4 -map "[o2]" -c:v h264_nvenc -b:v 10M output2.mp4 -map "[o3]" -c:v h264_nvenc -b:v 12M output3.mp4 -map "[o4]" -c:v h264_nvenc -b:v 14M output4.mp4
    if [ ! -e $OUTPUT/$FN_NVENC_RESAMPLED ] && [ ! -e "$PROCESSEDDIR/$FN_NVENC_RESAMPLED" ]; then
        if [ $(stat -f%z "$F" 2>/dev/null || stat -c%s "$F") -lt 10737418240 ]; then
            echo file is not bluray
            echo "$PROCESSEDDIR/$FN_NVENC_RESAMPLED"
            ffmpeg \
                -y -loglevel error -stats \
                -hwaccel cuda -hwaccel_output_format cuda -i $F \
                -init_hw_device cuda \
                -filter_complex \
                " \
                    [0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film,bwdif_cuda[vout];
                    [0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]" \
                -map "[vout]" -map "[aout]" -r:v $rate -vsync cfr -c:v hevc_nvenc -preset p7 -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -cq 18 -c:a ac3 -b:a 640k "$PROCESSEDDIR/$FN_NVENC_RESAMPLED"
        fi
    else;
        echo "Processed file found"
    fi
    # if [ ! -e $OUTPUT/$FN_LIB_RESAMPLED ]; then$OUTPUT/$FN_NVENC_RESAMPLED
    #     ffmpeg \
    #         -y -loglevel error -stats -i $F \
    #         -filter_complex \
    #         " \
    #             [0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film,bwdif[vout];
    #             [0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]" \
    #         -map "[vout]" -map "[aout]" -r:v $rate -vsync cfr -c:v libx265 -preset medium -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -crf 17 -c:a ac3 -b:a 640k $OUTPUT/$FN_LIB_RESAMPLED
    # fi

 # -preset lossless
 # -preset p7 -bf 1 and -b_ref_mode middle -spatial-aq 1 -temporal-aq 1
    # echo "extracting chapters"
    # mkvextract "$F" chapters "$OUTPUT/$FN_CHAPTERS"
    # echo "Merging chapters with resampled"
    # mkvmerge -o "$OUTPUT/$FN_FINAL" --chapter-sync "0,25025/24000" --chapters "$OUTPUT/$FN_CHAPTERS" "$OUTPUT/$FN_RESAMPLED" > ${LOGDIR}/${FN_BASE}_merge_out.txt 2> ${LOGDIR}/${FN_BASE}_merge_err.txt
    # echo "Cleaning up..."
    # rm -f "$F.lwi"
    # rm -f script.avs
    # rm -f "$OUTPUT/$FN_CHAPTERS"
    # mv "$OUTPUT/${FN_BASE}_final.mkv" "$OUTPUT/$FN"
      # SCRIPT="$OUTPUT/script.avs"
  # echo "A = FFVideoSource(\"$F\")" > $SCRIPT
  # echo "B = FFAudioSource(\"$F\")" >> $SCRIPT
  # echo "AudioDub(A,B)" >> $SCRIPT
  # echo "FFmpegSource2(\"$F\")" > $SCRIPT
  # echo "AssumeFPS(24000,1001,sync_audio=true)" >> $SCRIPT
  # echo "ResampleAudio(48000)" >> $SCRIPT
    echo "Done."
    let counter++
done
