#!/usr/bin/env zsh
zmodload zsh/mathfunc

INPUT=""
OUTPUT=""
DEVICE="auto"
DEVICE_IDX=0
LOG="fatal"
PRESET="medium"
V_CODEC="h264"
A_CODEC="ac3"
A_LANGUAGE="keep"
A_LANGUAGE_ONLY=false
S_LANGUAGE="keep"
S_LANGUAGE_ONLY=false
PIX_FMT="keep"
OUTPUT_FORMAT_STANDARD="keep"
A_BIT_RATE_METHOD="vbr"
V_BIT_RATE_METHOD="vbr"
DEINTERLACE=true
FORCE=false
PITCH_SHIFT=true

# Constants
readonly SUPPORTED_GPUS=(nvidia amd intel apple)
readonly SUPPORTED_GPU_PIX_FMTS=("nv1*" "nv2*" "p010*" "p210" "p210*" "yuv444p" "bgr0" "bgra" "rgb0" "rgba")
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

## FUNCTIONS
get_preset_values() {
  local PRESET_ARR="$1"
  local OUTPUT=$2
  local PRESET_VALUE
  local local_arr=(${${(P)PRESET_ARR}[@]})
  # echo "All elements: ${${(P)PRESET_ARR}[@]}"
  # echo "1st element: ${${(P)PRESET_ARR}[1]}"
  # echo "1st element: $local_arr[1]"
  case "$PRESET" in
    l|low)
      PRESET_VALUE=$local_arr[1]
    ;;
    m|medium)
      PRESET_VALUE=$local_arr[2]
    ;;
    h|high)
      PRESET_VALUE=$local_arr[3]
    ;;
    *)
      echo "Unknown preset level $PRESET"
      exit 2
    ;;
  esac
  typeset -g "$OUTPUT"="$PRESET_VALUE"
}


get_BRM_values() {
  local BRM=$1
  local RATE_ARR="$2"
  local OUTPUT=$3
  local RATE_VALUE
  local local_arr=(${${(P)RATE_ARR}[@]})
  # echo "All elements: ${${(P)PRESET_ARR}[@]}"
  # echo "1st element: ${${(P)PRESET_ARR}[1]}"
  # echo "1st element: $local_arr[1]"
  case "$BRM" in
    vbr)
      RATE_VALUE=$local_arr[1]
    ;;
    cbr)
      RATE_VALUE=$local_arr[2]
    ;;
    *)
      echo "Unknown preset level $BRM"
      exit 2
    ;;
  esac
  typeset -g "$OUTPUT"="$RATE_VALUE"
}


get_output_format_standard() {
  case "$OUTPUT_FORMAT_STANDARD" in
      ntsc)
        CORRECT_FPS_FILTER="fps=fps=ntsc"
        CORRECT_FPS=$NTSC_FRAMERATE
      ;;
      ntsc_film)
        CORRECT_FPS_FILTER="fps=fps=ntsc_film"
        CORRECT_FPS=$NTSC_FILM_FRAMERATE
      ;;
      pal)
        CORRECT_FPS_FILTER="fps=fps=pal"
        CORRECT_FPS=$PAL_FRAMERATE
      ;;
      keep)
        CORRECT_FPS_FILTER="fps=fps=source_fps"
        CORRECT_FPS=$F_V_FPS
      ;;
      *)
      echo "Unknown fix-type $OUTPUT_FORMAT_STANDARD"
      exit 2
      ;;
  esac
}


get_a_bitrate() {
  local NUM_CHANNELS=$2
  local MAX_BIT_RATE=$3
  local MIN_BIT_RATE=$4
  local OUTPUT=$5
  # Low to High order
  get_preset_values $1 A_BIT_RATE_PER_CHANNEL
  # echo "Bit rate: " $A_BIT_RATE_PER_CHANNEL
  COUNT_CHANNELS=0
  # echo "Number of channels: " $NUM_CHANNELS
  for n in ${(s:.:)NUM_CHANNELS}; do
    COUNT_CHANNELS=$((COUNT_CHANNELS + n))
  done
  BIT_RATE=$(( COUNT_CHANNELS * A_BIT_RATE_PER_CHANNEL ))
  BIT_RATE=$(( BIT_RATE < MIN_BIT_RATE ? MIN_BIT_RATE : (BIT_RATE > MAX_BIT_RATE ? MAX_BIT_RATE : BIT_RATE) ))
  # echo "Channel info: " $NUM_CHANNELS $COUNT_CHANNELS $A_BIT_RATE_PER_CHANNEL $BIT_RATE
  typeset -g "$OUTPUT"=""$BIT_RATE"k"
}


get_a_bitrate_method() {
  local A_VBR_ARGS=$1
  local A_CBR_ARGS=$2
  local OUTPUT=$2
  case "$A_BIT_RATE_METHOD" in
    vbr|variable)
        A_BITRATE_ARGS=$A_VBR_ARGS
      ;;
    cbr|constant)
        A_BITRATE_ARGS=$A_CBR_ARGS
      ;;
    *)
      echo "Unknown Audio bitrate method: $A_BIT_RATE_METHOD"
      ;;
  esac
  typeset -g "$OUTPUT"=$A_BITRATE_ARGS
}


