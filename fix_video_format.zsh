#!/usr/bin/env zsh
INPUT=""
OUTPUT=""
DEVICE="auto"
LOG="fatal"
PRESET="medium"
V_CODEC="h264"
A_CODEC="ac3"
LANGUAGE="keep"
PIX_FMT="keep"
FIX_TYPE="p2nf"
DEINTERLACE=false
A_BITRATE=320k

# Constants
readonly SUPPORTED_GPUS=(nvidia amd intel apple)
readonly DVD_WIDTH=720
# PAL
readonly PAL_DVD_HEIGHT=576
readonly PAL_DVD_WIDTH=704
readonly PAL_DVD_SCANLINES=625
readonly PAL_DVD_COLOR_SPACE=("bt470bg")
readonly PAL_FRAMERATE=25.0
# NTSC
readonly NTSC_DVD_SCANLINES=525
readonly NTSC_DVD_HEIGHT=480
readonly NTSC_DVD_WIDTH=680
readonly NTSC_DVD_COLOR_SPACE=("smpte170m" "smpte240m")
readonly NTSC_FILM_FRAMERATE=24000/1001.0
readonly NTSC_FRAMERATE=30000/1001.0
# Based on Dual layer Single Sided DVD-9 standard, max of a common DVD size 8.54GB (Bytes)
readonly DVD_MAX_SIZE=8540000000
readonly HD_COLOR_SPACE=("bt709" "bt2020")
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
    -s|--subtitle-lang)
      LANGUAGE="$2"
      shift 2
      ;;
    -t|--fix-type)
      FIX_TYPE="$2"
      shift 2
      ;;
    -bp|--bit-pixel-format)
      PIX_FMT="$2"
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
        DEINTERLACE=false
        shift 1
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "  -i                    Set input and container type"
      echo "  -o,                   Set output file, path and container (default </Processed/<input_file>)"
      echo "  -p, --preset          Set quality (higher quality = lower compression) preset: l|low, m|medium, h|high, u|uncompressed, k|keep  (default: medium)"
      echo "  -t, --fix-type        Set the fix type: pal2ntsc|p2n, pal2ntscfilm|p2nf, pal2pal|p2p, ntsc2pal|n2p, ntsc2ntscfilm|n2nf, ntsc2ntsc|n2n, ntscfilm2pal|nf2p, ntscfilm2ntscfilm|nf2nf, ntscfilm2ntsc|nf2n  (default:pal2ntscfilm)"
      echo "  -cv, --video-codec    Set video codec: keep (maintain input codec), h266|vvc, h265|hevc, h264|avc, vp9, av1, av2, ffv1|lossless (default: h264)"
      echo "  -ca, --audio-codec    Set audio codec: keep (maintain input codec), HQ: aac, ac3|dolby, eac3|dolbyplus, opus, vorbis ; Lossless: lpcm|pcm|none, flac, alac, truehd ; Legacy: mp3 (default: ac3)"
      echo "  -d, --device          Set device: auto (gpu with cpu fallback), cpu, gpu (autodetect: amd, nvidia, intel, mac) (default: auto)"
      echo "  -v, --log-level       Set/Flag the log level: quiet, panic, fatal, error, warning, info, verbose, debug, trace  (default: fatal)"
      echo "  -bp, --bit-pixel-format  Set bit pixel format: 8, 10, keep  (default: keep)"
      echo "  -s, --subtitle-lang   Set subtitle language filter: keep or standard ffmpeg language stream identifier e.g. eng  (default: keep)"
      echo "  --no-deinterlace      Flag no deinterlace"
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
    elif [ -f "$INPUT" ]; then
        FILES=($INPUT)
    else
        echo "$INPUT is NOT a folder"
        return 1 2> /dev/null || exit 1 # exit if seperate process, return if run in source (source or . script.sh)
    fi

fi

