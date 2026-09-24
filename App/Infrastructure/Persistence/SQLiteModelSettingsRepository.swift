import Foundation
import GRDB

/// Per-model settings stored in SQLite (`modelSettings` table).
struct SQLiteModelSettingsRepository: ModelSettingsRepository {
    let database: AppDatabase

    func allSettings() async throws -> [AIModel.ID: ModelSettings] {
        try await database.writer.read { db in
            let records = try ModelSettingsRecord.fetchAll(db)
            return Dictionary(records.map { ($0.modelID, $0.settings) }, uniquingKeysWith: { first, _ in first })
        }
    }

    func save(_ settings: ModelSettings, for model: AIModel.ID) async throws {
        let record = ModelSettingsRecord(settings, for: model)
        try await database.writer.write { db in
            if settings.isDefault {
                _ = try ModelSettingsRecord.deleteOne(db, key: ["provider": record.provider, "name": record.name])
            } else {
                try record.upsert(db)
            }
        }
    }
}

/// Row of the `modelSettings` table.
struct ModelSettingsRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "modelSettings"

    var provider: String
    var name: String
    var temperature: Double?
    var reasoning: String?
    var contextTokens: Int?

    init(_ settings: ModelSettings, for model: AIModel.ID) {
        provider = model.provider.rawValue
        name = model.name
        temperature = settings.temperature
        reasoning = settings.reasoning?.rawValue
        contextTokens = settings.contextTokens
    }

    var modelID: AIModel.ID { AIModel.ID(provider: ProviderID(rawValue: provider), name: name) }

    /// An unknown reasoning value (from a newer version) falls back to the default.
    var settings: ModelSettings {
        ModelSettings(temperature: temperature, reasoning: reasoning.flatMap(ReasoningEffort.init(rawValue:)),
                      contextTokens: contextTokens)
    }
}