get_a_encode_args() {
  local NUM_CHANNELS=$1
  local MAX_BIT_RATE=1024
  local MIN_BIT_RATE=64
  A_ENCODE_ARGS=(-c:a)
  A_BIT_RATE="64k"
  A_BIT_RATE_PER_CHANNEL=64
  A_CBR_METHOD=(-b:a)
  A_VBR_METHOD=(-q:a)
  A_BIT_RATES_PER_CHANNEL_ARR=("64" "112" "160")
  A_VBR_QUALITIES=("0" "4" "9")
  case "$A_CODEC" in
      aac)
        if (( ${AVAILABLE_A_CODECS[(Ie)libfdk_aac]} )); then
          # libfdk_aac is proprietary but a lot better, if available use it.
          A_VBR_QUALITIES=(2 4 5)
          A_BIT_RATES_PER_CHANNEL_ARR=("40" "72" "112")
          get_a_bitrate A_BIT_RATES_PER_CHANNEL_ARR $NUM_CHANNELS $MAX_BIT_RATE $MIN_BIT_RATE A_BIT_RATE
          get_preset_values VBR_QUALITY A_VBR_QUALITY
          A_CBR_METHOD=(-vbr 0 -b:a $A_BIT_RATE)
          A_VBR_METHOD=(-vbr $A_VBR_QUALITY)
          get_a_bitrate_method A_VBR_METHOD A_CBR_METHOD A_BIT_RATE_ARGS
          A_ENCODE_ARGS+=(libfdk_aac $A_BIT_RATE_ARGS)
        else
          A_VBR_QUALITIES=("0.5" "1.4" "2.0")
          A_BIT_RATES_PER_CHANNEL_ARR=("80" "112" "160")
          get_a_bitrate A_BIT_RATES_PER_CHANNEL_ARR $NUM_CHANNELS $MAX_BIT_RATE $MIN_BIT_RATE A_BIT_RATE
          get_preset_values VBR_QUALITY A_VBR_QUALITY
          A_CBR_METHOD+=($A_BIT_RATE)
          A_VBR_METHOD+=($A_VBR_QUALITY)
          get_a_bitrate_method A_VBR_METHOD A_CBR_METHOD A_BIT_RATE_ARGS
          A_ENCODE_ARGS+=(aac $A_BIT_RATE_ARGS)
        fi
      ;;
      ac3|dolby)
        MAX_BIT_RATE=640
        get_a_bitrate A_BIT_RATES_PER_CHANNEL_ARR $NUM_CHANNELS $MAX_BIT_RATE $MIN_BIT_RATE A_BIT_RATE
        get_preset_values VBR_QUALITY A_VBR_QUALITY
        A_CBR_METHOD+=($A_BIT_RATE)
        A_BITRATE_ARGS=$A_CBR_METHOD
        A_ENCODE_ARGS+=(ac3 $A_BIT_RATE_ARGS)
      ;;
      eac3|dolbyplus)
        get_a_bitrate A_BIT_RATES_PER_CHANNEL_ARR $NUM_CHANNELS $MAX_BIT_RATE $MIN_BIT_RATE A_BIT_RATE
        get_preset_values VBR_QUALITY A_VBR_QUALITY
        A_CBR_METHOD+=($A_BIT_RATE)
        A_BITRATE_ARGS=$A_CBR_METHOD
        A_ENCODE_ARGS+=(eac3 $A_BIT_RATE_ARGS)
      ;;
      opus)
        A_VBR_QUALITIES=("64" "96" "128")
        A_BIT_RATES_PER_CHANNEL_ARR=("64" "96" "128")
        get_a_bitrate A_BIT_RATES_PER_CHANNEL_ARR $NUM_CHANNELS $MAX_BIT_RATE $MIN_BIT_RATE A_BIT_RATE
        get_a_bitrate A_VBR_QUALITIES $NUM_CHANNELS VBR_QUALITY
        A_CBR_METHOD+=($A_BIT_RATE)
        A_VBR_METHOD=${A_CBR_METHOD}
        A_CBR_METHOD=(-vbr off)+$A_CBR_METHOD
        get_a_bitrate_method A_VBR_METHOD A_CBR_METHOD A_BIT_RATE_ARGS
        A_ENCODE_ARGS+=(libopus $A_BIT_RATE_ARGS)
      ;;
      vorbis)
        A_VBR_QUALITIES=("3.0" "5.0" "9.0")
        get_preset_values VBR_QUALITY A_VBR_QUALITY
        A_VBR_METHOD+=($A_VBR_QUALITY)
        A_BIT_RATE_ARGS=$A_VBR_METHOD
        A_ENCODE_ARGS+=(libvorbis $A_BIT_RATE_ARGS)
      ;;
      lpcm|pcm|none)
        A_ENCODE_ARGS+=(pcm_s16le)
      ;;
      flac)
        A_ENCODE_ARGS+=(flac)
      ;;
      alac)
        A_ENCODE_ARGS+=(alac)
      ;;
      copy)
        A_ENCODE_ARGS+=(copy)
      ;;
      mp3)
        A_VBR_QUALITIES=("7" "3" "0")
        get_a_bitrate A_BIT_RATES_PER_CHANNEL_ARR $NUM_CHANNELS $MAX_BIT_RATE $MIN_BIT_RATE A_BIT_RATE
        get_preset_values VBR_QUALITY A_VBR_QUALITY
        A_CBR_METHOD+=($A_BIT_RATE)
        A_VBR_METHOD+=($A_VBR_QUALITY)
        get_a_bitrate_method A_VBR_METHOD A_CBR_METHOD A_BIT_RATE_ARGS
        A_ENCODE_ARGS+=(libmp3lame $A_BIT_RATE_ARGS)
      ;;
      *)
        if (( ${AVAILABLE_A_CODECS[(Ie)$A_CODEC]} )); then
          A_ENCODE_ARGS+=($A_CODEC -b:a ${BIT_RATE}k)
        elif [[ -z $AUDIO_FILTER ]]; then
          # Not rencoding audio
          A_ENCODE_ARGS+=(copy)
        else
          echo "Unknown Video codec: $A_CODEC"
          exit 2
        fi
      ;;
  esac
}


