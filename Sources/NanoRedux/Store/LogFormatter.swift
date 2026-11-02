#if DEBUG
    /// Reflection is used only for display; no observation-generated names are rewritten.
    enum LogFormatter {
        static func format(_ value: Any) -> String {
            var ancestors: Set<ObjectIdentifier> = []
            var remaining = 1000
            return render(value, depth: 0, ancestors: &ancestors, remaining: &remaining)
        }

        private static func render(
            _ value: Any,
            depth: Int,
            ancestors: inout Set<ObjectIdentifier>,
            remaining: inout Int,
        ) -> String {
            let typeName = String(describing: type(of: value))
            guard depth < 10, remaining > 0 else { return "\(typeName) (omitted)" }
            remaining -= 1
            let mirror = Mirror(reflecting: value)
            var identity: ObjectIdentifier?
            if mirror.displayStyle == .class {
                let objectID = ObjectIdentifier(value as AnyObject)
                guard ancestors.insert(objectID).inserted else { return "\(typeName) (cycle)" }
                identity = objectID
            }
            defer {
                if let identity { ancestors.remove(identity) }
            }

            var children = Array(mirror.children.prefix(100))
            var superclass = mirror.superclassMirror
            while let parent = superclass, children.count < 100 {
                children.append(contentsOf: parent.children.prefix(100 - children.count))
                superclass = parent.superclassMirror
            }
            guard !children.isEmpty else {
                return leafDescription(value, style: mirror.displayStyle)
            }

            let indent = String(repeating: "  ", count: depth + 1)
            var lines = [typeName]
            for (index, child) in children.enumerated() {
                guard remaining > 0 else {
                    lines.append("\(indent)- … (omitted)")
                    break
                }
                let label = child.label ?? "[\(index)]"
                let description: String
                if label.hasPrefix("_$") {
                    description = "\(String(describing: type(of: child.value))) (omitted)"
                    remaining -= 1
                } else {
                    description = render(child.value, depth: depth + 1, ancestors: &ancestors, remaining: &remaining)
                }
                lines.append("\(indent)- \(label): \(description)")
            }
            if children.count == 100 {
                lines.append("\(indent)- … (child limit reached)")
            }
            return lines.joined(separator: "\n")
        }

        private static func leafDescription(_ value: Any, style: Mirror.DisplayStyle?) -> String {
            switch style {
            case .class:
                String(describing: type(of: value))
            case .enum:
                String(describing: value)
            default:
                String(reflecting: value)
            }
        }
    }
#endif
