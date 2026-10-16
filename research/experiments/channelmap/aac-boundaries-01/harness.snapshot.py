#!/usr/bin/env python3
"""Bounded B7 AAC edit oracle. Only generated, single-rate, contiguous MOV edits."""
import hashlib, json, struct, subprocess, sys
from pathlib import Path
from fractions import Fraction
FF='/opt/homebrew/bin/ffmpeg'; FP='/opt/homebrew/bin/ffprobe'; RATE=48000

def sha(b): return hashlib.sha256(b).hexdigest()
def need(ok, why):
    if not ok: raise ValueError(why)
def boxes(b, start=0, end=None):
    end=len(b) if end is None else end
    while start<end:
        need(start+8<=end,'short box header')
        size,kind=struct.unpack_from('>I4s',b,start); header=8
        if size==1:
            need(start+16<=end,'short extended header'); size=struct.unpack_from('>Q',b,start+8)[0]; header=16
        elif size==0: size=end-start
        need(size>=header and start+size<=end,'invalid box size')
        yield kind,start+header,start+size
        start+=size

def parse(path):
    b=path.read_bytes()
    def child(a,z,t):
        found=[(s,e) for k,s,e in boxes(b,a,z) if k==t];need(len(found)==1,'missing/duplicate '+str(t));return found[0]
    moov=child(0,len(b),b'moov');mv,_=child(*moov,b'mvhd')
    need(b[mv] in (0,1),'mvhd version'); ms=struct.unpack_from('>I',b,mv+(20 if b[mv] else 12))[0]
    tracks=[]
    for k,a,z in boxes(b,*moov):
        if k!=b'trak':continue
        mdia=child(a,z,b'mdia'); hd,_=child(*mdia,b'hdlr')
        if b[hd+8:hd+12]!=b'soun':continue
        md,_=child(*mdia,b'mdhd');need(b[md] in (0,1),'mdhd version')
        scale=struct.unpack_from('>I',b,md+(20 if b[md] else 12))[0]
        ed=child(a,z,b'edts'); el,ee=child(*ed,b'elst');v=b[el];need(v in (0,1),'elst version')
        count=struct.unpack_from('>I',b,el+4)[0];p=el+8;entries=[]
        for _ in range(count):
            fmt='>Qqhh' if v else '>Iihh';length=struct.calcsize(fmt);need(p+length<=ee,'short edit')
            dur,media,ri,rf=struct.unpack_from(fmt,b,p);entries.append(dict(duration=dur,media_time=media,rate=[ri,rf],offset=p));p+=length
        need(p==ee,'trailing edit bytes');tracks.append(dict(movie_scale=ms,media_scale=scale,entries=entries,version=v))
    return tracks

def contract(t):
    need(t['movie_scale']>0 and t['media_scale']==RATE,'unsupported timescale')
    cursor=Fraction(0); spans=[]
    for e in t['entries']:
        need(e['rate']==[1,0] and e['duration']>0,'unsupported rate/duration')
        dur=Fraction(e['duration']*RATE,t['movie_scale']);need(dur.denominator==1,'fractional sample boundary')
        if e['media_time']==-1:need(not spans,'interior/trailing empty edit unsupported')
        else:
            need(e['media_time']>=0,'invalid media time');spans.append((int(cursor),e['media_time'],int(dur)))
        cursor+=dur
    need(len(spans)==1,'only one media edit supported');return spans[0]

