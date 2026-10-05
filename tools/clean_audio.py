"""Clean, deterministic SFX. Linear headroom, smooth envelopes, no saturation.
No recorded samples; band-limited tonal bodies and low-pass transient noise.
"""
from pathlib import Path
import numpy as np
import wave,subprocess,json
root=Path(__file__).resolve().parents[1]
out=root/'assets/audio'
work=root/'tools/audio_work'
work.mkdir(exist_ok=True)
rate=48000
rng=np.random.default_rng(41862)
stats=[]
def noise(n,cutoff):
 x=rng.normal(0,1,n)
 f=np.fft.rfftfreq(n,1/rate)
 y=np.fft.irfft(np.fft.rfft(x)*np.exp(-(f/cutoff)**4),n)
 return y/max(1e-9,float(np.max(np.abs(y))))
def write(name,length,f0,f1,harmonic,noise_gain,cutoff,decay,pan=.08):
 t=np.arange(int(length*rate))/rate
 phase=2*np.pi*(f1*t+(f0-f1)*(1-np.exp(-t/.035))*.035)
 tonal=np.sin(phase)+harmonic*np.sin(phase*2.01)
 a=(tonal+noise_gain*noise(len(t),cutoff))*np.exp(-t*decay)
 attack=np.sin(np.minimum(1,t/.012)*np.pi/2)**2
 release=np.sin(np.minimum(1,(length-t)/min(.12,length*.25))*np.pi/2)**2
 envelope=attack*release
 a*=envelope
 a-=np.mean(a)*envelope/max(1e-9,np.mean(envelope))
 a*=.6/max(1e-9,np.max(np.abs(a)))
 stereo=np.stack([a*np.sqrt(1-pan),a*np.sqrt(1+pan)],axis=1)
 # Linear attenuation only; never use tanh/clip to normalize.
 if np.max(np.abs(stereo))>.7:stereo*=.7/np.max(np.abs(stereo))
 path=work/(name+'.wav')
 with wave.open(str(path),'wb') as f:
  f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate)
  f.writeframes((stereo*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(path),'-c:a','libvorbis','-q:a','6',str(out/(name+'.ogg'))],check=True)
 power=np.abs(np.fft.rfft(a))**2
 freq=np.fft.rfftfreq(len(a),1/rate)
 stats.append(dict(name=name,seconds=length,peak_db=float(20*np.log10(np.max(np.abs(stereo)))),rms_db=float(20*np.log10(np.sqrt(np.mean(stereo**2)))),above_4k_ratio=float(power[freq>4000].sum()/power.sum()),dc=float(a.mean()),clipped_samples=int(np.count_nonzero(np.abs(stereo)>=.99))))
for i,spec in enumerate([
 (.21,280,120,.08,.55,1600,15),(.18,580,180,.12,.17,2600,20),
 (.31,310,230,.12,.10,1200,10),(.36,220,170,.22,.10,1000,8),
 (.42,260,146,.16,.12,900,7),(.49,180,110,.22,.08,750,6)
]):write('clean_fire_'+str(i),*spec,pan=(-.06 if i%2 else .06))
write('clean_hit_rock',.14,135,84,.08,.55,900,24)
write('clean_hit_ship',.17,480,280,.19,.17,1600,26)
write('clean_destroy',.37,100,58,.12,.48,800,10)
write('clean_elite',.52,120,62,.13,.32,900,8)
write('clean_boss',1.08,90,46,.20,.28,650,4)
(root/'proofs/clean_audio_source.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('11 clean SFX: no clipped samples, no saturation; metrics in proofs/clean_audio_source.json')
