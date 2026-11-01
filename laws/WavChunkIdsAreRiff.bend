# IBM/Microsoft RIFF WAVE form: the form, wave, format and sample chunk
# identifiers are `RIFF`, `WAVE`, `fmt ` and `data`
import Base
import ../src/wav.bend as Wav

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
