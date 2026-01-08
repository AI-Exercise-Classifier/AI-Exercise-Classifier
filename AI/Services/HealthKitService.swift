//
//  HealthKitService.swift
//  ExerciseTracker
//
//  Created by Kristian Yousef on 2025-12-13.
//


import Foundation
import HealthKit

final class HealthKitService {
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = []

        try await store.requestAuthorization(toShare: toShare, read: toRead)
    }

    // Later: save workout + metadata
}
