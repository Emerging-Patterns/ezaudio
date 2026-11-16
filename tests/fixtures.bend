# Fixture checks: single inputs whose output is known byte for byte. They are
# not laws (each checks one input), so they run here, under `ez test` and the
# flake's `fixtures` check, and a regression fails `nix flake check`. Each
# prints `ok <name>` when ezaudio gives the expected value, else `FAIL <name>`.
# They cover what the laws do not prove: MP3 decode of hand-made frames
# (count1, CRC, ID3v2/Xing/Info/junk framing, partial frames, unsupported
# features, overruns), silent frames both ways, encode refusals, binary32
# clamping, the Table B.8 band rows, frame room at the bit budget, and WAV
# byte layouts, round trips, streamed and truncated files and chunk ids.
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../src/mp3_dec.bend as Dec
import ../src/mp3_enc.bend as Enc
import ../src/wav.bend as Wav
import ../laws/defs/MonoClip.bend as Mo
import ../laws/defs/WavFiles.bend as Wf
import ../fixtures/ByteLists.bend as By
import ../fixtures/Mp3Frames.bend as Fr
import ../fixtures/Mp3Header.bend as Hd
import ../fixtures/Room.bend as Rm
import ../fixtures/WavMore.bend as Wm

# two word lists are the same words in the same order
def eq.words(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case +x <> xt +y <> yt:
      Bool.and(U32.is_eq(x, y), eq.words(xt, yt))
    case _ _:
      False{}

# a word as a list
def code.u32(+x: U32) -> List<&2, U32>:
  [x]

# a word list as itself
def code.list(xs: List<&2, U32>) -> List<&2, U32>:
  xs

# a Bool as 1 or 0
def code.bool(b: Bool) -> List<&2, U32>:
  match b:
    case True{}:
      [1]
    case False{}:
      [0]

# a clip as its rate, channels, format tag and samples
def code.clip(c: Au.Clip) -> List<&2, U32>:
  match c:
    case Au.Clip{+hz, +nch, fmt, pcm}:
      hz <> nch <> Au.kind.of(fmt) <> pcm

# none as 0, a clip as 1 and its code
def code.mclip(m: Maybe<&2, Au.Clip>) -> List<&2, U32>:
  match m:
    case None{}:
      [0]
    case Some{c}:
      1 <> code.clip(c)

# none as 0, bytes as 1 and the bytes
def code.mlist(m: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match m:
    case None{}:
      [0]
    case Some{xs}:
      1 <> xs

# granule channels as their gain, line count and lines, one after another
def code.gls(gs: List<&2, Dec.Gl>) -> List<&2, U32>:
  match gs:
    case Nil{}:
      []
    case Dec.Gl{+gain, +lines} <> tl:
      List.append(&2, U32, gain <> U32.from_nat(List.length(&2, U32, lines)) <> lines, code.gls(tl))

# none as 0, granule channels as 1 and their code
def code.mgls(m: Maybe<&2, List<&2, Dec.Gl>>) -> List<&2, U32>:
  match m:
    case None{}:
      [0]
    case Some{gs}:
      1 <> code.gls(gs)

# ok or FAIL, then the fixture's name
def verdict(ok: Bool, name: String) -> String:
  match ok:
    case True{}:
      "ok " ++ name
    case False{}:
      "FAIL " ++ name

# the line one fixture prints
def check(name: String, got: List<&2, U32>, want: List<&2, U32>) -> String:
  verdict(eq.words(got, want), name)

# WavChunkIdsAreRiff: data_tag
def t.data.tag() -> String:
  check("data_tag",
    code.u32(Wav.tag.data()),
    code.u32(1684108385))

# WavChunkIdsAreRiff: fmt_tag
def t.fmt.tag() -> String:
  check("fmt_tag",
    code.u32(Wav.tag.fmt()),
    code.u32(1718449184))

# WavChunkIdsAreRiff: riff_tag
def t.riff.tag() -> String:
  check("riff_tag",
    code.u32(Wav.tag.riff()),
    code.u32(1380533830))

# WavChunkIdsAreRiff: wave_tag
def t.wave.tag() -> String:
  check("wave_tag",
    code.u32(Wav.tag.wave()),
    code.u32(1463899717))

# WavEncodesPcm: wav_f32_bytes
def t.wav.f32.bytes() -> String:
  check("wav_f32_bytes",
    code.mlist(Au.encode_wav(Au.clip(8000, 1, Au.f32(), [1065353216]))),
    code.mlist(Some{Wm.wav.float()}))

# WavEncodesPcm: wav_s16_bytes
def t.wav.s16.bytes() -> String:
  check("wav_s16_bytes",
    code.mlist(Au.encode_wav(Mo.fix.mono())),
    code.mlist(Some{Wf.wav.canonical()}))

# WavRoundTrips: wav_f32_mono
def t.wav.f32.mono() -> String:
  check("wav_f32_mono",
    code.mclip(Au.decode_wav(By.bytes.of(Au.encode_wav(Au.clip(8000, 1, Au.f32(), [0, 1065353216]))))),
    code.mclip(Some{Au.clip(8000, 1, Au.f32(), [0, 1065353216])}))

# WavRoundTrips: wav_f32_stereo
def t.wav.f32.stereo() -> String:
  check("wav_f32_stereo",
    code.mclip(Au.decode_wav(By.bytes.of(Au.encode_wav(Au.clip(8000, 2, Au.f32(), [0, 1065353216]))))),
    code.mclip(Some{Au.clip(8000, 2, Au.f32(), [0, 1065353216])}))

# WavRoundTrips: wav_no_frames_round
def t.wav.no.frames.round() -> String:
  check("wav_no_frames_round",
    code.mclip(Au.decode_wav(By.bytes.of(Au.encode_wav(Au.clip(8000, 1, Au.s16(), []))))),
    code.mclip(Some{Au.clip(8000, 1, Au.s16(), [])}))

# WavRoundTrips: wav_s16_round
def t.wav.s16.round() -> String:
  check("wav_s16_round",
    code.mclip(Au.decode_wav(By.bytes.of(Au.encode_wav(Mo.fix.mono())))),
    code.mclip(Some{Mo.fix.mono()}))

# WavRoundTrips: wav_s16_stereo
def t.wav.s16.stereo() -> String:
  check("wav_s16_stereo",
    code.mclip(Au.decode_wav(By.bytes.of(Au.encode_wav(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3]))))),
    code.mclip(Some{Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3])}))