get_device() {
  local OSTYPE="$1"
  DEVICE=$2
  DEVICE_IDX=$3
  local GPU_OUTPUT=$4

  # PLATFORM
  case "$OSTYPE" in
    darwin*)
      GPU=$(system_profiler SPDisplaysDataType | grep -i "chipset")
      GPUS=($P_GPU)
      AVAILABLE_A_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*A.*/ && $2 ~ /\w+/ {print $2}')}")
      AVAILABLE_V_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*V.*/ && $2 ~ /\w+/ {print $2}')}")
      ;;
    linux*)
      GPUS=($(lspci | grep -i --color 'vga\|3d\|2d'))
      GPU=$(glxinfo | grep -E "OpenGL renderer")
      AVAILABLE_A_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*A.*/ && $2 ~ /\w+/ {print $2}')}")
      AVAILABLE_V_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*V.*/ && $2 ~ /\w+/ {print $2}')}")
      ;;
    msys*) # WSL 2.0 only
      # GPU=$(wmic path win32_VideoController get caption)
      GPUS=($(lspci | grep -i --color 'vga\|3d\|2d'))
      GPU=$(glxinfo | grep -E "OpenGL renderer")
      AVAILABLE_A_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*A.*/ && $2 ~ /\w+/ {print $2}')}")
      AVAILABLE_V_CODECS=("${(f)$(ffmpeg -hide_banner -codecs | awk '$1 ~ /.*V.*/ && $2 ~ /\w+/ {print $2}')}")
      ;;
    *)
      echo "Unknown platform: $OSTYPE"
      ;;
  esac

  # Extract gpu name if it matches supported GPUs, return lowercase array
  GPUS=( ${(M)SUPPORTED_GPUS:#*${(j:|:L)GPUS}*} )
  # Primary GPU
  GPU=${SUPPORTED_GPUS[(r)*${GPU:l}*]}
  DEVICE=${DEVICE:l}

  if [[ $DEVICE == "auto" || $DEVICE == "gpu" ]] && [[ ! -z $GPU ]]; then
    DEVICE="gpu"
  # Check if DEVICE is specified to an active, supported gpu
  elif [[ "$DEVICE" == (${~${(j:|:)GPUS}}) ]]; then
    GPU="$DEVICE"
    DEVICE="gpu"
  fi
  # If no match to gpu on auto setting, use cpu
  if [[ $DEVICE == "auto" ]]; then
    DEVICE="cpu"
  fi

  if [[ -z $GPU && $DEVICE != "cpu" ]]; then
    echo "Device is gpu, but none found: $DEVICE"
    exit 2
  fi

  typeset -g "$GPU_OUTPUT"="$GPU"
}


select_on_device(){
  local PRESET_ARR="$1"
  local OUTPUT=$2
  local DEVICE_VALUE
  local local_arr=(${${(P)PRESET_ARR}[@]})

  case "$DEVICE" in
    cpu)
      DEVICE_VALUE=$local_arr[1]
    ;;
    gpu)
      case "$GPU" in
        nvidia)
          DEVICE_VALUE=$local_arr[2]
        ;;
        amd)
          DEVICE_VALUE=$local_arr[3]
        ;;
        intel)
          DEVICE_VALUE=$local_arr[4]
        ;;
        apple)
          DEVICE_VALUE=$local_arr[5]
        ;;
      esac
    ;;
    *)
    echo "Unknown device: $DEVICE"
    exit 2
    ;;
  esac

  typeset -g "$OUTPUT"="$DEVICE_VALUE"
}


