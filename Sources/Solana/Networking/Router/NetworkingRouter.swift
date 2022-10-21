import Foundation
import Combine

public enum HTTPMethod: String {
    case post = "POST"
    case get = "GET"
    case put = "PUT"
    case delete = "DELETE"
}

public enum RPCError: Error {
    case httpError
    case httpErrorCode(Int)
    case invalidResponseNoData
    case invalidResponse(ResponseError)
    case unknownResponse
    case retry
}

public class NetworkingRouter: SolanaRouter {
    
    public var endpoint: RPCEndpoint {
        endpoints[currentEndpointIndex]
    }
    
    private let urlSession: URLSession
    private let endpoints: [RPCEndpoint]
    
    private var currentEndpointIndex = 0
    private var bag = Set<AnyCancellable>()
    private var firedRequestsCounters: [String: Int] = [:]
    
    public init(endpoints: [RPCEndpoint], session: URLSession = .shared) {
        self.endpoints = endpoints
        self.urlSession = session
    }
    
    public func request<T: Decodable>(
        method: HTTPMethod = .post,
        bcMethod: String = #function,
        parameters: [Encodable?] = [],
        onComplete: @escaping (Result<T, Error>) -> Void
    ) {
        let bcMethod = bcMethod.replacingOccurrences(of: "\\([\\w\\s:]*\\)", with: "", options: .regularExpression)
        var endpointIndex = firedRequestsCounters[bcMethod] ?? 0
        endpointIndex = endpointIndex >= endpoints.count ? 0 : endpointIndex
        let url = endpoints[endpointIndex].url
        let params = parameters.compactMap {$0}
        let requestAPI = SolanaRequest(method: bcMethod, params: params)
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestAPI)
        } catch {
            onComplete(.failure(error))
        }
        
        bag.insert(
            urlSession.dataTaskPublisher(for: request)
                .tryMap { (data: Data?, response: URLResponse) -> Void in
                    guard let httpURLResponse = response as? HTTPURLResponse else {
                        throw RPCError.httpError
                    }
                    
                    switch httpURLResponse.statusCode {
                    case 200..<300:
                        break
                    case 429:
                        throw RPCError.retry
                    default:
                        throw RPCError.httpErrorCode(httpURLResponse.statusCode)
                    }
                    
                    guard let data = data else {
                        throw RPCError.invalidResponseNoData
                    }
                    
                    let decodedResponse = try JSONDecoder().decode(Response<T>.self, from: data)
                    
                    if let result = decodedResponse.result {
                        onComplete(.success(result))
                        return
                    }
                    if let responseError = decodedResponse.error {
                        throw RPCError.invalidResponse(responseError)
                    } else {
                        throw RPCError.unknownResponse
                    }
                }
                .retry(2)
                .sink(receiveCompletion: { [weak self] completion in
                    guard case let .failure(error) = completion else {
                        return
                    }
                    
                    func retry() {
                        self?.request(method: method,
                                      bcMethod: bcMethod,
                                      parameters: parameters,
                                      onComplete: onComplete)
                    }
                    
                    if let solanaError = error as? RPCError,
                       case .retry = solanaError {
                        retry()
                        return
                    }
                    guard self?.needRetry(for: bcMethod) ?? false else {
                        print("Failed to send request: \(bcMethod) \(url)")
                        onComplete(.failure(error))
                        return
                    }
                    
                    retry()
                }, receiveValue: { })
        )
    }
    
    private func needRetry(for function: String) -> Bool {
        let name = function
        let currentEndpointIndex = (firedRequestsCounters[name] ?? 0) + 1
        firedRequestsCounters[name] = currentEndpointIndex
        if currentEndpointIndex < endpoints.count {
            return true
        }
        
        firedRequestsCounters[name] = 0
        return false
    }
}
