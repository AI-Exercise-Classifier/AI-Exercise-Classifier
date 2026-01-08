#if !os(watchOS)
import Foundation
import CoreML

final class ExerciseClassifierService {
    private let wrapped: AI2_2
    private let model: MLModel

    private var buffer: [MotionSample] = []
    private let windowSize: Int

    // Optional LSTM state
    private var state: MLMultiArray?

    init(windowSize: Int = 200) {
        self.windowSize = windowSize
        self.wrapped = try! AI2_2(configuration: MLModelConfiguration())
        self.model = wrapped.model
        buffer.reserveCapacity(windowSize)

        // Init state if model expects it
        let inputs = model.modelDescription.inputDescriptionsByName
        if let c = inputs["stateIn"]?.multiArrayConstraint {
            self.state = try? MLMultiArray(shape: c.shape, dataType: c.dataType)
            if let s = self.state {
                for i in 0..<s.count { s[i] = 0 }
            }
        }

        // Debug (kolla i loggen att inputs innehåller grx/gry/grz)
        let outputs = model.modelDescription.outputDescriptionsByName
        print("✅ Model inputs:", inputs.keys.sorted())
        print("✅ Model outputs:", outputs.keys.sorted())
    }

    func reset() {
        buffer.removeAll(keepingCapacity: true)
        if let st = state {
            for i in 0..<st.count { st[i] = 0 }
        }
    }

    func append(_ s: MotionSample) {
        buffer.append(s)
        if buffer.count > windowSize {
            buffer.removeFirst(buffer.count - windowSize)
        }
    }

    var isReady: Bool { buffer.count == windowSize }

    func predict() throws -> (label: String, confidence: Double) {
        guard isReady else { throw NSError(domain: "not_ready", code: 0) }

        // 1D arrays per channel
        let ax  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let ay  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let az  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)

        let gx  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let gy  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let gz  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)

        // ✅ gravity (det som saknas hos dig)
        let grx = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let gry = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let grz = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)

        for i in 0..<windowSize {
            let s = buffer[i]
            ax[i]  = NSNumber(value: Float(s.userAcceleration.x))
            ay[i]  = NSNumber(value: Float(s.userAcceleration.y))
            az[i]  = NSNumber(value: Float(s.userAcceleration.z))

            gx[i]  = NSNumber(value: Float(s.rotationRate.x))
            gy[i]  = NSNumber(value: Float(s.rotationRate.y))
            gz[i]  = NSNumber(value: Float(s.rotationRate.z))

            grx[i] = NSNumber(value: Float(s.gravity.x))
            gry[i] = NSNumber(value: Float(s.gravity.y))
            grz[i] = NSNumber(value: Float(s.gravity.z))
        }

        var dict: [String: Any] = [
            "ax": ax, "ay": ay, "az": az,
            "gx": gx, "gy": gy, "gz": gz,
            "grx": grx, "gry": gry, "grz": grz
        ]

        if let st = state {
            dict["stateIn"] = st
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: dict)
        let out = try model.prediction(from: provider)

        // Update stateOut if present
        if let newState = out.featureValue(for: "stateOut")?.multiArrayValue {
            self.state = newState
        }

        // label
        let rawLabel =
            out.featureValue(for: "label")?.stringValue ??
            out.featureValue(for: "classLabel")?.stringValue ??
            out.featureValue(for: "target")?.stringValue ??
            "unknown"

        // probabilities
        let probAny =
            out.featureValue(for: "labelProbability")?.dictionaryValue ??
            out.featureValue(for: "classProbability")?.dictionaryValue

        var probs: [String: Double] = [:]
        if let d = probAny {
            for (k, v) in d {
                let keyStr: String
                if let ks = k as? String { keyStr = ks }
                else if let ks = k as? NSString { keyStr = ks as String }
                else { keyStr = String(describing: k) }

                if let num = v as? NSNumber { probs[keyStr] = num.doubleValue }
                else if let dbl = v as? Double { probs[keyStr] = dbl }
                else if let flt = v as? Float { probs[keyStr] = Double(flt) }
            }
        }

        if let c = probs[rawLabel] { return (rawLabel, c) }
        if let best = probs.max(by: { $0.value < $1.value }) { return (best.key, best.value) }
        return (rawLabel, 0.0)
    }
    func predictTopK(_ k: Int = 5) throws -> (label: String, confidence: Double, top: [(String, Double)]) {
        let (label, confidence, probs) = try predictWithProbs()

        let top = probs
            .sorted(by: { $0.value > $1.value })
            .prefix(k)
            .map { ($0.key, $0.value) }

        return (label, confidence, Array(top))
    }

    // Samma som predict() men returnerar också hela probs-dict
    private func predictWithProbs() throws -> (label: String, confidence: Double, probs: [String: Double]) {
        guard isReady else { throw NSError(domain: "not_ready", code: 0) }

        let ax  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let ay  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let az  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)

        let gx  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let gy  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let gz  = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)

        let grx = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let gry = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)
        let grz = try MLMultiArray(shape: [NSNumber(value: windowSize)], dataType: .float32)

        for i in 0..<windowSize {
            let s = buffer[i]
            ax[i]  = NSNumber(value: Float(s.userAcceleration.x))
            ay[i]  = NSNumber(value: Float(s.userAcceleration.y))
            az[i]  = NSNumber(value: Float(s.userAcceleration.z))
            gx[i]  = NSNumber(value: Float(s.rotationRate.x))
            gy[i]  = NSNumber(value: Float(s.rotationRate.y))
            gz[i]  = NSNumber(value: Float(s.rotationRate.z))
            grx[i] = NSNumber(value: Float(s.gravity.x))
            gry[i] = NSNumber(value: Float(s.gravity.y))
            grz[i] = NSNumber(value: Float(s.gravity.z))
        }

        var dict: [String: Any] = [
            "ax": ax, "ay": ay, "az": az,
            "gx": gx, "gy": gy, "gz": gz,
            "grx": grx, "gry": gry, "grz": grz
        ]
        if let st = state { dict["stateIn"] = st }

        let provider = try MLDictionaryFeatureProvider(dictionary: dict)
        let out = try model.prediction(from: provider)

        if let newState = out.featureValue(for: "stateOut")?.multiArrayValue {
            self.state = newState
        }

        let rawLabel =
            out.featureValue(for: "label")?.stringValue ??
            out.featureValue(for: "classLabel")?.stringValue ??
            out.featureValue(for: "target")?.stringValue ??
            "unknown"

        let probAny =
            out.featureValue(for: "labelProbability")?.dictionaryValue ??
            out.featureValue(for: "classProbability")?.dictionaryValue

        var probs: [String: Double] = [:]
        if let d = probAny {
            for (k, v) in d {
                let keyStr: String
                if let ks = k as? String { keyStr = ks }
                else if let ks = k as? NSString { keyStr = ks as String }
                else { keyStr = String(describing: k) }

                if let num = v as? NSNumber { probs[keyStr] = num.doubleValue }
                else if let dbl = v as? Double { probs[keyStr] = dbl }
                else if let flt = v as? Float { probs[keyStr] = Double(flt) }
            }
        }

        let confidence = probs[rawLabel] ?? probs.max(by: { $0.value < $1.value })?.value ?? 0.0
        let label = probs[rawLabel] != nil ? rawLabel : (probs.max(by: { $0.value < $1.value })?.key ?? rawLabel)

        return (label, confidence, probs)
    }
}
#endif
