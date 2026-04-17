import Foundation

/// In-memory history of picked colors with undo/redo support.
final class ColorHistory {
    private var stack: [ColorValue] = []
    private var undoneStack: [ColorValue] = []
    private let maxSize = 50

    var entries: [ColorValue] { stack }
    var canUndo: Bool { stack.count > 1 }
    var canRedo: Bool { !undoneStack.isEmpty }

    func push(_ color: ColorValue) {
        stack.insert(color, at: 0)
        if stack.count > maxSize { stack.removeLast() }
        undoneStack.removeAll()
    }

    func undo() -> ColorValue? {
        guard stack.count > 1 else { return nil }
        let removed = stack.removeFirst()
        undoneStack.insert(removed, at: 0)
        return stack.first
    }

    func redo() -> ColorValue? {
        guard let restored = undoneStack.first else { return nil }
        undoneStack.removeFirst()
        stack.insert(restored, at: 0)
        return restored
    }
}
