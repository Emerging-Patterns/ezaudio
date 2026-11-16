# IBM/Microsoft RIFF WAVE form: every file `encode_wav` writes, for every
# clip it encodes, starts with the form id `RIFF`, has the wave id `WAVE`
# after the form size, and opens its first chunk with the format id `fmt `
import Base
import ../main.bend as Au
import ../src/wav.bend as Wav

# the ids at bytes 0, 8 and 12, read big-endian as RIFF writes its four-character codes
def ids.of(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case +a <> +b <> +c <> +d <> _s0 <> _s1 <> _s2 <> _s3 <> +w0 <> +w1 <> +w2 <> +w3 <> +f0 <> +f1 <> +f2 <> +f3 <> _t:
      [Wav.be.u32(a, b, c, d), Wav.be.u32(w0, w1, w2, w3), Wav.be.u32(f0, f1, f2, f3)]
    case _:
      []

# LAW: IBM/Microsoft RIFF — a written file's ids are RIFF, WAVE and 'fmt '
law riff_ids:
  for +hz: U32
  for +nch: U32
  for +fmt: Au.Format
  for +pcm: List<&2, U32>
  for +bytes: List<&2, U32>
  for h_enc: {Au.encode_wav(Au.clip(hz, nch, fmt, pcm)) == Some{bytes} : Maybe<&2, List<&2, U32>>}
  {ids.of(bytes) == [1380533830, 1463899717, 1718449184] : List<&2, U32>}