# WavRoundTrips: wav_s16_wide
def t.wav.s16.wide() -> String:
  check("wav_s16_wide",
    code.mclip(Au.decode_wav(By.bytes.of(Au.encode_wav(Au.clip(44100, 2, Au.s16(), [65535, 32768]))))),
    code.mclip(Some{Au.clip(44100, 2, Au.s16(), [65535, 32768])}))

# WavReadsOtherWriters: wav_streamed
def t.wav.streamed() -> String:
  check("wav_streamed",
    code.mclip(Au.decode_wav(Wm.wav.streamed())),
    code.mclip(Some{Mo.fix.mono()}))

# WavReadsOtherWriters: wav_truncated
def t.wav.truncated() -> String:
  check("wav_truncated",
    code.mclip(Au.decode_wav(Wm.wav.truncated())),
    code.mclip(Some{Mo.fix.mono()}))

# WavRefusesBadInput: wav_rate_wraps
def t.wav.rate.wraps() -> String:
  check("wav_rate_wraps",
    code.mlist(Au.encode_wav(Au.clip(1073741825, 2, Au.s16(), [0, 0]))),
    code.mlist(None{}))

# FillRepeatsSample: fill_mono
def t.fill.mono() -> String:
  check("fill_mono",
    code.clip(Au.fill(8000, 1, Au.s16(), 7, 3)),
    code.clip(Au.clip(8000, 1, Au.s16(), [7, 7, 7])))

# FillRepeatsSample: fill_stereo
def t.fill.stereo() -> String:
  check("fill_stereo",
    code.clip(Au.fill(8000, 2, Au.f32(), 4, 2)),
    code.clip(Au.clip(8000, 2, Au.f32(), [4, 4, 4, 4])))

