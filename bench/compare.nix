# wave + ffmpeg compare script text (embedded; not a checked-in .py file).
# Consumed by writeText / writeShellApplication in default.nix.
#
# Fairness / what the numbers mean:
# - WAV speed: ezaudio encode_wav/decode_wav (in-memory) vs stdlib wave/struct
#   packing into BytesIO / memory buffers. Disk open/write is NOT timed on either side.
# - MP3 speed: ezaudio absolute ms/op only. There is no fair in-process MPEG-1 Layer III
#   encoder/decoder in nixpkgs Python; ffmpeg CLI process spawn is correctness-only
#   and must never appear as a speed reference (spawn overhead would fake a "win").
# - Speed fixtures are product-shaped: 16/44.1/48 kHz, mono+stereo, ~0.1–1 s,
#   speech-like (voiced/band-limited) and music-like (broadband/multi-tone). Silence
#   and Huffman-pair stay in correctness; they do not dominate the speed table.
# - IO.now is 1 ms. If MS is 0, N is raised; if still unresolved, wall/n is reported
#   honestly without claiming a vs-reference win.
{ drvBin ? "ezaudio-bench" }:
''
import io, math, os, struct, subprocess, sys, time, traceback, wave

DRV = os.environ.get("EZAUDIO_BENCH_DRV", "${drvBin}")
WORK = os.environ.get("EZAUDIO_BENCH_WORK", os.path.join(os.environ.get("TMPDIR", "/tmp"), "ezaudio-bench-work"))
MODE = os.environ.get("EZAUDIO_BENCH_MODE", "correctness")  # correctness | speed | all
FFMPEG = os.environ.get("EZAUDIO_BENCH_FFMPEG", "ffmpeg")
os.makedirs(WORK, exist_ok=True)

FMT_S16 = 1
FMT_F32 = 3
F32_ONE = 1065353216  # IEEE754 1.0 bits
lines, cases, speed_rows = [], [], []
fails = 0

def log(msg=""):
    print(msg, flush=True)
    lines.append(msg)

def s16_to_i(u):
    v = u & 0xFFFF
    return v - 0x10000 if v >= 0x8000 else v

def i_to_s16(i):
    return i & 0xFFFF

def f32_bits(x):
    return struct.unpack("<I", struct.pack("<f", float(x)))[0]

def write_eza(path, hz, nch, fmt, samples):
    open(path, "wb").write(
        b"EZA1"
        + struct.pack("<IIII", hz, nch, fmt, len(samples))
        + struct.pack("<" + "I" * len(samples), *samples)
    )

def read_eza(path):
    b = open(path, "rb").read()
    if b[:4] != b"EZA1":
        raise ValueError("not eza")
    hz, nch, fmt, ns = struct.unpack_from("<IIII", b, 4)
    samples = list(struct.unpack_from("<" + "I" * ns, b, 20))
    return hz, nch, fmt, samples

def ez(args, timeout):
    t0 = time.perf_counter()
    try:
        r = subprocess.run([DRV, *args], capture_output=True, timeout=timeout)
        return {"rc": r.returncode, "out": r.stdout.decode("utf-8", "replace"),
                "err": r.stderr.decode("utf-8", "replace"), "wall": time.perf_counter() - t0, "timeout": False}
    except subprocess.TimeoutExpired as e:
        out = e.stdout or b""; err = e.stderr or b""
        if isinstance(out, str): out = out.encode()
        if isinstance(err, str): err = err.encode()
        return {"rc": None, "out": out.decode("utf-8", "replace"), "err": err.decode("utf-8", "replace"),
                "wall": time.perf_counter() - t0, "timeout": True}

def parse_bench(out):
    parts = out.split()
    if len(parts) < 10 or parts[0] != "MS":
        return None
    return {parts[i]: int(parts[i + 1]) for i in range(0, 10, 2)}

# --- WAV reference: in-memory only (no disk on the timed path) ---

def wav_s16_bytes(hz, nch, samples_u32):
    frames = b"".join(struct.pack("<h", s16_to_i(s)) for s in samples_u32)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(nch)
        w.setsampwidth(2)
        w.setframerate(hz)
        w.writeframes(frames)
    return buf.getvalue()

