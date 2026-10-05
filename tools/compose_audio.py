"""Original stereo score and UI cues; offline, deterministic, no AI audio service.
Kenney SFX are copied unchanged with their CC0 license. Music is authored here.
"""
from pathlib import Path
import numpy as np
import wave, subprocess, shutil

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio'
WORK=ROOT/'tools/audio_work'
OUT.mkdir(parents=True,exist_ok=True)
WORK.mkdir(parents=True,exist_ok=True)
RATE=22050
RNG=np.random.default_rng(4262026)

def hz(note): return 440*2**((note-69)/12)
def save(name,a):
    a=np.tanh(a*1.1)*.85
    if a.ndim==1:a=np.stack([a,a],axis=1)
    pcm=(np.clip(a,-1,1)*32767).astype('<i2')
    file=WORK/(name+'.wav')
    with wave.open(str(file),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(file),'-c:a','libvorbis','-q:a','5',str(OUT/(name+'.ogg'))],check=True)

def add(a,start,sound,pan=0):
    indices=(np.arange(len(sound))+int(start*RATE))%len(a)
    a[indices,0]+=sound*np.sqrt((1-pan)/2)
    a[indices,1]+=sound*np.sqrt((1+pan)/2)

def bell(note,length=3.2):
    t=np.arange(int(RATE*length))/RATE
    f=hz(note)
    return (np.sin(2*np.pi*f*t)*np.exp(-t*1.35)+.28*np.sin(2*np.pi*f*2.003*t)*np.exp(-t*3.4)+.1*np.sin(2*np.pi*f*3.98*t)*np.exp(-t*5))*np.minimum(t/.016,1)*.055

for stage in range(6):
    duration=96
    a=np.zeros((RATE*duration,2),dtype=np.float64)
    root=[45,50,43,48,46,41][stage]
    # A minor/add-nine progression with suspended upper voices, resolving at the seam.
    chords=[[0,3,7,14],[-5,2,7,10],[-2,2,5,12],[-7,0,3,10],[0,3,7,14],[-5,2,7,12],[-2,5,9,12],[-7,0,3,7]]
    for j,chord in enumerate(chords):
        t=np.arange(int(RATE*15))/RATE
        env=np.minimum(t/2.7,1)*np.minimum((15-t)/3.8,1)
        for k,note in enumerate(chord):
            f=hz(root+note)
            pad=np.sin(2*np.pi*f*t)+.32*np.sin(2*np.pi*(f*2+.09)*t)+.14*np.sin(2*np.pi*(f*3-.1)*t)
            pad*=env*(.027+.007*np.sin(t*.45+k))
            pan=(-.52 if k%2 else .52)
            add(a,j*12,pad,pan)
            add(a,j*12+.13,pad*.18,-pan)
    melody=[0,7,10,14,7,3,12,10,0,3,7,14,12,10,7,3]
    for j in range(48):
        if j%8 in [3,7]:continue
        n=root+24+melody[(j+stage*3)%len(melody)]
        tone=bell(n)*(.72 if stage<2 else .55)
        start=j*2+.6
        pan=np.sin(j*1.4)*.65
        add(a,start,tone,pan)
        add(a,start+.375,tone*.32,-pan)
        add(a,start+.75,tone*.14,pan)
    for j in range(48):
        t=np.arange(int(RATE*.7))/RATE
        pulse=np.sin(2*np.pi*hz(root-12)*t)*np.exp(-t*7)*np.minimum(t/.018,1)*.045
        add(a,j*2,pulse)
    save(f'music_{stage}',a)
    print('composed stage',stage)

# Independent adaptive boss pulse: no background track restart on an alarm.
a=np.zeros((RATE*24,2))
for j in range(48):
    t=np.arange(int(RATE*.65))/RATE
    kick=(np.sin(2*np.pi*(48*t+32*.05*(1-np.exp(-t/.05))))*np.exp(-t*10)+RNG.normal(0,.07,len(t))*np.exp(-t*45))*.20
    add(a,j*.5,kick)
    if j%2:
        noise=RNG.normal(0,1,len(t)); noise=np.concatenate([[0],np.diff(noise)])
        snare=noise*np.exp(-t*18)*.018
        add(a,j*.5+.25,snare,(-.25 if j%4 else .25))
save('boss_pulse',a)

for name,notes,spacing in [('purchase',[72,79,84],.085),('milestone',[60,67,72,79,84],.13),('wave_clear',[67,72,79],.14),('victory',[60,64,67,72,76,79,84],.26),('failed',[60,58,53,48],.28)]:
    a=np.zeros((RATE*4,2))
    for j,n in enumerate(notes):add(a,j*spacing,bell(n)*1.7,(j-len(notes)/2)*.10)
    save(name,a)
t=np.arange(RATE)/RATE
alarm=(np.sin(2*np.pi*330*t)+.25*np.sin(2*np.pi*660*t))*np.exp(-t*4)*np.minimum(t/.025,1)*.17
save('alarm',alarm)

src=ROOT/'tools/audio_source/kenney'
chosen=['thrusterFire_000','thrusterFire_002','laserLarge_000','laserLarge_002','laserLarge_004','laserSmall_001','laserSmall_003','forceField_002','engineCircular_002','lowFrequency_explosion_000','lowFrequency_explosion_001','explosionCrunch_000','explosionCrunch_003','impactMetal_000','impactMetal_002','computerNoise_000','spaceEngineLarge_002']
for name in chosen:shutil.copy2(src/'Audio'/(name+'.ogg'),OUT/(name+'.ogg'))
shutil.copy2(src/'License.txt',OUT/'KENNEY_LICENSE.txt')
