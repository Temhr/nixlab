# aliases/scrcpy.sh — Android screen mirroring via scrcpy
# Common flags: h265 codec, 1080p cap, 30fps, no audio, screen off, stay awake, always on top

_SCRCPY_COMMON='--video-codec=h265 --max-size=1080 --max-fps=30 --no-audio --turn-screen-off --stay-awake --always-on-top --render-driver=opengl'

# Base (uses default render driver override only)
alias scrcpy='scrcpy --render-driver=opengl'

# Auto-detect single connected device (USB or TCP)
alias scrcpy-='scrcpy $SCRCPY_COMMON'

# USB — auto-detect or target a specific serial
alias scrcpy-d="scrcpy -d $_SCRCPY_COMMON"
alias scrcpy-d1="scrcpy -d -s HT69A0204070 $_SCRCPY_COMMON"
alias scrcpy-d3="scrcpy -d -s 92GAX00UA1   $_SCRCPY_COMMON"

# TCP/IP — auto-detect or target a specific IP
alias scrcpy-e="scrcpy --tcpip             $_SCRCPY_COMMON"
alias scrcpy-e1="scrcpy -s 192.168.0.191:5555 --tcpip $_SCRCPY_COMMON"
alias scrcpy-e3="scrcpy -s 192.168.0.193:5555 --tcpip $_SCRCPY_COMMON"

# Camera source (front/rear via scrcpy camera mode)
alias scrcpycam='scrcpy --video-source=camera --camera-size=1920x1080 -e --render-driver=opengl'

unset _SCRCPY_COMMON
