import Foundation

/// Shapes model output for on-screen display (e.g. when JSON ends up in a text field by mistake).
public enum TriageDisplayFormatting {
    /// Collapses repeated sentences/lines the model sometimes emits twice with different wording.
    public static func compactRepeatedProse(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let paras = trimmed.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var blocks: [String] = []
        for para in paras {
            let s = Self.dedupePeriodSeparated(para)
            if let last = blocks.last, last.caseInsensitiveCompare(s) == .orderedSame { continue }
            blocks.append(s)
        }
        return blocks.joined(separator: "\n\n")
    }

    private static func dedupePeriodSeparated(_ para: String) -> String {
        let chunks = para.components(separatedBy: ". ")
        var out: [String] = []
        var prevKey: String?
        for c in chunks {
            let t = c.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            let key = t.lowercased()
            if key == prevKey { continue }
            out.append(t)
            prevKey = key
        }
        return out.joined(separator: ". ")
    }

    public static func summaryForDisplay(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = raw.data(using: .utf8) else { return raw }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return raw }
        if let s = obj["summary"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return s
        }
        return raw
    }
}