get_v_encode_args() {
  V_ENCODE_ARGS=(-c:v)
  V_ENCODE_ARGS_COMMON=(-b:v $AVG_BIT_RATE -maxrate:v $MAX_BIT_RATE -bufsize:v $BUFFER_SIZE)
  case "$DEVICE" in
    cpu)
      CPU_PRESETS=("fast" "medium" "slow")
      HW_DECODE_ARGS=""
      COMMON_ARGS=($V_ENCODE_ARGS_COMMON -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1)
      case "$V_CODEC" in
          h266|vvc)
            QUALITY=$((QUALITY+3))
            get_preset_values CPU_PRESETS V_PRESET_ARG
            V_ENCODE_ARGS+=(libvvenc -preset $V_PRESET_ARG -qp $QUALITY $COMMON_ARGS)
          ;;
          h265|hevc)
            QUALITY=$((QUALITY+2))
            get_preset_values CPU_PRESETS V_PRESET_ARG
            V_ENCODE_ARGS+=(libx265 -preset $V_PRESET_ARG -crf $QUALITY $COMMON_ARGS)
          ;;
          h264|avc)
            get_preset_values CPU_PRESETS V_PRESET_ARG
            V_ENCODE_ARGS+=(libx264 -preset $V_PRESET_ARG -crf $QUALITY $COMMON_ARGS)
          ;;
          vp9)
            CPU_PRESETS=(2 1 0)
            get_preset_values CPU_PRESETS V_PRESET_ARG
            V_ENCODE_ARGS+=(libvpx-vp9 -cpu-used $V_PRESET_ARG -crf $QUALITY --auto-alt-ref=1 -lag-in-frames 25 -row-mt 1 $COMMON_ARGS)
          ;;
          av1)
            CPU_PRESETS=(8 6 4)
            get_preset_values CPU_PRESETS V_PRESET_ARG
            QUALITY=$((QUALITY+2))
            V_ENCODE_ARGS+=(libsvtav1 -preset $V_PRESET_ARG -svtav1-params tune=0 -crf $QUALITY $COMMON_ARGS)
          ;;
          ffv1|lossless)
            # level 3 is version 3, the currently best version
            V_ENCODE_ARGS+=(ffv1 -level 3)
          ;;
          mpeg2video)
          # qscale is from 2-31, 2 is highest quality
            V_ENCODE_ARGS+=(mpeg2video -qscale:v $(QUALITY-16) $COMMON_ARGS)
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
            GPU_PRESETS=("p4" "p6" "p7")
            CRF_ARGS=(-tune hq -rc vbr -cq $QUALITY $V_ENCODE_ARGS_COMMON -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1)
            case "$V_CODEC" in
              h265|hevc)
                get_preset_values GPU_PRESETS V_PRESET_ARG
                QUALITY=$((QUALITY+1))
                V_ENCODE_ARGS+=(hevc_nvenc -preset $V_PRESET_ARG $CRF_ARGS)
              ;;
              h264|avc)
                # get_preset_values GPU_PRESETS V_PRESET_ARG
                get_preset_values GPU_PRESETS V_PRESET_ARG
                QUALITY=$((QUALITY-1))
                V_ENCODE_ARGS+=(h264_nvenc -preset $V_PRESET_ARG $CRF_ARGS)
              ;;
              av1)
                get_preset_values GPU_PRESETS V_PRESET_ARG
                QUALITY=$((QUALITY+1))
                V_ENCODE_ARGS+=(av1_nvenc -preset $V_PRESET_ARG $CRF_ARGS)
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
          # HW_INIT_FILTER="hwupload"
          GPU_PRESETS=("balanced" "quality" "high_quality")
          COMMON_VBR_ARGS=($V_ENCODE_ARGS_COMMON -rc vbr_peak -preencode true -g 120 -high_motion_quality_boost_enable true -preanalysis true -max_b_frames 3 -pa_adaptive_mini_gop true -pa_lookahead_buffer_depth 40 -pa_taq_mode 2)
          COMMON_CBR_ARGS=(-qp $QUALITY $V_ENCODE_ARGS_COMMON)

          case "$V_CODEC" in
            h265|hevc)
              get_preset_values GPU_PRESETS V_PRESET_ARG
              QUALITY=$((QUALITY+2))
              # Alternative to -qp: -rc cqp -qp_i $QUALITY -qp_p $QUALITY -qp_b $QUALITY
              VBR_ARGS=(-vbaq true $COMMON_VBR_ARGS)
              CBR_ARGS=($COMMON_CBR_ARGS)
              RATE_OPTIONS=(VBR_ARGS CBR_ARGS)
              get_BRM_values RATE_OPTIONS CRF_ARGS
              V_ENCODE_ARGS+=(hevc_amf -preset $V_PRESET_ARG $CRF_ARGS)
            ;;
            h264|avc)
              get_preset_values GPU_PRESETS V_PRESET_ARG
              VBR_ARGS=(-vbaq true $COMMON_VBR_ARGS)
              CBR_ARGS=($COMMON_CBR_ARGS)
              RATE_OPTIONS=(VBR_ARGS CBR_ARGS)
              get_BRM_values RATE_OPTIONS CRF_ARGS
              V_ENCODE_ARGS+=(h264_amf -preset $V_PRESET_ARG $CRF_ARGS)
            ;;
            av1)
              get_preset_values GPU_PRESETS V_PRESET_ARG
              QUALITY=$((QUALITY+2))
              VBR_ARGS=(-aq_mode caq $COMMON_VBR_ARGS)
              CBR_ARGS=($COMMON_CBR_ARGS)
              RATE_OPTIONS=(VBR_ARGS CBR_ARGS)
              get_BRM_values RATE_OPTIONS CRF_ARGS
              V_ENCODE_ARGS+=(av1_amf -preset $V_PRESET_ARG $CRF_ARGS)
            ;;
            *)
              echo "Unknown or unsupported Video codec for $GPU: $V_CODEC"
              exit 2
            ;;
          esac
        ;;
        intel)
          HW_DECODE_ARGS=(-hwaccel qsv -init_hw_device qsv=hw:autodetect -filter_hw_device hw -hwaccel_output_format qsv)
          # -init_hw_device qsv=hw:autodetect -qsv_device /dev/dri/renderD128
          GPU_PRESETS=("5" "3" "1")
          case "$V_CODEC" in
            h265|hevc)
              get_preset_values GPU_PRESETS V_PRESET_ARG
              QUALITY=$((QUALITY+2))
              V_ENCODE_ARGS+=(hevc_qsv -preset $V_PRESET_ARG -crf $QUALITY $V_ENCODE_ARGS_COMMON)
            ;;
            h264|avc)
              get_preset_values GPU_PRESETS V_PRESET_ARG
              V_ENCODE_ARGS+=(hevc_qsv -preset $V_PRESET_ARG -crf $QUALITY $V_ENCODE_ARGS_COMMON)
            ;;
            av1)
              get_preset_values GPU_PRESETS V_PRESET_ARG
              QUALITY=$((QUALITY+2))
              V_ENCODE_ARGS+=(av1_qsv -preset $V_PRESET_ARG -global_quality $QUALITY -extbrc 1 -look_ahead_depth 40 -adaptive_i 1 -adaptive_b 1 $V_ENCODE_ARGS_COMMON)
            ;;
            *)
              echo "Unknown or unsupported Video codec for $GPU: $V_CODEC"
              exit 2
            ;;
          esac
        ;;
        apple)
          HW_DECODE_ARGS=(-init_hw_device videotoolbox -hwaccel videotoolbox -hwaccel_output_format videotoolbox_vld)
          COMMON_ARGS=($V_ENCODE_ARGS_COMMON -bf 1 -b_ref_mode middle -spatial-aq 1 -temporal-aq 1)
          case "$V_CODEC" in
            h265|hevc)
              QUALITY=$((4*(QUALITY)))
              # -tag:v hvc1 sets fourcc code to apple quicktime playback compatibility, hev1 is default fourcc code and not recognised by apple.
              V_ENCODE_ARGS+=(hevc_videotoolbox -tag:v hvc1 -q:v $QUALITY $COMMON_ARGS)
            ;;
            h264|avc)
              QUALITY=$((4*(QUALITY+2)))
              V_ENCODE_ARGS+=(h264_videotoolbox -q:v $QUALITY $COMMON_ARGS)
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
}


