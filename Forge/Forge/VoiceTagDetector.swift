//
//  VoiceTagDetector.swift
//  Forge
//
//  Phase 2, Feature 10: Parses voice-triggered tags from a transcript.
//  Feature 11: Correlates detected photo tags to PhotoCapture objects by
//              sequential timestamp order.
//
//  Recognised trigger phrases (case-insensitive): "photo:", "measurement:", "note:"
//

import Foundation

enum VoiceTagDetector {

    // MARK: - Types

    struct Tag {
        /// Keyword without the colon: "photo", "measurement", or "note".
        let keyword: String
        /// Text following the keyword, up to the next trigger phrase or end of transcript.
        let content: String
        /// Fractional position in the transcript (0.0 = start, 1.0 = end).
        let normalizedOffset: Double
    }

    // MARK: - Detection

    private static let keywords = ["photo", "measurement", "note"]

    /// Scans a transcript for "photo:", "measurement:", and "note:" trigger phrases.
    /// Returns all found tags sorted by their position in the transcript.
    static func detect(in transcript: String) -> [Tag] {
        guard !transcript.isEmpty else { return [] }

        var tags: [Tag] = []
        let lower = transcript.lowercased()
        let totalLength = max(lower.count, 1)

        for keyword in keywords {
            let marker = "\(keyword):"
            var searchStart = lower.startIndex

            while let markerRange = lower.range(of: marker, range: searchStart..<lower.endIndex) {
                let contentStart = markerRange.upperBound

                // Content ends at the next keyword marker or end of string.
                var contentEnd = lower.endIndex
                for other in keywords {
                    let otherMarker = "\(other):"
                    if let nextRange = lower.range(of: otherMarker, range: contentStart..<lower.endIndex),
                       nextRange.lowerBound < contentEnd {
                        contentEnd = nextRange.lowerBound
                    }
                }

                let rawContent = String(transcript[contentStart..<contentEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let offset = Double(lower.distance(from: lower.startIndex, to: markerRange.lowerBound))
                    / Double(totalLength)

                if !rawContent.isEmpty {
                    tags.append(Tag(keyword: keyword, content: rawContent, normalizedOffset: offset))
                }

                searchStart = contentEnd
            }
        }

        return tags.sorted { $0.normalizedOffset < $1.normalizedOffset }
    }

    // MARK: - Correlation

    /// Assigns `voiceTag` labels to `PhotoCapture` objects by sequential matching:
    /// the i-th "photo:" tag (by transcript order) is assigned to the i-th photo
    /// by ascending recording timestamp. Non-photo tags are not correlated to photos.
    static func correlate(transcript: String, photos: [PhotoCapture]) {
        guard !photos.isEmpty else { return }

        let tags = detect(in: transcript)
        let photoTags = tags.filter { $0.keyword == "photo" }
        guard !photoTags.isEmpty else { return }

        let sortedPhotos = photos.sorted { $0.timestamp < $1.timestamp }

        for (index, photo) in sortedPhotos.enumerated() where index < photoTags.count {
            photo.voiceTag = photoTags[index].content
        }
    }
}