# PLATFORM
case "$OSTYPE" in
  darwin*)
    GPU=$(system_profiler SPDisplaysDataType | grep -i "chipset")
    AVAILABLE_A_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*A.*/ && $2 ~ /\w+/ {print $2}')}")
    AVAILABLE_V_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*V.*/ && $2 ~ /\w+/ {print $2}')}")
    ;;
  linux*)
    GPU=$(lspci | grep -i --color 'vga\|3d\|2d')
    AVAILABLE_A_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*A.*/ && $2 ~ /\w+/ {print $2}')}")
    AVAILABLE_V_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*V.*/ && $2 ~ /\w+/ {print $2}')}")
    ;;
  msys*)
    # GPU=$(wmic path win32_VideoController get caption)
    GPU=$(lspci | grep -i --color 'vga\|3d\|2d')
    AVAILABLE_A_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*A.*/ && $2 ~ /\w+/ {print $2}')}")
    AVAILABLE_V_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*V.*/ && $2 ~ /\w+/ {print $2}')}")
    ;;
  *)
    echo "Unknown platform: $OSTYPE"
    ;;
esac

# Quality
case "$PRESET" in
    l|low)
    QUALITY=25
    PRESET_ARG=4
    BIT_RATE=192
    ;;
    m|medium)
    QUALITY=21
    GPU_PRESET_ARG=6
    CPU_PRESET_ARG=slower
    BIT_RATE=256
    ;;
    h|high)
    QUALITY=18
    GPU_PRESET_ARG=7
    CPU_PRESET_ARG=slower
    BIT_RATE=640
    ;;
    u|uncompresssed)
    QUALITY=0
    PRESET_ARG=0
    BIT_RATE=0
    ;;
    k|keep)
    QUALITY=-1
    PRESET_ARG=-1
    BIT_RATE=-1
    ;;
    *)
    echo "Unknown preset: $PRESET"
    exit 2
    ;;
esac

get_fix_filters() {
  case "$FIX_TYPE" in
      pal2ntsc|p2n)
        CORRECT_FPS_FILTER="fps=ntsc"
        CORRECT_FPS=$NTSC_FRAMERATE
      ;;
      pal2ntscfilm|p2nf)
        CORRECT_FPS_FILTER="fps=ntsc_film"
        CORRECT_FPS=$NTSC_FILM_FRAMERATE
      ;;
      pal2pal|p2p)
        CORRECT_FPS_FILTER="fps=source_fps"
        CORRECT_FPS=$PAL_FRAMERATE
      ;;
      ntsc2pal|n2p)
        CORRECT_FPS_FILTER="fps=pal"
        CORRECT_FPS=$PAL_FRAMERATE
      ;;
      ntsc2ntscfilm|n2nf)
        CORRECT_FPS_FILTER="fps=ntsc_film"
        CORRECT_FPS=$NTSC_FILM_FRAMERATE
      ;;
      ntsc2ntsc|n2n)
        CORRECT_FPS_FILTER="fps=source_fps"
        CORRECT_FPS=$NTSC_FRAMERATE
      ;;
      ntscfilm2ntscfilm|nf2nf)
        CORRECT_FPS_FILTER="fps=source_fps"
        CORRECT_FPS=$NTSC_FILM_FRAMERATE
      ;;
      ntscfilm2ntsc|nf2n)
        CORRECT_FPS_FILTER="fps=ntsc"
        CORRECT_FPS=$NTSC_FRAMERATE
      ;;
      ntscfilm2pal|nf2p)
        CORRECT_FPS_FILTER="fps=pal"
        CORRECT_FPS=$PAL_FRAMERATE
      ;;
      *)
      echo "Unknown fix-type $FIX_TYPE"
      exit 2
      ;;
  esac
}

