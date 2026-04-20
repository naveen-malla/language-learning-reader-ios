import Foundation

enum SubtitleCueTimeline {
    private static let compatibilityTolerance = 0.05

    static func activeIndex(for cues: [TimedSubtitleCue], at time: Double) -> Int? {
        guard !cues.isEmpty else { return nil }

        let clampedTime = max(0, time)
        if clampedTime <= cues[0].startTime {
            return 0
        }

        for index in cues.indices {
            let cue = cues[index]
            if clampedTime < cue.startTime {
                return max(index - 1, 0)
            }

            let nextCueStart = cues.indices.contains(index + 1) ? cues[index + 1].startTime : nil
            if let nextCueStart {
                if clampedTime < nextCueStart {
                    return index
                }
                continue
            }

            return index
        }

        return cues.count - 1
    }

    static func compatibleTranslatedCues(
        from cachedCues: [TranslatedSubtitleCue]?,
        with sourceCues: [TimedSubtitleCue]
    ) -> [TranslatedSubtitleCue]? {
        guard let cachedCues, cachedCues.count == sourceCues.count else {
            return nil
        }

        let isCompatible = zip(sourceCues, cachedCues).allSatisfy { sourceCue, cachedCue in
            abs(sourceCue.startTime - cachedCue.startTime) <= compatibilityTolerance
                && abs(sourceCue.duration - cachedCue.duration) <= compatibilityTolerance
        }

        return isCompatible ? cachedCues : nil
    }
}
