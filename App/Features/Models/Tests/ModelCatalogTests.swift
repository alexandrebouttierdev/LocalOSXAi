import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ModelCatalog")
struct ModelCatalogTests {
    @Test("keeps provider order and sorts models by display name")
    func ordering() async {
        let ollama = MockLLMProvider(id: "ollama", displayName: "Ollama", models: .success([
            Fixtures.model("qwen3:8b", provider: "ollama"), Fixtures.model("gpt-oss:20b", provider: "ollama")
        ]))
        let lmStudio = MockLLMProvider(id: "lmstudio", displayName: "LM Studio", models: .success([
            Fixtures.model("mistral", provider: "lmstudio")
        ]))

        let catalog = await ModelCatalog(providers: [ollama, lmStudio]).loadAll()

        #expect(catalog.map(\.provider.displayName) == ["Ollama", "LM Studio"])
        #expect(catalog[0].models.map(\.name) == ["gpt-oss:20b", "qwen3:8b"])
    }

    @Test("an unreachable provider does not hide the others")
    func failureIsolation() async {
        let down = MockLLMProvider(id: "lmstudio", displayName: "LM Studio",
                                   models: .failure(.unreachable(endpoint: "http://localhost:1234")))
        let up = MockLLMProvider(id: "ollama", displayName: "Ollama", models: .success([Fixtures.model("llama3.2", provider: "ollama")]))

        let catalog = await ModelCatalog(providers: [down, up]).loadAll()

        guard case .unavailable(let reason) = catalog[0].status else {
            Issue.record("Expected LM Studio to be unavailable")
            return
        }
        #expect(reason.contains("localhost:1234"))
        #expect(catalog[0].models.isEmpty)
        #expect(catalog[1].models.map(\.name) == ["llama3.2"])
    }

    @Test("no providers means an empty catalog")
    func empty() async {
        #expect(await ModelCatalog(providers: []).loadAll().isEmpty)
    }
}
