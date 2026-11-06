# ezaudio's laws. Each guarantee is one file under laws/, its prose on top
# and its laws under it, proved by the file of the same name under proofs/;
# LAWS.bend and PROOF.bend only import them. The gate: the first line
# `bend PROOF.bend` prints is exactly `ALL PROOFS CHECK`.
#
# There are three families: the clip in main.bend (its fields, count, fill,
# trim and concat), the IBM/Microsoft RIFF WAVE form (encode_wav,
# decode_wav), and ISO/IEC 11172-3 MPEG-1 Layer III (encode_mp3,
# decode_mp3). A clip is a sample rate, a channel count, a sample format and
# interleaved frames.
#
# Most laws are closed equalities on one fixture: they check one input. The
# quantified ones hold for every input: decoded WAV clips are well formed
# (WavDecodesWellFormed), partial frames do not encode and bytes after the
# data chunk change nothing (WavRefusesBadInput, WavReadsOtherWriters),
# fill and trim count samples without wrapping (FillRepeatsSample,
# TrimKeepsFrameSpan), encode_mp3 encodes exactly the clips it can
# (Mp3EncodeRefusesBadClips), its stream is whole frames with their headers
# and lengths (Mp3FramesFollowHeaders), its granules' part2_3_length and
# big_values agree with their bits (Mp3GranulesFitTheirFields), its binary32
# samples are clamped (Mp3SamplesAreClamped), decoded MP3 clips are whole
# Layer III frames (Mp3DecodesWholeFrames), and an MP3 decode depends on the
# bytes only through the frames found in them (Mp3DecodeReadsFrames). Full
# codec conformance is not claimed.
import Base
import ./laws/ClipReadsBack.bend as ClipReadsBack
import ./laws/ConcatNeedsMatchingClips.bend as ConcatNeedsMatchingClips
import ./laws/CountDividesByChannels.bend as CountDividesByChannels
import ./laws/FillRepeatsSample.bend as FillRepeatsSample
import ./laws/Mp3Count1Decoded.bend as Mp3Count1Decoded
import ./laws/Mp3CrcFramesDecode.bend as Mp3CrcFramesDecode
import ./laws/Mp3DecodeReadsFrames.bend as Mp3DecodeReadsFrames
import ./laws/Mp3DecodeRefusesUnsupported.bend as Mp3DecodeRefusesUnsupported
import ./laws/Mp3DecodesWholeFrames.bend as Mp3DecodesWholeFrames
import ./laws/Mp3EncodeRefusesBadClips.bend as Mp3EncodeRefusesBadClips
import ./laws/Mp3FramesFollowHeaders.bend as Mp3FramesFollowHeaders
import ./laws/Mp3GranulesFitTheirFields.bend as Mp3GranulesFitTheirFields
import ./laws/Mp3HeaderFieldsRead.bend as Mp3HeaderFieldsRead
import ./laws/Mp3HuffmanStaysInFrame.bend as Mp3HuffmanStaysInFrame
import ./laws/Mp3SamplesAreClamped.bend as Mp3SamplesAreClamped
import ./laws/Mp3SilenceDecodesToZeros.bend as Mp3SilenceDecodesToZeros
import ./laws/Mp3SilenceIsHeaderAndZeros.bend as Mp3SilenceIsHeaderAndZeros
import ./laws/ScaleFactorRowPerRate.bend as ScaleFactorRowPerRate
import ./laws/SynthesisAddSums.bend as SynthesisAddSums
import ./laws/TrimKeepsFrameSpan.bend as TrimKeepsFrameSpan
import ./laws/WavChunkIdsAreRiff.bend as WavChunkIdsAreRiff
import ./laws/WavDecodesWellFormed.bend as WavDecodesWellFormed
import ./laws/WavEncodesPcm.bend as WavEncodesPcm
import ./laws/WavReadsOtherWriters.bend as WavReadsOtherWriters
import ./laws/WavRefusesBadInput.bend as WavRefusesBadInput
import ./laws/WavRoundTrips.bend as WavRoundTrips
