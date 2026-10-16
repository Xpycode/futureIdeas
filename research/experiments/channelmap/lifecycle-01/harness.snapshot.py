#!/usr/bin/env python3
"""Disposable B7 lifecycle experiments; not a production export service."""
import errno, hashlib, json, os, platform, signal, subprocess, sys, tempfile, time
from pathlib import Path
FF = '/opt/homebrew/bin/ffmpeg'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def require(ok, msg):
    if not ok: raise RuntimeError(msg)
def main():
    evidence = Path(sys.argv[1]).resolve(); evidence.mkdir(parents=True, exist_ok=False)
    root = Path(tempfile.mkdtemp(prefix='channelmap-b7-lifecycle-'))
    result = dict(status='running', scratch=str(root), platform=platform.platform(), cases=[])
    commands=[]
    def record(name, **details): result['cases'].append(dict(name=name, **details))
    def run(args):
        p=subprocess.run([str(x) for x in args], capture_output=True, timeout=15)
        commands.append(dict(argv=[str(x) for x in args], exit=p.returncode, stderr=p.stderr.decode(errors='replace')))
        return p
    def publish(part, final):
        # Same protocol as B6: per-file only. Validation is caller responsibility.
        os.link(part, final); part.unlink()
    try:
        result['version']=run([FF,'-version']).stdout.decode()
        result['ffmpeg_sha256']=sha(FF); result['harness_sha256']=sha(__file__)
        (evidence/'harness.snapshot.py').write_bytes(Path(__file__).read_bytes())
        part=root/'collision.partial'; final=root/'existing.output'
        part.write_bytes(b'new validated bytes'); final.write_bytes(b'existing user destination')
        old=sha(final)
        try: publish(part, final)
        except FileExistsError as e: require(e.errno==errno.EEXIST,'wrong collision error')
        else: raise RuntimeError('collision clobbered destination')
        require(sha(final)==old and part.exists(),'collision state changed')
        record('existing_destination', diagnostic='EEXIST', destination_unchanged=True, partial_retained=True)
        # Actual competing creation after a preflight absence check.
        race=root/'race.output'; require(not race.exists(),'race baseline')
        race.write_bytes(b'competitor won'); old=sha(race)
        try: publish(part,race)
        except FileExistsError: pass
        else: raise RuntimeError('TOCTOU overwrite')
        require(sha(race)==old,'race clobber'); record('creation_after_preflight', destination_unchanged=True)
        success=root/'success.output'; publish(part, success)
        require(success.read_bytes()==b'new validated bytes' and not part.exists(),'publish failed')
        record('successful_publication', partial_removed=True, content_exact=True)
        # A later output fails: demonstrate that B6 is not a job transaction.
        later=root/'later.partial'; later.write_bytes(b'second')
        try: publish(later,final)
        except FileExistsError: pass
        else: raise RuntimeError('expected later collision')
        require(success.read_bytes()==b'new validated bytes' and later.exists() and final.read_bytes()==b'existing user destination', 'multi output state')
        record('later_output_failure', earlier_output_remains=True, job_atomic=False)
        failed=root/'failed.partial.wav'; failed_final=root/'failed.wav'
        p=run([FF,'-nostdin','-v','error','-n','-f','lavfi','-i','anullsrc=r=48000:cl=mono','-t','0.1','-af','no_such_channelmap_filter',failed])
        require(p.returncode!=0 and 'No such filter' in p.stderr.decode(), 'wrong worker failure')
        require(not failed_final.exists(),'failed job published')
        failed.unlink(missing_ok=True)
        record('ffmpeg_filter_failure', exit=p.returncode, published=False, partial_cleaned=True)
        try: run([root/'missing-helper'])
        except FileNotFoundError as e: require(e.errno==errno.ENOENT,'missing helper diagnostic')
        else: raise RuntimeError('missing helper accepted')
        record('missing_helper', diagnostic='ENOENT', published=False)
        # Deliberately injected storage error, not a physical full disk.
        injected=root/'enospc.partial'; injected.write_bytes(b'incomplete')
        try: raise OSError(errno.ENOSPC, 'injected disk-full boundary')
        except OSError as e:
            require(e.errno==errno.ENOSPC,'wrong injected error'); injected.unlink()
        require(not injected.exists() and not (root/'enospc.output').exists(),'injected failure published')
        record('injected_ENOSPC', level='in-process injected error after partial write', published=False, partial_cleaned=True)
        # Start only our own bounded-rate worker, wait until it writes, then cancel/reap.
        cancel=root/'cancel.partial.wav'; canceled_final=root/'cancel.wav'
        args=[FF,'-nostdin','-v','error','-n','-re','-f','lavfi','-i','anullsrc=r=48000:cl=mono','-c:a','pcm_s24le',str(cancel)]
        log=root/'cancel.stderr'
        with log.open('wb') as err:
            worker=subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=err,start_new_session=True)
            forced=False
            try:
                deadline=time.monotonic()+8
                while time.monotonic()<deadline and worker.poll() is None and (not cancel.exists() or cancel.stat().st_size<4096): time.sleep(.05)
                require(worker.poll() is None and cancel.exists() and cancel.stat().st_size>=4096,'worker did not enter writing phase')
                size=cancel.stat().st_size; start=time.monotonic()
                os.killpg(worker.pid,signal.SIGTERM)
                try: code=worker.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    forced=True; os.killpg(worker.pid,signal.SIGKILL); code=worker.wait(timeout=2)
                elapsed=time.monotonic()-start
                require(worker.poll() is not None and elapsed<5,'cancellation not bounded')
                # wait() has reaped the direct child; no shell/child-launching filters used.
                try: os.waitpid(worker.pid,os.WNOHANG)
                except ChildProcessError: reaped=True
                else: reaped=False
                require(reaped,'child not reaped')
            finally:
                if worker.poll() is None:
                    os.killpg(worker.pid,signal.SIGKILL); worker.wait(timeout=2)
        commands.append(dict(argv=args,exit=code,stderr=log.read_text()))
        cancel.unlink(missing_ok=True)
        require(not canceled_final.exists() and not cancel.exists(),'cancellation publication/cleanup')
        record('cancel_active_ffmpeg', bytes_before_cancel=size, latency_seconds=elapsed, forced_kill=forced, child_reaped=reaped, published=False, partial_cleaned=True)
        # Cancellation after validation but before commit: explicit guard, oracle control.
        pre=root/'precommit.partial'; pre.write_bytes(b'validated'); canceled=True
        if not canceled: publish(pre,root/'precommit.output')
        pre.unlink()
        require(not (root/'precommit.output').exists(),'precommit cancel ignored')
        record('precommit_cancel_guard', level='in-process cancellation flag', published=False)
        result['status']='passed'
    except Exception as e:
        result['status']='failed'; result['error']=repr(e); raise
    finally:
        (evidence/'results.json').write_text(json.dumps(result,indent=2))
        (evidence/'commands.json').write_text(json.dumps(commands,indent=2))
        print(json.dumps(result,indent=2))
if __name__=='__main__': main()
