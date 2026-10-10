import Testing
@testable import DatasetGeneratorCore

@Suite("Generator command line")
struct GeneratorCommandTests {
    @Test("no argument generates the dataset")
    func noArgumentGenerates() {
        #expect(GeneratorCommand(arguments: []) == .generate)
    }

    @Test("seed rewrites the seed list")
    func seed() {
        #expect(GeneratorCommand(arguments: ["seed"]) == .seed)
    }

    @Test("anything else is refused rather than falling through to a full run")
    func anythingElseIsRefused() {
        #expect(GeneratorCommand(arguments: ["seeds"]) == nil)
        #expect(GeneratorCommand(arguments: ["--help"]) == nil)
        #expect(GeneratorCommand(arguments: ["generate"]) == nil)
        #expect(GeneratorCommand(arguments: ["seed", "extra"]) == nil)
        #expect(GeneratorCommand(arguments: [""]) == nil)
    }
}
