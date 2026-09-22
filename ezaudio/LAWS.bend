# ezaudio: the laws. Closed equalities for the clip, the RIFF tags, and the
# MPEG-1 Layer III header. PROOF.bend fills them.
import Base
import ./main.bend as Au
import ./wav.bend as Wav
import ./mp3.bend as Mp3
import ./mp3_dec.bend as Dec
import ./mp3_enc.bend as Enc
import ./mp3_syn.bend as Syn

# two s16 frames at 8000 Hz
def fix.mono() -> Au.Clip:
  Au.clip(8000, 1, Au.s16(), [0, 1])

# the RIFF bytes of fix.mono: PCM, one channel, 16 bits
def fix.s16() -> List<&2, U32>:
  [
    82, 73, 70, 70, 40, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0,
    64, 31, 0, 0, 128, 62, 0, 0, 2, 0, 16, 0, 100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 1, 0
  ]

# FF FB 90 C0: MPEG-1 Layer III, 128 kbit/s, 44100 Hz, mono, no CRC
def fix.hdr() -> List<&2, U32>:
  [255, 251, 144, 192]

def bytes.of(got: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match got:
    case None{}:
      []
    case Some{xs}:
      xs

def head.of(got: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  List.take(&2, U32, bytes.of(got), 4n)

def len.of(got: Maybe<&2, List<&2, U32>>) -> U32:
  U32.from_nat(List.length(&2, U32, bytes.of(got)))

def zf32(+n: U32) -> List<&2, U32>:
  List.replicate(U32, U32.to_nat(n), 0)

# LAW: a clip keeps the rate it was built with
law rate_reads:
  {Au.rate(fix.mono()) == 8000 : U32}

# LAW: a clip keeps the channel count it was built with
law channels_read:
  {Au.channels(fix.mono()) == 1 : U32}

# LAW: s16 is the signed 16-bit format
law format_s16:
  {Au.format(Au.clip(8000, 1, Au.s16(), [])) == Au.s16() : Au.Format}

# LAW: f32 is the binary32 format
law format_f32:
  {Au.format(Au.clip(8000, 1, Au.f32(), [])) == Au.f32() : Au.Format}

# LAW: frames reads the samples a clip was built with
law frames_read:
  {Au.frames(fix.mono()) == [0, 1] : List<&2, U32>}

# LAW: the frame count is samples divided by channels
law count_frames:
  {Au.count(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3])) == 2 : U32}

# LAW: zero channels count as no frames
law count_zero_channels:
  {Au.count(Au.clip(8000, 0, Au.s16(), [1])) == 0 : U32}

# LAW: fill repeats one sample across the frames
law fill_mono:
  {Au.fill(8000, 1, Au.s16(), 7, 3) == Au.clip(8000, 1, Au.s16(), [7, 7, 7]) : Au.Clip}

# LAW: fill interleaves the sample once per channel
law fill_stereo:
  {Au.fill(8000, 2, Au.f32(), 4, 2) == Au.clip(8000, 2, Au.f32(), [4, 4, 4, 4]) : Au.Clip}

# LAW: trim keeps the frame span inside the clip
law trim_span:
  {Au.trim(Au.clip(8000, 1, Au.s16(), [0, 1, 2, 3]), 1, 2)
    == Some{Au.clip(8000, 1, Au.s16(), [1, 2])} : Maybe<&2, Au.Clip>}

# LAW: trim of the whole clip is the clip
law trim_all:
  {Au.trim(fix.mono(), 0, 2) == Some{fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: trim past the end is none
law trim_past:
  {Au.trim(fix.mono(), 1, 2) == None{} : Maybe<&2, Au.Clip>}

# LAW: trim of stereo drops whole frames
law trim_stereo:
  {Au.trim(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3]), 1, 1)
    == Some{Au.clip(8000, 2, Au.s16(), [2, 3])} : Maybe<&2, Au.Clip>}