# TrimKeepsFrameSpan: trim_all
def t.trim.all() -> String:
  check("trim_all",
    code.mclip(Au.trim(Mo.fix.mono(), 0, 2)),
    code.mclip(Some{Mo.fix.mono()}))

# TrimKeepsFrameSpan: trim_past
def t.trim.past() -> String:
  check("trim_past",
    code.mclip(Au.trim(Mo.fix.mono(), 1, 2)),
    code.mclip(None{}))

# TrimKeepsFrameSpan: trim_span
def t.trim.span() -> String:
  check("trim_span",
    code.mclip(Au.trim(Au.clip(8000, 1, Au.s16(), [0, 1, 2, 3]), 1, 2)),
    code.mclip(Some{Au.clip(8000, 1, Au.s16(), [1, 2])}))

# TrimKeepsFrameSpan: trim_stereo
def t.trim.stereo() -> String:
  check("trim_stereo",
    code.mclip(Au.trim(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3]), 1, 1)),
    code.mclip(Some{Au.clip(8000, 2, Au.s16(), [2, 3])}))

# ScaleFactorRowPerRate: scf_32000
def t.scf.hz32000() -> String:
  check("scf_32000",
    code.list(Dec.scf.row(32000)),
    code.list([4, 4, 4, 4, 4, 4, 6, 6, 8, 10, 12, 16, 20, 24, 30, 38, 46, 56, 68, 84, 102, 26]))

# ScaleFactorRowPerRate: scf_44100
def t.scf.hz44100() -> String:
  check("scf_44100",
    code.list(Dec.scf.row(44100)),
    code.list([4, 4, 4, 4, 4, 4, 6, 6, 8, 8, 10, 12, 16, 20, 24, 28, 34, 42, 50, 54, 76, 158]))

# ScaleFactorRowPerRate: scf_48000
def t.scf.hz48000() -> String:
  check("scf_48000",
    code.list(Dec.scf.row(48000)),
    code.list([4, 4, 4, 4, 4, 4, 6, 6, 6, 8, 10, 12, 16, 18, 22, 28, 34, 40, 46, 54, 54, 192]))

# Mp3Count1Decoded: mp3_count1_lines
def t.mp3.count1.lines() -> String:
  check("mp3_count1_lines",
    code.mgls(Mp3.mp3.lines(Fr.fix.frame())),
    code.mgls(Some{[Dec.Gl{210, Fr.ln.of([1, 0, Fr.ln.neg(1), 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, Fr.ln.neg(1), 1])},
      Dec.Gl{200, Fr.ln.of([16, 0, 0, 1, 0, Fr.ln.neg(1)])}]}))

# Mp3CrcFramesDecode: mp3_crc_decodes
def t.mp3.crc.decodes() -> String:
  check("mp3_crc_decodes",
    code.list(Fr.clip.shape(Au.decode_mp3(Fr.fix.crc()))),
    code.list([48000, 1, 1152]))

# Mp3CrcFramesDecode: mp3_crc_lines
def t.mp3.crc.lines() -> String:
  check("mp3_crc_lines",
    code.mgls(Mp3.mp3.lines(Fr.fix.crc())),
    code.mgls(Mp3.mp3.lines(Fr.fix.frame())))

# Mp3DecodeReadsFrames: mp3_id3_footer_skipped
def t.mp3.id3.footer.skipped() -> String:
  check("mp3_id3_footer_skipped",
    code.mclip(Au.decode_mp3(Fr.fx.cat(Fr.fix.id3foot(), Fr.fix.frame()))),
    code.mclip(Au.decode_mp3(Fr.fix.frame())))

# Mp3DecodeReadsFrames: mp3_id3_skipped
def t.mp3.id3.skipped() -> String:
  check("mp3_id3_skipped",
    code.mclip(Au.decode_mp3(Fr.fx.cat(Fr.fix.id3(), Fr.fix.frame()))),
    code.mclip(Au.decode_mp3(Fr.fix.frame())))

# Mp3DecodeReadsFrames: mp3_info_later_kept
def t.mp3.info.later.kept() -> String:
  check("mp3_info_later_kept",
    code.list(Fr.clip.shape(Au.decode_mp3(Fr.fx.cat(Fr.fix.frame(), Fr.fix.info())))),
    code.list([48000, 1, 2304]))

