import Foundation

/// On-device symptom database mapping common symptoms to a base severity hint.
///
/// This is intentionally a small, conservative set. The Gemma 3n LLM does the
/// real reasoning at runtime; this catalog only powers the multiple-choice
/// picker UI and a fast first-pass severity floor used by the orchestrator
/// when the model is not yet warmed up.
public enum SymptomCatalog {

    public static let all: [Symptom] = [
        // General
        .init(id: "fever",            displayName: NSLocalizedString("symptom.fever",            value: "Fever",                comment: ""), synonyms: ["temperature", "pyrexia"],         baseSeverity: .urgentCare, body: .general),
        .init(id: "fatigue",          displayName: NSLocalizedString("symptom.fatigue",          value: "Fatigue",              comment: ""), synonyms: ["tired", "exhaustion"],            baseSeverity: .selfCare,   body: .general),
        .init(id: "chills",           displayName: NSLocalizedString("symptom.chills",           value: "Chills",               comment: ""), synonyms: ["shivering"],                       baseSeverity: .selfCare,   body: .general),

        // Head / ENT
        .init(id: "headache",         displayName: NSLocalizedString("symptom.headache",         value: "Headache",             comment: ""), synonyms: ["head pain", "migraine"],          baseSeverity: .selfCare,   body: .head),
        .init(id: "sore_throat",      displayName: NSLocalizedString("symptom.soreThroat",       value: "Sore throat",          comment: ""), synonyms: ["pharyngitis"],                     baseSeverity: .selfCare,   body: .head),
        .init(id: "earache",          displayName: NSLocalizedString("symptom.earache",          value: "Earache",              comment: ""), synonyms: ["ear pain"],                        baseSeverity: .urgentCare, body: .head),
        .init(id: "vision_loss",      displayName: NSLocalizedString("symptom.visionLoss",       value: "Sudden vision loss",   comment: ""), synonyms: ["blurry vision", "blind spot"],    baseSeverity: .emergency,  body: .head),

        // Respiratory
        .init(id: "cough",            displayName: NSLocalizedString("symptom.cough",            value: "Cough",                comment: ""), synonyms: ["coughing"],                        baseSeverity: .selfCare,   body: .respiratory),
        .init(id: "shortness_breath", displayName: NSLocalizedString("symptom.shortBreath",      value: "Shortness of breath",  comment: ""), synonyms: ["dyspnea", "trouble breathing"],   baseSeverity: .emergency,  body: .respiratory),
        .init(id: "wheezing",         displayName: NSLocalizedString("symptom.wheezing",         value: "Wheezing",             comment: ""), synonyms: [],                                  baseSeverity: .urgentCare, body: .respiratory),

        // Cardiovascular
        .init(id: "chest_pain",       displayName: NSLocalizedString("symptom.chestPain",        value: "Chest pain",           comment: ""), synonyms: ["chest pressure"],                  baseSeverity: .emergency,  body: .cardiovascular),
        .init(id: "palpitations",     displayName: NSLocalizedString("symptom.palpitations",     value: "Palpitations",         comment: ""), synonyms: ["fast heartbeat"],                  baseSeverity: .urgentCare, body: .cardiovascular),

        // GI
        .init(id: "nausea",           displayName: NSLocalizedString("symptom.nausea",           value: "Nausea",               comment: ""), synonyms: ["queasy"],                          baseSeverity: .selfCare,   body: .gastrointestinal),
        .init(id: "vomiting",         displayName: NSLocalizedString("symptom.vomiting",         value: "Vomiting",             comment: ""), synonyms: ["throwing up"],                     baseSeverity: .urgentCare, body: .gastrointestinal),
        .init(id: "abdominal_pain",   displayName: NSLocalizedString("symptom.abdominalPain",    value: "Abdominal pain",       comment: ""), synonyms: ["stomach pain", "belly pain"],     baseSeverity: .urgentCare, body: .gastrointestinal),
        .init(id: "diarrhea",         displayName: NSLocalizedString("symptom.diarrhea",         value: "Diarrhea",             comment: ""), synonyms: [],                                  baseSeverity: .selfCare,   body: .gastrointestinal),

        // Musculoskeletal
        .init(id: "back_pain",        displayName: NSLocalizedString("symptom.backPain",         value: "Back pain",            comment: ""), synonyms: [],                                  baseSeverity: .selfCare,   body: .musculoskeletal),
        .init(id: "joint_pain",       displayName: NSLocalizedString("symptom.jointPain",        value: "Joint pain",           comment: ""), synonyms: ["arthralgia"],                      baseSeverity: .selfCare,   body: .musculoskeletal),
        .init(id: "limb_weakness",    displayName: NSLocalizedString("symptom.limbWeakness",     value: "Sudden limb weakness", comment: ""), synonyms: ["arm weakness", "leg weakness"],   baseSeverity: .emergency,  body: .musculoskeletal),

        // Skin
        .init(id: "rash",             displayName: NSLocalizedString("symptom.rash",             value: "Rash",                 comment: ""), synonyms: [],                                  baseSeverity: .selfCare,   body: .skin),
        .init(id: "hives",            displayName: NSLocalizedString("symptom.hives",            value: "Hives",                comment: ""), synonyms: ["urticaria"],                       baseSeverity: .urgentCare, body: .skin),

        // Neurological
        .init(id: "dizziness",        displayName: NSLocalizedString("symptom.dizziness",        value: "Dizziness",            comment: ""), synonyms: ["lightheaded"],                    baseSeverity: .urgentCare, body: .neurological),
        .init(id: "confusion",        displayName: NSLocalizedString("symptom.confusion",        value: "Confusion",            comment: ""), synonyms: ["disoriented"],                    baseSeverity: .emergency,  body: .neurological),
        .init(id: "facial_droop",     displayName: NSLocalizedString("symptom.facialDroop",      value: "Facial droop",         comment: ""), synonyms: ["one-sided face weakness"],         baseSeverity: .emergency,  body: .neurological),
        .init(id: "slurred_speech",   displayName: NSLocalizedString("symptom.slurredSpeech",    value: "Slurred speech",       comment: ""), synonyms: [],                                  baseSeverity: .emergency,  body: .neurological),

        // Mental health
        .init(id: "anxiety",          displayName: NSLocalizedString("symptom.anxiety",          value: "Anxiety",              comment: ""), synonyms: [],                                  baseSeverity: .selfCare,   body: .mentalHealth),
        .init(id: "panic_attack",     displayName: NSLocalizedString("symptom.panic",            value: "Panic attack",         comment: ""), synonyms: [],                                  baseSeverity: .urgentCare, body: .mentalHealth),
    ]

    public static let byBodySystem: [Symptom.BodySystem: [Symptom]] = {
        Dictionary(grouping: all, by: \.body)
    }()

    /// Highest base severity present in the supplied symptom IDs.
    /// Used as a conservative pre-LLM hint so the UI can render an immediate
    /// indicator while the model warms up. Never used as the final answer.
    public static func baseSeverity(for ids: Set<String>) -> Severity {
        let order: [Severity] = [.unknown, .selfCare, .urgentCare, .emergency]
        let idx: (Severity) -> Int = { order.firstIndex(of: $0) ?? 0 }
        var best: Severity = .unknown
        for symptom in all where ids.contains(symptom.id) {
            if idx(symptom.baseSeverity) > idx(best) { best = symptom.baseSeverity }
        }
        return best
    }

    public static func symptom(byId id: String) -> Symptom? {
        all.first(where: { $0.id == id })
    }
}
