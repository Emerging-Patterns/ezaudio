# byte and sample lists: an encoder's bytes, zeros, and a zero-padded frame
import Base

def bytes.of(got: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match got:
    case None{}:
      []
    case Some{xs}:
      xs

def pcm.z(+n: U32) -> List<&2, U32>:
  List.replicate(U32, U32.to_nat(n), 0)

# header, then zeros out to the frame length
def frame.z(head: List<&2, U32>, +n: U32) -> List<&2, U32>:
  List.append(&2, U32, head, List.replicate(U32, U32.to_nat((n - 4 : U32)), 0))