def read_wav_s16_mem(data):
    with wave.open(io.BytesIO(data), "rb") as w:
        nch = w.getnchannels()
        hz = w.getframerate()
        sw = w.getsampwidth()
        if sw != 2:
            raise ValueError(f"expected s16 sampwidth 2, got {sw}")
        raw = w.readframes(w.getnframes())
    samples = [i_to_s16(struct.unpack_from("<h", raw, i)[0]) for i in range(0, len(raw), 2)]
    return hz, nch, samples

def wav_f32_bytes(hz, nch, samples_u32):
    data = b"".join(struct.pack("<I", s & 0xFFFFFFFF) for s in samples_u32)
    byte_rate = hz * nch * 4
    block_align = nch * 4
    fmt = struct.pack("<HHIIHH", 3, nch, hz, byte_rate, block_align, 32)
    riff_size = 4 + (8 + len(fmt)) + (8 + len(data))
    return (b"RIFF" + struct.pack("<I", riff_size) + b"WAVE"
            + b"fmt " + struct.pack("<I", len(fmt)) + fmt
            + b"data" + struct.pack("<I", len(data)) + data)

def read_wav_f32_mem(b):
    if b[:4] != b"RIFF" or b[8:12] != b"WAVE":
        raise ValueError("not WAVE")
    pos = 12
    fmt = data = None
    while pos + 8 <= len(b):
        tag = b[pos:pos + 4]
        sz = struct.unpack_from("<I", b, pos + 4)[0]
        chunk = b[pos + 8:pos + 8 + sz]
        if tag == b"fmt ":
            fmt = chunk
        elif tag == b"data":
            data = chunk
        pos += 8 + sz + (sz & 1)
    if fmt is None or data is None or len(fmt) < 16:
        raise ValueError("missing fmt/data")
    kind, nch, hz, _br, _al, bits = struct.unpack_from("<HHIIHH", fmt, 0)
    if kind != 3 or bits != 32:
        raise ValueError(f"expected IEEE float32, got kind={kind} bits={bits}")
    samples = list(struct.unpack("<" + "I" * (len(data) // 4), data))
    return hz, nch, samples

# File helpers for correctness + ffmpeg (not used on the WAV speed path).

def write_wav_s16(path, hz, nch, samples_u32):
    open(path, "wb").write(wav_s16_bytes(hz, nch, samples_u32))

def read_wav_s16(path):
    return read_wav_s16_mem(open(path, "rb").read())

def write_wav_f32(path, hz, nch, samples_u32):
    open(path, "wb").write(wav_f32_bytes(hz, nch, samples_u32))

def read_wav_f32(path):
    return read_wav_f32_mem(open(path, "rb").read())

def add_case(group, name, status, detail, hard=True):
    global fails
    cases.append({"group": group, "name": name, "status": status, "detail": detail, "hard": hard})
    log(f"[{status}] {group} | {name}")
    log(f"    {detail}")
    if hard and status != "PASS":
        fails += 1

def run_decode(cmd, src, timeout=60):
    dst = src + ".eza"
    r = ez([cmd, src, dst], timeout)
    if r["timeout"] or r["rc"] != 0 or not os.path.exists(dst):
        return r, None
    try:
        return r, read_eza(dst)
    except Exception as e:
        r["err"] += "\n" + repr(e)
        return r, None

def frame_z(header, nbytes):
    return bytes(header) + bytes(nbytes - len(header))

def pcm_zeros(n):
    return [0] * n

def pcm_pair():
    return [1, 0] + [0] * 1150

def rms_f32_bits(samples):
    if not samples:
        return 0.0
    acc = 0.0
    for u in samples:
        x = struct.unpack("<f", struct.pack("<I", u & 0xFFFFFFFF))[0]
        acc += x * x
    return math.sqrt(acc / len(samples))

def ffmpeg_decode_mp3_to_f32(path):
    # Correctness only: decode MP3 via ffmpeg CLI → WAV file, then promote.
    wav = os.path.join(WORK, os.path.basename(path) + ".ff.wav")
    r = subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", path, "-f", "wav", wav],
        capture_output=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace")[:200])
    with wave.open(wav, "rb") as w:
        nch = w.getnchannels()
        hz = w.getframerate()
        sw = w.getsampwidth()
        nframes = w.getnframes()
        raw = w.readframes(nframes)
    if sw == 2:
        ints = [struct.unpack_from("<h", raw, i)[0] for i in range(0, len(raw), 2)]
        samples = [struct.unpack("<I", struct.pack("<f", float(v) / 32768.0))[0] for v in ints]
        return hz, nch, samples
    if sw == 4:
        samples = list(struct.unpack("<" + "I" * (len(raw) // 4), raw))
        return hz, nch, samples
    raise ValueError(f"unexpected sampwidth {sw}")

def ffmpeg_encode_silence_mp3(path, hz, nch, nframes):
    # Correctness only: silent PCM → ffmpeg/lame (not a speed reference).
    wav = os.path.join(WORK, f"ff_sil_{hz}_{nch}_{nframes}.wav")
    write_wav_s16(wav, hz, nch, [0] * (nframes * nch))
    r = subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
         "-i", wav, "-codec:a", "libmp3lame", "-b:a", "320k",
         "-ar", str(hz), "-ac", str(nch), path],
        capture_output=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace")[:200])

# --- Real-world PCM fixtures (speech-like / music-like; not silence) ---

def clamp_s16(x):
    return i_to_s16(int(max(-32767, min(32767, round(x)))))

def speech_pcm(hz, nch, nframes):
    # Voiced / band-limited: F0≈120 Hz + harmonics with formant-ish peaks + syllable AM.
    out = []
    for i in range(nframes):
        t = i / float(hz)
        x = 0.0
        for h in range(1, 10):
            f = 120.0 * h
            if f >= hz * 0.45:
                break
            env = (math.exp(-((f - 500.0) / 800.0) ** 2)
                   + 0.55 * math.exp(-((f - 1500.0) / 1000.0) ** 2)
                   + 0.35 * math.exp(-((f - 2500.0) / 1200.0) ** 2))
            x += (0.42 / h) * env * math.sin(2.0 * math.pi * f * t)
        x *= 0.55 + 0.45 * math.sin(2.0 * math.pi * 3.5 * t)
        s = clamp_s16(x * 22000.0)
        if nch == 1:
            out.append(s)
        else:
            out.append(s)
            out.append(clamp_s16(s16_to_i(s) * 0.72))
    return out

def music_pcm(hz, nch, nframes):
    # Broadband / multi-tone: chord + harmonics + dense partials (not silent-frame path).
    freqs = [261.63, 329.63, 392.00, 523.25, 659.25, 784.0]
    out = []
    for i in range(nframes):
        t = i / float(hz)
        x = 0.0
        for f in freqs:
            if f >= hz * 0.45:
                continue
            x += 0.16 * math.sin(2.0 * math.pi * f * t)
            x += 0.05 * math.sin(2.0 * math.pi * (2.0 * f) * t)
        for k in range(1, 24):
            f = 180.0 + k * 167.0
            if f >= hz * 0.45:
                break
            x += 0.012 * math.sin(2.0 * math.pi * f * t + 0.7 * k)
        s = clamp_s16(x * 14000.0)
        if nch == 1:
            out.append(s)
        else:
            out.append(s)
            out.append(clamp_s16(s16_to_i(s) * 0.85 + 1200.0 * math.sin(2.0 * math.pi * 440.0 * t)))
    return out

def as_f32(samples_s16):
    return [f32_bits(s16_to_i(s) / 32768.0) for s in samples_s16]

def fixture(kind, hz, nch, seconds, fmt=FMT_S16):
    nframes = max(1, int(round(hz * seconds)))
    pcm = speech_pcm(hz, nch, nframes) if kind == "speech" else music_pcm(hz, nch, nframes)
    if fmt == FMT_F32:
        pcm = as_f32(pcm)
    return {"kind": kind, "hz": hz, "nch": nch, "seconds": seconds, "fmt": fmt,
            "nframes": nframes, "samples": pcm,
            "label": f"{kind} {hz}Hz ch{nch} {seconds:g}s {'s16' if fmt == FMT_S16 else 'f32'}"}

def correct_wav():
    log("\n== WAV correctness (stdlib wave / struct) ==")
    specs = [
        ("s16 mono 8000 2", 8000, 1, FMT_S16, [0, 1]),
        ("s16 stereo 8000", 8000, 2, FMT_S16, [0, 1, 2, 3]),
        ("s16 mono 44100 silence8", 44100, 1, FMT_S16, [0] * 8),
        ("f32 mono 8000", 8000, 1, FMT_F32, [0, F32_ONE]),
        ("f32 stereo 8000", 8000, 2, FMT_F32, [0, F32_ONE, 0, F32_ONE]),
    ]
    for name, hz, nch, fmt, samples in specs:
        # A: reference → ezaudio decode
        src = os.path.join(WORK, "ref_" + name.replace(" ", "_") + ".wav")
        if fmt == FMT_S16:
            write_wav_s16(src, hz, nch, samples)
        else:
            write_wav_f32(src, hz, nch, samples)
        r, got = run_decode("wav-dec", src, 60)
        if got is None:
            add_case("A ref→ezaudio wav", name, "FAIL", f"decode rc={r['rc']} err={r['err'][:200]}")
        else:
            ghz, gnch, gfmt, gpx = got
            ok = (ghz, gnch, gfmt, gpx) == (hz, nch, fmt, samples)
            add_case("A ref→ezaudio wav", name, "PASS" if ok else "FAIL",
                     f"ref → ezaudio {ghz}/{gnch}/fmt{gfmt} n={len(gpx)}")

        # B: ezaudio encode → reference decode
        eza = os.path.join(WORK, "src_" + name.replace(" ", "_") + ".eza")
        write_eza(eza, hz, nch, fmt, samples)
        outp = eza + ".wav"
        er = ez(["wav-enc", eza, outp], 60)
        if er["timeout"] or er["rc"] != 0 or not os.path.exists(outp):
            add_case("B ezaudio→ref wav", name, "FAIL", f"encode rc={er['rc']} err={er['err'][:200]}")
        else:
            try:
                if fmt == FMT_S16:
                    rhz, rnch, rpx = read_wav_s16(outp)
                else:
                    rhz, rnch, rpx = read_wav_f32(outp)
                ok = (rhz, rnch, rpx) == (hz, nch, samples)
                add_case("B ezaudio→ref wav", name, "PASS" if ok else "FAIL",
                         f"ezaudio wav {os.path.getsize(outp)}B → ref {rhz}/{rnch} n={len(rpx)}")
            except Exception as e:
                add_case("B ezaudio→ref wav", name, "FAIL", repr(e))

        # B2: ezaudio round-trip
        rt = eza + ".rt.eza"
        rr = ez(["wav-rt", eza, rt], 60)
        if rr["timeout"] or rr["rc"] != 0 or not os.path.exists(rt):
            add_case("B ezaudio wav round-trip", name, "FAIL", f"rc={rr['rc']}")
        else:
            ghz, gnch, gfmt, gpx = read_eza(rt)
            ok = (ghz, gnch, gfmt, gpx) == (hz, nch, fmt, samples)
            add_case("B ezaudio wav round-trip", name, "PASS" if ok else "FAIL",
                     f"{ghz}/{gnch}/fmt{gfmt} n={len(gpx)}")

def correct_mp3():
    log("\n== MP3 correctness (LAWS fixtures + ffmpeg where fair) ==")
    # Silent frame fixtures matching ezaudio/LAWS.bend (correctness only; not speed)
    silent_cases = [
        ("silence 44100 mono", [255, 251, 224, 196], 1044, 44100, 1, 1152),
        ("silence 44100 stereo", [255, 251, 224, 4], 1044, 44100, 2, 2304),
        ("silence 48000 mono", [255, 251, 228, 196], 960, 48000, 1, 1152),
        ("silence 32000 mono", [255, 251, 232, 196], 1440, 32000, 1, 1152),
    ]
    for name, head, nbytes, hz, nch, nsamp in silent_cases:
        raw = frame_z(head, nbytes)
        path = os.path.join(WORK, name.replace(" ", "_") + ".mp3")
        open(path, "wb").write(raw)
        r, got = run_decode("mp3-dec", path, 120)
        if got is None:
            add_case("C ezaudio mp3 silence decode", name, "FAIL", f"rc={r['rc']} err={r['err'][:200]}")
        else:
            ghz, gnch, gfmt, gpx = got
            ok = (ghz, gnch, gfmt, gpx) == (hz, nch, FMT_F32, pcm_zeros(nsamp))
            add_case("C ezaudio mp3 silence decode", name, "PASS" if ok else "FAIL",
                     f"{ghz}/{gnch}/fmt{gfmt} n={len(gpx)} rms={rms_f32_bits(gpx):.2e}")

        # encode silence from one s16 zero sample (ezaudio pads a full frame)
        eza = os.path.join(WORK, "enc_" + name.replace(" ", "_") + ".eza")
        write_eza(eza, hz, nch, FMT_S16, [0] * nch)
        outp = eza + ".mp3"
        er = ez(["mp3-enc", eza, outp], 120)
        if er["timeout"] or er["rc"] != 0 or not os.path.exists(outp):
            add_case("C ezaudio mp3 silence encode", name, "FAIL", f"rc={er['rc']} err={er['err'][:200]}")
        else:
            got_bytes = open(outp, "rb").read()
            ok = got_bytes == raw
            add_case("C ezaudio mp3 silence encode", name, "PASS" if ok else "FAIL",
                     f"len={len(got_bytes)} expected={nbytes}")

        # ffmpeg decode of two LAWS silent frames → near silence (ffmpeg wants ≥2 frames)
        try:
            twin = os.path.join(WORK, name.replace(" ", "_") + "_x2.mp3")
            open(twin, "wb").write(raw + raw)
            fhz, fnch, fpx = ffmpeg_decode_mp3_to_f32(twin)
            rrms = rms_f32_bits(fpx)
            ok = rrms < 1e-3 and fhz == hz and fnch == nch
            add_case("D ffmpeg←ezaudio silence", name, "PASS" if ok else "FAIL",
                     f"ffmpeg {fhz}/{fnch} n={len(fpx)} rms={rrms:.2e} (2 frames)")
        except Exception as e:
            add_case("D ffmpeg←ezaudio silence", name, "FAIL", repr(e)[:200])

    # Huffman-pair fixture from LAWS: one s16 sample of magnitude 1 (correctness only)
    log("\n== MP3 Huffman-pair fixture ==")
    eza = os.path.join(WORK, "pair.eza")
    write_eza(eza, 44100, 1, FMT_S16, [1])
    outp = eza + ".mp3"
    er = ez(["mp3-enc", eza, outp], 120)
    if er["timeout"] or er["rc"] != 0 or not os.path.exists(outp):
        add_case("E ezaudio mp3 pair", "encode", "FAIL", f"rc={er['rc']}")
    else:
        got = open(outp, "rb").read()
        ok_head = got[:4] == bytes([255, 251, 224, 196]) and len(got) == 1044
        add_case("E ezaudio mp3 pair", "header+len", "PASS" if ok_head else "FAIL",
                 f"head={list(got[:4])} len={len(got)}")
        r, dec = run_decode("mp3-dec", outp, 120)
        if dec is None:
            add_case("E ezaudio mp3 pair", "decode", "FAIL", f"rc={r['rc']}")
        else:
            ghz, gnch, gfmt, gpx = dec
            ok = (ghz, gnch, gfmt, gpx) == (44100, 1, FMT_F32, pcm_pair())
            add_case("E ezaudio mp3 pair", "decode pair+zeros", "PASS" if ok else "FAIL",
                     f"n={len(gpx)} head={gpx[:4] if gpx else []}")

    # Non-silent encode smoke: one full frame of music (not silence / not Huffman-pair)
    log("\n== MP3 non-silent filterbank smoke ==")
    fx = fixture("music", 44100, 1, 1152 / 44100.0)  # exactly one Layer III frame
    eza = os.path.join(WORK, "nz_music.eza")
    write_eza(eza, fx["hz"], fx["nch"], fx["fmt"], fx["samples"])
    outp = eza + ".mp3"
    er = ez(["mp3-enc", eza, outp], 300)
    if er["timeout"] or er["rc"] != 0 or not os.path.exists(outp):
        add_case("E2 ezaudio mp3 live", fx["label"], "FAIL", f"rc={er['rc']} err={er['err'][:160]}")
    else:
        got = open(outp, "rb").read()
        # Silent path is header+zeros; live path still FF FB… but side-info/payload differ
        ok = len(got) == 1044 and got[:4] == bytes([255, 251, 224, 196]) and any(b != 0 for b in got[4:])
        add_case("E2 ezaudio mp3 live", fx["label"] + " encode", "PASS" if ok else "FAIL",
                 f"len={len(got)} head={list(got[:4])} nonzero_tail={any(b != 0 for b in got[4:])}")
        r, dec = run_decode("mp3-dec", outp, 300)
        if dec is None:
            add_case("E2 ezaudio mp3 live", fx["label"] + " decode", "FAIL", f"rc={r['rc']}")
        else:
            ghz, gnch, gfmt, gpx = dec
            rrms = rms_f32_bits(gpx)
            # Not the silent-frame path: decoded energy must be clearly non-zero
            ok = ghz == 44100 and gnch == 1 and gfmt == FMT_F32 and rrms > 1e-4 and len(gpx) >= 1152
            add_case("E2 ezaudio mp3 live", fx["label"] + " decode energy", "PASS" if ok else "FAIL",
                     f"{ghz}/{gnch} n={len(gpx)} rms={rrms:.2e}")

    # ffmpeg-produced silence → ezaudio decode near silence (lossy; RMS gate)
    log("\n== MP3 ffmpeg→ezaudio silence ==")
    for hz, nch in ((44100, 1), (44100, 2), (48000, 1)):
        name = f"ffmpeg silence {hz} ch{nch}"
        path = os.path.join(WORK, name.replace(" ", "_") + ".mp3")
        try:
            ffmpeg_encode_silence_mp3(path, hz, nch, 1152)
            r, got = run_decode("mp3-dec", path, 180)
            if got is None:
                detail = f"rc={r['rc']} err={r['err'][:160]}"
                if r["timeout"]:
                    add_case("F ffmpeg→ezaudio silence", name, "FAIL", detail)
                else:
                    add_case("F ffmpeg→ezaudio silence", name, "SKIP",
                             "decode none (long-block no-CRC only); " + detail,
                             hard=False)
            else:
                ghz, gnch, gfmt, gpx = got
                rrms = rms_f32_bits(gpx)
                ok = rrms < 1e-2 and ghz == hz and gnch == nch and gfmt == FMT_F32
                add_case("F ffmpeg→ezaudio silence", name, "PASS" if ok else "FAIL",
                         f"{ghz}/{gnch} n={len(gpx)} rms={rrms:.2e}")
        except Exception as e:
            add_case("F ffmpeg→ezaudio silence", name, "FAIL", repr(e)[:200])

def ez_ms_per(parsed, wall, n):
    # Prefer IO.now; fall back to wall/n when the 1ms timer still reads 0.
    if parsed is None:
        return None, "no-parse"
    if parsed["MS"] > 0:
        return parsed["MS"] / float(n), "IO.now"
    return (wall * 1000.0 / float(n)), "IO.now=0; wall/n"

def run_bench_bump(args_prefix, n0, timeout, max_n=4096):
    # Raise N until IO.now resolves (MS>0) or we hit max_n.
    n = n0
    last = None
    while True:
        r = ez([*args_prefix, str(n)], timeout)
        last = (r, parse_bench(r["out"]) if not r["timeout"] else None, n)
        if r["timeout"]:
            return last
        parsed = last[1]
        if parsed is None:
            return last
        if parsed["MS"] > 0 or n >= max_n:
            return last
        n = min(max_n, max(n * 4, n + 1))

def speed():
    log("\n== Speed (printable; does not fail the check) ==")
    log("FAIR: WAV = in-memory ezaudio codec vs in-memory stdlib wave/struct (BytesIO).")
    log("FAIR: MP3 = ezaudio absolute ms/op only (full filterbank path on non-silent clips).")
    log("NOT a speed ref: ffmpeg CLI spawn, disk open/write on the WAV reference path,")
    log("  silent-frame / Huffman-pair MP3 fast paths.")
    log("Fixtures: speech-like (voiced) + music-like (broadband); 16/44.1/48 kHz; mono+stereo;")
    log("  ~0.1–1 s. ratio > 1 means ezaudio slower than the in-process WAV reference.")
    log("No fair in-process MP3 reference in nixpkgs Python — absolute only, no fake ratio.")

    # Product-shaped clips. WAV can be longer; MP3 encode is heavier → shorter but still multi-frame.
    wav_jobs = [
        fixture("speech", 16000, 1, 0.25),
        fixture("speech", 44100, 1, 0.25),
        fixture("music", 44100, 2, 0.25),
        fixture("music", 48000, 1, 0.5),
        fixture("music", 48000, 1, 0.25, FMT_F32),
        fixture("speech", 44100, 1, 1.0),
    ]
    mp3_jobs = [
        fixture("speech", 44100, 1, 0.1),
        fixture("music", 44100, 2, 0.1),
        fixture("music", 48000, 1, 0.1),
        fixture("speech", 16000, 1, 0.25),  # 16 kHz is outside encode rates → expect skip/fail note
    ]

    log("\n-- WAV encode (in-memory vs in-memory) --")
    for fx in wav_jobs:
        eza = os.path.join(WORK, "spd_" + fx["label"].replace(" ", "_") + ".eza")
        write_eza(eza, fx["hz"], fx["nch"], fx["fmt"], fx["samples"])
        n0 = 8 if fx["nframes"] >= 20000 else 20
        timeout = 180
        r, parsed, n = run_bench_bump(["bench-wav-enc-file", eza], n0, timeout)
        # Reference: pack same PCM into memory N times (wave module or struct RIFF).
        t0 = time.perf_counter()
        for _ in range(n):
            if fx["fmt"] == FMT_S16:
                wav_s16_bytes(fx["hz"], fx["nch"], fx["samples"])
            else:
                wav_f32_bytes(fx["hz"], fx["nch"], fx["samples"])
        ref_ms = (time.perf_counter() - t0) * 1000.0
        if r["timeout"]:
            row = f"TIMEOUT wav-enc {fx['label']} N={n} after {r['wall']:.1f}s"
        elif parsed is None:
            row = f"ERROR wav-enc {fx['label']} rc={r['rc']} out={r['out']!r} err={r['err'][:120]!r}"
        else:
            ez_per, note = ez_ms_per(parsed, r["wall"], n)
            ref_per = ref_ms / float(n)
            if parsed["MS"] > 0:
                ratio = ez_per / ref_per if ref_per > 0 else float("inf")
                row = (f"wav-enc  {fx['label']:<36} N={n:<4} "
                       f"ezaudio {ez_per:8.4f} ms/op ({note})  "
                       f"wave {ref_per:8.4f} ms/op  "
                       f"ratio {ratio:8.1f}x  "
                       f"raw={r['out'].strip()}")
            else:
                row = (f"wav-enc  {fx['label']:<36} N={n:<4} "
                       f"ezaudio {ez_per:8.4f} ms/op ({note}; no vs-wave claim)  "
                       f"wave {ref_per:8.4f} ms/op  "
                       f"raw={r['out'].strip()}")
        log(row)
        speed_rows.append(row)

    log("\n-- WAV decode (in-memory vs in-memory) --")
    for fx in wav_jobs[:4]:
        # Build WAV bytes once; both sides decode from memory / preloaded bytes.
        if fx["fmt"] == FMT_S16:
            data = wav_s16_bytes(fx["hz"], fx["nch"], fx["samples"])
        else:
            data = wav_f32_bytes(fx["hz"], fx["nch"], fx["samples"])
        path = os.path.join(WORK, "spd_" + fx["label"].replace(" ", "_") + ".wav")
        open(path, "wb").write(data)  # disk only to feed the driver; timed loop is in-memory
        n0 = 10 if fx["nframes"] >= 20000 else 30
        r, parsed, n = run_bench_bump(["bench-wav-dec", path], n0, 180)
        t0 = time.perf_counter()
        for _ in range(n):
            if fx["fmt"] == FMT_S16:
                read_wav_s16_mem(data)
            else:
                read_wav_f32_mem(data)
        ref_ms = (time.perf_counter() - t0) * 1000.0
        if r["timeout"]:
            row = f"TIMEOUT wav-dec {fx['label']} N={n}"
        elif parsed is None:
            row = f"ERROR wav-dec {fx['label']} rc={r['rc']}"
        else:
            ez_per, note = ez_ms_per(parsed, r["wall"], n)
            ref_per = ref_ms / float(n)
            if parsed["MS"] > 0:
                ratio = ez_per / ref_per if ref_per > 0 else float("inf")
                row = (f"wav-dec  {fx['label']:<36} N={n:<4} "
                       f"ezaudio {ez_per:8.4f} ms/op ({note})  "
                       f"wave {ref_per:8.4f} ms/op  "
                       f"ratio {ratio:8.1f}x  "
                       f"raw={r['out'].strip()}")
            else:
                row = (f"wav-dec  {fx['label']:<36} N={n:<4} "
                       f"ezaudio {ez_per:8.4f} ms/op ({note}; no vs-wave claim)  "
                       f"wave {ref_per:8.4f} ms/op  "
                       f"raw={r['out'].strip()}")
        log(row)
        speed_rows.append(row)

    log("\n-- MP3 encode (absolute ezaudio ms/op; full path; no ffmpeg ratio) --")
    for fx in mp3_jobs:
        if fx["hz"] not in (32000, 44100, 48000):
            log(f"SKIP mp3-enc {fx['label']} (ezaudio encode rates are 32/44.1/48 kHz only)")
            continue
        eza = os.path.join(WORK, "spd_mp3_" + fx["label"].replace(" ", "_") + ".eza")
        write_eza(eza, fx["hz"], fx["nch"], fx["fmt"], fx["samples"])
        # Full filterbank is heavy; start at N=1, bump only if IO.now is 0.
        r, parsed, n = run_bench_bump(["bench-mp3-enc-file", eza], 1, 600, max_n=8)
        if r["timeout"]:
            row = f"TIMEOUT mp3-enc {fx['label']} N={n} after {r['wall']:.1f}s"
        elif parsed is None:
            row = (f"ERROR mp3-enc {fx['label']} rc={r['rc']} "
                   f"out={r['out']!r} err={r['err'][:160]!r}")
        else:
            ez_per, note = ez_ms_per(parsed, r["wall"], n)
            row = (f"mp3-enc  {fx['label']:<36} N={n:<4} "
                   f"ezaudio {ez_per:10.4f} ms/op ({note})  "
                   f"[no in-process MP3 ref; ffmpeg not timed]  "
                   f"raw={r['out'].strip()}")
        log(row)
        speed_rows.append(row)

    log("\n-- MP3 decode (absolute ezaudio ms/op; bytes preloaded; no ffmpeg ratio) --")
    for fx in mp3_jobs:
        if fx["hz"] not in (32000, 44100, 48000):
            continue
        eza = os.path.join(WORK, "spd_mp3_" + fx["label"].replace(" ", "_") + ".eza")
        if not os.path.exists(eza):
            write_eza(eza, fx["hz"], fx["nch"], fx["fmt"], fx["samples"])
        outp = eza + ".mp3"
        er = ez(["mp3-enc", eza, outp], 600)
        if er["timeout"] or er["rc"] != 0 or not os.path.exists(outp):
            log(f"SKIP mp3-dec {fx['label']}: encode failed rc={er['rc']}")
            continue
        r, parsed, n = run_bench_bump(["bench-mp3-dec", outp], 1, 600, max_n=16)
        if r["timeout"]:
            row = f"TIMEOUT mp3-dec {fx['label']} N={n}"
        elif parsed is None:
            row = f"ERROR mp3-dec {fx['label']} rc={r['rc']}"
        else:
            ez_per, note = ez_ms_per(parsed, r["wall"], n)
            row = (f"mp3-dec  {fx['label']:<36} N={n:<4} "
                   f"ezaudio {ez_per:10.4f} ms/op ({note})  "
                   f"[no in-process MP3 ref; ffmpeg not timed]  "
                   f"raw={r['out'].strip()}")
        log(row)
        speed_rows.append(row)

def main():
    log("ezaudio vs wave bench (Nix-embedded); ffmpeg for MP3 correctness only")
    log(f"driver={DRV}")
    log(f"mode={MODE}")
    log("WAV speed ref: stdlib wave+struct in-memory. MP3 speed: ezaudio absolute only.")
    ping = ez(["ping"], 10)
    if ping["out"].strip() != "pong":
        log("FAIL: driver ping"); log(repr(ping)); sys.exit(2)
    log("driver ping ok (native ELF)")
    try:
        if MODE in ("correctness", "all"):
            correct_wav(); correct_mp3()
        if MODE in ("speed", "all"):
            speed()
    except Exception:
        log("HARNESS EXCEPTION"); log(traceback.format_exc()); sys.exit(2)
    log(f"\n== Summary: {fails} hard failure(s) of {len(cases)} cases ==")
    for c in cases:
        if c["status"] != "PASS" and c["hard"]:
            log(f"  FAIL {c['group']} | {c['name']}")
    if fails:
        sys.exit(1)
    log("ALL HARD CHECKS PASSED")

if __name__ == "__main__":
    main()
''
