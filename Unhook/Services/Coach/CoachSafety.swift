import Foundation

/// Crisis detection. Checked before any coach (scripted or model) sees a message, so a person in danger
/// always gets the same caring answer and a way to reach real help. Never paywalled.
enum CoachSafety {
    /// Free directory of crisis lines in most countries.
    static let helplineURL = URL(string: "https://findahelpline.com")

    /// Phrases, already normalized (see `CoachText.normalize`), that mean the user may be in danger.
    /// Matched as whole words, so "I want to diet" or "this craving is killing me" don't trigger it.
    static let crisisPhrases: [String] = [
        "suicide", "suicidal", "kill myself", "killing myself", "killed myself",
        "end my life", "ending my life", "end it all", "take my own life", "taking my own life",
        "want to die", "wanna die", "want to be dead", "wish i was dead", "wish i were dead", "better off dead",
        "dont want to live", "dont want to be alive", "dont want to be here anymore", "do not want to live",
        "no reason to live", "nothing to live for", "not worth living", "no point in living", "no point living",
        "dont want to wake up", "rather be dead", "hang myself", "hanging myself", "shoot myself",
        "self harm", "selfharm", "hurt myself", "hurting myself", "harm myself", "harming myself",
        "cut myself", "cutting myself", "overdose", "overdosed", "overdosing", "unalive",
        "im in danger", "i am in danger", "in immediate danger",
    ]

    /// Crisis phrases in the other languages Unhook ships in. Checked as plain substrings of the case- and
    /// accent-folded message, because Chinese, Japanese and Thai don't separate words with spaces. Kept short
    /// and specific, and erring toward showing help: a false alarm costs a helpline banner, a miss costs far more.
    static let multilingualCrisisPhrases: [String] = [
        // Spanish
        "quiero morir", "suicid", "matarme", "no quiero vivir", "quitarme la vida", "acabar con mi vida", "hacerme dano",
        // Portuguese
        "quero morrer", "me matar", "nao quero viver", "tirar minha vida", "acabar com minha vida", "me machucar",
        // French
        "je veux mourir", "me tuer", "en finir avec la vie", "plus envie de vivre", "me faire du mal",
        // German
        "ich will sterben", "selbstmord", "mich umbringen", "nicht mehr leben", "mir das leben nehmen", "mir wehtun",
        // Italian
        "voglio morire", "uccidermi", "non voglio piu vivere", "farla finita", "farmi del male",
        // Dutch
        "ik wil dood", "zelfmoord", "mezelf van kant maken", "mezelf iets aandoen",
        // Russian
        "хочу умереть", "покончить с собой", "суицид", "самоубийств", "убить себя", "не хочу жить", "причинить себе вред",
        // Turkish
        "olmek istiyorum", "intihar", "kendimi oldur", "yasamak istemiyorum", "canima kiy", "kendime zarar",
        // Arabic
        "أريد أن أموت", "انتحار", "أقتل نفسي", "لا أريد أن أعيش", "أنهي حياتي", "أؤذي نفسي",
        // Hindi
        "मरना चाहत", "आत्महत्या", "खुद को मार", "जीना नहीं चाहत", "खुद को नुकसान",
        // Indonesian
        "ingin mati", "mau mati", "bunuh diri", "mengakhiri hidup", "tidak ingin hidup", "menyakiti diri",
        // Japanese
        "死にたい", "自殺", "消えたい", "生きていたくない", "自分を傷つけ", "命を絶",
        // Korean
        "죽고 싶", "죽고싶", "자살", "살고 싶지 않", "목숨을 끊", "자해",
        // Chinese (Simplified and Traditional)
        "想死", "自杀", "不想活", "结束生命", "伤害自己", "轻生", "結束生命", "傷害自己", "輕生",
    ]

    static func isCrisis(_ text: String) -> Bool {
        if CoachText.matchesAny(CoachText.normalize(text), crisisPhrases) {
            return true
        }
        let folded = CoachText.fold(text)
        return multilingualCrisisPhrases.contains { folded.contains(CoachText.fold($0)) }
    }

    /// The fixed, supportive reply to a crisis message.
    static var crisisResponse: CoachReply {
        CoachReply(
            intent: .crisis,
            opener: String(localized: "I'm really sorry you're feeling this way, and I'm glad you told me. You deserve support from a real person right now."),
            action: String(localized: "Please call your local emergency number or a crisis line. findahelpline.com lists free, confidential helplines in your country.")
        )
    }

    static var crisisReply: String { crisisResponse.text }
}

/// Text helpers shared by intent and crisis detection.
enum CoachText {
    /// Lowercased words separated by single spaces, padded with a space on each side so whole-word matching is a
    /// plain `contains`. Apostrophes are dropped ("don't" → "dont") and everything else that isn't a letter or digit
    /// (punctuation, emoji) becomes a space.
    static func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.lowercased().unicodeScalars {
            if scalar == "'" || scalar == "\u{2019}" || scalar == "\u{2018}" || scalar == "`" {
                continue
            }
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
            } else {
                scalars.append(" ")
            }
        }
        let words = String(scalars).split(separator: " ")
        return " " + words.joined(separator: " ") + " "
    }

    /// Whether `normalized` contains `keyword` as whole words. A trailing `*` matches any word ending
    /// ("stress*" matches "stressed" and "stressful").
    static func matches(_ normalized: String, keyword: String) -> Bool {
        if keyword.hasSuffix("*") {
            return normalized.contains(" " + String(keyword.dropLast()))
        }
        return normalized.contains(" " + keyword + " ")
    }

    static func matchesAny(_ normalized: String, _ keywords: [String]) -> Bool {
        keywords.contains { matches(normalized, keyword: $0) }
    }

    /// Lowercased with accents removed ("Não" → "nao", "Ölmek" → "olmek"), for substring matching in any language.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
