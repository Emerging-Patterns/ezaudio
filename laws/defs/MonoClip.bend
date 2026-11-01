# a two-frame signed-16 mono clip at 8000 Hz
import Base
import ../../main.bend as Au

# two s16 frames at 8000 Hz
def fix.mono() -> Au.Clip:
  Au.clip(8000, 1, Au.s16(), [0, 1])
