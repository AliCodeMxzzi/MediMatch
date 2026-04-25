import Foundation

/// Shapes model output for on-screen display (e.g. when JSON ends up in a text field by mistake).
public enum TriageDisplayFormatting {
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
