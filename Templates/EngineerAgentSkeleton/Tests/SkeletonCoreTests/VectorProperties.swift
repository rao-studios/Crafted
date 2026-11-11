import Foundation

/// The properties a vector may hold its result to, each checked against the result and, where it says so, more calls.
enum VectorProperties {
    typealias Call = (_ function: String?, _ args: [String: VectorJSON]) throws -> VectorJSON

    static func verdict(_ property: VectorProperty, result: VectorJSON, args: [String: VectorJSON], tolerance: Double,
                        call: Call) throws -> String? {
        let value = result.at(property.path)
        switch property.kind {
        case "equals", "approx":
            guard let expected = property.value else { return "\(property.kind) needs a value" }
            let within = property.kind == "approx" ? max(tolerance, 1e-6) : tolerance
            return value.map { $0.matches(expected, tolerance: within) } == true ? nil : "expected \(expected), got \(value?.description ?? "nothing")"
        case "deterministic":
            let again = try call(nil, args)
            return again == result ? nil : "two calls gave \(result) and \(again)"
        case "roundTrip":
            guard let via = property.via, let into = property.into, let back = property.back, let original = args[back] else {
                return "roundTrip needs via, into and back"
            }
            var next = args
            if case .object(let extra)? = property.value {
                for (key, json) in extra { next[key] = json }
            }
            next[into] = result
            let returned = try call(via, next)
            return returned.matches(original, tolerance: max(tolerance, 1e-6)) ? nil : "\(via) brought \(original) back as \(returned)"
        case "monotonic":
            guard let argument = property.argument, let values = property.values, values.count >= 2 else {
                return "monotonic needs an argument and two values or more"
            }
            var outputs: [Double] = []
            for input in values {
                var next = args
                next[argument] = input
                guard let number = try call(nil, next).at(property.path)?.number else { return "monotonic needs a number at \(property.path ?? "the result")" }
                outputs.append(number)
            }
            let decreasing = property.direction == "decreasing"
            let ordered = zip(outputs, outputs.dropFirst()).allSatisfy { decreasing ? $0 >= $1 : $0 <= $1 }
            return ordered ? nil : "not \(decreasing ? "decreasing" : "increasing") in \(argument): \(outputs)"
        case "sumsTo":
            guard let target = property.value?.number, let items = value?.array else { return "sumsTo needs a value and a list" }
            let sum = items.compactMap(\.number).reduce(0, +)
            return abs(sum - target) <= max(tolerance, 1e-6) ? nil : "the items sum to \(sum), not \(target)"
        case "inRange":
            guard let number = value?.number else { return "inRange needs a number, got \(value?.description ?? "nothing")" }
            if let low = property.min, number < low - tolerance { return "\(number) is below \(low)" }
            if let high = property.max, number > high + tolerance { return "\(number) is above \(high)" }
            return nil
        case "permutationOf":
            guard let items = value?.array, let expected = property.value?.array else { return "permutationOf needs two lists" }
            let sort: ([VectorJSON]) -> [String] = { $0.map(\.description).sorted() }
            return sort(items) == sort(expected) ? nil : "\(items) is not a permutation of \(expected)"
        case "lengthIs":
            guard let length = property.value?.number else { return "lengthIs needs a value" }
            let count = value?.array?.count ?? value?.string?.count
            return count == Int(length) ? nil : "the length is \(count.map(String.init) ?? "unknown"), not \(Int(length))"
        case "matches":
            guard let pattern = property.pattern, let text = value?.string else { return "matches needs a pattern and a string" }
            return text.range(of: pattern, options: .regularExpression) != nil ? nil : "\(text) does not match \(pattern)"
        default:
            return "no property called \(property.kind)"
        }
    }
}