get_pix_fmt() {
  local PIX_BITS="$1"
  local PIX_FMT="$2"
  local OUTPUT_ARGS=$3
  local OUTPUT_FILTER=$4
  # CPU, NVENC, AMF, QSV, APPLE
  local CHROMA
  local ARGS
  local FILTER

  if [[ ! $PIX_BITS =~ ^[0-9]+$ ]]; then
    case "${PIX_FMT:l}" in
        p*8*|i*|nv1*|yuv*p)
          PIX_BITS=8
        ;;
        p*10*|*p10*)
          PIX_BITS=10
        ;;
        p*12*|*p12*)
          PIX_BITS=12
        ;;
        *)
        echo "No pixel bit depth found and unrecognised pixel format: $PIX_FMT"
        exit 2
        ;;
    esac
  fi

  case "$DEVICE" in
    cpu)
      ARGS=(-pix_fmt $PIX_FMT)
      FILTER=(format=$PIX_FMT)
    ;;
    gpu)
      # Compare against basic gpu support format list
      if [[ ! "$PIX_FMT" == (${~${(j:|:)SUPPORTED_GPU_PIX_FMTS}}) ]]; then
        case "$PIX_FMT" in
          nv24|yuv444*)
            case "$PIX_BITS" in
              8)
                PIX_FMT="nv24"
              ;;
              10)
                PIX_FMT="yuv444p10le"
              ;;
              12)
                # 12 isn't supported widely on gpus
                PIX_FMT="yuv444p10le"
              ;;
              *)
                echo "Unknown bit pixel depth: $PIX_BITS"
                exit 2
              ;;
            esac
          ;;
          nv16|yuv422*)
            case "$PIX_BITS" in
              8)
                PIX_FMT="nv16"
              ;;
              10)
                PIX_FMT="p210le"
              ;;
              12)
                # 12 isn't supported widely on gpus
                PIX_FMT="p212le"
              ;;
              *)
                echo "Unknown bit pixel depth: $PIX_BITS"
                exit 2
              ;;
            esac
          ;;
          p*|nv12|yuv420*)
            case "$PIX_BITS" in
              8)
                PIX_FMT="nv12"
              ;;
              10)
                PIX_FMT="p010le"
              ;;
              12)
                PIX_FMT="p012le"
              ;;
              *)
                echo "Unknown bit pixel depth: $PIX_BITS"
                exit 2
              ;;
            esac
          ;;
          *)
            echo "Unknown pixel format, defaulting to 420 formats."
            case "$PIX_BITS" in
              8)
                PIX_FMT="nv12"
              ;;
              10)
                PIX_FMT="p010le"
              ;;
              12)
                # 12 isn't support widely on gpus
                PIX_FMT="p012le"
              ;;
              *)
                echo "Unknown bit pixel depth: $PIX_BITS"
                exit 2
              ;;
            esac
          ;;
        esac
      fi
      ARGS=()
      local FILTERS=(format=$PIX_FMT scale_cuda=format=$PIX_FMT format=$PIX_FMT scale_qsv=format=$PIX_FMT hwdownload,format=$PIX_FMT)
      select_on_device FILTERS FILTER
    ;;
  esac

  typeset -g "$OUTPUT_FILTER"="$FILTER"
  typeset -g "$OUTPUT_ARGS"="$ARGS"
}


