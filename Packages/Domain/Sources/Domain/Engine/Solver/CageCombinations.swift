/// Killer-cage digit arithmetic: which digits can participate in a cage given
/// its remaining sum, remaining cell count, and already-used digits.
enum CageCombinations {
    /// The tightest possible sums for `count` distinct digits drawn from the
    /// `available` mask.
    static func sumBounds(count: Int, available: DigitMask, size: Int) -> (min: Int, max: Int) {
        var ascending: [Int] = []
        for digit in 1 ... size where available & mask(digit) != 0 {
            ascending.append(digit)
        }
        guard ascending.count >= count, count > 0 else {
            return (min: Int.max, max: Int.min)
        }
        let minSum = ascending.prefix(count).reduce(0, +)
        let maxSum = ascending.suffix(count).reduce(0, +)
        return (min: minSum, max: maxSum)
    }

    /// Union of digit masks over every combination of `count` distinct digits
    /// from `available` summing exactly to `sum`. Digits outside the result
    /// can be eliminated from all remaining cells of the cage.
    static func usableDigits(count: Int, sum: Int, available: DigitMask, size: Int) -> DigitMask {
        var digits: [Int] = []
        for digit in 1 ... size where available & mask(digit) != 0 {
            digits.append(digit)
        }
        var union: DigitMask = 0
        var chosen: [Int] = []

        func search(startIndex: Int, remainingCount: Int, remainingSum: Int) {
            if remainingCount == 0 {
                if remainingSum == 0 {
                    for digit in chosen {
                        union |= mask(digit)
                    }
                }
                return
            }
            guard startIndex < digits.count else { return }
            for index in startIndex ..< digits.count {
                let digit = digits[index]
                if digit > remainingSum {
                    break
                }
                chosen.append(digit)
                search(
                    startIndex: index + 1,
                    remainingCount: remainingCount - 1,
                    remainingSum: remainingSum - digit,
                )
                chosen.removeLast()
            }
        }

        search(startIndex: 0, remainingCount: count, remainingSum: sum)
        return union
    }

    private static func mask(_ digit: Int) -> DigitMask {
        DigitMask(1) << DigitMask(digit - 1)
    }
}
