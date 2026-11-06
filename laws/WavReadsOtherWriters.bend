# `decode_wav` reads RIFF WAVE files as libsndfile, dr_wav, ffmpeg and
# Python's wave read them, not only the 44-byte header encode_wav writes. It
# walks the chunks in order and stops at the data chunk, so any bytes after
# it, such as a LIST chunk, an ID3 tag or junk past the form, are not read and
# change nothing. A data chunk larger than the bytes left is clamped to them:
# a truncated file, and a streamed one whose sizes are 0xFFFFFFFF, read what
# is there. The samples are cut to whole frames. Chunks the reader does not
# know are skipped with their pad byte, before fmt and between fmt and data.
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

# LAW: a streamed file, its sizes 0xFFFFFFFF, reads the samples that are there
law wav_streamed:
  {Au.decode_wav(D2.wav.streamed()) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: a truncated data chunk reads the samples that are there
law wav_truncated:
  {Au.decode_wav(D2.wav.truncated()) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: a data chunk that ends in half a frame reads the whole frames
law wav_partial_frame:
  {Au.decode_wav(D2.wav.partial()) == Some{Au.clip(8000, 2, Au.s16(), [0, 1])} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — an odd-sized LIST chunk and its pad byte are skipped
law wav_list_chunk:
  {Au.decode_wav(D2.wav.list()) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — a chunk before fmt is skipped
law wav_junk_first:
  {Au.decode_wav(D2.wav.junk.first()) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: WAVEFORMATEXTENSIBLE — the PCM sub-format reads as format tag 1
law wav_extensible:
  {Au.decode_wav(D2.wav.ext()) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: the byte rate and block align are not checked
law wav_byte_rate:
  {Au.decode_wav(D2.wav.byterate()) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: a data chunk of no bytes is a clip of no frames
law wav_no_frames:
  {Au.decode_wav(D2.wav.empty()) == Some{Au.clip(8000, 1, Au.s16(), [])} : Maybe<&2, Au.Clip>}

# LAW: data before fmt is none
law wav_data_first:
  {Au.decode_wav(D2.wav.data.first()) == None{} : Maybe<&2, Au.Clip>}
