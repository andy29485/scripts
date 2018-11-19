# AZ's Scripts
A bunch of scripts that I wrote and sometimes use.

### cut.sh
cut a video using time codes

### flac-compress.sh
compress flac files

### gen-keframes.sh
Generates keyframe files for a video (for timing in Aegisub)

### ksetwallpaper.py
changes the wallpaper in KDE (because it has to be done in a complex way)

### link.sh
creates a symlink in an output dir, deletes old symlinks

### mscreen
starts a multi-user screen session

### mkgif.sh
creates an apng file (or a gif) from a video
(using time codes, and maybe crop parameters)
- Requires (needs to be in `$PATH`):
  - `apngasm` (apng tools)
  - `ffmpeg`
  - `convert` or `magick` (image magic)

### mpv-mkgif.lua
lua script for mpv.
- Requires (needs to be in `$PATH`):
  - `mkgif.sh` (that thing up above this one)
- copy to:
  - `%APPDATA%/mpv/scripts/` (windows)
  - `~/.config/mpv/scripts/` (GNU/Linux)
- Usage:
|     Shortcut    |          Action         |
| --------------- | ----------------------- |
|  `Shift+C`      | set crop                |
|  `g`            | set start time          |
|  `Shift+G`      | set end time            |
|  `Ctrl+g`       | make gif, with subs     |
|  `Ctrl+Shift+G` | make gif, without subs  |
|  `Ctrl+w`       | make webm, with subs    |
|  `Ctrl+Shift+W` | make webm, without subs |

### music-tag.py
tag an album (looks up stuff in vgmdb)

### op-ed-creator.sh
creates emby nfo files opening/ending of shows (video files)

### print.sh
print file to pdf (formats code)
