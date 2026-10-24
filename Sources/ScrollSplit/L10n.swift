import Foundation

private let isKorean = Locale.preferredLanguages.first?.hasPrefix("ko") ?? false

/// Tiny two-language helper: English by default, Korean when the system language is Korean.
func L(_ en: String, _ ko: String) -> String { isKorean ? ko : en }
