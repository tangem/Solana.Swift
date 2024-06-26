import Foundation

/**
 An object that determins how network requests are handled in use of the Solana tools.

 Most use cases can prefer `NetworkingRouter` for daily use. Conform to this with a cusstom implementation to create local integration test tooling.
 */
public protocol SolanaRouter {
    func request<T>(method: HTTPMethod, bcMethod: String, parameters: [Encodable?], enableСontinuedRetry: Bool, onComplete: @escaping (Result<T, Error>) -> Void) where T : Decodable

    var endpoint: RPCEndpoint  { get }
}