## START ##
# ARG INPUT
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      INPUT="$2"
      shift 2 # Past argument only
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
    -di|--device-index)
      DEVICE_IDX="$2"
      shift 2
    ;;
    -ofs|--output-format-standard)
      OUTPUT_FORMAT_STANDARD=$2
      shift 2
    ;;
    -bp|--bit-pixel-format)
      PIX_FMT="$2"
      shift 2
    ;;
    -abm|--audio-bitrate-method)
      A_BIT_RATE_METHOD="$2"
      shift 2
    ;;
    -vbm|--video-bitrate-method)
      V_BIT_RATE_METHOD="$2"
      shift 2
    ;;
    -v|--log-level)
      # if [[ (quiet panic fatal error warning info verbose debug trace)[(e)$2] ]]; then
      #   LOG="$2"
      #   shift 2
      # else
        LOG="verbose"
        shift 1
      # fi
    ;;
    -sl|--subtitle-language)
      S_LANGUAGE="$2"
      shift 2
    ;;
    -slo|--subtitle-language-only)
      S_LANGUAGE_ONLY=true
      shift 1
    ;;
    -al|--audio-language)
      A_LANGUAGE="$2"
      shift 2
    ;;
    -alo|--audio-language-only)
      A_LANGUAGE_ONLY=true
      shift 1
    ;;
    -nd|--no-deinterlace)
      DEINTERLACE=false
      shift 1
    ;;
    -nps|--no-pitch-shift)
      PITCH_SHIFT=false
      shift 1
    ;;
    -f|--force)
      FORCE=true
      shift 1
    ;;
    --help)
      echo "Usage: $0 [options]"
      echo "  -i                    Set input and container type"
      echo "  -o,                   Set output file, path and container (default </Processed/<input_file>)"
      echo "  -p, --preset          Set quality (higher quality = lower compression) preset: l|low, m|medium, h|high, u|uncompressed, k|keep  (default: medium)"
      echo "  -ofs, --output-format-standard   Set correct output format standard: keep, pal, ntsc_film, ntsc  (default: keep)"
      echo "  -cv, --video-codec    Set video codec: keep (maintain input codec), h266|vvc, h265|hevc, h264|avc, vp9, av1, ffv1|lossless (default: h264)"
      echo "  -ca, --audio-codec    Set audio codec: keep (maintain input codec), HQ: aac, ac3|dolby, eac3|dolbyplus, opus, vorbis ; Lossless: lpcm|pcm|none, flac, alac ; Legacy: mp3 (default: ac3)"
      echo "  -d, --device          Set device: auto (gpu with cpu fallback), cpu, gpu (autodetect: amd, nvidia, intel, apple), amd, nvidia, intel, apple (default: auto)"
      echo "  -di, --device-idx     (ADVANCED) Set device index: 0 starting, must be an int corresponding to device set. Allows multiple GPUs of same vendor to be used. (default: 0)"
      echo "  -v, --log-level       Set/Flag the log level: quiet, panic, fatal, error, warning, info, verbose, debug, trace  (default: fatal)"
      echo "  -bp, --bit-pixel-format  Set bit pixel format: 8, 10, 12, keep  (default: keep)"
      echo "  -abm, --audio-bitrate-method  Set audio bitrate method: cbr|constant, vbr|variable  (default: vbr)"
      echo "  -vbm, --video-bitrate-method  Set video bitrate method: cbr|constant, vbr|variable  (default: vbr)"
      echo "  -sl, --subtitle-language  Set preferred subtitle language: keep, none or standard ffmpeg language stream identifier e.g. eng  (default: keep)"
      echo "  -al, --audio-language Set preferred audio language: keep or standard ffmpeg language stream identifier e.g. eng  (default: keep)"
      echo "  -alo, --audio-language-only    Flag to keep only preferred audio language stream"
      echo "  -sbo, --subtitle-language-only Flag to keep only preferred subtitle language stream"
      echo "  -nd, --no-deinterlace      Flag no deinterlace"
      echo "  -nps, --no-pitch-shift Flag for preventing pitch shifting audio"
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

# Quality
case "$PRESET" in
    l|low)
    QUALITY=25
    BIT_RATE_MULT=0.3
    ;;
    m|medium)
    QUALITY=21
    BIT_RATE_MULT=0.5
    ;;
    h|high)
    QUALITY=18
    BIT_RATE_MULT=0.75
    ;;
    u|uncompresssed)
    QUALITY=0
    BIT_RATE_MULT=1.0
    ;;
    k|keep)
    QUALITY=-1
    BIT_RATE_MULT=1.0
    # This will be raw bitstream method
    ;;
    *)
    echo "Unknown preset: $PRESET"
    exit 2
    ;;
esac

# Use device and gpu setting to select transcoding pipeline.
GPU=""
echo $DEVICE $GPU
get_device $OSTYPE $DEVICE $DEVICE_IDX GPU
echo $DEVICE $GPU