get_a_encode_args() {
  A_ENCODE_ARGS=(-c:a)
  case "$A_CODEC" in
      aac)
        A_ENCODE_ARGS+=(libfdk_aac -b:a ${BIT_RATE}k)
      ;;
      ac3|dolby)
        if (( ${AVAILABLE_A_CODECS[(Ie)libfdk_aac]} )); then
          # libfdk_aac is proprietary but a lot better, if available use it.
          A_ENCODE_ARGS+=(libfdk_aac -b:a ${BIT_RATE}k)
        else
          A_ENCODE_ARGS+=(aac -b:a ${BIT_RATE}k)
        fi
      ;;
      eac3|dolbyplus)
        A_ENCODE_ARGS+=(eac3 -b:a ${BIT_RATE}k)
      ;;
      opus)
        A_ENCODE_ARGS+=(libopus -b:a ${BIT_RATE}k)
      ;;
      vorbis)
        A_ENCODE_ARGS+=(libvorbis -b:a ${BIT_RATE}k)
      ;;
      lpcm|pcm|none)
        A_ENCODE_ARGS+=(pcm_s16le -b:a ${BIT_RATE}k)
      ;;
      flac)
        A_ENCODE_ARGS+=(flac -b:a ${BIT_RATE}k)
      ;;
      alac)
        A_ENCODE_ARGS+=(alac -b:a ${BIT_RATE}k)
      ;;
      copy)
        A_ENCODE_ARGS+=(copy)
      ;;
      mp3)
        A_ENCODE_ARGS+=(libmp3lame -b:a ${BIT_RATE}k)
      ;;
      *)
      if (( ${AVAILABLE_A_CODECS[(Ie)$A_CODEC]} )); then
        A_ENCODE_ARGS+=($A_CODEC -b:a ${BIT_RATE}k)
      elif [[ "${NEED_FIXING:l}" == "false" ]]; then
        # If it doesn't need fixing, copy the audio stream
        A_ENCODE_ARGS+=(copy)
      else
        echo "Unknown Video codec: $A_CODEC"
        exit 2
      fi
      ;;
  esac
}

get_device() {
  for S_GPU in $SUPPORTED_GPUS; do
    if [[ ${GPU:l} == *"$S_GPU"* ]]; then
      GPU="$S_GPU"
      DEVICE="gpu"
      break
    fi
  done
  # If no match to gpu use cpu
  if [[ ${DEVICE:l} == "auto" ]]; then
    DEVICE="cpu"
  fi
}