# Mp3DecodeReadsFrames: mp3_info_skipped
def t.mp3.info.skipped() -> String:
  check("mp3_info_skipped",
    code.mclip(Au.decode_mp3(Fr.fx.cat(Fr.fix.info(), Fr.fix.frame()))),
    code.mclip(Au.decode_mp3(Fr.fix.frame())))

# Mp3DecodeReadsFrames: mp3_junk_skipped
def t.mp3.junk.skipped() -> String:
  check("mp3_junk_skipped",
    code.mclip(Au.decode_mp3(Fr.fx.cat(Fr.fix.junk(), Fr.fx.cat(Fr.fix.frame(), Fr.fx.cat(Fr.fix.junk(),
      Fr.fix.frame()))))),
    code.mclip(Au.decode_mp3(Fr.fx.cat(Fr.fix.frame(), Fr.fix.frame()))))

# Mp3DecodeReadsFrames: mp3_partial_alone
def t.mp3.partial.alone() -> String:
  check("mp3_partial_alone",
    code.mclip(Au.decode_mp3(Fr.fx.take(95, Fr.fix.frame()))),
    code.mclip(None{}))

# Mp3DecodeReadsFrames: mp3_partial_dropped
def t.mp3.partial.dropped() -> String:
  check("mp3_partial_dropped",
    code.mclip(Au.decode_mp3(Fr.fx.cat(Fr.fix.frame(), Fr.fx.take(50, Fr.fix.frame())))),
    code.mclip(Au.decode_mp3(Fr.fix.frame())))

# Mp3DecodeReadsFrames: mp3_two_frames
def t.mp3.two.frames() -> String:
  check("mp3_two_frames",
    code.list(Fr.clip.shape(Au.decode_mp3(Fr.fx.cat(Fr.fix.frame(), Fr.fix.frame())))),
    code.list([48000, 1, 2304]))

# Mp3DecodeReadsFrames: mp3_xing_skipped
def t.mp3.xing.skipped() -> String:
  check("mp3_xing_skipped",
    code.mclip(Au.decode_mp3(Fr.fx.cat(Fr.fix.xing(), Fr.fix.frame()))),
    code.mclip(Au.decode_mp3(Fr.fix.frame())))

# Mp3DecodeRefusesUnsupported: mp3_frame_decodes
def t.mp3.frame.decodes() -> String:
  check("mp3_frame_decodes",
    code.list(Fr.clip.shape(Au.decode_mp3(Fr.fix.frame()))),
    code.list([48000, 1, 1152]))

# Mp3DecodeRefusesUnsupported: mp3_joint
def t.mp3.joint() -> String:
  check("mp3_joint",
    code.mclip(Au.decode_mp3(Fr.fix.joint())),
    code.mclip(None{}))

# Mp3DecodeRefusesUnsupported: mp3_joint_ms_silent
def t.mp3.joint.ms.silent() -> String:
  check("mp3_joint_ms_silent",
    code.mclip(Au.decode_mp3(Fr.fx.frame([255, 251, 20, 100], [], []))),
    code.mclip(None{}))

# Mp3DecodeRefusesUnsupported: mp3_joint_plain
def t.mp3.joint.plain() -> String:
  check("mp3_joint_plain",
    code.list(Fr.clip.shape(Au.decode_mp3(Fr.fx.frame([255, 251, 20, 68], [], [])))),
    code.list([48000, 2, 2304]))

# Mp3DecodeRefusesUnsupported: mp3_layer1
def t.mp3.layer1() -> String:
  check("mp3_layer1",
    code.mclip(Au.decode_mp3(Fr.fix.layer1())),
    code.mclip(None{}))

# Mp3DecodeRefusesUnsupported: mp3_layer2
def t.mp3.layer2() -> String:
  check("mp3_layer2",
    code.mclip(Au.decode_mp3(Fr.fix.layer2())),
    code.mclip(None{}))

# Mp3DecodeRefusesUnsupported: mp3_reservoir
def t.mp3.reservoir() -> String:
  check("mp3_reservoir",
    code.mclip(Au.decode_mp3(Fr.fix.reservoir())),
    code.mclip(None{}))