def main():
    ev=Path(sys.argv[1]);ev.mkdir(exist_ok=False);cmds=[];result={'status':'running','cases':[]}
    (ev/'harness.snapshot.py').write_bytes(Path(__file__).read_bytes())
    def run(args):
        args=list(map(str,args));p=subprocess.run(args,capture_output=True,timeout=60);i=len(cmds)
        cmds.append({'argv':args,'exit':p.returncode,'stdout_sha256':sha(p.stdout)});(ev/f'{i:03d}.stderr.txt').write_bytes(p.stderr)
        need(p.returncode==0,p.stderr.decode()[-2000:]);return p.stdout
    def ff(args):return run([FF,'-nostdin','-v','error','-n',*args])
    def probe(p):
        d=json.loads(run([FP,'-v','error','-show_streams','-show_packets','-show_data_hash','sha256','-of','json',p]));(ev/(p.stem+'.probe.json')).write_text(json.dumps(d,indent=2));return d
    def dec(p,idx=1,ignore=False):return ff([*(['-ignore_editlist','1'] if ignore else []),'-i',p,'-map',f'0:{idx}','-c:a','pcm_s32le','-f','s32le','-'])
    def mono(b,c):return b''.join(b[i+c*4:i+c*4+4] for i in range(0,len(b),24))
    def video(d):
        tb=Fraction(d['streams'][0]['time_base']);return [(int(p['pts'])*tb,int(p['dts'])*tb,int(p['duration'])*tb,p['data_hash']) for p in d['packets'] if p['stream_index']==0]
    try:
        result['ffmpeg_version']=run([FF,'-version']).decode(); result['harness_sha256']=sha(Path(__file__).read_bytes())
        prior=json.loads(Path('research/experiments/channelmap/formats-04/results.json').read_text())
        sources=[]
        for c in prior['cases'][2:]:
            src=Path(c['source']);need(sha(src.read_bytes())==c['source_sha256'],'historical fixture hash mismatch')
            dest=ev/(c['name']+'.mov');dest.write_bytes(src.read_bytes());sources.append(dest)
        # A separate explicit edit fixture: retain priming exclusion, non-packet-aligned edges and exact 250 ms delay.
        b=bytearray(sources[1].read_bytes());t=parse(sources[1])[0];e0,e1=t['entries']
        struct.pack_into('>I',b,e0['offset'],12000)
        struct.pack_into('>Ii',b,e1['offset'],47000,1061)
        # Track duration must agree with the two edits (tkhd v0 in this generated fixture).
        for k,a,z in boxes(b):
            if k==b'moov':
                for kk,aa,zz in boxes(b,a,z):
                    if kk==b'trak':
                        childlist=list(boxes(b,aa,zz));mdia=next((s,e) for q,s,e in childlist if q==b'mdia')
                        hd=next(s for q,s,e in boxes(b,*mdia) if q==b'hdlr')
                        if b[hd+8:hd+12]==b'soun':
                            tk=next(s for q,s,e in childlist if q==b'tkhd');need(b[tk]==0,'tkhd version');struct.pack_into('>I',b,tk+20,59000)
        edited=ev/'aac-explicit-edit.mov';edited.write_bytes(b);sources.append(edited)
        for src in sources:
            before=sha(src.read_bytes());tracks=parse(src);need(len(tracks)==1,'source topology');t=tracks[0];start,media,count=contract(t)
            d=probe(src);raw=dec(src,ignore=True);normal=dec(src)
            need(len(raw)%24==0 and media+count<=len(raw)//24,'raw decode coverage')
            refs=[mono(raw[media*24:(media+count)*24],c) for c in (4,1)]
            case={'name':src.stem,'source_sha256':before,'atoms':t,'presentation_start_sample':start,'media_start_sample':media,'presentation_samples':count,'raw_frames':len(raw)//24,'normal_frames':len(normal)//24,'tail_outside_edit':len(raw)//24-media-count,'variants':[]}
            # Use an edit-disabled full decode for deterministic media indexing. Independent Python oracle slices bytes.
            for name,lo,n,shift,channels in [('bounded',media,count,0,(4,1)),('head_plus_one',media+1,count-1,0,(4,1)),('tail_minus_one',media,count-1,0,(4,1)),('tail_plus_one',media,count+1,0,(4,1)),('shift_one',media,count,1,(4,1)),('reversed',media,count,0,(1,4))]:
                out=ev/(src.stem+'-'+name+'.mov')
                filt=';'.join(f'[0:1]atrim=start_sample={lo}:end_sample={lo+n},asetpts=N/SR/TB+{start+shift}/SR/TB,pan=mono|c0=c{c}[a{i}]' for i,c in enumerate(channels))
                ff(['-copyts','-ignore_editlist','1','-i',src,'-filter_complex',filt,'-map','0:0','-map','[a0]','-map','[a1]','-c:v','copy','-c:a','pcm_s32le','-avoid_negative_ts','disabled','-movie_timescale',RATE,out])
                od=probe(out);ot=parse(out);aud=[s for s in od['streams'] if s['codec_type']=='audio'];need(len(aud)==len(ot)==2,'output topology')
                errors=[];hashes=[]
                for i,s in enumerate(aud):
                    got=dec(out,s['index']);hashes.append(sha(got))
                    if got!=refs[i]:errors.append(f'{i}:samples')
                    if len(got)!=count*4:errors.append(f'{i}:count')
                    a,m,nout=contract(ot[i])
                    if (a,nout)!=(start,count):errors.append(f'{i}:atom_timeline')
                    tb=Fraction(s['time_base']);span=(int(s['start_pts'])*tb*RATE,int(s['duration_ts'])*tb*RATE)
                    if span!=(start,count):errors.append(f'{i}:probe_timeline')
                    ps=[p for p in od['packets'] if p['stream_index']==s['index']]
                    if any(int(p['size'])!=int(p['duration'])*tb*RATE*4 for p in ps):errors.append(f'{i}:packet_size_duration')
                    if any(int(p['pts'])+int(p['duration'])!=int(q['pts']) for p,q in zip(ps,ps[1:])):errors.append(f'{i}:continuity')
                if video(od)!=video(d):errors.append('video')
                need(not errors if name=='bounded' else bool(errors),'unexpected gate '+name)
                if name=='shift_one':need(any('timeline' in e for e in errors) and not any('samples' in e for e in errors),'shift oracle separation')
                case['variants'].append({'name':name,'errors':errors,'sample_sha256':hashes})
            need(sha(src.read_bytes())==before,'source mutation');result['cases'].append(case)
        result['status']='passed'
    except Exception as e:result['status']='failed';result['error']=repr(e);raise
    finally:
        (ev/'results.json').write_text(json.dumps(result,indent=2));(ev/'commands.json').write_text(json.dumps(cmds,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
