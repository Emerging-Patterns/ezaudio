# bolt.bend: how bolt lints this repo. Every group is an error: the gate
# must see `clean`. See bolt/config.bend for the groups and levels.
import Base

# what will fail or blow up
def correctness() -> String:
  "error"

# what is probably a slip
def suspicious() -> String:
  "error"

# comments and whitespace
def style() -> String:
  "error"

# a pure def named by no law
def laws() -> String:
  "error"
