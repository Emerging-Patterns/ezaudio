# `decode_wav` reads RIFF WAVE files as libsndfile, dr_wav, ffmpeg and
# Python's wave read them, not only the 44-byte header encode_wav writes. It
# walks the chunks in order and stops at the data chunk, so any bytes after
# it, such as a LIST chunk, an ID3 tag or junk past the form, are not read and
# change nothing: each law below holds for every tail after its file. The
# samples are cut to whole frames. Chunks the reader does not know are
# skipped with their pad byte, before fmt and between fmt and data.
# WAVE_FORMAT_EXTENSIBLE is read through its sub-format GUID. The byte rate
# and block align are not checked: the channels and the bits decide them.
# Data before fmt is still none, as in Python's wave.
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1
import ./defs/WavFiles.bend as D2

# LAW: IBM/Microsoft RIFF — any bytes after the data chunk change nothing
law wav_after_data:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.canonical(), tail)) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: a data chunk that ends in half a frame reads the whole frames
law wav_partial_frame:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.partial(), tail)) == Some{Au.clip(8000, 2, Au.s16(), [0, 1])}
    : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — an odd-sized LIST chunk and its pad byte are skipped
law wav_list_chunk:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.list(), tail)) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — a chunk before fmt is skipped
law wav_junk_first:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.junk.first(), tail)) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: WAVEFORMATEXTENSIBLE — the PCM sub-format reads as format tag 1
law wav_extensible:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.ext(), tail)) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: the byte rate and block align are not checked
law wav_byte_rate:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.byterate(), tail)) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: a data chunk of no bytes is a clip of no frames
law wav_no_frames:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.empty(), tail)) == Some{Au.clip(8000, 1, Au.s16(), [])}
    : Maybe<&2, Au.Clip>}

# LAW: data before fmt is none
law wav_data_first:
  for +tail: List<&2, U32>
  {Au.decode_wav(List.append(&2, U32, D2.wav.data.first(), tail)) == None{} : Maybe<&2, Au.Clip>}
