#!/usr/bin/env python3
"""B7.2 synthetic MOV metadata investigation; no application acceptance.
Usage: python3 wider_metadata.py NEW_EVIDENCE_DIRECTORY
"""
import hashlib, json, platform, subprocess, sys, tempfile, wave
from fractions import Fraction
from pathlib import Path
FF='/opt/homebrew/bin/ffmpeg'
FP='/opt/homebrew/bin/ffprobe'
def sha(b): return hashlib.sha256(b).hexdigest()
def require(ok, message):
    if not ok: raise RuntimeError(message)
def main():
    evidence=Path(sys.argv[1]).resolve(); evidence.mkdir(parents=True,exist_ok=False)
    scratch=Path(tempfile.mkdtemp(prefix='channelmap-metadata-'))
    commands=[]; result={'status':'running','scratch':str(scratch),'platform':platform.platform()}
    def run(args):
        args=list(map(str,args)); p=subprocess.run(args,capture_output=True,timeout=60)
        i=len(commands); (evidence/f'command-{i:03d}.stderr.txt').write_bytes(p.stderr)
        commands.append({'argv':args,'exit':p.returncode,'stdout_sha256':sha(p.stdout)})
        require(p.returncode==0,f'command {i}: {p.stderr.decode()[-3000:]}'); return p.stdout
    def ff(args): return run([FF,'-nostdin','-hide_banner','-v','error','-n',*args])
    def probe(path):
        d=json.loads(run([FP,'-v','error','-show_streams','-show_format','-show_packets','-show_data_hash','sha256','-of','json',path]))
        (evidence/(path.name+'.probe.json')).write_text(json.dumps(d,indent=2)); return d
    def video(d): return next(s for s in d['streams'] if s['codec_type']=='video')
    def meta(d):
        v=video(d)
        return {'rotation':[s for s in v.get('side_data_list',[]) if s.get('side_data_type')=='Display Matrix'],
                'color':{k:v.get(k) for k in ['color_range','color_space','color_transfer','color_primaries']},
                'video_timecode':v.get('tags',{}).get('timecode'),
                'timecode_tracks':[{'codec_tag_string':s.get('codec_tag_string'),'timecode':s.get('tags',{}).get('timecode'), 'avg_frame_rate':s.get('avg_frame_rate'),'time_base':s.get('time_base'),'duration_ts':s.get('duration_ts'),'packets':[(p.get('data_hash'),p.get('pts'),p.get('duration')) for p in d['packets'] if p['stream_index']==s['index']]} for s in d['streams'] if s.get('codec_tag_string')=='tmcd']}
    def seq(d):
        v=video(d); tb=Fraction(v['time_base']); ps=[p for p in d['packets'] if p['stream_index']==v['index']]
        return [(p['size'],p['data_hash']) for p in ps],[(str(int(p['pts'])*tb),str(int(p['dts'])*tb),str(int(p['duration'])*tb)) for p in ps]
    def pcm(path,index): return ff(['-i',path,'-map',f'0:{index}','-c:a','pcm_s24le','-f','s24le','-'])
    try:
        result['ffmpeg_version']=run([FF,'-version']).decode();result['ffprobe_version']=run([FP,'-version']).decode()
        result['executable_sha256']={p:sha(Path(p).read_bytes()) for p in [FF,FP]}
        result['harness_sha256']=sha(Path(__file__).read_bytes());(evidence/'harness.snapshot.py').write_bytes(Path(__file__).read_bytes())
        refs=[b''.join((((n*1009+c*70001)%4000001)-2000000).to_bytes(3,'little',signed=True) for n in range(48000)) for c in range(8)]
        raw=b''.join(refs[c][n*3:n*3+3] for n in range(48000) for c in range(8))
        wav=scratch/'input.wav'
        with wave.open(str(wav),'wb') as w:
            w.setnchannels(8);w.setsampwidth(3);w.setframerate(48000);w.writeframes(raw)
        base=scratch/'base.mov'
        ff(['-f','lavfi','-i','testsrc2=size=160x90:rate=25:duration=2','-i',wav,'-map','0:v','-map','1:a','-c:v','prores_ks','-profile:v','0','-pix_fmt','yuv422p10le','-color_primaries','bt2020','-color_trc','smpte2084','-colorspace','bt2020nc','-color_range','tv','-c:a','pcm_s24le','-timecode','01:02:03:04',base])
        src=scratch/'source.mov'
        ff(['-display_rotation:v:0','90','-i',base,'-map','0:v','-map','0:a','-c','copy','-bsf:v','prores_metadata=color_primaries=bt2020:color_trc=smpte2084:colorspace=bt2020nc','-color_primaries','bt2020','-color_trc','smpte2084','-colorspace','bt2020nc',src])
        source_hash=sha(src.read_bytes()); sd=probe(src); sm=meta(sd)
        require(sm['rotation'] and abs(sm['rotation'][0]['rotation'])==90,'fixture rotation absent')
        require(sm['color']=={'color_range':'tv','color_space':'bt2020nc','color_transfer':'smpte2084','color_primaries':'bt2020'},'fixture color absent')
        require(sm['video_timecode']=='01:02:03:04' and len(sm['timecode_tracks'])==1 and sm['timecode_tracks'][0]['timecode']=='01:02:03:04','fixture timecode absent')
        require(pcm(src,1)==raw,'fixture PCM differs')
        result['source_metadata']=sm
        out=scratch/'routed.mov'
        ff(['-copyts','-guess_layout_max','0','-i',src,'-filter_complex','[0:1]pan=mono|c0=c4[a0];[0:1]pan=mono|c0=c1[a1]','-map','0:0','-map','[a0]','-map','[a1]','-c:v','copy','-c:a','pcm_s24le','-avoid_negative_ts','disabled','-movie_timescale','48000',out])
        od=probe(out); om=meta(od)
        result['routed_metadata']=om;result['metadata_equal']={k:sm[k]==om[k] for k in sm}
        result['metadata_losses']=[k for k in sm if sm[k]!=om[k]]
        require(seq(sd)==seq(od),'copied video payload/timing changed')
        aud=[s for s in od['streams'] if s['codec_type']=='audio'];require(len(aud)==2,'audio topology')
        checks=[]
        for s,c in zip(aud,[4,1]):
            b=pcm(out,s['index']);require(b==refs[c] and s['channels']==1,'numeric route mismatch')
            checks.append({'channel_index':c,'samples':len(b)//3,'sha256':sha(b)})
        result['routing']={'video_packets':len(seq(sd)[0]),'video_payload_and_pts_dts_duration_equal':True,'audio':checks}
        # Actual remux controls. The color control edits encoded headers as well as container hints.
        cases=[('rotation_removed',['-display_rotation:v:0','0'],[],['rotation']),
               ('timecode_removed',[],['-map_metadata','-1','-map_metadata:s:v','-1','-write_tmcd','0'],['video_timecode','timecode_tracks']),
               ('color_removed',[],['-bsf:v','prores_metadata=color_primaries=unknown:color_trc=unknown:colorspace=unknown','-color_primaries','unknown','-color_trc','unknown','-colorspace','unknown'],['color'])]
        result['negative']=[]
        for name,pre,post,expected in cases:
            bad=scratch/(name+'.mov');ff([*pre,'-i',out,'-map','0:v','-map','0:a','-c','copy',*post,bad]);bd=probe(bad);bm=meta(bd)
            differences=[k for k in sm if sm[k]!=bm[k]]
            require(set(expected)<=set(differences),f'{name} not detected: {differences}')
            if name=='rotation_removed':require(not bm['rotation'],'rotation not removed')
            if name=='timecode_removed':require(bm['video_timecode'] is None and not bm['timecode_tracks'],'timecode not removed')
            if name=='color_removed':require(all(bm['color'][k] in [None,'unknown','reserved'] for k in ['color_space','color_transfer','color_primaries']),'color not cleared')
            result['negative'].append({'name':name,'rejected_by':differences,'metadata':bm,'video_payload_equal':seq(sd)[0]==seq(bd)[0],'video_timing_equal':seq(sd)[1]==seq(bd)[1]})
        require(sha(src.read_bytes())==source_hash,'source changed');result['source_unchanged']=True
        result['status']='completed_with_losses' if result['metadata_losses'] else 'passed'
    except Exception as e:
        result['status']='failed';result['error']=repr(e);raise
    finally:
        (evidence/'commands.json').write_text(json.dumps(commands,indent=2));(evidence/'results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