get_device_args() {
  V_ENCODE_ARGS=(-c:v)
  case "$DEVICE" in
    cpu)
      HW_DECODE_ARGS=""
      DEINTERLACE_FILTER="bwdif"
      case "$V_CODEC" in
          h266|vvc)
            QUALITY=$((QUALITY+3))
            V_ENCODE_ARGS+=(libvvenc -preset $PRESET_ARG $PIX_FMT_ARGS -qp $QUALITY)
          ;;
          h265|hevc)
            QUALITY=$((QUALITY+2))
            V_ENCODE_ARGS+=(libx265 -preset $PRESET_ARG $PIX_FMT_ARGS -crf $QUALITY)
          ;;
          h264|avc)
            V_ENCODE_ARGS+=(libx264 -preset $PRESET_ARG $PIX_FMT_ARGS -crf $QUALITY)
          ;;
          vp9)
            V_ENCODE_ARGS+=(libvpx-vp9 -quality $PRESET_ARG -speed $PRESET_SPEED $PIX_FMT_ARGS -crf $QUALITY --auto-alt-ref=1 -lag-in-frames 25 -row-mt 1)
          ;;
          av1)
            QUALITY=$((QUALITY+2))
            V_ENCODE_ARGS+=(libsvtav1 -preset $PRESET_ARG -svtav1-params tune=0 $PIX_FMT_ARGS -crf $QUALITY)
          ;;
          ffv1|lossless)
            V_ENCODE_ARGS+=(ffv1 -level 3 $PIX_FMT_ARGS)
          ;;
          mpeg2video)
          # qscale is from 2-31, 2 is highest quality
            V_ENCODE_ARGS+=(mpeg2video $PIX_FMT_ARGS -qscale:v $(QUALITY-16))
          ;;
          *)
          echo "Unknown Video codec: $V_CODEC"
          exit 2
          ;;
      esac
    ;;
    gpu)
      case "$GPU" in
        nvidia)
            HW_DECODE_ARGS=(-hwaccel cuda -hwaccel_output_format cuda)
            # HW_INIT_FILTER=""
            DEINTERLACE_FILTER="bwdif_cuda"
            case "$V_CODEC" in
              h265|hevc)
                QUALITY=$((QUALITY+1))
                V_ENCODE_ARGS+=(hevc_nvenc -preset p${PRESET_ARG} $PIX_FMT_ARGS -cq $QUALITY)
              ;;
              h264|avc)
                QUALITY=$((QUALITY-1))
                V_ENCODE_ARGS+=(h264_nvenc -preset p${PRESET_ARG} $PIX_FMT_ARGS -cq $QUALITY)
              ;;
              av1)
                QUALITY=$((QUALITY+1))
                V_ENCODE_ARGS+=(av1_nvenc -preset p${PRESET_ARG} $PIX_FMT_ARGS -cq $QUALITY)
              ;;
              *)
                echo "Unknown or unsupported Video codec for $GPU: $V_CODEC"
                exit 2
              ;;
            esac
        ;;
        amd)
          # ffmpeg -init_hw_device vulkan=vk:0 -init_hw_device amf=amf@vk:0 \
          # -hwaccel amf -hwaccel_output_format amf_surface \
          # -vf "hwmap=derive_device=vulkan,format=vulkan"
          HW_DECODE_ARGS=(-init_hw_device vulkan=vk:0 -init_hw_device amf=amf@vk:0 -hwaccel amf -hwaccel_output_format amf_surface)
          # HW_DECODE_ARGS=(-init_hw_device "vulkan=vk:0" -hwaccel vulkan -hwaccel_output_format vulkan -filter_hw_device vk)
          # Only deinterlace marked fields
          DEINTERLACE_FILTER="hwmap=derive_device=vulkan,format=vulkan,bwdif_vulkan=mode=send_frame"
          # HW_INIT_FILTER="hwupload"
          case "$V_CODEC" in
            h265|hevc)
              QUALITY=$((QUALITY+2))
              # Alternative to -qp: -rc cqp -qp_i $QUALITY -qp_p $QUALITY -qp_b $QUALITY
              V_ENCODE_ARGS+=(hevc_amf -preset $PRESET $PIX_FMT_ARGS -qp $QUALITY)
            ;;
            h264|avc)
              V_ENCODE_ARGS+=(h264_amf -preset $PRESET $PIX_FMT_ARGS -qp $QUALITY)
            ;;
            av1)
              QUALITY=$((QUALITY+2))
              V_ENCODE_ARGS+=(av1_amf -preset $PRESET $PIX_FMT_ARGS -qp $QUALITY)
            ;;
            *)
              echo "Unknown or unsupported Video codec for $GPU: $V_CODEC"
              exit 2
            ;;
          esac
        ;;
        intel)
          HW_DECODE_ARGS=(-init_hw_device qsv=hw:autodetect -hwaccel qsv -filter_hw_device hw -hwaccel_output_format qsv)
          # -qsv_device /dev/dri/renderD128
          # 2 is advanced motion-adaptive, 1 is bob weaver
          DEINTERLACE_FILTER="vpp_qsv=deinterlace=2"
          case "$V_CODEC" in
            h265|hevc)
              QUALITY=$((QUALITY+2))
              V_ENCODE_ARGS+=(hevc_qsv -preset $PRESET_ARG $PIX_FMT_ARGS -crf $QUALITY)
            ;;
            h264|avc)
              V_ENCODE_ARGS+=(hevc_qsv -preset $PRESET_ARG $PIX_FMT_ARGS -crf $QUALITY)
            ;;
            av1)
              QUALITY=$((QUALITY+2))
              V_ENCODE_ARGS+=(av1_qsv -preset $PRESET_ARG $PIX_FMT_ARGS -global_quality $QUALITY -extbrc 1 -look_ahead_depth 40 -adaptive_i 1 -adaptive_b 1)
            ;;
            *)
              echo "Unknown or unsupported Video codec for $GPU: $V_CODEC"
              exit 2
            ;;
          esac
        ;;
        apple|mac)
          HW_DECODE_ARGS=(-hwaccel videotoolbox -hwaccel_output_format videotoolbox_vld)
          DEINTERLACE_FILTER="bwdif"
          case "$V_CODEC" in
            h265|hevc)
              QUALITY=$((4*(QUALITY)))
              # -tag:v hvc1 sets fourcc code to apple quicktime playback compatibility, hev1 is default fourcc code and not recognised by apple.
              V_ENCODE_ARGS+=(hevc_videotoolbox -preset $PRESET_ARG -tag:v hvc1 $PIX_FMT_ARGS -q:v $QUALITY)
            ;;
            h264|avc)
              QUALITY=$((4*(QUALITY+2)))
              V_ENCODE_ARGS+=(h264_videotoolbox -preset $PRESET_ARG $PIX_FMT_ARGS -q:v $QUALITY)
            ;;
            *)
              echo "Unknown or unsupported Video codec for $GPU: $V_CODEC"
              exit 2
            ;;
          esac
        ;;
      esac
    ;;
    *)
    echo "Unknown device: $DEVICE"
    exit 2
    ;;
  esac
  VIDEO_CODEC_ARGS+=(-bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1)
}

