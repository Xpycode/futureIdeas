#!/usr/bin/env python3
"""CM-E1 synthetic CLI research, not an application/export implementation.
Usage: python3 routing_experiment.py NEW_EVIDENCE_DIRECTORY
Media is retained in the recorded unique temporary directory; JSON/logs in evidence.
"""
import copy, hashlib, json, math, os, platform, subprocess, sys, tempfile, wave
from fractions import Fraction
from pathlib import Path

FF = "/opt/homebrew/bin/ffmpeg"
FP = "/opt/homebrew/bin/ffprobe"
RATE = 48000
N = 48000

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def filehash(path):
    return digest(Path(path).read_bytes())

def main():
    evidence = Path(sys.argv[1]).resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    scratch = Path(tempfile.mkdtemp(prefix="channelmap-cm-e1-"))
    commands, results = [], {"status": "running", "scratch": str(scratch),
        "platform": platform.platform(), "positive": [], "negative": []}

    def save():
        (evidence / "commands.json").write_text(json.dumps(commands, indent=2))
        (evidence / "results.json").write_text(json.dumps(results, indent=2))

    def run(args):
        args = [str(x) for x in args]
        p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45)
        i = len(commands)
        (evidence / f"command-{i:03d}.stderr.txt").write_bytes(p.stderr)
        commands.append({"argv": args, "exit": p.returncode,
                         "stdout_bytes": len(p.stdout), "stdout_sha256": digest(p.stdout)})
        require(p.returncode == 0, f"command {i} failed: {p.stderr.decode(errors='replace')[-2000:]}")
        return p.stdout

    def ff(args):
        return run([FF, "-nostdin", "-hide_banner", "-v", "error", "-n", *args])

    def probe(path):
        d = json.loads(run([FP, "-v", "error", "-show_streams", "-show_format",
            "-show_packets", "-show_data_hash", "sha256", "-of", "json", path]))
        (evidence / (path.name + ".probe.json")).write_text(json.dumps(d, indent=2))
        return d

    def stream(d, index):
        return next(s for s in d["streams"] if s["index"] == index)

    def packets(d, index):
        return [p for p in d["packets"] if p["stream_index"] == index]

    def times(d, index):
        tb = Fraction(stream(d, index)["time_base"])
        ps = packets(d, index)
        require(bool(ps), "missing packets")
        return [(int(p["pts"])*tb, int(p["duration"])*tb) for p in ps]

    def span(d, index):
        ts = times(d, index)
        return min(t for t, dur in ts), max(t+dur for t, dur in ts)

    def payloads(d, index):
        return [(p["size"], p["data_hash"]) for p in packets(d, index)]

    def pcm(path, index):
        return ff(["-guess_layout_max", "0", "-i", path, "-map", f"0:{index}",
                   "-c:a", "pcm_s24le", "-f", "s24le", "-"])

    def pcm_errors(actual, expected):
        errs = []
        if len(actual) != len(expected): errs.append("sample_count")
        if actual != expected: errs.append("sample_values")
        return errs

    def validate(source, output, expected, source_index):
        d = probe(output)
        errs = []
        vids = [s for s in d["streams"] if s["codec_type"] == "video"]
        auds = [s for s in d["streams"] if s["codec_type"] == "audio"]
        if len(vids) != 1 or len(auds) != 2: return ["topology"], {}
        vi = vids[0]["index"]
        if payloads(source, 0) != payloads(d, vi): errs.append("video_payload_sequence")
        if times(source, 0) != times(d, vi): errs.append("video_timeline")
        offsets, counts, hashes = [], [], []
        target = span(source, source_index)[0] - span(source, 0)[0]
        for ordinal, (s, ref) in enumerate(zip(auds, expected)):
            if (s["codec_name"], int(s["sample_rate"]), s["channels"], int(s["bits_per_sample"])) != ("pcm_s24le", RATE, 1, 24):
                errs.append(f"audio{ordinal}_format")
            actual = pcm(output, s["index"])
            errs += [f"audio{ordinal}_{e}" for e in pcm_errors(actual, ref)]
            offset = span(d, s["index"])[0] - span(d, vi)[0]
            if abs(offset-target) > Fraction(1, RATE): errs.append(f"audio{ordinal}_offset")
            if abs((span(d,s["index"])[1]-span(d,s["index"])[0])-Fraction(N,RATE)) > Fraction(1,RATE):
                errs.append(f"audio{ordinal}_duration")
            offsets.append(str(offset)); counts.append(len(actual)//3); hashes.append(digest(actual))
        return errs, {"audio_offsets_seconds": offsets, "samples_per_channel": counts,
                      "pcm_sha256": hashes, "video_packets": len(packets(d,vi)),
                      "video_span_seconds": [str(x) for x in span(d,vi)]}

    def route(src, idx, channels, dst, reset=False):
        parts = [f"[0:{idx}]pan=mono|c0=c{c}" +
                 (",asetpts=PTS-STARTPTS" if reset else "") + f"[a{i}]"
                 for i,c in enumerate(channels)]
        ff(["-copyts", "-guess_layout_max", "0", "-i", src,
            "-filter_complex", ";".join(parts), "-map", "0:0",
            "-map", "[a0]", "-map", "[a1]", "-c:v", "copy", "-c:a", "pcm_s24le",
            "-avoid_negative_ts", "disabled", "-movie_timescale", str(RATE), dst])

    def negative(name, errors, required):
        require(set(required).issubset(errors), f"negative {name} not rejected as intended: {errors}")
        results["negative"].append({"name":name, "rejected_by":errors})

    def check_plan(plan, src, d):
        require(plan["sha256"] == filehash(src), "source_snapshot_changed")
        s = stream(d, plan["absolute_stream_index"])
        require(s["codec_type"] == "audio", "not_audio")
        require(s["channels"] == plan["expected_channels"], "topology_changed")
        require(all(0 <= c < s["channels"] for c in plan["channels"]), "channel_absent")
        require(int(s["sample_rate"]) == RATE, "sample_rate_changed")

    try:
        results["ffmpeg_version"] = run([FF, "-version"]).decode()
        results["ffprobe_version"] = run([FP, "-version"]).decode()
        results["executable_sha256"] = {"ffmpeg":filehash(FF), "ffprobe":filehash(FP)}
        results["harness_sha256"] = filehash(__file__)
        # Ground truth built without FFmpeg routing. Each channel is unique and nonconstant.
        refs = []
        for variant in range(2):
            chans = []
            for ch in range(8):
                values = [int(1000000*math.sin(2*math.pi*(300+ch*100)*n/RATE))
                          + ((n*17+ch*101+variant*1009)%251)-125 for n in range(N)]
                if variant: values = [-v+101 for v in values]
                values[:8] = [((ch+1)*10000+variant*100000+n*13)*(-1 if n%2 else 1) for n in range(8)]
                chans.append(b"".join(v.to_bytes(3,"little",signed=True) for v in values))
            refs.append(chans)
            interleaved = b"".join(chans[ch][n*3:n*3+3] for n in range(N) for ch in range(8))
            with wave.open(str(scratch/f"input{variant}.wav"),"wb") as w:
                w.setnchannels(8); w.setsampwidth(3); w.setframerate(RATE); w.writeframes(interleaved)
        video = scratch/"video.mov"
        ff(["-f","lavfi","-i","testsrc2=size=160x90:rate=25:duration=2",
            "-an","-c:v","prores_ks","-profile:v","0","-pix_fmt","yuv422p10le",video])
        sources = []
        for multi in (False, True):
            src = scratch/("multi.mov" if multi else "single.mov")
            args = ["-i",video,"-itsoffset","0.25","-guess_layout_max","0","-i",scratch/"input0.wav"]
            if multi: args += ["-itsoffset","0.25","-guess_layout_max","0","-i",scratch/"input1.wav"]
            args += ["-map","0:0","-map","1:0"]
            if multi: args += ["-map","2:0"]
            ff([*args,"-c","copy","-movie_timescale",str(RATE),src])
            d = probe(src)
            require(span(d,0) == (Fraction(0),Fraction(2)), "fixture video span")
            require(len(packets(d,0)) == 50, "fixture video packet count")
            for idx in range(1, 3 if multi else 2):
                s=stream(d,idx)
                require(s["channels"] == 8 and int(s["sample_rate"]) == RATE, "fixture topology")
                require(span(d,idx) == (Fraction(1,4),Fraction(5,4)), "fixture offset/duration")
                expected=b"".join(refs[idx-1][ch][n*3:n*3+3] for n in range(N) for ch in range(8))
                require(pcm(src,idx)==expected, "fixture PCM changed during mux")
            sources.append((src,d))
        for multi, (src,d) in enumerate(sources):
            idx=2 if multi else 1
            plan={"source":str(src),"sha256":filehash(src),"size":src.stat().st_size,
                  "absolute_stream_index":idx,"channels":[4,1],"expected_channels":8,
                  "sample_rate":RATE,"sample_format":"pcm_s24le","intent":"two separate mono streams",
                  "declared_layout":stream(d,idx).get("channel_layout"),
                  "source_offset_seconds":"1/4"}
            (evidence/f"plan-{multi}.json").write_text(json.dumps(plan,indent=2))
            check_plan(plan,src,d)
            expected=[refs[multi][4],refs[multi][1]]
            temp=scratch/f"route-{multi}.partial.mov"
            route(src,idx,[4,1],temp)
            errs, stats=validate(d,temp,expected,idx)
            require(not errs, f"positive routing failed: {errs}")
            final=scratch/f"route-{multi}.mov"
            require(not final.exists(),"collision")
            os.link(temp,final); temp.unlink() # atomic no-clobber publication on this filesystem
            for c,ref in zip([4,1],expected):
                out=scratch/f"channel-{multi}-{c}.partial.wav"
                ff(["-guess_layout_max","0","-i",src,"-map",f"0:{idx}",
                    "-af",f"pan=mono|c0=c{c}","-c:a","pcm_s24le",out])
                wd=probe(out); ws=wd["streams"][0]
                require(ws["channels"]==1 and ws["codec_name"]=="pcm_s24le" and int(ws["sample_rate"])==RATE,"wav format")
                require(not pcm_errors(pcm(out,0),ref),"WAV sample mismatch")
                published=out.with_name(out.name.replace(".partial",""))
                os.link(out,published); out.unlink()
            require(filehash(src)==plan["sha256"],"source changed")
            results["positive"].append({"case":"multi-second-stream" if multi else "single",
                "output":str(final), "layout_from_probe":plan["declared_layout"], **stats,
                "wav_samples_exact":True,"source_unchanged":True})
        src,d=sources[0]; expected=[refs[0][4],refs[0][1]]
        for name,cs,reset,needed in [
            ("reversed",[1,4],False,["audio0_sample_values","audio1_sample_values"]),
            ("duplicated",[4,4],False,["audio1_sample_values"]),
            ("off_by_one",[5,2],False,["audio0_sample_values","audio1_sample_values"]),
            ("reset_timestamps",[4,1],True,["audio0_offset","audio1_offset"])]:
            bad=scratch/f"negative-{name}.mov"; route(src,1,cs,bad,reset)
            errs,_=validate(d,bad,expected,1); negative(name,errs,needed)
            if reset: require(not any("sample" in e for e in errs),"timing negative also altered PCM")
        src,d=sources[1]
        bad=scratch/"negative-wrong-stream.mov"; route(src,1,[4,1],bad)
        errs,_=validate(d,bad,[refs[1][4],refs[1][1]],2)
        negative("wrong_absolute_stream",errs,["audio0_sample_values","audio1_sample_values"])
        for name,raw,needed in [
            ("one_sample_changed",bytes([refs[0][4][0]^1])+refs[0][4][1:],["sample_values"]),
            ("one_sample_removed",refs[0][4][:-3],["sample_count","sample_values"])]:
            # Actual mutated PCM WAV goes through decoder before comparison.
            bad=scratch/f"negative-{name}.wav"
            with wave.open(str(bad),"wb") as w:
                w.setnchannels(1);w.setsampwidth(3);w.setframerate(RATE);w.writeframes(raw)
            negative(name,pcm_errors(pcm(bad,0),refs[0][4]),needed)
        bad=scratch/"negative-video-drop.mov"
        ff(["-copyts","-i",scratch/"route-0.mov","-map","0","-c","copy","-frames:v","49",
            "-avoid_negative_ts","disabled","-movie_timescale",str(RATE),bad])
        errs,_=validate(sources[0][1],bad,expected,1)
        negative("video_packet_dropped",errs,["video_payload_sequence","video_timeline"])
        base=json.loads((evidence/"plan-1.json").read_text())
        for name,changes in [("absent_channel",{"channels":[8,1]}),
                             ("changed_snapshot",{"sha256":"0"*64}),
                             ("topology_mismatch",{"expected_channels":6})]:
            p=copy.deepcopy(base);p.update(changes)
            try: check_plan(p,*sources[1])
            except RuntimeError as e: results["negative"].append({"name":name,"rejected_by":[str(e)],"level":"plan preflight"})
            else: raise RuntimeError(f"preflight accepted {name}")
        # Preserve unknown topology rather than manufacture speaker names in our plan.
        require(all(r["layout_from_probe"] is None for r in results["positive"]), "fixture acquired a declared layout; unknown-layout case not established")
        results["status"]="passed"
    except Exception as e:
        results["status"]="failed";results["error"]=repr(e)
        raise
    finally:
        save()
        print(json.dumps(results,indent=2))

if __name__=="__main__":
    main()
