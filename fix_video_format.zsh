#!/usr/bin/env zsh
INPUT=""
OUTPUT=""
DEVICE="cpu"
TYPE="auto"
LOG="fatal"
PRESET="medium"
V_CODEC="h264"
A_CODEC="aac"
LANGUAGE="keep"
DEINTERLACE=false
DVD_WIDTH=720
DVD_PAL_HEIGHT=576
DVD_NTSC_HEIGHT=480
# Based on Dual layer Single Sided DVD-9 standard, max of a common DVD size (Bytes)
MAX_DVD_SIZE=8540000000

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
    -s|--subtitle-lang)
      LANGUAGE="$2"
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
      echo "  -t, --type            Set type: auto (if > 10GB => br), (DVD) ntsc, (DVD) ntsc_film, (DVD) pal, (BLURAY) br (default: auto)"
      echo "  -v, --log-level       Set/Flag the log level: quiet, panic, fatal, error, warning, info, verbose, debug, trace  (default: fatal)"
      echo "  -s, --subtitle-lang   Set subtitle language filter: keep or standard ffmpeg language stream identifier e.g. eng  (default: keep)"
      echo "  --deinterlace         Flag whether to deinterlace or not: default (off)"
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

# Software or hardware accelerated
case "$DEVICE" in
  cpu)
    HW_ACCEL=""
    DEINTERLACE_FILTER="bwdif"
  ;;
  gpu)
    case "$GPU" in
      nvidia)
        HW_ACCEL=(-hwaccel cuda -hwaccel_output_format cuda)
        DEINTERLACE_FILTER="bwdif_cuda"
      ;;
      amd)
        HW_ACCEL=(-init_hw_device "vulkan=vk:0" -hwaccel vulkan -hwaccel_output_format vulkan)
        # Only deinterlace marked fields
        DEINTERLACE_FILTER="bwdif_vulkan=deint=1"
      ;;
      intel)
        HW_ACCEL=(-hwaccel qsv -qsv_device /dev/dri/renderD128)
        # 2 is advanced motion-adaptive, 1 is bob weaver
        # -init_hw_device "qsv=qsv"
        DEINTERLACE_FILTER="vpp_qsv=deinterlace=2"
      ;;
      mac)
        HW_ACCEL=(-hwaccel videotoolbox -hwaccel_output_format videotoolbox_vld)
        DEINTERLACE_FILTER="bwdif"
      ;;
      vaapi)
        # HW_ACCEL=(-vaapi_device /dev/dri/renderD128)
        HW_ACCEL=(-hwaccel vaapi -hwaccel_output_format vaapi -hwaccel_device /dev/dri/renderD128)
        DEINTERLACE_FILTER="deinterlace_vaapi=rate=field:auto=1"
      ;;
    esac
  ;;
  *)
  echo "Unknown device: $DEVICE"
  exit 2
  ;;
