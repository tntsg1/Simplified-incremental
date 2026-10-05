"""Analyze captured engine output, not an assumed mix. Does not judge pleasure."""
from pathlib import Path
import sys,json,wave
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools/analysis_deps'))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
proof=root/'proofs'
cases=[('Before: rejected sample','audio_before.wav','#d38882'),('Clean SFX: same feedback fixture','runtime_audio.wav','#7edcc5'),('Clean SFX: continuous combat','continuous_clean.wav','#e1c28c')]
fig,axes=plt.subplots(3,3,figsize=(15,10),layout='constrained')
fig.patch.set_facecolor('#0b1620')
report={}
for row,(title,name,color) in enumerate(cases):
 with wave.open(str(proof/name),'rb') as f:
  rate=f.getframerate(); channels=f.getnchannels(); bits=f.getsampwidth()
  assert bits==2
  a=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float64).reshape(-1,channels)/32768
 mono=a.mean(axis=1)
 peak=float(np.max(np.abs(a))); rms=float(np.sqrt(np.mean(a*a)))
 size=int(rate*.085333333333); step=size//2; window=np.hanning(size)
 spectra=np.array([4*np.abs(np.fft.rfft(mono[i:i+size]*window)/window.sum())**2 for i in range(0,len(mono)-size,step)])
 spectrum=spectra.mean(axis=0); frequency=np.fft.rfftfreq(size,1/rate)
 power=float(spectrum.sum())
 report[name]=dict(seconds=len(a)/rate,channels=channels,rate=rate,peak_dbfs=float(20*np.log10(max(peak,1e-12))),rms_dbfs=float(20*np.log10(max(rms,1e-12))),crest_db=float(20*np.log10(max(peak,1e-12)/max(rms,1e-12))),clipped_samples=int(np.count_nonzero(np.abs(a)>=.999)),dc_abs=float(abs(a.mean())),energy_above_4k_percent=float(spectrum[frequency>4000].sum()/power*100),energy_below_60_percent=float(spectrum[frequency<60].sum()/power*100))
 # A common full-scale view of the loudest 60 ms, so headroom stays visible.
 loudest=int(np.argmax(np.abs(mono)))
 start=max(0,min(len(mono)-int(rate*.06),loudest-int(rate*.03)))
 excerpt=mono[start:start+int(rate*.06)]
 axes[row,0].plot(np.arange(len(excerpt))/rate*1000,excerpt,color=color,lw=.6)
 axes[row,0].set_ylim(-1,1)
 axes[row,0].set_xlabel('Time (ms)'); axes[row,0].set_ylabel('Amplitude (full scale)')
 axes[row,0].set_title(title+'\nLoudest 60 ms',color=color,fontsize=10)
 stride=max(1,int(rate*.1))
 envelope=np.array([np.max(np.abs(mono[i:i+stride])) for i in range(0,len(mono),stride)])
 axes[row,1].plot(np.arange(len(envelope))*stride/rate,20*np.log10(np.maximum(envelope,1e-7)),color=color,lw=.8)
 axes[row,1].set_ylim(-65,0)
 axes[row,1].set_xlabel('Time (s)');axes[row,1].set_ylabel('100 ms peak (dBFS)')
 axes[row,1].set_title(f'Peak {report[name]["peak_dbfs"]:.1f} / RMS {report[name]["rms_dbfs"]:.1f} dBFS',color=color,fontsize=10)
 shown=(frequency>=30)&(frequency<=8000)
 db=10*np.log10(np.maximum(spectra[:,shown].T,1e-14))
 axes[row,2].imshow(db,origin='lower',aspect='auto',extent=(0,len(mono)/rate,frequency[shown][0],frequency[shown][-1]),vmin=-100,vmax=-20,cmap='magma')
 axes[row,2].set_xlabel('Time (s)');axes[row,2].set_ylabel('Frequency (Hz)')
 axes[row,2].set_title(f'>4 kHz energy {report[name]["energy_above_4k_percent"]:.3f}%',color=color,fontsize=10)
 for axis in axes[row]:
  axis.set_facecolor('#102332');axis.tick_params(colors='#a8bcc8',labelsize=8)
  axis.xaxis.label.set_color('#b8c9d3');axis.yaxis.label.set_color('#b8c9d3')
  for spine in axis.spines.values():spine.set_color('#385160')
fig.suptitle('SKYGUARD — waveform / headroom / spectral audit\nNo hearing claim. Lower noise and clean peaks do not establish subjective sound quality.',color='#d9e5ec',fontsize=13)
fig.savefig(proof/'audio_analysis.png',dpi=140,facecolor=fig.get_facecolor())
(proof/'audio_analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for name,metrics in report.items():print(name,json.dumps(metrics))
