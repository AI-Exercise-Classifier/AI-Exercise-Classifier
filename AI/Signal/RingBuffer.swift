//
//  RingBuffer.swift
//  ExerciseTracker
//
//  Created by Kristian Yousef on 2025-12-13.
//


import Foundation

/// Simple fixed-capacity ring buffer.
/// Keeps the most recent `capacity` items.
struct RingBuffer<T> {
    private(set) var capacity: Int
    private var storage: [T] = []

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage.reserveCapacity(self.capacity)
    }

    mutating func append(_ item: T) {
        if storage.count < capacity {
            storage.append(item)
        } else {
            // Drop oldest
            storage.removeFirst()
            storage.append(item)
        }
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
    }

    var count: Int { storage.count }

    /// Returns items oldest -> newest.
    var values: [T] { storage }
}
