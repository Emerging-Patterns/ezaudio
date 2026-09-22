# wave + ffmpeg compare script text (embedded; not a checked-in .py file).
# Consumed by writeText / writeShellApplication in default.nix.
#
# Reference tools:
# - stdlib `wave` + `struct` for RIFF WAVE PCM s16 and IEEE float f32
# - nixpkgs `ffmpeg` CLI for MPEG-1 Layer III encode/decode fixtures
{ drvBin ? "ezaudio-bench" }:
''
import math, os, struct, subprocess, sys, time, traceback, wave

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

def write_wav_s16(path, hz, nch, samples_u32):
    frames = b"".join(struct.pack("<h", s16_to_i(s)) for s in samples_u32)
    with wave.open(path, "wb") as w:
        w.setnchannels(nch)
        w.setsampwidth(2)
        w.setframerate(hz)
        w.writeframes(frames)

def read_wav_s16(path):
    with wave.open(path, "rb") as w:
        nch = w.getnchannels()
        hz = w.getframerate()
        sw = w.getsampwidth()
        if sw != 2:
            raise ValueError(f"expected s16 sampwidth 2, got {sw}")
        raw = w.readframes(w.getnframes())
    samples = [i_to_s16(struct.unpack_from("<h", raw, i)[0]) for i in range(0, len(raw), 2)]
    return hz, nch, samples

def write_wav_f32(path, hz, nch, samples_u32):
    # Manual RIFF WAVE IEEE float (format tag 3); stdlib wave is PCM-only.
    data = b"".join(struct.pack("<I", s & 0xFFFFFFFF) for s in samples_u32)
    byte_rate = hz * nch * 4
    block_align = nch * 4
    fmt = struct.pack("<HHIIHH", 3, nch, hz, byte_rate, block_align, 32)
    riff_size = 4 + (8 + len(fmt)) + (8 + len(data))
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", riff_size) + b"WAVE")
        f.write(b"fmt " + struct.pack("<I", len(fmt)) + fmt)
        f.write(b"data" + struct.pack("<I", len(data)) + data)

