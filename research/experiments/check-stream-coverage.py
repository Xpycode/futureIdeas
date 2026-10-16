"""Reproduce checker command stream selection on synthetic media; no app is launched."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ffmpeg = shutil.which('ffmpeg')
ffprobe = shutil.which('ffprobe')
if not ffmpeg or not ffprobe:
    raise SystemExit('Requires ffmpeg and ffprobe on PATH')
commands = []
def run(args):
    commands.append(args)
    r = subprocess.run(args, capture_output=True, text=True, timeout=60)
    if r.returncode:
        raise RuntimeError(r.stderr)
    return r
with tempfile.TemporaryDirectory(prefix='futureideas-streams-') as tmp:
    src = str(Path(tmp) / 'two-audio.mov')
    run([ffmpeg, '-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'color=c=black:s=64x64:r=25:d=2',
         '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000:duration=2',
         '-f', 'lavfi', '-i', 'sine=frequency=880:sample_rate=48000:duration=2',
         '-map', '0:v', '-map', '1:a', '-map', '2:a', '-c:v', 'mpeg4', '-c:a', 'pcm_s24le', src])
    before = hashlib.sha256(Path(src).read_bytes()).hexdigest()
    probe = json.loads(run([ffprobe, '-v', 'error', '-show_streams', '-of', 'json', src]).stdout)
    # Same argument policy as FFmpegAnalyzer; info verbosity makes mapping observable.
    automatic = run([ffmpeg, '-nostdin', '-v', 'info', '-i', src, '-f', 'null', '-'])
    explicit = run([ffmpeg, '-nostdin', '-v', 'info', '-i', src, '-map', '0:v?', '-map', '0:a?', '-f', 'null', '-'])
    # Execute the exact current argument policy too; success says nothing about omitted streams.
    exact = run([ffmpeg, '-nostdin', '-v', 'error', '-i', src, '-f', 'null', '-'])
    def mapping(log):
        return re.findall(r'Stream #0:(\d+) -> #0:\d+', log)
    audio_ids = [str(s['index']) for s in probe['streams'] if s['codec_type'] == 'audio']
    auto_ids, explicit_ids = mapping(automatic.stderr), mapping(explicit.stderr)
    assert len(audio_ids) == 2
    assert len(set(audio_ids) & set(auto_ids)) == 1
    assert set(audio_ids).issubset(explicit_ids)
    assert hashlib.sha256(Path(src).read_bytes()).hexdigest() == before
    summary = {
        'ffmpeg_version': run([ffmpeg, '-version']).stdout.splitlines()[0],
        'scope': 'CLI reproduction of source argument policy, not execution of the macOS app',
        'input_streams': [{'index': s['index'], 'type': s['codec_type'], 'codec': s['codec_name']} for s in probe['streams']],
        'automatic_mapping': auto_ids,
        'explicit_mapping': explicit_ids,
        'exact_checker_command_exit': exact.returncode,
        'exact_checker_command_stderr': exact.stderr,
        'source_unchanged': True,
        'conclusion': 'Current FFmpeg argument policy checks only one of two audio streams on this valid fixture.',
        'limits': 'No damaged-stream fixture, application execution, cancellation or full codec matrix tested.'
    }
    (HERE / 'stream-coverage-result.json').write_text(json.dumps(summary, indent=2)+'\n')
    (HERE / 'stream-coverage-commands.json').write_text(json.dumps(commands, indent=2)+'\n')
    (HERE / 'stream-coverage-auto.log').write_text(automatic.stderr)
    (HERE / 'stream-coverage-explicit.log').write_text(explicit.stderr)
    print(json.dumps(summary, indent=2))
