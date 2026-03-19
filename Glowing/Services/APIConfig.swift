import Foundation

enum APIConfig {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:8080/api/v1")!
    static let useMockBackend = true
    #else
    static let baseURL = URL(string: "https://api.glowing-app.com/api/v1")!
    static let useMockBackend = false
    #endif
}
