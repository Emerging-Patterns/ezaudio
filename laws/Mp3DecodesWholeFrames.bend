# Every clip `decode_mp3` returns is whole MPEG-1 Layer III frames, for every
# input: one or two channels, and a sample count that is a multiple of 1152
# samples per channel, since every Layer III frame is 1152 samples a channel.
# The other direction, that a frame does decode, is Mp3DecodeRefusesUnsupported's
# mp3_frame_decodes.
import Base
import ../main.bend as Au
import ./defs/WholeFrames.bend as D1

# LAW: every clip decode_mp3 returns, whatever the bytes, is whole Layer III frames
law mp3_decode_whole_frames:
  for +bytes: List<&2, U32>
  for +clip: Au.Clip
  for h_dec: {Au.decode_mp3(bytes) == Some{clip} : Maybe<&2, Au.Clip>}
  {D1.whole(clip) == True{} : Bool}
