# ezaudio

Audio for [Bend 2](https://github.com/bendlang/bend).

## Install

Use with [Bend](https://github.com/bendlang/bend) or install easily with [ez](https://github.com/Emerging-Patterns/ez):

```
ez init
ez add Emerging-Patterns/ezaudio
```

## Usage

A clip is a `Clip`: a sample rate, a channel count, a sample format, and
interleaved frames. `s16` is signed 16-bit PCM. `f32` is IEEE 754 binary32,
stored as its bits. `decode_wav` and `encode_wav` read and write a RIFF WAVE
file of that PCM. `decode_mp3` reads MPEG-1 Layer III into `f32` frames.
`encode_mp3` writes MPEG-1 Layer III at 320 kbit/s. `count`, `fill`, `trim`,
and `concat` are the raw-frame helpers. Resampling is not in this version.

```
import ./ezaudio/main.bend as Au

def main() -> U32:
  Au.rate(Au.clip(8000, 1, Au.s16(), [0, 1]))
```

## Compliance

Closed equalities in `ezaudio/LAWS.bend`, proved in `ezaudio/PROOF.bend`
(`bend ezaudio/PROOF.bend`), target:

- The IBM/Microsoft RIFF WAVE form: the `RIFF`, `WAVE`, `fmt `, and `data`
  identifiers. A mono signed-16 clip at 8000 Hz encodes as PCM (format tag 1),
  one channel, 16 bits, little-endian samples, and decodes back to that clip.
  Stereo signed-16, and mono and stereo IEEE 754 binary32 (format tag 3),
  round-trip the same way, including the bits of 1.0. A byte list that is not
  RIFF, an empty frame list, and a zero sample rate encode or decode as none.
- [ISO/IEC 11172-3](https://www.iso.org/standard/22412.html) MPEG-1 Layer III:
  the header `FF FB 90 C0` is Layer III, MPEG-1, 128 kbit/s, 44100 Hz, single
  channel. Layer I and Layer II decode as none, as do joint stereo, a CRC,
  and a header with no frame behind it. A silent frame encodes at 320 kbit/s
  with header `FF FB E0 C4` (mono) or `FF FB E0 04` (stereo). Its length is
  `1152 * 320 * 125 / hz` (1044 bytes at 44100 Hz, 960 at 48000 Hz, 1440 at
  32000 Hz). Decoding the 44100 Hz frame yields 1152 zero binary32 samples
  per channel. An empty sample list, and a rate other than 32000, 44100, or
  48000, encode as none.

Decode accepts long blocks only. Short blocks, a non-zero scale-factor
compress, a bit reservoir, joint stereo, a CRC, the count1 region, preflag,
and scale-factor scale are none. Full codec conformance is not claimed yet.
