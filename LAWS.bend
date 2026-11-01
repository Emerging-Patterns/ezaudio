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
# Every law is still a closed equality on one fixture: it checks one input,
# not every input. Full codec conformance is not claimed.
import Base
import ./laws/ClipReadsBack.bend as ClipReadsBack
import ./laws/ConcatNeedsMatchingClips.bend as ConcatNeedsMatchingClips
import ./laws/CountDividesByChannels.bend as CountDividesByChannels
import ./laws/EncoderNthReadsIndex.bend as EncoderNthReadsIndex
import ./laws/FillRepeatsSample.bend as FillRepeatsSample
import ./laws/Mp3DecodeRefusesUnsupported.bend as Mp3DecodeRefusesUnsupported
import ./laws/Mp3EncodeRefusesBadClips.bend as Mp3EncodeRefusesBadClips
import ./laws/Mp3HeaderFieldsRead.bend as Mp3HeaderFieldsRead
import ./laws/Mp3OneSampleIsHuffmanPair.bend as Mp3OneSampleIsHuffmanPair
import ./laws/Mp3SilenceDecodesToZeros.bend as Mp3SilenceDecodesToZeros
import ./laws/Mp3SilenceIsHeaderAndZeros.bend as Mp3SilenceIsHeaderAndZeros
import ./laws/ScaleFactorRowPerRate.bend as ScaleFactorRowPerRate
import ./laws/SynthesisAddSums.bend as SynthesisAddSums
import ./laws/TrimKeepsFrameSpan.bend as TrimKeepsFrameSpan
import ./laws/WavChunkIdsAreRiff.bend as WavChunkIdsAreRiff
import ./laws/WavEncodesPcm.bend as WavEncodesPcm
import ./laws/WavRefusesBadInput.bend as WavRefusesBadInput
import ./laws/WavRoundTrips.bend as WavRoundTrips
