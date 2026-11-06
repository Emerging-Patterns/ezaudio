# RIFF WAVE files as other writers lay them out, for fix.mono's two s16
# samples 0 and 1 at 8000 Hz unless said otherwise
import Base

# a streamed file: RIFF and data sizes 0xFFFFFFFF, as ffmpeg writes to a pipe
def wav.streamed() -> List<&2, U32>:
  [
    82, 73, 70, 70, 255, 255, 255, 255, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0, 64,
    31, 0, 0, 128, 62, 0, 0, 2, 0, 16, 0, 100, 97, 116, 97, 255, 255, 255, 255, 0, 0, 1, 0
  ]

# a truncated file: the data chunk says 100 bytes and 4 are there
def wav.truncated() -> List<&2, U32>:
  [
    82, 73, 70, 70, 40, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0, 64, 31, 0,
    0, 128, 62, 0, 0, 2, 0, 16, 0, 100, 97, 116, 97, 100, 0, 0, 0, 0, 0, 1, 0
  ]

# stereo s16 whose data chunk ends in half a frame: 6 bytes
def wav.partial() -> List<&2, U32>:
  [
    82, 73, 70, 70, 42, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 2, 0, 64, 31, 0,
    0, 0, 125, 0, 0, 4, 0, 16, 0, 100, 97, 116, 97, 6, 0, 0, 0, 0, 0, 1, 0, 2, 0
  ]

# a LIST chunk of odd size, with its pad byte, between fmt and data
def wav.list() -> List<&2, U32>:
  [
    82, 73, 70, 70, 52, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0, 64, 31, 0,
    0, 128, 62, 0, 0, 2, 0, 16, 0, 76, 73, 83, 84, 3, 0, 0, 0, 1, 2, 3, 0, 100, 97, 116, 97, 4, 0, 0, 0,
    0, 0, 1, 0
  ]

# a JUNK chunk before fmt
def wav.junk.first() -> List<&2, U32>:
  [
    82, 73, 70, 70, 52, 0, 0, 0, 87, 65, 86, 69, 74, 85, 78, 75, 4, 0, 0, 0, 0, 0, 0, 0, 102, 109, 116,
    32, 16, 0, 0, 0, 1, 0, 1, 0, 64, 31, 0, 0, 128, 62, 0, 0, 2, 0, 16, 0, 100, 97, 116, 97, 4, 0, 0, 0,
    0, 0, 1, 0
  ]

# WAVE_FORMAT_EXTENSIBLE with the PCM sub-format GUID
def wav.ext() -> List<&2, U32>:
  [
    82, 73, 70, 70, 64, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 40, 0, 0, 0, 254, 255, 1, 0, 64, 31,
    0, 0, 128, 62, 0, 0, 2, 0, 16, 0, 22, 0, 16, 0, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170,
    0, 56, 155, 113, 100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 1, 0
  ]

# a byte rate and block align of 0
def wav.byterate() -> List<&2, U32>:
  [
    82, 73, 70, 70, 40, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0, 64, 31, 0,
    0, 0, 0, 0, 0, 0, 0, 16, 0, 100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 1, 0
  ]

# a data chunk of no bytes
def wav.empty() -> List<&2, U32>:
  [
    82, 73, 70, 70, 36, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0, 64, 31, 0,
    0, 128, 62, 0, 0, 2, 0, 16, 0, 100, 97, 116, 97, 0, 0, 0, 0
  ]

# data before fmt
def wav.data.first() -> List<&2, U32>:
  [
    82, 73, 70, 70, 40, 0, 0, 0, 87, 65, 86, 69, 100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 1, 0, 102, 109,
    116, 32, 16, 0, 0, 0, 1, 0, 1, 0, 64, 31, 0, 0, 128, 62, 0, 0, 2, 0, 16, 0
  ]

# fix.mono as encode_wav writes it: PCM, one channel, 16 bits, 44 header bytes
def wav.canonical() -> List<&2, U32>:
  [
    82, 73, 70, 70, 40, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0,
    64, 31, 0, 0, 128, 62, 0, 0, 2, 0, 16, 0, 100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 1, 0
  ]

# 1.0 as one mono binary32 sample at 8000 Hz, as encode_wav writes it: format
# tag 3, an 18-byte fmt chunk whose cbSize is 0, and a fact chunk of one frame
def wav.float() -> List<&2, U32>:
  [
    82, 73, 70, 70, 54, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 18, 0, 0, 0, 3, 0, 1, 0,
    64, 31, 0, 0, 0, 125, 0, 0, 4, 0, 32, 0, 0, 0, 102, 97, 99, 116, 4, 0, 0, 0, 1, 0, 0, 0,
    100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 128, 63
  ]