# LAW: concat appends frames when the clips agree
law concat_match:
  {Au.concat(fix.mono(), Au.clip(8000, 1, Au.s16(), [2]))
    == Some{Au.clip(8000, 1, Au.s16(), [0, 1, 2])} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the rates differ
law concat_rate:
  {Au.concat(fix.mono(), Au.clip(16000, 1, Au.s16(), [2])) == None{} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the channel counts differ
law concat_channels:
  {Au.concat(fix.mono(), Au.clip(8000, 2, Au.s16(), [2, 3])) == None{} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the formats differ
law concat_format:
  {Au.concat(fix.mono(), Au.clip(8000, 1, Au.f32(), [0])) == None{} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — the form id is RIFF
law riff_tag:
  {Wav.tag.riff() == 1380533830 : U32}

# LAW: IBM/Microsoft RIFF — the wave id is WAVE
law wave_tag:
  {Wav.tag.wave() == 1463899717 : U32}

# LAW: IBM/Microsoft RIFF — the format chunk id is 'fmt '
law fmt_tag:
  {Wav.tag.fmt() == 1718449184 : U32}

# LAW: IBM/Microsoft RIFF — the sample chunk id is data
law data_tag:
  {Wav.tag.data() == 1684108385 : U32}

# LAW: IBM/Microsoft RIFF — s16 mono encodes as PCM, 8000 Hz, 16-bit little-endian
law wav_s16_bytes:
  {Au.encode_wav(fix.mono()) == Some{fix.s16()} : Maybe<&2, List<&2, U32>>}

# LAW: IBM/Microsoft RIFF — decoding that encoding is the clip
law wav_s16_round:
  {Au.decode_wav(bytes.of(Au.encode_wav(fix.mono()))) == Some{fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — stereo s16 round-trips
law wav_s16_stereo:
  {Au.decode_wav(bytes.of(Au.encode_wav(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3]))))
    == Some{Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3])} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — binary32 mono round-trips, including 1.0
law wav_f32_mono:
  {Au.decode_wav(bytes.of(Au.encode_wav(Au.clip(8000, 1, Au.f32(), [0, 1065353216]))))
    == Some{Au.clip(8000, 1, Au.f32(), [0, 1065353216])} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — binary32 stereo round-trips
law wav_f32_stereo:
  {Au.decode_wav(bytes.of(Au.encode_wav(Au.clip(8000, 2, Au.f32(), [0, 1065353216]))))
    == Some{Au.clip(8000, 2, Au.f32(), [0, 1065353216])} : Maybe<&2, Au.Clip>}

# LAW: a byte list that is not RIFF decodes as none
law wav_bad:
  {Au.decode_wav([0]) == None{} : Maybe<&2, Au.Clip>}

# LAW: an empty frame list does not encode
law wav_empty:
  {Au.encode_wav(Au.clip(8000, 1, Au.s16(), [])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a zero sample rate does not encode
law wav_rate0:
  {Au.encode_wav(Au.clip(0, 1, Au.s16(), [1])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is Layer III
law mp3_layer:
  {Mp3.hdr.layer(fix.hdr()) == 1 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is MPEG-1
law mp3_mpeg1:
  {Mp3.hdr.mpeg1(fix.hdr()) == 1 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is 128 kbit/s
law mp3_kbps:
  {Mp3.hdr.kbps(fix.hdr()) == 128 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is 44100 Hz
law mp3_hz:
  {Mp3.hdr.hz(fix.hdr()) == 44100 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is single channel
law mp3_mode:
  {Mp3.hdr.mode(fix.hdr()) == 3 : U32}

# LAW: ISO/IEC 11172-3 — Layer I decodes as none
law mp3_layer1:
  {Au.decode_mp3([255, 255, 144, 192]) == None{} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — Layer II decodes as none
law mp3_layer2:
  {Au.decode_mp3([255, 253, 144, 192]) == None{} : Maybe<&2, Au.Clip>}

# LAW: a joint-stereo header decodes as none
law mp3_joint:
  {Au.decode_mp3([255, 251, 144, 64]) == None{} : Maybe<&2, Au.Clip>}

# LAW: a header with a CRC decodes as none
law mp3_crc:
  {Au.decode_mp3([255, 250, 144, 192]) == None{} : Maybe<&2, Au.Clip>}

# LAW: a header without its frame decodes as none
law mp3_short:
  {Au.decode_mp3(fix.hdr()) == None{} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — silence at 44100 Hz mono opens FF FB E0 C4
law mp3_silence_head:
  {head.of(Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [0]))) == [255, 251, 224, 196] : List<&2, U32>}

# LAW: ISO/IEC 11172-3 — that frame is 1152 * 320 * 125 / 44100 bytes
law mp3_silence_len:
  {len.of(Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [0]))) == 1044 : U32}

# LAW: ISO/IEC 11172-3 — decoding that frame is 1152 zero binary32 samples
law mp3_silence_pcm:
  {Au.decode_mp3(bytes.of(Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [0]))))
    == Some{Au.clip(44100, 1, Au.f32(), zf32(1152))} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — stereo silence opens FF FB E0 04
law mp3_stereo_head:
  {head.of(Au.encode_mp3(Au.clip(44100, 2, Au.s16(), [0, 0]))) == [255, 251, 224, 4] : List<&2, U32>}

# LAW: ISO/IEC 11172-3 — decoding that frame is 1152 zero samples on each channel
law mp3_stereo_pcm:
  {Au.decode_mp3(bytes.of(Au.encode_mp3(Au.clip(44100, 2, Au.s16(), [0, 0]))))
    == Some{Au.clip(44100, 2, Au.f32(), zf32(2304))} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — 48000 Hz sets the sampling-frequency index to 1
law mp3_hz48:
  {head.of(Au.encode_mp3(Au.clip(48000, 1, Au.s16(), [0]))) == [255, 251, 228, 196] : List<&2, U32>}

# LAW: ISO/IEC 11172-3 — a 48000 Hz silent frame is 960 bytes
law mp3_len48:
  {len.of(Au.encode_mp3(Au.clip(48000, 1, Au.s16(), [0]))) == 960 : U32}

# LAW: ISO/IEC 11172-3 — 32000 Hz sets the sampling-frequency index to 2
law mp3_hz32:
  {head.of(Au.encode_mp3(Au.clip(32000, 1, Au.s16(), [0]))) == [255, 251, 232, 196] : List<&2, U32>}

# LAW: ISO/IEC 11172-3 — a 32000 Hz silent frame is 1440 bytes
law mp3_len32:
  {len.of(Au.encode_mp3(Au.clip(32000, 1, Au.s16(), [0]))) == 1440 : U32}

# LAW: binary32 silence uses the same header as s16 silence
law mp3_f32_head:
  {head.of(Au.encode_mp3(Au.clip(44100, 1, Au.f32(), [0]))) == [255, 251, 224, 196] : List<&2, U32>}

# LAW: an empty sample list does not encode
law mp3_empty:
  {Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a rate outside 32000, 44100, and 48000 does not encode
law mp3_rate:
  {Au.encode_mp3(Au.clip(22050, 1, Au.s16(), [0])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: the 44100 Hz scale-factor row is the first row
law scf_44100:
  {Dec.scf.off(44100) == 0 : U32}

# LAW: the 48000 Hz scale-factor row starts at band 22
law scf_48000:
  {Dec.scf.off(48000) == 22 : U32}

# LAW: the 32000 Hz scale-factor row starts at band 44
law scf_32000:
  {Dec.scf.off(32000) == 44 : U32}

# LAW: a sample list reads the sample at an index
law enc_nth:
  {Enc.u.nth([4, 5], 1) == 5 : U32}

# LAW: adding two counts yields their sum
law syn_add:
  {Syn.u.add(2, 3) == 5 : U32}
