# RIFF WAVE files whose data chunk runs to the end of the bytes, and the
# file encode_wav writes for one binary32 sample
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

# 1.0 as one mono binary32 sample at 8000 Hz, as encode_wav writes it: format
# tag 3, an 18-byte fmt chunk whose cbSize is 0, and a fact chunk of one frame
def wav.float() -> List<&2, U32>:
  [
    82, 73, 70, 70, 54, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 18, 0, 0, 0, 3, 0, 1, 0,
    64, 31, 0, 0, 0, 125, 0, 0, 4, 0, 32, 0, 0, 0, 102, 97, 99, 116, 4, 0, 0, 0, 1, 0, 0, 0,
    100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 128, 63
  ]