# Mp3DecodeRefusesUnsupported: mp3_scfc
def t.mp3.scfc() -> String:
  check("mp3_scfc",
    code.mclip(Au.decode_mp3(Fr.fix.scfc())),
    code.mclip(None{}))

# Mp3DecodeRefusesUnsupported: mp3_short
def t.mp3.short() -> String:
  check("mp3_short",
    code.mclip(Au.decode_mp3(Hd.fix.hdr())),
    code.mclip(None{}))

# Mp3DecodeRefusesUnsupported: mp3_window
def t.mp3.window() -> String:
  check("mp3_window",
    code.mclip(Au.decode_mp3(Fr.fix.window())),
    code.mclip(None{}))

# Mp3HuffmanStaysInFrame: mp3_overrun
def t.mp3.overrun() -> String:
  check("mp3_overrun",
    code.mclip(Au.decode_mp3(Fr.fix.overrun())),
    code.mclip(None{}))

# Mp3HuffmanStaysInFrame: mp3_overrun_lines
def t.mp3.overrun.lines() -> String:
  check("mp3_overrun_lines",
    code.mgls(Mp3.mp3.lines(Fr.fix.overrun())),
    code.mgls(None{}))

# Mp3HuffmanStaysInFrame: mp3_past_end
def t.mp3.past.end() -> String:
  check("mp3_past_end",
    code.mclip(Au.decode_mp3(Fr.fix.past())),
    code.mclip(None{}))

# Mp3HuffmanStaysInFrame: mp3_past_end_lines
def t.mp3.past.end.lines() -> String:
  check("mp3_past_end_lines",
    code.mgls(Mp3.mp3.lines(Fr.fix.past())),
    code.mgls(None{}))

# Mp3SilenceDecodesToZeros: mp3_hz32_fix
def t.mp3.at32.fix() -> String:
  check("mp3_hz32_fix",
    code.mclip(Au.decode_mp3(By.frame.z([255, 251, 232, 196], 1440))),
    code.mclip(Some{Au.clip(32000, 1, Au.f32(), By.pcm.z(1152))}))

# Mp3SilenceDecodesToZeros: mp3_hz48_fix
def t.mp3.at48.fix() -> String:
  check("mp3_hz48_fix",
    code.mclip(Au.decode_mp3(By.frame.z([255, 251, 228, 196], 960))),
    code.mclip(Some{Au.clip(48000, 1, Au.f32(), By.pcm.z(1152))}))

# Mp3SilenceDecodesToZeros: mp3_silence_fix
def t.mp3.silence.fix() -> String:
  check("mp3_silence_fix",
    code.mclip(Au.decode_mp3(By.frame.z([255, 251, 224, 196], 1044))),
    code.mclip(Some{Au.clip(44100, 1, Au.f32(), By.pcm.z(1152))}))

# Mp3SilenceDecodesToZeros: mp3_stereo_fix
def t.mp3.stereo.fix() -> String:
  check("mp3_stereo_fix",
    code.mclip(Au.decode_mp3(By.frame.z([255, 251, 224, 4], 1044))),
    code.mclip(Some{Au.clip(44100, 2, Au.f32(), By.pcm.z(2304))}))

# Mp3SilenceIsHeaderAndZeros: mp3_f32_frame
def t.mp3.f32.frame() -> String:
  check("mp3_f32_frame",
    code.mlist(Au.encode_mp3(Au.clip(44100, 1, Au.f32(), [0]))),
    code.mlist(Some{List.append(&2, U32, By.frame.z([255, 251, 224, 196], 1044), By.frame.z([255, 251, 226, 196],
      1045))}))

# Mp3SilenceIsHeaderAndZeros: mp3_hz32_frame
def t.mp3.at32.frame() -> String:
  check("mp3_hz32_frame",
    code.mlist(Au.encode_mp3(Au.clip(32000, 1, Au.s16(), [0]))),
    code.mlist(Some{List.append(&2, U32, By.frame.z([255, 251, 232, 196], 1440), By.frame.z([255, 251, 232, 196],
      1440))}))

