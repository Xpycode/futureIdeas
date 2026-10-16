#!/usr/bin/env python3
"""B7.1 bounded synthetic format research; output execution and media gates separately."""
import hashlib,json,platform,struct,subprocess,sys,tempfile,wave
from fractions import Fraction
from pathlib import Path
FF='/opt/homebrew/bin/ffmpeg'; FP='/opt/homebrew/bin/ffprobe'; RATE=48000; N=48024

def sha(b): return hashlib.sha256(b).hexdigest()
def require(ok,msg):
    if not ok: raise RuntimeError(msg)
def main():
    ev=Path(sys.argv[1]).resolve(); ev.mkdir(parents=True,exist_ok=False)
    tmp=Path(tempfile.mkdtemp(prefix='channelmap-formats-')); commands=[]
    results={'execution_status':'running','scratch':str(tmp),'platform':platform.platform(),'cases':[],'negative_controls':[]}
    def save():
        (ev/'commands.json').write_text(json.dumps(commands,indent=2))
        (ev/'results.json').write_text(json.dumps(results,indent=2))
    def run(args):
        args=list(map(str,args)); p=subprocess.run(args,capture_output=True,timeout=60); i=len(commands)
        (ev/f'command-{i:03d}.stderr.txt').write_bytes(p.stderr)
        commands.append({'argv':args,'exit':p.returncode,'stdout_bytes':len(p.stdout),'stdout_sha256':sha(p.stdout)})
        require(p.returncode==0,f'command {i}: {p.stderr.decode()[-2000:]}'); return p.stdout
    def ff(a): return run([FF,'-nostdin','-hide_banner','-v','error','-n',*a])
    def probe(p):
        d=json.loads(run([FP,'-v','error','-show_streams','-show_format','-show_packets','-show_data_hash','sha256','-of','json',p]))
        (ev/(p.name+'.probe.json')).write_text(json.dumps(d,indent=2));return d
    def audio(d): return [s for s in d['streams'] if s['codec_type']=='audio']
    def span(s):
        tb=Fraction(s['time_base']); start=int(s['start_pts'])*tb
        return (start,start+int(s['duration_ts'])*tb)
    def decode(p,idx,width): return ff(['-guess_layout_max','0','-i',p,'-map',f'0:{idx}','-c:a',f'pcm_s{width*8}le','-f',f's{width*8}le','-'])
    def deinterleave(b,ch,width,index):
        require(len(b)%(ch*width)==0,'partial frame'); return b''.join(b[i+index*width:i+(index+1)*width] for i in range(0,len(b),ch*width))
    def route(src,out,width,cs=(4,1),extra=''):
        filt=';'.join(f'[0:1]'+(extra+',' if extra else '')+f'pan=mono|c0=c{c}[a{i}]' for i,c in enumerate(cs))
        ff(['-copyts','-guess_layout_max','0','-i',src,'-filter_complex',filt,'-map','0:0','-map','[a0]','-map','[a1]','-c:v','copy','-c:a',f'pcm_s{width*8}le','-avoid_negative_ts','disabled','-movie_timescale',RATE,out])
    def assess(srcd,out,refs,width):
        d=probe(out); aud=audio(d); require(len(aud)==2,'output topology'); errors=[]; stats=[]
        for i,(s,ref) in enumerate(zip(aud,refs)):
            b=decode(out,s['index'],width)
            e=[]
            if b!=ref:e.append('sample_values')
            if len(b)!=len(ref):e.append('sample_count')
            if s['channels']!=1 or int(s['sample_rate'])!=RATE or s['codec_name']!=f'pcm_s{width*8}le':e.append('format')
            if span(s)!=span(audio(srcd)[0]): e.append('presentation_span')
            ps=[p for p in d['packets'] if p['stream_index']==s['index']]; tb=Fraction(s['time_base'])
            if any(int(p['size'])//width != int(p['duration'])*tb*RATE for p in ps):e.append('packet_duration')
            if any(int(p['pts'])+int(p['duration'])!=int(q['pts']) for p,q in zip(ps,ps[1:])):e.append('continuity')
            errors += [f'audio{i}_{x}' for x in e]
            stats.append({'samples':len(b)//width,'sha256':sha(b),'presentation_span':[str(x) for x in span(s)],'errors':e})
        def video(d):return [(p['pts'],p['duration'],p['size'],p['data_hash']) for p in d['packets'] if p['stream_index']==0]
        if video(d)!=video(srcd):errors.append('video_packets_or_timing')
        return errors,stats
    try:
        results['ffmpeg_version']=run([FF,'-version']).decode();results['ffprobe_version']=run([FP,'-version']).decode()
        results['executable_sha256']={x:sha(Path(p).read_bytes()) for x,p in [('ffmpeg',FF),('ffprobe',FP)]}
        results['harness_sha256']=sha(Path(__file__).read_bytes());(ev/'harness.snapshot.py').write_bytes(Path(__file__).read_bytes())
        video=tmp/'video.mov';ff(['-f','lavfi','-i','testsrc2=size=160x90:rate=25:duration=2','-an','-c:v','prores_ks','-profile:v','0','-pix_fmt','yuv422p10le',video])
        for name,ch,width,codec,offset in [('pcm32-eight',8,4,'copy','0.25'),('pcm24-six',6,3,'copy','0.25'),('aac-six-zero',6,4,'aac','0'),('aac-six-offset',6,4,'aac','0.25')]:
            # Integer-only independent oracle: >24 significant bits, odd low bits, positive/negative and unique channels.
            vals=[[((-1 if (n+c)%2 else 1)*((1<<29)+c*1000003+((n*7919)%10000019))*2+1 if width==4 else (-1 if (n+c)%2 else 1)*(500000+c*100003+(n*7919)%100003)) for n in range(N)] for c in range(ch)]
            refs=[b''.join(v.to_bytes(width,'little',signed=True) for v in vs) for vs in vals]
            inter=b''.join(refs[c][n*width:(n+1)*width] for n in range(N) for c in range(ch));wav=tmp/(name+'.wav')
            with wave.open(str(wav),'wb') as w:w.setnchannels(ch);w.setsampwidth(width);w.setframerate(RATE);w.writeframes(inter)
            src=tmp/(name+'.mov');ff(['-i',video,'-itsoffset',offset,*( ['-channel_layout','5.1'] if codec=='aac' else ['-guess_layout_max','0']),'-i',wav,'-map','0:0','-map','1:0','-c:v','copy','-c:a',codec,*(['-b:a','384k'] if codec=='aac' else []),'-movie_timescale',RATE,src])
            source_hash=sha(src.read_bytes());d=probe(src);s=audio(d)[0];require(s['channels']==ch,'fixture channel count')
            decoded=decode(src,1,width)
            if codec=='copy':require(decoded==inter,'PCM fixture changed')
            else:refs=[deinterleave(decoded,ch,width,c) for c in range(ch)]
            expected=[refs[4],refs[1]];out=tmp/(name+'-routed.mov');route(src,out,width);errors,stats=assess(d,out,expected,width)
            frameinfo=json.loads(run([FP,'-v','error','-select_streams','a:0','-show_frames','-of','json',src]));(ev/(src.name+'.frames.json')).write_text(json.dumps(frameinfo,indent=2))
            require(source_hash==sha(src.read_bytes()),'source changed')
            results['cases'].append({'name':name,'source':str(src),'output':str(out),'source_sha256':source_hash,'generated_frames':N,'decoded_frames':len(decoded)//(ch*width),'decoded_interleaved_sha256':sha(decoded),'reference_sha256':[sha(x) for x in expected],'source_presentation_span':[str(x) for x in span(s)],'source_audio_packets':[{k:p[k] for k in ('pts','duration','side_data_list') if k in p} for p in d['packets'] if p['stream_index']==1],'sample_gate':'passed' if not any('sample' in e or 'format' in e for e in errors) else 'failed','presentation_gate':'passed' if not errors else 'failed','errors':errors,'outputs':stats,'source_unchanged':True})
            controls=[('reversed',(1,4),'','sample_values'),('reset_pts',(4,1),'asetpts=PTS-STARTPTS','presentation_span')]
            if name=='pcm32-eight':controls += [('forced_float32',(4,1),'aformat=sample_fmts=flt','sample_values')]
            for control,cs,extra,required in controls:
                # Reset at zero is an identity, so test reset only when source starts later.
                if control=='reset_pts' and span(s)[0]==0:continue
                bad=tmp/(name+'-negative-'+control+'.mov');route(src,bad,width,cs,extra);errs,_=assess(d,bad,expected,width)
                require(any(required in e for e in errs),f'negative not caught: {name} {control}')
                results['negative_controls'].append({'fixture':name,'name':control,'errors':errs})
            # Exact low-bit perturbation and tail deletion exercise independent oracle, no FFmpeg pan reused.
            if name=='pcm32-eight':
                require(any(struct.unpack('<f',struct.pack('<f',float(v)))[0]!=v for v in vals[4]),'no beyond-float32 values')
                results['pcm32_non_float32_exact_samples']=sum(struct.unpack('<f',struct.pack('<f',float(v)))[0]!=v for v in vals[4])
        results['execution_status']='completed';results['all_media_gates_passed']=all(c['sample_gate']==c['presentation_gate']=='passed' for c in results['cases'])
    except Exception as e:results['execution_status']='failed';results['error']=repr(e);raise
    finally:save();print(json.dumps(results,indent=2))
if __name__=='__main__':main()