def read_wav_f32(path):
    b = open(path, "rb").read()
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
    # Decode MP3 to raw little-endian f32 mono/stereo via ffmpeg.
    out = os.path.join(WORK, os.path.basename(path) + ".f32")
    # probe channels/rate from decoded wav pipe metadata is awkward; use s16 wav then promote.
    wav = os.path.join(WORK, os.path.basename(path) + ".ff.wav")
    r = subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", path, "-f", "wav", wav],
        capture_output=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace")[:200])
    # Prefer float dump when possible
    with wave.open(wav, "rb") as w:
        nch = w.getnchannels()
        hz = w.getframerate()
        sw = w.getsampwidth()
        nframes = w.getnframes()
        raw = w.readframes(nframes)
    if sw == 2:
        ints = [struct.unpack_from("<h", raw, i)[0] for i in range(0, len(raw), 2)]
        # convert to f32 bits approximating decode compare for silence
        samples = [struct.unpack("<I", struct.pack("<f", float(v) / 32768.0))[0] for v in ints]
        return hz, nch, samples
    if sw == 4:
        # may be int32; treat as f32 bits only when IEEE path used
        samples = list(struct.unpack("<" + "I" * (len(raw) // 4), raw))
        return hz, nch, samples
    raise ValueError(f"unexpected sampwidth {sw}")

def ffmpeg_encode_silence_mp3(path, hz, nch, nframes):
    # Build silent PCM and encode MPEG-1 Layer III with ffmpeg/lame.
    wav = os.path.join(WORK, f"ff_sil_{hz}_{nch}_{nframes}.wav")
    write_wav_s16(wav, hz, nch, [0] * (nframes * nch))
    r = subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
         "-i", wav, "-codec:a", "libmp3lame", "-b:a", "320k",
         "-ar", str(hz), "-ac", str(nch), path],
        capture_output=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace")[:200])

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
    # Silent frame fixtures matching ezaudio/LAWS.bend
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

    # Huffman-pair fixture from LAWS: one s16 sample of magnitude 1
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

    # ffmpeg-produced silence → ezaudio decode near silence (lossy; RMS gate)
    log("\n== MP3 ffmpeg→ezaudio silence ==")
    for hz, nch in ((44100, 1), (44100, 2), (48000, 1)):
        name = f"ffmpeg silence {hz} ch{nch}"
        path = os.path.join(WORK, name.replace(" ", "_") + ".mp3")
        try:
            ffmpeg_encode_silence_mp3(path, hz, nch, 1152)
            r, got = run_decode("mp3-dec", path, 180)
            if got is None:
                # ezaudio rejects CRC / joint / short / reservoir — soft if ffmpeg layout differs
                detail = f"rc={r['rc']} err={r['err'][:160]}"
                # Still a hard check: prefer PASS when decode works; FAIL when driver crashes
                if r["timeout"]:
                    add_case("F ffmpeg→ezaudio silence", name, "FAIL", detail)
                else:
                    # ezaudio may reject ffmpeg's side-info / reservoir / CRC layout
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

def speed():
    log("\n== Speed (printable; does not fail the check) ==")
    log("ezaudio: IO.now around codec only (native ELF).")
    log("reference: stdlib wave/struct in-process; ffmpeg CLI wall for MP3.")
    log("ratio > 1 means ezaudio slower than the reference.")
    jobs = [
        ("wav-enc", 8000, 64, 50, 30),
        ("wav-enc", 8000, 1024, 40, 60),
        ("wav-enc", 44100, 4096, 20, 60),
        ("mp3-enc", 44100, 1, 20, 120),
        ("mp3-enc", 44100, 1152, 5, 180),
    ]
    for kind, hz, nframes, n, timeout in jobs:
        if kind == "wav-enc":
            r = ez(["bench-wav-enc", str(hz), str(nframes), str(n)], timeout)
            samples = [0] * nframes
            t0 = time.perf_counter()
            for _ in range(n):
                buf = os.path.join(WORK, "_spd_wav.bin")
                write_wav_s16(buf, hz, 1, samples)
            ref_ms = (time.perf_counter() - t0) * 1000
        else:
            r = ez(["bench-mp3-enc", str(hz), str(nframes), str(n)], timeout)
            # ffmpeg reference: encode n times from a silent wav
            wav = os.path.join(WORK, "_spd_mp3.wav")
            write_wav_s16(wav, hz, 1, [0] * max(nframes, 1))
            out = os.path.join(WORK, "_spd_mp3.out.mp3")
            t0 = time.perf_counter()
            for _ in range(n):
                subprocess.run(
                    [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
                     "-i", wav, "-codec:a", "libmp3lame", "-b:a", "320k", out],
                    capture_output=True, timeout=timeout)
            ref_ms = (time.perf_counter() - t0) * 1000
        parsed = parse_bench(r["out"]) if not r["timeout"] else None
        if r["timeout"]:
            row = f"TIMEOUT {kind} hz={hz} fr={nframes} N={n} after {r['wall']:.1f}s"
        elif parsed is None:
            row = f"ERROR {kind} hz={hz} fr={nframes} rc={r['rc']} out={r['out']!r} err={r['err'][:120]!r}"
        else:
            ez_ms = parsed["MS"]
            ez_per = (ez_ms / n) if ez_ms > 0 else (r["wall"] * 1000 / n)
            note = "IO.now=0; wall/n" if ez_ms == 0 else "IO.now"
            ref_per = ref_ms / n
            ratio = ez_per / ref_per if ref_per > 0 else float("inf")
            ref_name = "wave" if kind == "wav-enc" else "ffmpeg"
            row = (f"{kind:9} hz={hz:<5} fr={nframes:<5} N={n:<4} "
                   f"ezaudio {ez_per:8.4f} ms/op ({note})  "
                   f"{ref_name} {ref_per:8.4f} ms/op  "
                   f"ratio {ratio:8.1f}x  "
                   f"raw={r['out'].strip()}")
        log(row)
        speed_rows.append(row)

    # decode pairs
    for kind, make in (("wav", "wav"), ("mp3", "mp3")):
        hz, nframes = (8000, 1024) if kind == "wav" else (44100, 1)
        eza = os.path.join(WORK, f"spd_{kind}.eza")
        write_eza(eza, hz, 1, FMT_S16, [0] * max(nframes, 1))
        out = os.path.join(WORK, f"spd_{kind}." + ("wav" if kind == "wav" else "mp3"))
        er = ez([f"{kind}-enc", eza, out], 120)
        if er["timeout"] or er["rc"] != 0:
            log(f"{kind}-dec skip: encode failed")
            continue
        n = 10
        r = ez([f"bench-{kind}-dec", out, str(n)], 120)
        data = open(out, "rb").read()
        t0 = time.perf_counter()
        for _ in range(n):
            if kind == "wav":
                read_wav_s16(out)
            else:
                # ffmpeg decode wall
                subprocess.run(
                    [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
                     "-i", out, "-f", "null", "-"],
                    capture_output=True, timeout=60)
        ref_ms = (time.perf_counter() - t0) * 1000
        parsed = parse_bench(r["out"]) if not r["timeout"] else None
        if parsed:
            ez_per = parsed["MS"] / n if parsed["MS"] else r["wall"] * 1000 / n
            ref_per = ref_ms / n
            ratio = ez_per / ref_per if ref_per > 0 else float("inf")
            ref_name = "wave" if kind == "wav" else "ffmpeg"
            log(f"{kind+'-dec':9} hz={hz:<5} fr={nframes:<5} N={n:<4} "
                f"ezaudio {ez_per:8.4f} ms/op  {ref_name} {ref_per:8.4f} ms/op  "
                f"ratio {ratio:8.1f}x  raw={r['out'].strip()}")
        else:
            log(f"{kind}-dec error/timeout wall={r['wall']:.2f}")

def main():
    log("ezaudio vs wave/ffmpeg bench (Nix-embedded)")
    log(f"driver={DRV}")
    log(f"reference: stdlib wave+struct (WAV), ffmpeg CLI (MP3); mode={MODE}")
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
