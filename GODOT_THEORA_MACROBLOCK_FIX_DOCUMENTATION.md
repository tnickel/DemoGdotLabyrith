# GODOT 4 THEORA MACROBLOCK & PIXEL CORRUPTION FIX
**Date**: April 2026

## The Problem
When converting standard `.mp4` (H.264/H.265) videos to Godot's officially supported `.ogv` (Ogg Theora) format, massive visual glitches, green pixels, and white macroblocks often tear through the screen.

This corruption is NOT a Godot bug. This is a severe failure of `libtheora`'s motion-estimation algorithm when processing complex high-movement scenes, or when FFmpeg accidentally maps hidden `mjpeg` cover thumbnails into the motion vector pipeline.

## The Solution
To permanently fix the visual corruption, you MUST force `libtheora` into an **Intra-Only Encoding Mode** using the `-g 1` parameter (Group of Pictures = 1).
This forces FFmpeg to encode every single video frame as an independent Keyframe. By mathematically eliminating P-Frames and B-Frames, motion vector corruption becomes physically impossible.

### The Perfect FFmpeg Conversion Script
To perfectly convert any MP4 for Godot 4 without glitches, use the following template:

```powershell
ffmpeg -i input.mp4 -map 0:v:0 -map 0:a:0? -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1:1" -pix_fmt yuv420p -c:v libtheora -q:v 7 -g 1 -c:a libvorbis -q:a 5 output.ogv
```

### Parameter Breakdown
*   `-map 0:v:0` -> **CRITICAL**: Strips hidden thumbnail channels that crash the Theora muxer.
*   `-pix_fmt yuv420p` -> Standardizes color space (VLC and Godot will crash without this).
*   `-q:v 7` -> Very high visual quality (values range 0-10, 7 is optimal).
*   `-g 1` -> **THE MAGIC BULLET**: Forces 100% Keyframe intra-encoding. File sizes will be larger, but visual tearing is 100% eliminated.

*This document was generated and stored explicitly to prevent future recurrence of the Theora corruption bug.*
