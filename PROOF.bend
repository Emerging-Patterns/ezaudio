# The proofs: proofs/<name>.bend proves laws/<name>.bend. The gate:
# `bend PROOF.bend` prints exactly `ALL PROOFS CHECK` as its first line.
import Base
import ./LAWS.bend as Laws
import ./proofs/ClipReadsBack.bend as PClipReadsBack
import ./proofs/ConcatNeedsMatchingClips.bend as PConcatNeedsMatchingClips
import ./proofs/CountDividesByChannels.bend as PCountDividesByChannels
import ./proofs/FillRepeatsSample.bend as PFillRepeatsSample
import ./proofs/Mp3DecodeReadsFrames.bend as PMp3DecodeReadsFrames
import ./proofs/Mp3DecodesWholeFrames.bend as PMp3DecodesWholeFrames
import ./proofs/Mp3EncodeRefusesBadClips.bend as PMp3EncodeRefusesBadClips
import ./proofs/Mp3FramesFollowHeaders.bend as PMp3FramesFollowHeaders
import ./proofs/Mp3GranulesFitTheirFields.bend as PMp3GranulesFitTheirFields
import ./proofs/Mp3HeaderFieldsRead.bend as PMp3HeaderFieldsRead
import ./proofs/Mp3SamplesAreClamped.bend as PMp3SamplesAreClamped
import ./proofs/TrimKeepsFrameSpan.bend as PTrimKeepsFrameSpan
import ./proofs/WavChunkIdsAreRiff.bend as PWavChunkIdsAreRiff
import ./proofs/WavDecodesWellFormed.bend as PWavDecodesWellFormed
import ./proofs/WavReadsOtherWriters.bend as PWavReadsOtherWriters
import ./proofs/WavRefusesBadInput.bend as PWavRefusesBadInput