# Mp3SilenceIsHeaderAndZeros: mp3_hz48_frame
def t.mp3.at48.frame() -> String:
  check("mp3_hz48_frame",
    code.mlist(Au.encode_mp3(Au.clip(48000, 1, Au.s16(), [0]))),
    code.mlist(Some{List.append(&2, U32, By.frame.z([255, 251, 228, 196], 960), By.frame.z([255, 251, 228, 196],
      960))}))

# Mp3SilenceIsHeaderAndZeros: mp3_negzero_frame
def t.mp3.negzero.frame() -> String:
  check("mp3_negzero_frame",
    code.mlist(Au.encode_mp3(Au.clip(44100, 1, Au.f32(), [2147483648]))),
    code.mlist(Some{List.append(&2, U32, By.frame.z([255, 251, 224, 196], 1044), By.frame.z([255, 251, 226, 196],
      1045))}))

# Mp3SilenceIsHeaderAndZeros: mp3_silence_frame
def t.mp3.silence.frame() -> String:
  check("mp3_silence_frame",
    code.mlist(Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [0]))),
    code.mlist(Some{List.append(&2, U32, By.frame.z([255, 251, 224, 196], 1044), By.frame.z([255, 251, 226, 196],
      1045))}))

# Mp3SilenceIsHeaderAndZeros: mp3_stereo_frame
def t.mp3.stereo.frame() -> String:
  check("mp3_stereo_frame",
    code.mlist(Au.encode_mp3(Au.clip(44100, 2, Au.s16(), [0, 0]))),
    code.mlist(Some{List.append(&2, U32, By.frame.z([255, 251, 224, 4], 1044), By.frame.z([255, 251, 226, 4],
      1045))}))

# Mp3EncodeRefusesBadClips: mp3_empty
def t.mp3.empty() -> String:
  check("mp3_empty",
    code.mlist(Au.encode_mp3(Au.clip(44100, 1, Au.s16(), []))),
    code.mlist(None{}))

# Mp3EncodeRefusesBadClips: mp3_rate
def t.mp3.rate() -> String:
  check("mp3_rate",
    code.mlist(Au.encode_mp3(Au.clip(22050, 1, Au.s16(), [0]))),
    code.mlist(None{}))

# Mp3EncodeRefusesBadClips: mp3_three
def t.mp3.three() -> String:
  check("mp3_three",
    code.mlist(Au.encode_mp3(Au.clip(44100, 3, Au.s16(), [0, 0, 0]))),
    code.mlist(None{}))

# Mp3SamplesAreClamped: mp3_half
def t.mp3.half() -> String:
  check("mp3_half",
    code.u32(Enc.samp.sat(1056964608)),
    code.u32(1056964608))

# Mp3SamplesAreClamped: mp3_loud
def t.mp3.loud() -> String:
  check("mp3_loud",
    code.u32(Enc.samp.sat(1115684864)),
    code.u32(1065353216))

# Mp3SamplesAreClamped: mp3_neg_inf
def t.mp3.neg.inf() -> String:
  check("mp3_neg_inf",
    code.u32(Enc.samp.sat(4286578688)),
    code.u32(3212836864))

# Mp3GranulesFitTheirFields: mp3_room
def t.mp3.room() -> String:
  check("mp3_room",
    code.bool(Rm.room.all()),
    code.bool(True{}))

# the WAV file fixtures
def results.wav() -> List<String>:
  [
    t.data.tag(),
    t.fmt.tag(),
    t.riff.tag(),
    t.wave.tag(),
    t.wav.f32.bytes(),
    t.wav.s16.bytes(),
    t.wav.f32.mono(),
    t.wav.f32.stereo(),
    t.wav.no.frames.round(),
    t.wav.s16.round(),
    t.wav.s16.stereo(),
    t.wav.s16.wide(),
    t.wav.streamed(),
    t.wav.truncated(),
    t.wav.rate.wraps()
  ]

# the clip fixtures
def results.clip() -> List<String>:
  [
    t.fill.mono(),
    t.fill.stereo(),
    t.trim.all(),
    t.trim.past(),
    t.trim.span(),
    t.trim.stereo()
  ]

