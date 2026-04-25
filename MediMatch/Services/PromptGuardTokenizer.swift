import Foundation

/// Minimal, dependency-free tokenizer for the `llama_prompt_guard` classifier.
///
/// Real Llama models use SentencePiece (32k vocab). The Zetic Melange dashboard
/// exposes the deployed model's input spec; if that spec expects pre-tokenized
/// SentencePiece IDs, swap this implementation for the bundled vocab from the
/// dashboard. Until then we use a deterministic byte-level fallback that:
///
/// 1. Produces a fixed-length sequence of `Int32` IDs.
/// 2. Maps each UTF-8 byte to an ID in [3, 258] so 0/1/2 stay reserved for
///    PAD / BOS / EOS markers (common Llama convention).
/// 3. Pads or truncates to `Self.sequenceLength`.
///
/// This is good enough to exercise the SDK end-to-end. The orchestrator
/// always combines the model's verdict with the heuristic filter, so even if
/// the classifier returns noise, the user is still protected.
public struct PromptGuardTokenizer: Sendable {
    public static let sequenceLength: Int = 128
    public static let padId: Int32 = 0
    public static let bosId: Int32 = 1
    public static let eosId: Int32 = 2

    public init() {}

    /// Encodes `text` into `(inputIds, attentionMask)`, both of length
    /// `Self.sequenceLength`.
    public func encode(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        var ids: [Int32] = [Self.bosId]
        for byte in text.utf8 {
            ids.append(Int32(byte) + 3)
            if ids.count >= Self.sequenceLength - 1 { break }
        }
        ids.append(Self.eosId)

        var mask = Array(repeating: Int32(1), count: ids.count)
        if ids.count < Self.sequenceLength {
            let padCount = Self.sequenceLength - ids.count
            ids.append(contentsOf: Array(repeating: Self.padId, count: padCount))
            mask.append(contentsOf: Array(repeating: Int32(0), count: padCount))
        } else if ids.count > Self.sequenceLength {
            ids = Array(ids.prefix(Self.sequenceLength))
            mask = Array(mask.prefix(Self.sequenceLength))
        }
        return (ids, mask)
    }
}
