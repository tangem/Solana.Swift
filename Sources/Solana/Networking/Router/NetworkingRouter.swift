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
    
    private var host: String? {
        endpoint.url.host
    }
    
    private let urlSession: URLSession
    private let endpoints: [RPCEndpoint]
    
    private var currentEndpointIndex = 0
    
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
        let url = endpoint.url
        let params = parameters.compactMap {$0}
        let requestAPI = SolanaRequest(method: bcMethod, params: params)
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKeyHeaderName = endpoint.apiKeyHeaderName, let apiKeyHeaderValue = endpoint.apiKeyHeaderValue {
            request.setValue(apiKeyHeaderValue, forHTTPHeaderField: apiKeyHeaderName)
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(requestAPI)
        } catch {
            onComplete(.failure(error))
        }
        
        var subscription: AnyCancellable?
        subscription = urlSession.dataTaskPublisher(for: request)
            .tryMap { (data: Data?, response: URLResponse) -> Void in
                guard let httpURLResponse = response as? HTTPURLResponse else {
                    throw RPCError.httpError
                }
                
                switch httpURLResponse.statusCode {
                case 200..<300:
                    break
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
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                guard case let .failure(error) = completion else {
                    return
                }
                
                func retry() {
                    self.request(method: method,
                                  bcMethod: bcMethod,
                                  parameters: parameters,
                                  onComplete: onComplete)
                }
                
                if let solanaError = error as? RPCError,
                   case .retry = solanaError {
                    retry()
                    return
                }
                
                guard self.needRetry(for: url.host) else {
                    print("Failed to send request: \(bcMethod) \(url)")
                    onComplete(.failure(error))
                    return
                }
                
                retry()
                
                withExtendedLifetime(subscription) {}
            }, receiveValue: { })
    }
    
    private func needRetry(for errorHost: String?) -> Bool {
        if self.host != errorHost {
            return true
        }
        
        currentEndpointIndex += 1
        if currentEndpointIndex < endpoints.count {
            return true
        }
        
        currentEndpointIndex = 0
        return false
    }
}
