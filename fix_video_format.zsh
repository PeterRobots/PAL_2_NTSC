#!/usr/bin/env zsh
zmodload zsh/mathfunc
## FUNCTIONS
# # Add directory to function path
local CWD="${0:A:h}"
fpath=("$CWD/.zfunc" $fpath)
# Autoload all functions in that directory
autoload -Uz ./.zfunc/*(:t)
# Load language codes
LANGUAGE_CODES_FILE="$CWD/languages_iso_639.csv"
ALLOWED_LANGUAGES=($(awk -F"\t" '{print $1}' $LANGUAGE_CODES_FILE))
# Remove the first elemnet (header)
shift ALLOWED_LANGUAGES

# set -euo pipefail

INPUT=""
OUTPUT=""
DEVICE="auto"
DEVICE_IDX=0
LOG="fatal"
PRESET="medium"
V_CODEC="h264"
A_CODEC="ac3"
A_LANGUAGE="keep"
A_LANGUAGES_SELECTED='all'
S_LANGUAGE="keep"
S_LANGUAGES_SELECTED='all'
PIX_FMT="keep"
OUTPUT_FORMAT_STANDARD="keep"
A_BIT_RATE_METHOD="vbr"
V_BIT_RATE_METHOD="vbr"
DEINTERLACE=true
DENOISE=true
FORCE=false
PITCH_SHIFT=true
DENOISE_SCALE=10.0
DENOISE_RESEARCH_SIZES=(15 21 25)
DENOISE_PATCH_SIZES=(7 9 11)

# Constants
readonly SUPPORTED_GPUS=("nvidia" "amd" "intel" "apple")
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
    -kls|--keep-list-subtitle)
      S_LANGUAGES_SELECTED="$2"
      shift 2
    ;;
    -al|--audio-language)
      A_LANGUAGE="$2"
      shift 2
    ;;
    -kla|--keep-list-audio)
      A_LANGUAGES_SELECTED="$2"
      shift 2
    ;;
    -ndi|--no-deinterlace)
      DEINTERLACE=false
      shift 1
    ;;
    -ndn|--no-denoise)
      DENOISE=false
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
      echo "  -i                                Set input and container type"
      echo "  -o,                               Set output file, path and container (default </Processed/<input_file>)"
      echo "  -p, --preset                      Set quality (higher quality = lower compression) preset: l|low, m|medium, h|high, u|uncompressed, k|keep  (default: medium)"
      echo "  -ofs, --output-format-standard    Set correct output format standard: keep, pal, ntsc_film, ntsc  (default: keep)"
      echo "  -cv, --video-codec                Set video codec: keep (maintain input codec), h266|vvc, h265|hevc, h264|avc, vp9, av1, ffv1|lossless (default: h264)"
      echo "  -ca, --audio-codec                Set audio codec: keep (maintain input codec), HQ: aac, ac3|dolby, eac3|dolbyplus, opus, vorbis ; Lossless: lpcm|pcm|none, flac, alac ; Legacy: mp3 (default: ac3)"
      echo "  -d, --device                      Set device: auto (gpu with cpu fallback), cpu, gpu (autodetect: amd, nvidia, intel, apple), amd, nvidia, intel, apple (default: auto)"
      echo "  -di, --device-idx                 (ADVANCED) Set device index: 0 starting, must be an int corresponding to device set. Allows multiple GPUs of same vendor to be used. (default: 0)"
      echo "  -v, --log-level                   Set/Flag the log level: quiet, panic, fatal, error, warning, info, verbose, debug, trace  (default: fatal)"
      echo "  -bp, --bit-pixel-format           Set bit pixel format: 8, 10, 12, keep  (default: keep)"
      echo "  -abm, --audio-bitrate-method      Set audio bitrate method: cbr|constant, vbr|variable  (default: vbr)"
      echo "  -vbm, --video-bitrate-method      Set video bitrate method: cbr|constant, vbr|variable  (default: vbr)"
      echo "  -sl, --default-subtitle-language  Set default subtitle language: keep, none or ffmpeg language (ISO-639-2/B) stream identifier e.g. eng  (default: keep)"
      echo "  -al, --default-audio-language     Set default audio language: keep or ffmpeg language (ISO-639-2/B) stream identifier e.g. eng  (default: keep)"
      echo "  -kla, --keep-list-audio           String list (delimiter=',') of languages (ISO-639-2/B) to keep for audio e.g. 'eng,fre' (default: all)"
      echo "  -kls, --keep-list-subtitle        String list (delimiter=',') of languages (ISO-639-2/B) to keep for subtitles e.g. 'eng,fre' (default: all)"
      echo "  -ndi, --no-deinterlace            Flag no deinterlace"
      echo "  -ndn, --no-denoise                Flag no denoise"
      echo "  -nps, --no-pitch-shift            Flag for preventing pitch shifting audio"
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
get_device $OSTYPE $DEVICE $DEVICE_IDX GPU DEVICE_IDX

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

  echo "Resampling audio and video"
  STREAMS=("${(fu)$(ffprobe -hide_banner -v error -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 $F)}")

  if (( ${STREAMS[(Ie)audio]} )); then
    echo "Audio stream found"
  fi

  if (( ${STREAMS[(Ie)video]} )); then
    echo "Video stream found"
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
  F_A_LANGUAGES=($(ffprobe -hide_banner -v error -select_streams a -show_entries stream_tags=language -of default=noprint_wrappers=1:nokey=1 $F))

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

  # Deinterlace filters
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
  else
    DEINTERLACE=false
  fi

  # Denoise filters
  # -filter_complex "hwmap=derive_device=vulkan,scale_vulkan=1920:1080,hwmap=derive_device=cuda"
  get_noise F_V_NOISE $F $PIX_BITS
  echo "overall noise: " $F_V_NOISE[all]
  if $DENOISE && (( $F_V_NOISE[all]>=0.05 )); then
    get_preset_values DENOISE_RESEARCH_SIZES DN_RESEARCH_SIZE
    get_preset_values DENOISE_PATCH_SIZES DN_PATCH_SIZE
    # Weak strength, the noise value should be between 0 - 1.0
    # nlmeans indexing for specific values is avuy (alpha, chroma_v, chroma_u, luminance)
    # CPU nlmeans strength is 1.0 - 30.0
    clamp $(( F_V_NOISE[all] * DENOISE_SCALE/3.0 + 1.0 )) 1.0 30.0 DN_STRENGTH
    # Vulkan can take avuy values 0.0 - 100.0
    clamp $(( F_V_NOISE[y] * DENOISE_SCALE )) 0.0 100.0 DN_Y_STRENGTH
    clamp $(( F_V_NOISE[u] * DENOISE_SCALE )) 0.0 100.0 DN_U_STRENGTH
    clamp $(( F_V_NOISE[v] * DENOISE_SCALE )) 0.0 100.0 DN_V_STRENGTH
    echo "Denoise strength: all=${DN_STRENGTH} y=${DN_Y_STRENGTH} u=${DN_U_STRENGTH} v=${DN_V_STRENGTH}"
    # DN_VULKAN_FILTER="nlmeans_vulkan=s1=${DN_V_STRENGTH}:s2=${DN_U_STRENGTH}:s3=${DN_Y_STRENGTH}:r=${DN_RESEARCH_SIZE}:p=${DN_PATCH_SIZE}"
    DN_VULKAN_FILTER="nlmeans_vulkan"
    DENOISE_FILTER_ARR=()
    # CPU
    DENOISE_FILTER_ARR+="nlmeans=s=${DN_STRENGTH}:p=${DN_PATCH_SIZE}:r=${DN_RESEARCH_SIZE}"
    # NVIDIA CUDA
    DENOISE_FILTER_ARR+="hwupload=derive_device=vulkan,$DN_VULKAN_FILTER,hwupload=derive_device=cuda"
    # AMD VULKAN
    if $DEINTERLACE; then
      DENOISE_FILTER_ARR+="$DN_VULKAN_FILTER,hwmap=derive_device=amf"
    else
      DENOISE_FILTER_ARR+="hwmap=derive_device=vulkan,format=vulkan,$DN_VULKAN_FILTER,hwmap=derive_device=amf"
    fi
    # INTEL QSV
    DENOISE_FILTER_ARR+="hwmap=derive_device=vulkan,$DN_VULKAN_FILTER,hwmap=derive_device=qsv"
    # APPLE (CPU)
    DENOISE_FILTER_ARR+="nlmeans"
    select_on_device DENOISE_FILTER_ARR DENOISE_FILTER
    VIDEO_FILTER_ARR+=($DENOISE_FILTER)
  else
    DENOISE=false
    if $DEINTERLACE && [[ $GPU=="amd" ]]; then
      VIDEO_FILTER_ARR+=("hwmap=derive_device=amf")
    fi
  fi

  # MAP ARGS
  # Video
  MAP_ARGS=(-map 0:v)
  DISPOSITION_ARGS=()
  # Audio
  if [[ $A_LANGUAGE != "keep" ]]; then
      DISPOSITION_ARGS+=(-disposition:a:m:language:$A_LANGUAGE default -disposition:a:0 0)
  fi

  if [[ $A_LANGUAGES_SELECTED != "all" ]]; then
      A_LANGUAGES=()
      A_LANGUAGES_SELECTED=(${(s[,])A_LANGUAGES_SELECTED})
      if [[ ${A_LANGUAGES_SELECTED[(r)$A_LANGUAGE]} != $A_LANGUAGE && $A_LANGUAGE != "keep" ]]; then
        A_LANGUAGES_SELECTED+=(${A_LANGUAGE})
      fi
      get_languages A_LANGUAGES_SELECTED F_A_LANGUAGES A_LANGUAGES
      for lang in $A_LANGUAGES; do
        MAP_ARGS+=(-map a:m:language:$lang)
      done
  else
    MAP_ARGS+=(-map 0:a)
  fi
  # Subtitles
  if (( ${STREAMS[(Ie)subtitle]} )); then
    echo "Subtitle stream found"
    F_S_LANGUAGES=($(ffprobe -hide_banner -v error -select_streams s -show_entries stream_tags=language -of default=noprint_wrappers=1:nokey=1 $F))
    F_S_CODEC=$(ffprobe -hide_banner -v error -select_streams s:0 -show_entries streams=codec_name -of default=noprint_wrappers=1:nokey=1 $F)
    # echo -e "Subtitle probe results:\n" $F_S_CODEC

    if [[ $S_LANGUAGE != "keep" ]]; then
        DISPOSITION_ARGS+=(-disposition:s:m:language:$S_LANGUAGE default -disposition:s:0 0)
    fi

    if [[ $S_LANGUAGES_SELECTED != "all" ]]; then
      S_LANGUAGES=()
      S_LANGUAGES_SELECTED=(${(s[,])S_LANGUAGES_SELECTED})
      if [[ ${S_LANGUAGES_SELECTED[(r)$S_LANGUAGE]} != $S_LANGUAGE && $S_LANGUAGE != "keep" && $S_LANGUAGE != "none" ]]; then
        S_LANGUAGES_SELECTED+=(${S_LANGUAGE})
      fi
      get_languages S_LANGUAGES_SELECTED F_S_LANGUAGES S_LANGUAGES
      echo $S_LANGUAGES
      for lang in $S_LANGUAGES; do
        MAP_ARGS+=(-map s:m:language:$lang)
      done
    else
      MAP_ARGS+=(-map 0:s)
    fi
    S_ENCODE_ARGS=(-c:s copy)
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
  get_v_encode_args $GPU $DEVICE_IDX $DEVICE


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
