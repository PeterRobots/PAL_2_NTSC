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
- Input a file or folder containing video files from DVD or BLURAY.
- Set output path or filename.
- Specify device for encoding
- Set quality preset
- Set type of video file: DVD pal/ntsc or BLURAY
- Set verbosity `-v level`
    - Without `level`, `-v` sets to `verbose`

Example: `./fix_video_format.zsh -i bad_pal_video.mkv -t pal -p medium -d gpu -v -o fixed_pal_video.mkv`

# Explanation
I enjoy a challenge and wanted a FOSS framework for fixing badly converted PAL/NTSC DVDs.
It's evolved into a larger framework that includes encoding/decoding options and tries to streamline using ffmpeg for those less familiar.

The process is split into two parts:
### Hardware acceleration
There's three stages where cpu or hardware acceleration comes into play:
1) Decode
	- **DVDs:** Uses the original **MPEG-2** video codec.
	- **Blu-rays:** Uses whichever codec the studio used on the disc, typically **H.264 (MPEG-4 AVC)**, **VC-1**, or **MPEG-2**.
	- **4K Ultra HD Blu-rays:** Uses the **H.265 (HEVC)** codec
2) Filters
3) Encode

I decided to support as wide a base as possible.
- Unaccelerated software `cpu` encoding
- `amd` with `vulkan`
	- `VAAPI` is an option
		- https://trac.ffmpeg.org/wiki/Hardware/VAAPI
- `nvidia` with `cuda`
- `intel` with `qsv`
	- https://trac.ffmpeg.org/wiki/Hardware/QuickSync
		- Compatibiltity and setup is a bit of a nightmare.
	- `vaapi` is also an option
		- https://trac.ffmpeg.org/wiki/Hardware/VAAPI
- `apple` with `videotoolbox`

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