counter=1
for F in $FILES; do
  echo "iteration = $counter"
  echo "file = $F"

  F_BASE=$(basename $INPUT)
  F_NAME="${F_BASE%.*}"
  # echo "File name = $F_NAME"
  F_CONTAINER="${F_BASE:e}"
  # echo "File container = $F_CONTAINER"
  F_DIR="${F:h}"
  # echo "File dir = $F_DIR"
  if [ -z $OUTPUT ]; then
      OUTPUT="$F_DIR/Processed/$F_NAME.$F_CONTAINER"
  fi
  # echo "Output = $OUTPUT"
  F_CHAPTERS="${OUTPUT%.*}_chapters.txt"
  F_SUBTITLES="${OUTPUT%.*}_subtitles.$F_CONTAINER"
  OUTPUT_DIR=${OUTPUT:h}
  LOG_DIR="$OUTPUT_DIR/Logs"

  if [[ ! -d $OUTPUT_DIR ]]; then
    mkdir -p $OUTPUT_DIR
  fi
  mkdir -p $LOG_DIR

  echo "Resampling audio and video"
  STREAMS=("${(fu)$(ffprobe -hide_banner -v error -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 $F)}")
  echo "Streams found:" $STREAMS

  if (( ${STREAMS[(Ie)audio]} )); then
    echo "Audio found"
  fi

  if (( ${STREAMS[(Ie)video]} )); then
    echo "Video found"
  fi

  # Audio
  typeset -A A_FFPROBE_DICT
  while IFS== read -r key value; do
    A_FFPROBE_DICT[$key]=$value
  done < <(ffprobe -hide_banner -v error -select_streams a:0 -show_entries stream=codec_name,bit_rate,sample_rate,channels -of default=noprint_wrappers=1 $F)

  # echo -e "Audio probe results:\n" ${(Fkv)A_FFPROBE_DICT}
  F_A_CODEC=$A_FFPROBE_DICT[codec_name]
  F_A_SAMPLERATE=$A_FFPROBE_DICT[sample_rate]
  F_A_BITRATE=$A_FFPROBE_DICT[bit_rate]
  F_A_CHANNELS=$A_FFPROBE_DICT[channels]

  # Video
  typeset -A V_FFPROBE_DICT
  while IFS== read -r key value; do
    V_FFPROBE_DICT[$key]=$value
  done < <(ffprobe -hide_banner -v error -select_streams V:0 -show_entries stream_tags:stream_side_data=max_bitrate,avg_bitrate,buffer_size:stream=codec_name,width,height,field_order,r_frame_rate,pix_fmt,bits_per_raw_sample,max_bit_rate,bit_rate,profile,level -of default=noprint_wrappers=1 $F)

  F_V_CODEC=$V_FFPROBE_DICT[codec_name]
  F_V_FIELD_ORDER=$V_FFPROBE_DICT[field_order]
  F_V_FPS=$V_FFPROBE_DICT[r_frame_rate]
  F_V_WIDTH=$V_FFPROBE_DICT[width]
  F_V_HEIGHT=$V_FFPROBE_DICT[height]
  F_V_PIX_FMT=$V_FFPROBE_DICT[pix_fmt]
  F_V_PIX_BITS=$V_FFPROBE_DICT[bits_per_raw_sample]
  F_V_LEVEL=$V_FFPROBE_DICT[level]
  F_V_PROFILE=$V_FFPROBE_DICT[profile]

  # VIDEO BIT RATE
  INT_FIELDS=(avg_bitrate max_bitrate buffer_size bit_rate max_bit_rate)
  for k in $INT_FIELDS; do
    if [[ "$V_FFPROBE_DICT[$k]" == "N/A" ]]; then
      V_FFPROBE_DICT[$k]=0
    fi
  done
  F_V_META_BIT_RATE=${(v)V_FFPROBE_DICT[(i)TAG:BPS*]}
  echo "META BIT RATE BPS: " $F_V_META_BIT_RATE
  F_V_META_AVG_BIT_RATE=$V_FFPROBE_DICT[avg_bitrate]
  F_V_META_MAX_BIT_RATE=$V_FFPROBE_DICT[max_bitrate]
  F_V_META_BUFFER_SIZE=$V_FFPROBE_DICT[buffer_size]
  F_V_STREAM_BIT_RATE=$V_FFPROBE_DICT[bit_rate]
  F_V_STREAM_MAX_BIT_RATE=$V_FFPROBE_DICT[max_bit_rate]

  # echo -e "Video probe results:\n" ${(Fkv)V_FFPROBE_DICT}

  # Get highest bitrates, naive approach
  F_AVG_BIT_RATE=$(( F_V_META_BIT_RATE > F_V_META_AVG_BIT_RATE ? F_V_STREAM_BIT_RATE > F_V_META_BIT_RATE ? F_V_STREAM_BIT_RATE : F_V_META_BIT_RATE : F_V_STREAM_BIT_RATE > F_V_META_AVG_BIT_RATE ? F_V_STREAM_BIT_RATE : F_V_META_AVG_BIT_RATE))
  F_MAX_BIT_RATE=$(( F_V_META_MAX_BIT_RATE > F_V_STREAM_MAX_BIT_RATE ? F_V_META_MAX_BIT_RATE : F_V_STREAM_MAX_BIT_RATE ))
  # If max isn't found, guess.
  if (( $F_MAX_BIT_RATE <= 1 )); then
    F_MAX_BIT_RATE=$F_AVG_BIT_RATE*2
  fi
  F_BUFFER_SIZE=$F_V_META_BUFFER_SIZE

  AVG_BIT_RATE=$(( int(BIT_RATE_MULT * F_AVG_BIT_RATE) ))
  MAX_BIT_RATE=$(( int(BIT_RATE_MULT * F_MAX_BIT_RATE) ))
  BUFFER_SIZE=$(( int(BIT_RATE_MULT * F_BUFFER_SIZE) ))
  echo "Avg Bit Rate: " $AVG_BIT_RATE "Max Bit Rate: " $MAX_BIT_RATE "Buffer size: " $BUFFER_SIZE

  if [[ $PIX_FMT == "keep" ]]; then
    PIX_FMT=$F_V_PIX_FMT
    PIX_BITS=$F_V_PIX_BITS
  fi

  # Get BITS, FORMAT, PIX_FMT_ARGS, PIX_FMT_FILTERS
  get_pix_fmt $PIX_BITS $PIX_FMT PIX_FMT_ARGS PIX_FMT_FILTER
  # Filters
  VIDEO_FILTER_ARR=()
  AUDIO_FILTER_ARR=()
  FRAMERATE_ARGS=()
  # Add pixel filter first
  VIDEO_FILTER_ARR+=($PIX_FMT_FILTER)
  if $DEINTERLACE && [[ $F_V_FIELD_ORDER!="progressive" ]]; then
    DEINTERLACE_FILTER_ARR=()
    # CPU
    DEINTERLACE_FILTER_ARR+="bwdif=mode=send_frame"
    # NVIDIA CUDA
    DEINTERLACE_FILTER_ARR+="bwdif_cuda=mode=0"
    # AMD VULKAN
    # Only deinterlace marked fields
    DEINTERLACE_FILTER_ARR+="hwmap=derive_device=vulkan,format=vulkan,bwdif_vulkan=mode=send_frame"
    # INTEL QSV
    # 2 is advanced motion-adaptive, 1 is bob weaver
    DEINTERLACE_FILTER_ARR+="vpp_qsv=deinterlace=2"
    # APPLE (CPU)
    DEINTERLACE_FILTER_ARR+="bwdif=mode=send_frame,hwupload=videotoolbox"
    select_on_device DEINTERLACE_FILTER_ARR DEINTERLACE_FILTER
    VIDEO_FILTER_ARR+=($DEINTERLACE_FILTER)
  fi
  # CORRECT_FPS and CORRECT_FPS_FILTER
  get_output_format_standard
  if [[ $OUTPUT_FORMAT_STANDARD:l != "keep" ]]; then
    echo "Adjusting format to: " $OUTPUT_FORMAT_STANDARD:l
    FPS_CORRECTION=$(( CORRECT_FPS / F_V_FPS ))
    INVERSE_FPS_CORRECTION=$(( F_V_FPS / CORRECT_FPS ))

    ITSSCALE_ARGS=(-itsscale $((INVERSE_FPS_CORRECTION)))
    # VIDEO_FILTER_ARR+=("setpts=PTS*$INVERSE_FPS_CORRECTION" $CORRECT_FPS_FILTER)
    VIDEO_FILTER_ARR+=($CORRECT_FPS_FILTER)
    # AUDIO_FILTER="[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]"
    FRAMERATE_ARGS+=(-r $CORRECT_FPS -fps_mode cfr)
     # -fps_mode cfr
    if $PITCH_SHIFT; then
      AUDIO_FILTER_ARR+=("atempo=$FPS_CORRECTION" "asetrate=$FPS_CORRECTION*$F_A_SAMPLERATE" "atempo=$INVERSE_FPS_CORRECTION" "aresample=resampler=soxr:osr=$F_A_SAMPLERATE")
    else
      AUDIO_FILTER_ARR+=("atempo=$INVERSE_FPS_CORRECTION")
    fi
  else
    FRAMERATE_ARGS+=(-fps_mode passthrough)
  fi
  # MAP ARGS
  # Video
  MAP_ARGS=(-map 0:v)
  DISPOSITION_ARGS=()
  # Audio
  if [[ $A_LANGUAGE != "keep" ]]; then
    if $A_LANGUAGE_ONLY; then
      MAP_ARGS+=(-map a:m:language:$A_LANGUAGE)
    else
      MAP_ARGS+=(-map 0:a)
      DISPOSITION_ARGS+=(-disposition:a:m:language:$A_LANGUAGE default -disposition:a:0 0)
    fi
  else
    MAP_ARGS+=(-map 0:a)
  fi
  # Subtitles
  if (( ${STREAMS[(Ie)subtitle]} )); then
    echo "subtitle found"
    if [[ $S_LANGUAGE != "keep" ]]; then
      if $S_LANGUAGE_ONLY; then
        MAP_ARGS+=(-map s:m:language:$S_LANGUAGE)
        S_ENCODE_ARGS=(-c:s copy)
      else
        MAP_ARGS+=(-map 0:s)
        DISPOSITION_ARGS+=(-disposition:s:m:language:$S_LANGUAGE default -disposition:s:0 0)
        S_ENCODE_ARGS=(-c:s copy)
      fi
    else
      MAP_ARGS+=(-map 0:s)
      S_ENCODE_ARGS=(-c:s copy)
    fi
  fi
  # , delimiter for sub arguments
  VIDEO_FILTER="${(j[,])VIDEO_FILTER_ARR:#}"
  AUDIO_FILTER="${(j[,])AUDIO_FILTER_ARR:#}"

  if [[ ! -z "$VIDEO_FILTER" ]]; then
    V_FILTER_ARGS=(-vf "${VIDEO_FILTER}")
  else
    V_FILTER_ARGS=()
  fi
  if [[ ! -z "$AUDIO_FILTER" ]]; then
    A_FILTER_ARGS=(-af "${AUDIO_FILTER}")
  else
    A_FILTER_ARGS=()
  fi

  # ENCODING
  if [[ $V_CODEC == 'keep' ]]; then
    V_CODEC=$F_V_CODEC
  fi
  if [[ $A_CODEC == 'keep' ]]; then
    A_CODEC=$F_A_CODEC
  fi
  get_a_encode_args $F_A_CHANNELS
  get_v_encode_args


    if [[ ! -e $OUTPUT ]] || $FORCE; then
      FFMPEG_ARGS=(-hide_banner -y -loglevel "$LOG" -stats)
      FFMPEG_ARGS+=(${HW_DECODE_ARGS})
      FFMPEG_ARGS+=(${ITSSCALE_ARGS})
      FFMPEG_ARGS+=(-i "$F")
      FFMPEG_ARGS+=(${MAP_ARGS})
      FFMPEG_ARGS+=(${V_FILTER_ARGS})
      FFMPEG_ARGS+=(${V_ENCODE_ARGS})
      FFMPEG_ARGS+=(${A_FILTER_ARGS})
      FFMPEG_ARGS+=(${A_ENCODE_ARGS})
      FFMPEG_ARGS+=(${S_ENCODE_ARGS})
      FFMPEG_ARGS+=(${DISPOSITION_ARGS})
      FFMPEG_ARGS+=(${FRAMERATE_ARGS})
      FFMPEG_ARGS+=(${PIX_FMT_ARGS})
      FFMPEG_ARGS+=("$OUTPUT")

      echo "ffmpeg "$FFMPEG_ARGS

      ffmpeg $FFMPEG_ARGS
    else;
        echo "Processed file found"
    fi

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