# -vf "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film,bwdif_cuda[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"
# -vf "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film[vout];[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"

if [[ ${DEVICE:l} == "auto" ]]; then
  get_device
fi
echo $DEVICE $GPU
counter=1
for F in $FILES; do
  echo "iteration = $counter"
  echo "file = $F"

  F_BASE=$(basename $INPUT)
  F_NAME="${F_BASE%.*}"
  echo "File name = $F_NAME"
  F_CONTAINER="${F_BASE:e}"
  echo "File container = $F_CONTAINER"
  F_DIR="${F:h}"
  echo "File dir = $F_DIR"
  if [ -z $OUTPUT ]; then
      OUTPUT="$F_DIR/Processed/$F_NAME$F_CONTAINER"
  fi
  echo "Output = $OUTPUT"
  F_CHAPTERS="${OUTPUT%.*}_chapters.txt"
  OUTPUT_DIR=${OUTPUT:h}
  LOG_DIR="$OUTPUT_DIR/Logs"

  if [[ ! -d $OUTPUT_DIR ]]; then
    mkdir -p $OUTPUT_DIR
  fi
  mkdir -p $LOG_DIR

  echo "Resampling audio and video"

  # PRESET_COMMANDS=(-c:v hevc_nvenc -preset p7 -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -cq $QUALITY)
  # PRESET_COMMANDS=(-c:v libx265 -preset medium -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1 -crf $QUALITY)
  # PRESET_COMMANDS=(-c:v ffv1 -level 3)
  # VA-API example of transcope with deinterlace (intel/amd option)
  # ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i input.mp4 -vf 'deinterlace_vaapi=rate=field:auto=1,scale_vaapi=w=1280:h=720' -c:v hevc_vaapi -b:v 5M output.mp4
  typeset -A A_FFPROBE_DICT
  typeset -A V_FFPROBE_DICT
  while IFS== read -r key value; do
    A_FFPROBE_DICT=$value
  done < <(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels -of default=noprint_wrappers=1 $F)

  while IFS== read -r key value; do
    V_FFPROBE_DICT[$key]=$value
  done < <(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,field_order,r_frame_rate,pix_fmt -of default=noprint_wrappers=1 $F)
  # A_FFPROBE_ARR=("${(f)$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels -of default=noprint_wrappers=1 $F)}")
  # V_FFPROBE_ARR=("${(f)$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,field_order,r_frame_rate,pix_fmt -of default=noprint_wrappers=1 $F)}")
  # Example output of ffprobe
  # Video
  # codec_name=mpeg2video
  # width=720
  # height=576
  # pix_fmt=yuv420p
  # field_order=tt
  # r_frame_rate=25/1
  # \w+ >=1 alphanumeric and _, \d+ >=1 number
  F_V_CODEC=$V_FFPROBE_DICT[codec_name]
  F_V_FIELD_ORDER=$V_FFPROBE_DICT[field_order]
  F_V_FPS=$V_FFPROBE_DICT[r_frame_rate]
  F_V_WIDTH=$V_FFPROBE_DICT[width]
  F_V_HEIGHT=$V_FFPROBE_DICT[height]
  F_V_PIX_FMT=$V_FFPROBE_DICT[pix_fmt]
  # F_V_CODEC=$(sed -nE 's/.*codec_name=(\w+).*/\1/p' $V_FFPROBE_ARR)
  # F_V_FIELD_ORDER=$(sed -nE 's/.*field_order=(\w+).*/\1/p' $V_FFPROBE_ARR)
  # F_V_FPS=$(sed -nE 's/.*r_frame_rate=(\d+).*/\1/p' $V_FFPROBE_ARR)
  # F_V_WIDTH=$(sed -nE 's/.*width=(\d+).*/\1/p' $V_FFPROBE_ARR)
  # F_V_HEIGHT=$(sed -nE 's/.*height=(\d+).*/\1/p' $V_FFPROBE_ARR)
  # F_V_PIX_FMT=$(sed -nE 's/.*pix_fmt=(\w+).*/\1/p' $V_FFPROBE_ARR)
  # Audio
  # codec_name=ac3
  # sample_rate=48000
  # channels=6
  # r_frame_rate=0/0
  # bit_rate=384000
  F_A_CODEC=$A_FFPROBE_DICT[codec_name]
  F_A_SAMPLERATE=$A_FFPROBE_DICT[sample_rate]
  F_A_BITRATE=$A_FFPROBE_DICT[bit_rate]
  F_A_CHANNELS=$A_FFPROBE_DICT[channels]
  # F_A_CODEC=$(sed -nE 's/.*codec_name=(\w+).*/\1/p' $A_FFPROBE_ARR)
  # F_A_SAMPLERATE=$(sed -nE 's/.*sample_rate=(\d+).*/\1/p' $A_FFPROBE_ARR)
  # F_A_BITRATE=$(sed -nE 's/.*bit_rate=(\d+).*/\1/p' $A_FFPROBE_ARR)
  # F_A_CHANNELS=$(sed -nE 's/.*channels=(\d+).*/\1/p' $A_FFPROBE_ARR)

  if [[ $V_CODEC == 'keep' ]]; then
    V_CODEC=$F_V_CODEC
  fi
  get_device_args
  if [[ $A_CODEC == 'keep' ]]; then
    A_CODEC=$F_A_CODEC
  fi

  get_a_encode_args

  case "$PIX_FMT" in
      keep)
        PIX_FMT_ARGS=(-pix_fmt $F_V_PIX_FMT)
        PIX_FMT_FILTER=(format=$F_V_PIX_FMT)
      ;;
      8)
      case "$DEVICE" in
        cpu)
          PIX_FMT_ARGS=(-pix_fmt yuv420p)
          PIX_FMT_FILTER=(format=yuv420p)
        ;;
        gpu)
          PIX_FMT_ARGS=(-pix_fmt nv12)
          PIX_FMT_FILTER=(format=nv12)
        ;;
        *)
          echo "Unknown device: $DEVICE"
          exit 2
        ;;
      esac
      ;;
      10)
      case "$DEVICE" in
        cpu)
          PIX_FMT_ARGS=(-pix_fmt yuv420p10le)
          PIX_FMT_FILTER=(format=yuv420p10le)
        ;;
        gpu)
          PIX_FMT_ARGS=(-pix_fmt p010le)
          PIX_FMT_FILTER=(format=p010le)
        ;;
        *)
          echo "Unknown device: $DEVICE"
          exit 2
        ;;
      esac
      ;;
      *)
      echo "Unknown bit pixel format: $PIX_FMT"
      exit 2
      ;;
  esac

  # FILTER
  get_fix_filters
  FPS_CORRECTION=$(( CORRECT_FPS / F_V_FPS ))
  INVERSE_FPS_CORRECTION=$(( F_V_FPS / CORRECT_FPS ))
  echo $F_V_FPS $CORRECT_FPS $FPS_CORRECTION
  # VIDEO_FILTER="[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film,bwdif_cuda[vout]"
  VIDEO_FILTER_ARR=(-vf "setpts=PTS*$INVERSE_FPS_CORRECTION" $CORRECT_FPS_FILTER)
  if [[ $DEINTERLACE ]] && [[ $F_V_FIELD_ORDER!="progressive" ]]; then
    VIDEO_FILTER_ARR+=($DEINTERLACE_FILTER)
  fi

  if [[ ! -z $LANGUAGE ]]; then
    LANG_FILTER="[0:a:m:language:$LANGUAGE]"
  else
    LANG_FILTER="[0:a:0]"
  fi

  # AUDIO_FILTER="[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"
  AUDIO_FILTER_ARR=("asetrate=$CORRECTION*$samplerate" "aresample=resampler=soxr:osr=$samplerate")
  # , delimiter for sub arguments
  VIDEO_FILTER="${(j[,])VIDEO_FILTER_ARR:#}"
  VIDEO_FILTER="$VIDEO_FILTER[vout]"
  AUDIO_FILTER="${(j[,])VIDEO_FILTER_ARR:#}"
  AUDIO_FILTER="$AUDIO_FILTER[aout]"
  if [[ ! -z "$VIDEO_FILTER" ]]; then
    V_FILTER_ARGS=(-vf $VIDEO_FILTER)
    FRAMERATE_ARGS=(-r:v $rate -vsync cfr)
  else
    V_FILTER_ARGS=()
    FRAMERATE_ARGS=(-fps_mode passthrough)
  fi
  if [[ ! -z "$AUDIO_FILTER" ]]; then
    A_FILTER_ARGS=(-filter$LANG_FILTER $LANG_FILTER $AUDIO_FILTER)
  else
    A_FILTER_ARGS=()
  fi

  # FILTER_ARR=()
  # ; delimiter for video + audio
  # FILTER="${(j[;])FILTER_ARR:#}"
  # if [[ ! -z "$FILTER" ]]; then
  #   FILTER=(-filter_complex "$FILTER")
  #   if [[ ! -z "$VIDEO_FILTER" ]]; then
  #     FILTER+=(-map "[vout]")
  #   fi
  #
  #   if [[ ! -z "$AUDIO_FILTER" ]]; then
  #     FILTER+=(-map "[aout]")
  #   fi
  # fi
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
    if [[ ! -e $OUTPUT ]]; then
      # if [[ $PRESET=="keep" && $V_CODEC-="keep" && $A_CODEC=="keep" && $LANGUAGE=="keep" && $PIX_FMT=="keep" && $FIX_TYPE=="p2nf" && ! $DEINTERLACE ]]

        # echo "$PROCESSEDDIR/$FN_NVENC_RESAMPLED"
        # ffmpeg \
          # -y -loglevel $LOG -stats \
          # $HW_DECODE_ARGS \
          # -i $F \
          # $V_FILTER_ARGS \
          # $A_FILTER_ARGS \
          # $FRAMERATE_ARGS \
          # $V_ENCODE_ARGS \
          # $PROFILE_ARGS \
          # $BIT_FORMAT_ARGS \
          # $A_ENCODE_ARGS \
          # "$F_OUTPUT" \
cat << EOF
-y -loglevel $LOG -stats
$HW_DECODE_ARGS
-i $F
$V_FILTER_ARGS
$A_FILTER_ARGS
$FRAMERATE_ARGS
$V_ENCODE_ARGS
$PROFILE_ARGS
$BIT_FORMAT_ARGS
$A_ENCODE_ARGS
$F_OUTPUT
EOF
        # fi
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
