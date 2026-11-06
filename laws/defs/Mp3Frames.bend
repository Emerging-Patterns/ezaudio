# small MPEG-1 Layer III frames for the decode laws, made by hand: 32 kbit/s,
# 48000 Hz, mono, so a frame is 96 bytes: the header, 17 bytes of side info,
# 75 bytes of main data. Granule 0 holds two big-value pairs from Huffman
# table 1, then count1 quadruples from table A, the last of which runs past
# part2_3_length; granule 1 holds one pair from table 16 (linbits 1) and one
# count1 quadruple from table B. No byte after the header is 0xFF.
import Base
import ../../main.bend as Au

# the bytes, then zeros out to n bytes
def fx.pad(+xs: List<&2, U32>, +n: U32) -> List<&2, U32>:
  List.append(&2, U32, xs, List.replicate(U32, U32.to_nat((n - U32.from_nat(List.length(&2, U32, xs)) : U32)), 0))

# one 96-byte frame from its header, side info and main data
def fx.frame(head: List<&2, U32>, side: List<&2, U32>, main: List<&2, U32>) -> List<&2, U32>:
  fx.pad(List.append(&2, U32, head, List.append(&2, U32, side, main)), 96)

# main_data_begin 0. granule 0: part2_3_length 29, big_values 2, global_gain 210,
# tables 1 0 0, count1 table A. granule 1: part2_3_length 17, big_values 1,
# global_gain 200, tables 16 0 0, count1 table B. Long blocks, no scale-factor bits.
def fix.side() -> List<&2, U32>:
  [0, 0, 0, 116, 5, 164, 0, 128, 0, 0, 8, 128, 114, 1, 0, 0, 1]

# granule 0: (1, 0) (-1, 1), quadruples 1000, 0000, 00-11, then 1111 cut off in its
# sign bits; granule 1: (16, 0), quadruple 010-1
def fix.main() -> List<&2, U32>:
  [66, 116, 176, 32, 50, 164]

# FF FB 14 C4: MPEG-1 Layer III, no CRC, 32 kbit/s, 48000 Hz, no padding, mono
def fix.frame() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], fix.side(), fix.main())

# the same frame with a CRC: protection bit 0, then the CRC-16 of header bytes 2..3 and the side info
def fix.crc() -> List<&2, U32>:
  fx.frame([255, 250, 20, 196, 41, 209], fix.side(), fix.main())

# the layer bits say Layer I
def fix.layer1() -> List<&2, U32>:
  fx.frame([255, 255, 20, 196], fix.side(), fix.main())

# the layer bits say Layer II
def fix.layer2() -> List<&2, U32>:
  fx.frame([255, 253, 20, 196], fix.side(), fix.main())

# the mode bits say joint stereo with mid/side
def fix.joint() -> List<&2, U32>:
  fx.frame([255, 251, 20, 100], fix.side(), fix.main())

# main_data_begin 1: the main data would start in the frame before
def fix.reservoir() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], [0, 128, 0, 116, 5, 164, 0, 128, 0, 0, 8, 128, 114, 1, 0, 0, 1], fix.main())

# granule 0 has scalefac_compress 1: scale-factor bits before the Huffman bits
def fix.scfc() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], [0, 0, 0, 116, 5, 164, 32, 128, 0, 0, 8, 128, 114, 1, 0, 0, 1], fix.main())

# granule 0 switches to short blocks (window_switching_flag 1, block_type 2)
def fix.window() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], [0, 0, 0, 116, 5, 164, 24, 16, 0, 0, 8, 128, 114, 1, 0, 0, 1], fix.main())

# granule 0's part2_3_length is 7, one bit short of its two big-value pairs
def fix.overrun() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], [0, 0, 0, 28, 5, 164, 0, 128, 0, 0, 8, 128, 114, 1, 0, 0, 1], [66, 12, 169])

# granule 1's part2_3_length is 4000 bits, past the frame's 600 bits of main data
def fix.past() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], [0, 0, 0, 116, 5, 164, 0, 128, 0, 7, 208, 0, 114, 1, 0, 0, 1], fix.main())

# a LAME/Xing header frame: "Info" where the main data would start
def fix.info() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], List.replicate(U32, 17n, 0), [73, 110, 102, 111])

# a Xing header frame: "Xing" where the main data would start
def fix.xing() -> List<&2, U32>:
  fx.frame([255, 251, 20, 196], List.replicate(U32, 17n, 0), [88, 105, 110, 103])

# an ID3v2.3 tag of 12 bytes whose data holds a Layer III header and a JPEG start
def fix.id3() -> List<&2, U32>:
  [73, 68, 51, 3, 0, 0, 0, 0, 0, 12, 255, 251, 20, 196, 255, 216, 255, 224, 0, 1, 2, 3]

# an ID3v2.4 tag with the footer flag: 4 bytes of data, then the 10-byte footer
def fix.id3foot() -> List<&2, U32>:
  [73, 68, 51, 4, 0, 16, 0, 0, 0, 4, 255, 251, 20, 196, 51, 68, 73, 4, 0, 16, 0, 0, 0, 4]

# junk: a Layer II header, an MPEG-2.5 sync as in an APEv2 tag, a JPEG start, ASCII
def fix.junk() -> List<&2, U32>:
  [0, 1, 255, 253, 20, 196, 255, 226, 255, 216, 255, 224, 65, 80, 69]

# the first n bytes
def fx.take(+n: U32, xs: List<&2, U32>) -> List<&2, U32>:
  List.take(&2, U32, xs, U32.to_nat(n))

def fx.cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

# a negative quantized line, as the decoder holds it: two's complement
def ln.neg(+mag: U32) -> U32:
  (0 - mag : U32)

# a granule channel's 576 lines: the first ones, then zeros
def ln.of(xs: List<&2, U32>) -> List<&2, U32>:
  fx.pad(xs, 576)

# what a decode gives: rate, channels and sample count, or nothing for none
def clip.shape(got: Maybe<&2, Au.Clip>) -> List<&2, U32>:
  match got:
    case None{}:
      []
    case Some{+clip}:
      [Au.rate(clip), Au.channels(clip), U32.from_nat(List.length(&2, U32, Au.frames(clip)))]
