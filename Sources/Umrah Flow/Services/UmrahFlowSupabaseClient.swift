import Foundation

struct UmrahFlowTranslationRow: Decodable {
    let key: String
    let value: String
}

struct UmrahFlowAudioRow: Decodable {
    let key: String
    let url: String
}

enum UmrahFlowSupabaseError: Error {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
}

struct UmrahFlowSupabaseClient {
    // Same public Supabase project used by the legacy Umrah Flow. The anon key is
    // intentionally a client-side/public key; database RLS remains authoritative.
    private static let baseURL = "https://coaqrsapnpyutsxflsru.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvYXFyc2FwbnB5dXRzeGZsc3J1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzNjE2OTcsImV4cCI6MjA3OTkzNzY5N30.iycnHay3nX__40VTKzvkyX3NKbSo8wWqBhKGKGl2yIo"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translations(language: String) async throws -> [String: String] {
        // "translations2" is the isolated Umrah-only table target. Until it is
        // created in Supabase, the client transparently falls back to the current
        // shared "translations" table and filters strictly to Umrah Flow keys.
        for table in ["translations2", "translations"] {
            do {
                let rows: [UmrahFlowTranslationRow] = try await request(
                    table: table,
                    select: "key,value",
                    language: language
                )
                let filtered = rows.reduce(into: [String: String]()) { result, row in
                    guard UmrahFlowKeys.all.contains(row.key) else { return }
                    result[row.key] = row.value
                }
                if !filtered.isEmpty { return filtered }
            } catch {
                if table == "translations" { throw error }
            }
        }
        return [:]
    }

    func audioURLs(language: String) async throws -> [String: URL] {
        let rows: [UmrahFlowAudioRow] = try await request(
            table: "audio",
            select: "key,url",
            language: language
        )
        return rows.reduce(into: [String: URL]()) { result, row in
            guard let url = URL(string: row.url) else { return }
            result[row.key] = url
        }
    }

    private func request<Row: Decodable>(
        table: String,
        select: String,
        language: String
    ) async throws -> [Row] {
        var components = URLComponents(string: "\(Self.baseURL)/rest/v1/\(table)")
        components?.queryItems = [
            URLQueryItem(name: "select", value: select),
            URLQueryItem(name: "lang", value: "eq.\(language)")
        ]
        guard let url = components?.url else { throw UmrahFlowSupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UmrahFlowSupabaseError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UmrahFlowSupabaseError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode([Row].self, from: data)
    }
}
