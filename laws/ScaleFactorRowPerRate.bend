# ISO/IEC 11172-3 Table B.8: the decoder's long-block scale-factor bands at
# each sampling frequency are these 22 widths, in lines, summing to 576. The
# decoder places its Huffman region boundaries on them.
import Base
import ../src/mp3_dec.bend as Dec

# LAW: ISO/IEC 11172-3 Table B.8 — the long-block band widths at 44100 Hz
law scf_44100:
  {Dec.scf.row(44100) == [4, 4, 4, 4, 4, 4, 6, 6, 8, 8, 10, 12, 16, 20, 24, 28, 34, 42, 50, 54, 76, 158]
    : List<&2, U32>}

# LAW: ISO/IEC 11172-3 Table B.8 — the long-block band widths at 48000 Hz
law scf_48000:
  {Dec.scf.row(48000) == [4, 4, 4, 4, 4, 4, 6, 6, 6, 8, 10, 12, 16, 18, 22, 28, 34, 40, 46, 54, 54, 192]
    : List<&2, U32>}

# LAW: ISO/IEC 11172-3 Table B.8 — the long-block band widths at 32000 Hz
law scf_32000:
  {Dec.scf.row(32000) == [4, 4, 4, 4, 4, 4, 6, 6, 8, 10, 12, 16, 20, 24, 30, 38, 46, 56, 68, 84, 102, 26]
    : List<&2, U32>}
