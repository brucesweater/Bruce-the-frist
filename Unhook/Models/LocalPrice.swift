import Foundation

/// Turns the US-dollar cost written into each habit preset into a sensible starting amount in the user's
/// currency, so a Japanese user sees about ¥1,500 a day rather than "¥10". These are rough, fixed rates for
/// suggestions only; the user edits the amount, and nothing is ever charged.
enum LocalPrice {
    private static let unitsPerUSD: [String: Double] = [
        "USD": 1, "EUR": 0.92, "GBP": 0.79, "CHF": 0.88, "CAD": 1.37, "AUD": 1.52, "NZD": 1.66,
        "JPY": 150, "KRW": 1_350, "CNY": 7.2, "HKD": 7.8, "TWD": 32, "SGD": 1.35, "INR": 83,
        "IDR": 15_700, "THB": 36, "VND": 25_000, "PHP": 56, "MYR": 4.7, "PKR": 280, "BDT": 110,
        "BRL": 5, "MXN": 17, "CLP": 940, "COP": 3_900, "PEN": 3.7, "ZAR": 18.5, "NGN": 1_500, "EGP": 48,
        "KES": 130, "TRY": 32, "RUB": 92, "UAH": 40, "PLN": 4, "CZK": 23, "HUF": 360, "RON": 4.6,
        "SEK": 10.5, "NOK": 10.7, "DKK": 6.9, "ILS": 3.7, "AED": 3.67, "SAR": 3.75, "QAR": 3.64,
    ]

    /// A suggested local amount for `usd`, rounded to two significant digits; 0 (left blank) when the
    /// currency is unknown, because a number in the wrong magnitude is worse than an empty field.
    static func suggested(fromUSD usd: Double, currencyCode: String) -> Double {
        guard usd.isFinite, usd > 0, let rate = unitsPerUSD[currencyCode.uppercased()] else { return 0 }
        // Currencies close to the dollar keep the preset's round numbers.
        let effectiveRate = (0.7...1.7).contains(rate) ? 1 : rate
        return roundedToTwoSignificantDigits(usd * effectiveRate)
    }

    static func roundedToTwoSignificantDigits(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        let exponent = Int(floor(log10(value))) - 1
        if exponent >= 0 {
            let scale = pow(10, Double(exponent))
            return (value / scale).rounded() * scale
        }
        // Divide by the power of ten (not multiply by its inverse) so results print cleanly, like 2.8.
        let scale = pow(10, Double(-exponent))
        return (value * scale).rounded() / scale
    }
}
