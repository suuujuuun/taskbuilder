import SwiftData
@available(macOS 14, *)
func testDelete(context: ModelContext) throws {
    try context.delete(model: ConceptNode.self)
}
