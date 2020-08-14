/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import ExposureNotification
import Foundation
import ZIPFoundation

class ExposureNotificationMatcher: Matcher {
    weak var timingManager: ExposureDetectionTimingManager?

    weak var delegate: MatcherDelegate?

    private let manager: ENManager

    private let exposureDayStorage: ExposureDayStorage

    private let logger = Logger(ExposureNotificationMatcher.self, category: "matcher")

    private var localURLs: [Date: [URL]] = [:]

    private let defaults: DefaultStorage

    private let configuration: ENExposureConfiguration?
    
    private let factorLow: Double?

    private let factorHigh: Double?

    private let triggerThreshold: Int?


    let synchronousQueue = DispatchQueue(label: "org.dpppt.matcher")

    init(manager: ENManager, exposureDayStorage: ExposureDayStorage, defaults: DefaultStorage = Default.shared, configuration: ENExposureConfiguration? = nil, factorLow: Double? = nil, factorHigh: Double? = nil, triggerThreshold: Int? = nil) {
        self.manager = manager
        self.exposureDayStorage = exposureDayStorage
        self.defaults = defaults
        self.configuration = configuration
        self.factorLow = factorLow
        self.factorHigh = factorHigh
        self.triggerThreshold = triggerThreshold
    }

    func receivedNewKnownCaseData(_ data: Data, keyDate: Date) throws {
        logger.trace()

        if let archive = Archive(data: data, accessMode: .read) {
            logger.debug("unarchived archive")
            for entry in archive {
                let localURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                    .appendingPathComponent(UUID().uuidString).appendingPathComponent(entry.path)

                _ = try archive.extract(entry, to: localURL)

                synchronousQueue.sync {
                    self.logger.debug("found %@ item in archive", entry.path)
                    self.localURLs[keyDate, default: []].append(localURL)
                }
            }
        }
    }

    func finalizeMatchingSession(now: Date = .init()) throws {
        logger.trace()
        try synchronousQueue.sync {
            guard localURLs.isEmpty == false else {
                self.logger.log("finalizeMatchingSession with no data returning early")
                return
            }

            self.logger.log("finalizeMatchingSession processing %{public}d urls", localURLs.count)

            let configuration: ENExposureConfiguration = self.configuration ?? .configuration()

            for (day, urls) in localURLs {
                let semaphore = DispatchSemaphore(value: 0)
                var exposureSummary: ENExposureDetectionSummary?
                var exposureDetectionError: Error?

                logger.log("calling detectExposures for day %{public}@ and description: %{public}@", day.description, configuration.stringVal)
                manager.detectExposures(configuration: configuration, diagnosisKeyURLs: urls) { summary, error in
                    exposureSummary = summary
                    exposureDetectionError = error
                    semaphore.signal()
                }
                semaphore.wait()

                if let error = exposureDetectionError {
                    logger.error("ENManager.detectExposures failed error: %{public}@", error.localizedDescription)
                    throw error
                }

                timingManager?.addDetection(timestamp: now)

                try urls.forEach(deleteDiagnosisKeyFile(at:))

                if let summary = exposureSummary {
                    let fl = self.factorLow ?? defaults.parameters.contactMatching.factorLow
                    let fh = self.factorHigh ?? defaults.parameters.contactMatching.factorHigh
                    let tt = self.triggerThreshold ?? defaults.parameters.contactMatching.triggerThreshold

                    let computedThreshold: Double = (Double(truncating: summary.attenuationDurations[0]) * fl + Double(truncating: summary.attenuationDurations[1]) * fh) / TimeInterval.minute

                    logger.log("reiceived exposureSummary for day %{public}@ : %{public}@ computed threshold: %{public}.2f (low:%{public}.2f, high: %{public}.2f) required %{public}d",
                               day.description, summary.debugDescription, computedThreshold, fl, fh, tt)

                    if computedThreshold >= Double(defaults.parameters.contactMatching.triggerThreshold) {
                        logger.log("exposureSummary meets requiremnts")
                        let day: ExposureDay = ExposureDay(identifier: UUID(), exposedDate: day, reportDate: Date(), isDeleted: false)
                        exposureDayStorage.add(day)
                        delegate?.didFindMatch()
                    } else {
                        logger.log("exposureSummary does not meet requirements")
                    }
                }
            }
            localURLs.removeAll()
        }
    }

    func deleteDiagnosisKeyFile(at localURL: URL) throws {
        logger.trace()
        try FileManager.default.removeItem(at: localURL)
    }
}

extension ENExposureConfiguration {
    static var thresholdsKey: String = "attenuationDurationThresholds"

    static func configuration(parameters: DP3TParameters = Default.shared.parameters) -> ENExposureConfiguration {
        let configuration = ENExposureConfiguration()
        configuration.minimumRiskScore =                    1
        configuration.attenuationLevelValues =              [0, 1, 3, 5, 6, 7, 8, 8]
        configuration.daysSinceLastExposureLevelValues =    [0, 0, 2, 4, 5, 6, 7, 8]
        configuration.durationLevelValues =                 [0, 0, 1, 2, 4, 6, 7, 8]
        configuration.transmissionRiskLevelValues =         [0, 1, 2, 3, 5, 6, 7, 8]
        configuration.metadata = [Self.thresholdsKey: [
                parameters.contactMatching.lowerThreshold, // 50
                parameters.contactMatching.higherThreshold // 55
            ]
        ]
        return configuration
    }

    var stringVal: String {
        if let thresholds = metadata?[Self.thresholdsKey] as? [Int] {
            return "<ENExposureConfiguration attenuationDurationThresholds: [\(thresholds[0]),\(thresholds[1])]>"
        }
        return "<ENExposureConfiguration attenuationDurationThresholds: nil>"
    }
}
