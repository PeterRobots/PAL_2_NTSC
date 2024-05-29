#!/bin/zsh
echo Converting:
# echo $mkvs
# DIR=$1
DIR="/Volumes/USB WD750/Media/star_trek_DS9/S1_test"
echo "$DIR"
cd $DIR

if [ -z "$DIR" ]; then
    echo "\$DIR is empty"
    FILES=(*.mkv)
else
    # echo "\$DIR is NOT empty"
    if [ -d "$DIR" ]; then
        FILES=($DIR/*.mkv)
        echo "grabbing files"
    else
        echo "$DIR is NOT a folder"
    fi

fi

OUTDIR="$DIR/Output"
LOGDIR="$DIR/Logs"

mkdir -p $OUTDIR
mkdir -p $LOGDIR
echo $OUTDIR
counter=1
for F in $FILES
do
    echo "iteration = $counter"
    echo "file = $F"
    SCRIPT="$OUTDIR/script.avs"
    # echo "A = FFVideoSource(\"$F\")" > $SCRIPT
    # echo "B = FFAudioSource(\"$F\")" >> $SCRIPT
    # echo "AudioDub(A,B)" >> $SCRIPT
    # echo "FFmpegSource2(\"$F\")" > $SCRIPT
    # echo "AssumeFPS(24000,1001,sync_audio=true)" >> $SCRIPT
    # echo "ResampleAudio(48000)" >> $SCRIPT
    FN="$(basename "${F}")"
    FN_BASE="${FN%.*}"
    FN_RESAMPLED="${FN_BASE}_resampled2.mkv"
    FN_FINAL="${FN_BASE}_final.mkv"
    FN_CHAPTERS="$FN_BASE.txt"
    # echo "File $FN"
    # echo "File base $FN_BASE"
    # echo "$OUTDIR/${FN_BASE}_final.mkv"
    echo "Resampling audio and video"
    samplerate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 $F)
    let factor=24000.0/25025.0
    let inverse_factor=1.0/$factor
    let rate=24000.0/1001.0
    ffmpeg -threads auto -hwaccel auto -y -i $F -filter_complex "[0:V:0]setpts=PTS*$inverse_factor,fps=fps=ntsc_film[vout];[0:a:0]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate:[aout]" -map "[vout]" -map "[aout]" -aspect 4:3 -r:v $rate -vsync cfr -c:v hevc_videotoolbox -q:v 80 -c:a aac -b:a 320k -profile:v main -tag:v hvc1 "$OUTDIR/$FN_RESAMPLED" > ${LOGDIR}/${FN_BASE}_ff_out.txt 2> ${LOGDIR}/${FN_BASE}_ff_err.txt
    # ffmpeg -y -i $F -filter_complex "[0:a:m:language:eng]asetrate=$factor*$samplerate,aresample=resampler=soxr:osr=$samplerate" -sample_fmt s16 -map_chapters -1 -map_metadata -1 "$OUTDIR/$FN_BASE.eng.flac" 
    # mkvmerge -o "$OUTDIR/$FN_RESAMPLED" --no-chapters --no-audio --default-duration 0:${rate}fps "$f" --track-name "0:FLAC English" --language 0:eng "$OUTDIR/$FN_BASE.eng.flac"
    # echo "extracting chapters"
    # mkvextract "$F" chapters "$OUTDIR/$FN_CHAPTERS"
    # echo "Merging chapters with resampled"
    # mkvmerge -o "$OUTDIR/$FN_FINAL" --chapter-sync "0,$inverse_factor" --chapters "$OUTDIR/$FN_CHAPTERS" "$OUTDIR/$FN_RESAMPLED" > ${LOGDIR}/${FN_BASE}_merge_out.txt 2> ${LOGDIR}/${FN_BASE}_merge_err.txt
    echo "Cleaning up..."
    rm -f "$F.lwi"
    # rm -f script.avs
    rm -f "$OUTDIR/$FN_CHAPTERS"
    # mv "$OUTDIR/${FN_BASE}_final.mkv" "$OUTDIR/$FN"
    echo "Done."
    let counter++
done