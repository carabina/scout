import Foundation
import AEXML

public struct PathExplorerXML {

    // MARK: - Properties

    var element: AEXMLElement

    // MARK: - Initialization

    public init(data: Data) throws {
        let document = try AEXMLDocument(xml: data)
        element = document.root
    }

    init(element: AEXMLElement) {
        self.element = element
    }

    public init(value: Any) {
        element = AEXMLElement(name: "", value: String(describing: value), attributes: [:])
    }

    // MARK: - Functions

    // MARK: Get

    func get(at index: Int) throws -> Self {
        guard element.children.count > index, index >= 0 else {
            throw PathExplorerError.subscriptWrongIndex(index: index, arrayCount: element.children.count)
        }

        return PathExplorerXML(element: element.children[index])
    }

    func get(for key: String) throws  -> PathExplorerXML {
        if element.name == key {
            return self
        } else {
            let child = element[key]
            guard child.error == nil else {
                throw PathExplorerError.subscriptMissingKey(key)
            }
            return PathExplorerXML(element: element[key])
        }
    }

    func get(pathElement: PathElement) throws  -> Self {
        if let stringElement = pathElement as? String {
            return try get(for: stringElement)
        } else if let intElement = pathElement as? Int {
            return try get(at: intElement)
        } else {
            // prevent a new type other than int or string to conform to PathElement
            assertionFailure("Only Int and String can be PathElement")
            return self
        }
    }

    // MARK: Set

    mutating func set(index: Int, to newValue: String) throws {
        guard element.children.count > index, index >= 0 else {
            throw PathExplorerError.arraySubscript(element.xml)
        }

        element.children[index].value = newValue
    }

    mutating func set(key: String, to newValue: String) throws {

        guard element[key].children.isEmpty else {
            throw PathExplorerError.invalidValue(newValue)
        }

        element[key].value = newValue
    }

    public mutating func set(_ path: [PathElement], to newValue: Any) throws {
        let newValueString = try convert(newValue, to: .string)

        var currentPathExplorer = self

        try path.forEach {
            currentPathExplorer = try currentPathExplorer.get(pathElement: $0)
        }

        guard currentPathExplorer.element.children.isEmpty else {
            throw PathExplorerError.wrongValueForKey(value: newValueString, element: currentPathExplorer.element.name)
        }

        currentPathExplorer.element.value = newValueString
    }

    // -- Set key name

    public mutating func set(_ path: Path, keyNameTo newKeyName: String) throws {
        var currentPathExplorer = self

        try path.forEach {
            currentPathExplorer = try currentPathExplorer.get(pathElement: $0)
        }

        currentPathExplorer.element.name = newKeyName
    }

    // MARK: Delete

    public mutating func delete(_ path: Path) throws {
        var currentPathExplorer = self

        try path.forEach {
            currentPathExplorer = try currentPathExplorer.get(pathElement: $0)
        }

        currentPathExplorer.element.removeFromParent()
    }

    public mutating func delete(_ pathElements: PathElement...) throws {
        try delete(pathElements)
    }

    // MARK: Add

    public mutating func add(_ newValue: Any, at path: Path) throws {
        guard !path.isEmpty else { return }

        let newValue = try convert(newValue, to: .string)

        var path = path
        let lastElement = path.removeLast()
        var currentPathExplorer = self

        try path.forEach {
            if let pathExplorer = try? currentPathExplorer.get(pathElement: $0) {
                // the key exist. Just keep parsing
                currentPathExplorer = pathExplorer
            } else {
                // the key does not exist. Add a new key to it
                let keyName = $0 as? String ?? element.childrenName
                currentPathExplorer.element.addChild(name: keyName, value: nil, attributes: [:])
                currentPathExplorer = try currentPathExplorer.get(pathElement: $0)
            }
        }

        try currentPathExplorer.add(newValue, for: lastElement)
        self = currentPathExplorer
    }

    public mutating func add(_ newValue: Any, at pathElements: PathElement...) throws {
        try add(newValue, at: pathElements)
    }

    /// Add the new value to the array or dictionary value
    /// - Parameters:
    ///   - newValue: The new value to add
    ///   - element: If string, try to add the new value to the dictionary. If int, try to add the new value to the array. `-1` will add the value at the end of the array.
    /// - Throws: if self cannot be subscript with the given element
    mutating func add(_ newValue: String, for pathElement: PathElement) throws {

        if let key = pathElement as? String {
            element.addChild(name: key, value: newValue, attributes: [:])
        } else if let index = pathElement as? Int {
            let keyName = element.childrenName

            if index == -1 {
                element.addChild(name: keyName, value: newValue, attributes: [:])
            } else if index >= 0, element.children.count > index {
                // we have to copy the element as we cannot modify its children
                let copy = AEXMLElement(name: element.name, value: element.value, attributes: element.attributes)
                for childIndex in 0...element.children.count {
                    switch childIndex {
                    case 0..<index:
                        copy.addChild(element.children[childIndex])
                    case index:
                        copy.addChild(name: keyName, value: newValue, attributes: [:])
                    case index+1...element.children.count:
                        copy.addChild(element.children[childIndex - 1])
                    default: break
                    }
                }
                element = copy
            } else {
                throw PathExplorerError.wrongValueForKey(value: newValue, element: index)
            }
        }
    }

    // MARK: Export

    public func exportData() throws -> Data {
        let document = AEXMLDocument(root: element, options: .init())
        let xmlString = document.xml

        guard let data  = xmlString.data(using: .utf8) else {
            throw PathExplorerError.stringToDataConversionError
        }

        return data
    }

    public func exportString() throws -> String {
        AEXMLDocument(root: element, options: .init()).xml
    }
}

extension PathExplorerXML: PathExplorer {

    public var string: String? { element.string }
    public var bool: Bool? { element.bool }
    public var int: Int? { element.int }
    public var real: Double? { element.double }

    public var description: String { element.xml }

    public var stringValue: String { element.string }

    // MARK: Get

    public func get(_ pathElements: PathElement...) throws -> Self {
        try get(pathElements)
    }

    public func get(_ pathElements: Path) throws  -> Self {
        var currentPathExplorer = self

        try pathElements.forEach {
            currentPathExplorer = try currentPathExplorer.get(pathElement: $0)
        }

        return currentPathExplorer
    }

    // MARK: Set

    public mutating func set<Type>(_ path: [PathElement], to newValue: Any, as type: KeyType<Type>) throws where Type: KeyAllowedType {
        try set(path, to: newValue)
    }

    public mutating  func set(_ pathElements: PathElement..., to newValue: Any) throws {
        try set(pathElements, to: newValue)
    }

    public mutating func set<Type>(_ pathElements: PathElement..., to newValue: Any, as type: KeyType<Type>) throws where Type: KeyAllowedType {
        try set(pathElements, to: newValue)
    }

    // -- Set key name

    public mutating func set(_ pathElements: PathElement..., keyNameTo newKeyName: String) throws {
        try set(pathElements, keyNameTo: newKeyName)
    }

    // MARK: Add

    public mutating func add<Type>(_ newValue: Any, at path: Path, as type: KeyType<Type>) throws where Type: KeyAllowedType {
        try add(newValue, at: path)
    }

    public mutating func add<Type>(_ newValue: Any, at pathElements: PathElement..., as type: KeyType<Type>) throws where Type: KeyAllowedType {
        try add(newValue, at: pathElements)
    }

}
