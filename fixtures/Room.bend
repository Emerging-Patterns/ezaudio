# whether an unpadded 320 kbit/s frame holds its header, side information and
# two granules per channel at the encoder's bit budget
import Base
import ../src/mp3.bend as Mp3

# header, side information and 2 * ch granules at the budget fit an unpadded frame
def room.ok(+hz: U32, +ch: U32) -> Bool:
  U32.is_le(
    ((((ch * 2 : U32) * Mp3.enc.bud(hz, ch) : U32) + 32 : U32) + (Mp3.side.n(ch) * 8 : U32) : U32),
    (Mp3.frame.n(320, hz, 0) * 8 : U32))

# at 32000, 44100 and 48000 Hz, mono and stereo
def room.all() -> Bool:
  Bool.and(Bool.and(Bool.and(room.ok(32000, 1), room.ok(32000, 2)), Bool.and(room.ok(44100, 1), room.ok(44100, 2))),
    Bool.and(room.ok(48000, 1), room.ok(48000, 2)))
