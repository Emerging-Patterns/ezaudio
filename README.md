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
`encode_mp3` writes MPEG-1 Layer III at 320 kbit/s. One mono signed-16 sample
whose magnitude is 1..15 is stored as a single Huffman pair; decoding that
frame returns the two magnitudes and then zeros. Other clips are encoded with
the filterbank. `count`, `fill`, `trim`, and `concat` are the raw-frame
helpers. Resampling is not in this version.

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
- `trim` keeps a span of frames, including the whole clip, and is none past
  the end. `concat` appends clips that share rate, channels, and format, and
  is none when they differ.
- [ISO/IEC 11172-3](https://www.iso.org/standard/22412.html) MPEG-1 Layer III:
  the header `FF FB 90 C0` is Layer III, MPEG-1, 128 kbit/s, 44100 Hz, single
  channel. Layer I and Layer II decode as none, as do joint stereo, a CRC,
  and a header with no frame behind it. A silent frame at 320 kbit/s is the
  header and then zeros for the rest of `1152 * 320 * 125 / hz` bytes:
  `FF FB E0 C4` and 1044 bytes at 44100 Hz mono, `FF FB E0 04` and 1044 bytes
  for stereo, `FF FB E4 C4` and 960 bytes at 48000 Hz, `FF FB E8 C4` and 1440
  bytes at 32000 Hz. Decoding those byte strings yields 1152 zero binary32
  samples per channel. Binary32 silence encodes as the mono frame. One mono
  signed-16 sample of magnitude 1 encodes with the same header and length.
  Its first granule is a long block, `big_values` 1, `global_gain` 0,
  `part2_3_length` 4, Huffman table 13. The second granule's `big_values` is
  0. Decoding that frame returns the Huffman pair as the first two words
  (1, then 0) and 1150 zeros. That equality is the pair, not the synthesis
  filterbank. An empty sample list, and a rate other than 32000, 44100, or
  48000, encode as none.

Decode accepts long blocks only. Short blocks, a non-zero scale-factor
compress, a bit reservoir, joint stereo, a CRC, the count1 region, preflag,
and scale-factor scale are none. Full codec conformance is not claimed yet.