esac


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

  echo "Resampling audio and video"

  # PRESET_COMMANDS=(-c:v hevc_nvenc -preset p7 -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -cq $QUALITY)
  # PRESET_COMMANDS=(-c:v libx265 -preset medium -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -crf $QUALITY)
  # PRESET_COMMANDS=(-c:v ffv1 -level 3)
  # VA-API example of transcope with deinterlace (intel/amd option)
  # ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i input.mp4 -vf 'deinterlace_vaapi=rate=field:auto=1,scale_vaapi=w=1280:h=720' -c:v hevc_vaapi -b:v 5M output.mp4


    IFS=',' read -r -a FFPROBE_ARR <<< ffprobe -v error -show_format -show_entries stream=codec_name,width,height,field_order,r_frame_rate,sample_rate -of default=noprint_wrappers=1 $INPUT
  # SAMPLERATE=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 $F)
  # FPS=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $F)
  # Interlaced
  # INTERLACED=$(ffmpeg -i $INPUT -vf "idet" -f null - 2>&1 | grep "Multi frame")
  # BFF= $(sed -nE 's/.*BFF: (\d+).*/\1/p' $INTERLACED)
  # TFF= $(sed -nE 's/.*TFF: (\d+).*/\1/p' $INTERLACED)
  # If deinterlace and BFF or TFF found
  # if [[ $DEINTERLACE ]] && (( $BFF > 0 || $TFF > 0 )); then
  #   DEINTERLACE_FILTER="bwdif"
  # else
  #   DEINTERLACE_FILTER=""
  # fi
  F_BFF=$(sed -nE 's/.*bb: (\d+).*/\1/p' $FFPROBE_ARR)
  F_TFF=$(sed -nE 's/.*tt: (\d+).*/\1/p' $FFPROBE_ARR)
  F_FPS=$(sed -nE 's/.*fps: (\d+).*/\1/p' $FFPROBE_ARR)
  F_CODEC=$(sed -nE 's/.*codec: (\d+).*/\1/p' $FFPROBE_ARR)
  F_WIDTH=$(sed -nE 's/.*width: (\d+).*/\1/p' $FFPROBE_ARR)
  F_HEIGHT=$(sed -nE 's/.*height: (\d+).*/\1/p' $FFPROBE_ARR)
  echo ${FFPROBE_ARR}
  CORRECTION=$(( 24000/25025.0 ))
  INVERSE_CORRECTION=$(( 1.0/$CORRECTION ))
  CORRECT_SAMPLERATE=$((24000.0/1001.0))
  # FILTER
  case "$TYPE" in
      auto)
      CORRECT_FPS_FILTER="fps=ntsc_film"
      CORRECT_FPS_FILTER="fps=source_fps"
      ;;
      ntsc_film)
      CORRECT_FPS_FILTER="fps=ntsc_film"
      ;;
      ntsc)
      CORRECT_FPS_FILTER="fps=ntsc"
      ;;
      pal)
      CORRECT_FPS_FILTER="fps=pal"
      ;;
      br)
      CORRECT_FPS_FILTER="fps=ntsc_film"
      ;;
      *)
      echo "Unknown preset: $PRESET"
      exit 2
      ;;
  esac
  VIDEO_FILTER_ARR=(setpts=PTS*$INVERSE_CORRECTION $CORRECT_FPS_FILTER $DEINTERLACE_FILTER)
  # AUDIO_FILTER_ARR=(asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout])
  AUDIO_FILTER_ARR=(asetrate=$CORRECTION*$samplerate aresample=resampler=soxr:osr=$samplerate)
  # , delimiter for sub arguments
  VIDEO_FILTER="${(j[,])VIDEO_FILTER_ARR:#}"
  VIDEO_FILTER="$VIDEO_FILTER[vout]"
  AUDIO_FILTER="${(j[,])VIDEO_FILTER_ARR:#}"
  AUDIO_FILTER="$AUDIO_FILTER[aout]"
  FILTER_ARR=()
  if [[ ! -z "$FILTER" ]]; then
    FILTER_ARR+=([0:V:0] $VIDEO_FILTER)
  fi
  if [[ ! -z "$AUDIO_FILTER" ]]; then
    LANG_FILTER="[0:a:m:language:eng]"
    FILTER_ARR+=([0:a:m:language:eng] $AUDIO_FILTER)
  fi
  # VIDEO_FILTER="[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film,bwdif_cuda[vout]"
  # AUDIO_FILTER="[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"
  # ; delimiter for video + audio
  FILTER="${(j[;])FILTER_ARR:#}"

  if [[ ! -z "$FILTER" ]]; then
    FILTER=(-filter_complex "$FILTER")
    if [[ ! -z "$VIDEO_FILTER" ]]; then
    FILTER+=(-map "[vout]")
    fi
    if [[ ! -z "$AUDIO_FILTER" ]]; then
    fi
     FILTER+=(-map "[aout]")
  fi
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
        # If file has size and is greater than 8.54GB (Dual layer Single Sided DVD-9 standard, max of a common DVD size) =  BLURAY
        if [ $(stat -f%z "$F" 2>/dev/null || stat -c%s "$F") -lt $MAX_DVD_SIZE ]; then
            echo file is not bluray
            echo "$PROCESSEDDIR/$FN_NVENC_RESAMPLED"
            ffmpeg \
                -y -loglevel error -stats \
                -hwaccel cuda -hwaccel_output_format cuda -i $F \
                -init_hw_device cuda \
                $FILTER
                 -r:v $rate -vsync cfr -c:v hevc_nvenc -preset p7 -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -cq 18 -c:a ac3 -b:a 640k "$PROCESSEDDIR/$FN_NVENC_RESAMPLED"
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
