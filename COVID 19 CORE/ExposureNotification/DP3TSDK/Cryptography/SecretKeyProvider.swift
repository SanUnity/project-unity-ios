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

protocol SecretKeyProvider: class {
    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)

    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void)
}

private var logger = Logger(.main, category: "SecretKeyProvider")

extension ENManager: SecretKeyProvider {
    func getDiagnosisKeys(onsetDate: Date?, appDesc: ApplicationDescriptor, completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        logger.trace()
        let handler: ENGetDiagnosisKeysHandler = { [weak self] keys, error in
            guard let self = self else { return }
            if let error = error {
                logger.error("ENManager.getDiagnosisKeys error: %{public}@", error.localizedDescription)
                completionHandler(.failure(.exposureNotificationError(error: error)))
            } else if let keys = keys {
                logger.log("received %d keys", keys.count)
                var filteredKeys = keys

                // if a onsetDate was passed we filter the keys using it
                if let onsetDate = onsetDate {
                    filteredKeys = filteredKeys.filter { $0.date > onsetDate }
                }

                var transformedKeys = filteredKeys.map(CodableDiagnosisKey.init(key:))

                // always make sure we fill up the keys to Default.shared.parameters.crypto.numberOfKeysToSubmit
                transformedKeys.append(contentsOf: self.getFakeKeys(count: Default.shared.parameters.crypto.numberOfKeysToSubmit - transformedKeys.count))

                transformedKeys.sort { (lhs, rhs) -> Bool in
                    lhs.rollingStartNumber > rhs.rollingStartNumber
                }

                transformedKeys = Array(transformedKeys.prefix(Default.shared.parameters.crypto.numberOfKeysToSubmit))

                completionHandler(.success(transformedKeys))
            } else {
                fatalError("getDiagnosisKeys returned neither an error nor a keys")
            }
        }

        switch appDesc.mode {
        case .production:
            logger.log("calling ENManager.getDiagnosisKeys")
            getDiagnosisKeys(completionHandler: handler)
        case .test:
            logger.log("calling ENManager.getTestDiagnosisKeys")
            getTestDiagnosisKeys(completionHandler: handler)
        }
    }

    func getFakeDiagnosisKeys(completionHandler: @escaping (Result<[CodableDiagnosisKey], DP3TTracingError>) -> Void) {
        logger.log("getFakeDiagnosisKeys")
        completionHandler(.success(getFakeKeys(count: Default.shared.parameters.crypto.numberOfKeysToSubmit)))
    }

    private func getFakeKeys(count: Int) -> [CodableDiagnosisKey] {
        guard count > 0 else { return [] }
        var keys: [CodableDiagnosisKey] = []
        let parameters = Default.shared.parameters
        for i in 0 ..< count {
            let day = DayDate(date: Date().addingTimeInterval(.day * Double(i) * (-1)))
            let rollingPeriod = UInt32(TimeInterval.day / (.minute * 10))
            let key = (try? Crypto.generateRandomKey(lenght: parameters.crypto.keyLength)) ?? Data(count: parameters.crypto.keyLength)
            keys.append(.init(keyData: key,
                              rollingPeriod: rollingPeriod,
                              rollingStartNumber: day.period,
                              transmissionRiskLevel: .zero,
                              fake: 1))
        }
        return keys
    }
}

extension CodableDiagnosisKey {
    init(key: ENTemporaryExposureKey) {
        keyData = key.keyData
        rollingPeriod = key.rollingPeriod
        rollingStartNumber = key.rollingStartNumber
        transmissionRiskLevel = key.transmissionRiskLevel
        fake = 0
    }
}

extension ENTemporaryExposureKey {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(rollingStartNumber) * TimeInterval.minute * 10)
    }
}
