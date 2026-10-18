#!/bin/bash
# usage: ./make_vo.sh 9 nine   -> audio/vo_day9.mp3  (stock Microsoft Edge TTS voice en-US-GuyNeural, needs `pip install edge-tts`)
D=$1; WORD=${2:-$1}; cd "$(dirname "$0")"; mkdir -p audio
TTS=$(command -v edge-tts || echo .venv/bin/edge-tts)
$TTS --voice en-US-GuyNeural --rate=+20% \
  --text "One hundred dollars to start. One hundred thousand dollars is the goal. Day ${WORD}, let's trade!" --write-media /tmp/vo_raw.mp3
ffmpeg -y -v error -i /tmp/vo_raw.mp3 -af "silenceremove=start_periods=1:start_threshold=-40dB:stop_periods=-1:stop_duration=0.3:stop_silence=0.18:stop_threshold=-40dB" -ac 1 -ar 24000 -b:a 48k audio/vo_day${D}.mp3
echo "audio/vo_day${D}.mp3"