# the MP3 decode fixtures
def results.dec() -> List<String>:
  [
    t.scf.hz32000(),
    t.scf.hz44100(),
    t.scf.hz48000(),
    t.mp3.count1.lines(),
    t.mp3.crc.decodes(),
    t.mp3.crc.lines(),
    t.mp3.id3.footer.skipped(),
    t.mp3.id3.skipped(),
    t.mp3.info.later.kept(),
    t.mp3.info.skipped(),
    t.mp3.junk.skipped(),
    t.mp3.partial.alone(),
    t.mp3.partial.dropped(),
    t.mp3.two.frames(),
    t.mp3.xing.skipped(),
    t.mp3.frame.decodes(),
    t.mp3.joint(),
    t.mp3.joint.ms.silent(),
    t.mp3.joint.plain(),
    t.mp3.layer1(),
    t.mp3.layer2(),
    t.mp3.reservoir(),
    t.mp3.scfc(),
    t.mp3.short(),
    t.mp3.window(),
    t.mp3.overrun(),
    t.mp3.overrun.lines(),
    t.mp3.past.end(),
    t.mp3.past.end.lines(),
    t.mp3.at32.fix(),
    t.mp3.at48.fix(),
    t.mp3.silence.fix(),
    t.mp3.stereo.fix()
  ]

# the MP3 encode fixtures
def results.enc() -> List<String>:
  [
    t.mp3.f32.frame(),
    t.mp3.at32.frame(),
    t.mp3.at48.frame(),
    t.mp3.negzero.frame(),
    t.mp3.silence.frame(),
    t.mp3.stereo.frame(),
    t.mp3.empty(),
    t.mp3.rate(),
    t.mp3.three(),
    t.mp3.half(),
    t.mp3.loud(),
    t.mp3.neg.inf(),
    t.mp3.room()
  ]

# every fixture's line, in order
def results() -> List<String>:
  List.concat(&1, String, [results.wav(), results.clip(), results.dec(), results.enc()])

# print each line
def say(xs: List<String>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case x <> tl:
      do IO<Unit>:
        IO.print(x)
        say(tl)

def main() -> IO(Unit):
  say(results())

#|ok data_tag
#|ok fmt_tag
#|ok riff_tag
#|ok wave_tag
#|ok wav_f32_bytes
#|ok wav_s16_bytes
#|ok wav_f32_mono
#|ok wav_f32_stereo
#|ok wav_no_frames_round
#|ok wav_s16_round
#|ok wav_s16_stereo
#|ok wav_s16_wide
#|ok wav_streamed
#|ok wav_truncated
#|ok wav_rate_wraps
#|ok fill_mono
#|ok fill_stereo
#|ok trim_all
#|ok trim_past
#|ok trim_span
#|ok trim_stereo
#|ok scf_32000
#|ok scf_44100
#|ok scf_48000
#|ok mp3_count1_lines
#|ok mp3_crc_decodes
#|ok mp3_crc_lines
#|ok mp3_id3_footer_skipped
#|ok mp3_id3_skipped
#|ok mp3_info_later_kept
#|ok mp3_info_skipped
#|ok mp3_junk_skipped
#|ok mp3_partial_alone
#|ok mp3_partial_dropped
#|ok mp3_two_frames
#|ok mp3_xing_skipped
#|ok mp3_frame_decodes
#|ok mp3_joint
#|ok mp3_joint_ms_silent
#|ok mp3_joint_plain
#|ok mp3_layer1
#|ok mp3_layer2
#|ok mp3_reservoir
#|ok mp3_scfc
#|ok mp3_short
#|ok mp3_window
#|ok mp3_overrun
#|ok mp3_overrun_lines
#|ok mp3_past_end
#|ok mp3_past_end_lines
#|ok mp3_hz32_fix
#|ok mp3_hz48_fix
#|ok mp3_silence_fix
#|ok mp3_stereo_fix
#|ok mp3_f32_frame
#|ok mp3_hz32_frame
#|ok mp3_hz48_frame
#|ok mp3_negzero_frame
#|ok mp3_silence_frame
#|ok mp3_stereo_frame
#|ok mp3_empty
#|ok mp3_rate
#|ok mp3_three
#|ok mp3_half
#|ok mp3_loud
#|ok mp3_neg_inf
#|ok mp3_room
