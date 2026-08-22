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
2) Filters
3) Encode

I decided to support as wide a base as possible.
- `amd` with `vulkan`
- `nvidia` with `cuda`
- `intel` with `qsv`
- `apple` with `videotoolbox`

- CPU
- GPU
    - `nvidia` use `cuda` 
    - `amd` use `amf` 

# To Do
- Better autodetection of pal/ntsc
    - Compare file lengths to online databases?
- Test:
    - Windows
    - Intel gpu
- Upscaling options
