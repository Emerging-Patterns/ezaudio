# The proofs: proofs/<name>.bend proves laws/<name>.bend. The gate:
# `bend PROOF.bend` prints exactly `ALL PROOFS CHECK` as its first line.
import Base
import ./LAWS.bend as Laws
import ./proofs/ClipReadsBack.bend as PClipReadsBack
import ./proofs/ConcatNeedsMatchingClips.bend as PConcatNeedsMatchingClips
import ./proofs/CountDividesByChannels.bend as PCountDividesByChannels
import ./proofs/FillRepeatsSample.bend as PFillRepeatsSample
import ./proofs/Mp3DecodeRefusesUnsupported.bend as PMp3DecodeRefusesUnsupported
import ./proofs/Mp3EncodeRefusesBadClips.bend as PMp3EncodeRefusesBadClips
import ./proofs/Mp3FramesFollowHeaders.bend as PMp3FramesFollowHeaders
import ./proofs/Mp3GranulesFitTheirFields.bend as PMp3GranulesFitTheirFields
import ./proofs/Mp3HeaderFieldsRead.bend as PMp3HeaderFieldsRead
import ./proofs/Mp3SamplesAreClamped.bend as PMp3SamplesAreClamped
import ./proofs/Mp3SilenceDecodesToZeros.bend as PMp3SilenceDecodesToZeros
import ./proofs/Mp3SilenceIsHeaderAndZeros.bend as PMp3SilenceIsHeaderAndZeros
import ./proofs/ScaleFactorRowPerRate.bend as PScaleFactorRowPerRate
import ./proofs/SynthesisAddSums.bend as PSynthesisAddSums
import ./proofs/TrimKeepsFrameSpan.bend as PTrimKeepsFrameSpan
import ./proofs/WavChunkIdsAreRiff.bend as PWavChunkIdsAreRiff
import ./proofs/WavDecodesWellFormed.bend as PWavDecodesWellFormed
import ./proofs/WavEncodesPcm.bend as PWavEncodesPcm
import ./proofs/WavReadsOtherWriters.bend as PWavReadsOtherWriters
import ./proofs/WavRefusesBadInput.bend as PWavRefusesBadInput
import ./proofs/WavRoundTrips.bend as PWavRoundTrips
