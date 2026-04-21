import Foundation
import UIKit

@MainActor
final class FundValuationChartLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var didFail = false

    private var activeCode: String?
    private var loadedCode: String?
    private var loadTask: Task<Void, Never>?
    private var generation = 0
    private let session: URLSession

    init(session: URLSession = FundValuationChartLoader.makeSession()) {
        self.session = session
    }

    func load(code: String, force: Bool = false) {
        let normalizedCode = normalized(code)
        guard !normalizedCode.isEmpty else {
            reset()
            return
        }

        if !force, loadedCode == normalizedCode, image != nil {
            activeCode = normalizedCode
            didFail = false
            return
        }

        activeCode = normalizedCode
        loadTask?.cancel()
        generation += 1
        let currentGeneration = generation
        isLoading = true
        didFail = false

        loadTask = Task { [weak self] in
            guard let self else { return }

            defer {
                if self.generation == currentGeneration, self.activeCode == normalizedCode {
                    self.isLoading = false
                    self.loadTask = nil
                }
            }

            do {
                let request = try self.makeRequest(code: normalizedCode)
                let (data, response) = try await self.session.data(for: request)
                guard !Task.isCancelled else { return }
                guard
                    let http = response as? HTTPURLResponse,
                    200..<300 ~= http.statusCode,
                    let image = UIImage(data: data)
                else {
                    throw URLError(.badServerResponse)
                }
                guard self.generation == currentGeneration, self.activeCode == normalizedCode else { return }
                self.image = image
                self.loadedCode = normalizedCode
                self.didFail = false
            } catch {
                guard !Task.isCancelled else { return }
                guard self.generation == currentGeneration, self.activeCode == normalizedCode else { return }
                self.image = nil
                self.didFail = true
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    func reset() {
        cancel()
        activeCode = nil
        loadedCode = nil
        image = nil
        didFail = false
    }

    private func normalized(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeRequest(code: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "j4.dfcfw.com"
        components.path = "/charts/pic6/\(code).png"
        components.queryItems = [
            URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    nonisolated private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }
}
