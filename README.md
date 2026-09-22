# Requirements
- Tested on `mac` and `linux`
- Untested `windows (wsl)`
- `ZSH`
- `ffmpeg`
    - (mac/linux/wsl) (brew) you can install a fullfat ffmpeg with: `brew install ffmpeg-full`
    - (windows) (chocolatey) #untested you can install ffmpeg with chocolatey: `choco install ffmpeg-full`
    - Or download an appropriate version from ffmpeg: https://ffmpeg.org/download.html
        - Ensure appropriate libraries for your intended use (H264, H265, AV1, hardware acceleration...)
        - Check your installed ffmpeg output with: `ffmpeg` in your terminal.        

## Test systems
```Linux
OS: Bazzite 44
CPU: 9700K
GPU: 2070 super
```

```Mac
OS: MacOS Tahoe
CPU: M1
GPU: M1 (videotoolbox)
```

# Method
- Check available hardware acceleration methods with `ffmpeg -hwaccels`
	- It will list available libraries and decoders/encoders compatible with and installed on your system
- Input a video file (`.mkv` container recommended) or folder containing video files from DVD or BLURAY.
- Set output path or filename.
- Specify device for hardware acceleration or purely software.
- Set quality preset `(default: medium)`: `l|low`, `m|medium`, `h|high`, `u|uncompressed`, `k|keep`
- Set type of video file: DVD pal/ntsc or BLURAY
- Set verbosity `-v level`
    - Without `level`, `-v` sets to `verbose`

Example: `./fix_video_format.zsh -i ./bad_pal_video.mkv -cv h264 -d nvidia -al eng -sl none -p medium -ofs ntsc_film -o ./fixed_pal_video.mkv`
`./fix_video_format.zsh`, source and run the program in zsh environment
`-i ./bad_pal_video.mkv`, input file path
`-cv h264`, (Opt) video codec
`-d nvidia`, (Opt) Hardware accelerator
`-al eng`, (Opt) default audio language
`-sl none`, (Opt) default subtitle language (none disables subtitles by default)
`-p medium`, (Opt) quality preset
`-ofs ntsc_film`, (Opt) correct/original format of media
`-o fixed_pal_video.mkv`, (Opt) output location and name.

# Presets
1) Low
	- Some quality loss compared to source
	- Smallest file size (aiming for `~0.3X` compression)
2) Medium
	- Slight loss of quality compared to source
	- Reasonable file size (`~0.6X` compression)
3) High
	- Intended to visually lossless compared to source
	- Some compression compared to source (`~0.9X` compression)
4) Keep
# Audio
I've aimed to minimise codec choice on quality with the presets, but there will be some variation. Additionally not all codecs offer all features, some do not offer `vbr` or `7.1` surround.

Variable rate (`vbr`) will be more efficient than Constant (`cbr`), but may not playback as well on older devices (more computationally demanding).
## Video
Similarly to audio I aimed to minimise the effect of codec choice on the video quality where possible. Like with audio, not all codecs or hardware accelerated methods are equal and there will be some variation in quality.

I've also tried to standardise for quality across encoding methods. You should get the same quality with the same preset, regardless of codec or encoder.
This is something I'm actively working on, I need to do image quality comparisons, ideally with quantitative results.
The file sizes are not standardised, `cpu` will usually have better file sizes for the same quality.

For now I've done the best I can with the hardware I have access to. (Please bug report if you have issues!)


# Explanation
Years ago I wanted a solution for fixing badly converted PAL/NTSC DVDs. This started me on a journey to learn how to use ffmpeg and various libraries and filters in order to achieve that.
This project is the culmination of that and it's evolved into a larger framework that includes encoding/decoding options and tries to streamline using ffmpeg for those less familiar.

Q) Could you just use ffmpeg or mkvtoolnix without this?
A) Yes and if you want features not supported by this program I encourage you to explore.

Q) handbrake? 
A) 100% and I encourage you to try it, it's feature rich, has cli and gui interaction, and is open sourced (hurray!). I skipped straight to ffmpeg years ago and didn't really investigate it until very recently. 

Q) https://github.com/staxrip/staxrip
A) If you use windows it looks like a great option

I justify this project accessible script for fixing badly converted region formatted media with streamlined encoding options.

### Options
The first choice is whether you want to use software `cpu` method or some kind of hardware accelerated method.

Tradtionally `cpu` encoding offers the best compression i.e. best quality for a given file size.
Where possible I have endeavoured to feature and quality match hardware accelerated options. I have chosen to sacrifice file size a bit for hardware accelerated options.
You can still aim for smaller files with a lower quality preset or use `cpu` for optimal file sizes at the cost of speed.

- Software `cpu` encoding 
	- Decoding: `all`
	- Encoding: `all`
	- Filters: `all`
- `amd` with `amf` and `vulkan`
	- Supports a range of amd chips, codec support will be limited on older gpus or igpus
	- Decoding (`amf`): H.264, HEVC, AV1
	- Encoding (`amf`): H.264, HEVC, AV1
	- Filters (`vulkan`): scale, deinterlace
- `nvidia` with `cuda`
	- Supports a range of nvidia gpus, codec support will be limited on older gpus
	- Decoding: H.264, HEVC, MJPEG, MPEG-1/2/4, VP8/VP9, VC-1, AV1
	- Encoding: `all`
		- https://docs.nvidia.com/video-technologies/video-codec-sdk/13.1/nvenc-application-note/index.html
	- Filters:  scale, deinterlace
- `intel` with `qsv`
	- Supports a range of intel chips, codec support will be limited on older gpus or igpus
	- Decoding: H.264, MPEG-2, MPEG-4 part 2, VC-1, H.265
	- Encoding: H.264, HEVC, AV1
	- Filters:  scale, deinterlace
	- Compatibility and setup is a bit of a nightmare.
 		- https://trac.ffmpeg.org/wiki/Hardware/QuickSync
 		- Untested for now.
- `apple` with `videotoolbox`
	- Supports a range of apple chips, codec support will be limited on older chips and intel based macs may not work with this option
	- Decoding: H.263, H.264, HEVC, MPEG-1, MPEG-2, MPEG-4 Part 2, ProRes
	- Encoding: H.264, HEVC, ProRes
	- Filters (`cpu`): `all`

### Stages
There's three stages where cpu or hardware acceleration comes into play, depending on available hardware, not all stages may be possible.
1) Bit stream packet timestamp changes
	- Only activated if `-ofs` is set
2) Decode
	- DVDs: MPEG-2
	- Blu-rays: H.264 (MPEG-4 AVC), VC-1, or MPEG-2.
	- 4K Ultra HD Blu-rays: H.265 (HEVC)
	I do not specify input codecs, I leave this up to ffmpeg and hardware acceleration libraries to handle. This could cause some edge cases to fail, such as if an acceleration device does not support `mpeg2video` or another codec.
3) Filters
	- Video:
		- If using `gpu` methods, pixel formats and chroma subsampling will be altered to compatible pixel formats.
  			- I've done my best to automatically preserve bit depth and chroma subsampling.
		- Deinterlace
	- Audio:
		- Correct pitch and runtime
4) Encode
	- Choice of codecs with optimised presets
	- `cpu`
	- Hardware accelerated
		- Aim of equivalence in quality with `cpu`, but faster (YMMV)
