# Requirements
- Tested on `mac` and `linux`, untested on `windows`.
- `ZSH`
- `ffmpeg`
    - (mac/linux/wsl) (brew) you can install a fullfat ffmpeg with: `brew install ffmpeg-full`
    - (windows) (chocolatey) you can install ffmpeg with chocolatey: `choco install ffmpeg-full`
    - Or download an appropriate version from ffmpeg: https://ffmpeg.org/download.html
        - Ensure appropriate libraries for your intended use (H264, H265, AV1, hardware acceleration...)
        - Check your installed ffmpeg output with: `ffmpeg` in your terminal.        
- `mkvtoolnix` installed

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

Example: `./fix_video_format.zsh -i bad_pal_video.mkv -t pal -p medium -d gpu -v -o fixed_pal_video.mkv`

# Explanation
Years ago I wanted a solution for fixing badly converted PAL/NTSC DVDs. This started me on a journey to learn how to use ffmpeg and various libraries and filters in order to achieve that.
This project is the culmination of that and it's evolved into a larger framework that includes encoding/decoding options and tries to streamline using ffmpeg for those less familiar.

Q) Could you just use ffmpeg or mkvtoolnix without this?
A) Yes and if you want features not supported by this program I encourage you to explore.

Q) handbrake? 
A) 100% and I encourage you to try it, it's feature rich, has cli and gui interaction, and is open sourced (hurray!). I skipped straight to ffmpeg years ago and didn't really investigate it until very recently. 

I justify this project as a wrapper for ffmpeg to simplify the for setting up a simple routine to fix, deinterlace and encode a wide selection of DVDs and Blurays in a user friendly consistently 'good' way. 
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
	- Missing deinterlacing support on `amf` required `directx`, `vaapi` or `vulkan`
		- I went with `vulkan` as it was newer and crossplatform
	- Decoding (`amf`): H.264, HEVC, AV1
	- Encoding (`amf`): H.264, HEVC, AV1
	- Filters (`vulkan`): scale, deinterlace
- `nvidia` with `cuda`
	- Supports a range of nvidia gpus, codec support will be limited on older gpus
	- Decoding: H.264, HEVC, MJPEG, MPEG-1/2/4, VP8/VP9, VC-1, AV1
	- Encoding: `all`
	- Filters:  scale, deinterlace
- `intel` with `qsv`  https://trac.ffmpeg.org/wiki/Hardware/QuickSync
	- Supports a range of intel chips, codec support will be limited on older gpus or igpus
	- Decoding: H.264, MPEG-2, MPEG-4 part 2, VC-1, H.265
	- Encoding: H.264, HEVC, AV1
	- Filters:  scale, deinterlace
	- Compatibiltity and setup is a bit of a nightmare.
- `apple` with `videotoolbox`
	- Supports a range of apple chips, codec support will be limited on older chips and intel based macs may not work with this option
	- Decoding: H.263, H.264, HEVC, MPEG-1, MPEG-2, MPEG-4 Part 2, ProRes
	- Encoding: H.264, HEVC, ProRes
	- Filters (`cpu`): `all` 
- I have yet to explore`VAAPI` as an option https://trac.ffmpeg.org/wiki/Hardware/VAAPI
### Stages
There's three stages where cpu or hardware acceleration comes into play, depending on available hardware, not all stages may be possible.
0) `.mkv` manipulation with `mkvtoolnix`
	- If **not deinterlacing** and you just want to correct speeds, this is skips other stages and just fixes the timestamps of each stream.
1) Decode
	- DVDs: MPEG-2
	- Blu-rays: H.264 (MPEG-4 AVC), VC-1, or MPEG-2.
	- 4K Ultra HD Blu-rays: H.265 (HEVC)
	I do not specify input codecs, I leave this up to ffmpeg and hardware acceleration libraries to handle. This could cause some edge cases to fail, such as if an acceleration device does not support `mpeg2video` or another codec.
2) Filters
	- Video: 
		- Correct FPS and runtime
		- Deinterlace
	- Audio:
		- Correct pitch and runtime
3) Encode
	- Choice of codecs with optimised presets
	- `cpu`
	- Hardware accelerated
		- Aim of equivalence in quality with `cpu`, but faster (YMMV)
# Examples
VA-API example of transcope with deinterlace (intel/amd option)
https://trac.ffmpeg.org/wiki/Hardware/VAAPI
  ```sh
  ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi -i input.mp4 -vf 'deinterlace_vaapi=rate=field:auto=1' -c:v hevc_vaapi -b:v 5M output.mp4
  ```
 
 H264 qsv decode + h264 qsv encode with 5Mbps using ICQ && Look_ahead mode (similar to x264 crf)
 https://trac.ffmpeg.org/wiki/Hardware/QuickSync
```sh
ffmpeg -hwaccel qsv -c:v h264_qsv -i input.mp4 -vf 'vpp_qsv=deinterlace=2' -c:v h264_qsv -global_quality 25 -look_ahead 1 output.mp4
```
# To Do
- Better autodetection of pal/ntsc
    - Compare file lengths to online databases?
- Test:
    - Windows
    - Intel gpu
- Upscaling options
