# Renders index.html -> frames (jpeg pipe) + offline WebAudio music/SFX -> MP4 with voiceover
import asyncio,base64,subprocess,sys,os
from playwright.async_api import async_playwright
OUT=sys.argv[1] if len(sys.argv)>1 else "/workspace/monkey_desk/monkey_desk_day8.mp4"
VO=sys.argv[2] if len(sys.argv)>2 else "/workspace/monkey_desk/vo_day8.wav"
D="/workspace/monkey_desk"
DAYCFG=sys.argv[3] if len(sys.argv)>3 else ""   # e.g. day_configs/2026-10-16.js (relative to index.html)
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path="/usr/bin/google-chrome")
        pg=await b.new_page(viewport={"width":1080,"height":1920})
        await pg.goto(f"file://{D}/index.html?render=1"+(f"&day={DAYCFG}" if DAYCFG else ""));await pg.wait_for_function("window.READY===true",timeout=20000)
        dur=await pg.evaluate("CONFIG.duration"); fps=30; n=int(dur*fps)
        wav=await pg.evaluate("renderAudioWav()"); open(f"{D}/music_sfx.wav","wb").write(base64.b64decode(wav))
        ff=subprocess.Popen(["ffmpeg","-y","-v","error","-f","image2pipe","-framerate",str(fps),"-c:v","mjpeg","-i","-","-c:v","libx264","-preset","medium","-crf","18","-pix_fmt","yuv420p",f"{D}/video_only.mp4"],stdin=subprocess.PIPE)
        for i in range(n):
            d=await pg.evaluate(f"(renderFrame({i/fps}),document.getElementById('c').toDataURL('image/jpeg',0.93))")
            ff.stdin.write(base64.b64decode(d.split(",")[1]))
            if i%150==0: print("frame",i,"/",n,flush=True)
        ff.stdin.close(); ff.wait(); await b.close()
    inputs=["-i",f"{D}/video_only.mp4","-i",f"{D}/music_sfx.wav"]
    if os.path.exists(VO):
        inputs+=["-i",VO]; fc="[2:a]volume=1.5,aresample=48000,pan=stereo|c0=c0|c1=c0[v];[1:a][v]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[a]"
    else: fc="[1:a]anull[a]"
    subprocess.run(["ffmpeg","-y","-v","error",*inputs,"-filter_complex",fc,"-map","0:v","-map","[a]","-c:v","copy","-c:a","aac","-b:a","192k","-ar","48000","-shortest","-movflags","+faststart",OUT],check=True)
    print("done",OUT)
asyncio.run(main())
