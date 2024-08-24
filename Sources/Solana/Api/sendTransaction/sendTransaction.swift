import Foundation

public extension Api {
    func sendTransaction(serializedTransaction: String,
                         configs: RequestConfiguration = RequestConfiguration(encoding: "base64", maxRetries: 12)!,
                         startSendingTimestamp: Date,
                         onComplete: @escaping(Result<TransactionID, Error>) -> Void) {
        router.request(parameters: [serializedTransaction, configs], enableСontinuedRetry: false) {[weak self] (result: Result<TransactionID, Error>) in
            guard let self else { return }

            switch result {
            case .success(let transaction):
                onComplete(.success(transaction))
            case .failure(let error):
                if let solanaError = error as? RPCError, solanaError.isBlockhashNotFoundError,
                   Date().timeIntervalSince(startSendingTimestamp) <= Constants.retryTimeoutSeconds {

                    Thread.sleep(forTimeInterval: Constants.retryDelaySeconds)
                    sendTransaction(serializedTransaction: serializedTransaction,
                                    configs: configs,
                                    startSendingTimestamp: startSendingTimestamp,
                                    onComplete: onComplete)
                    return
                }

                if let solanaError = error as? SolanaError {
                    onComplete(.failure(self.handleError(error: solanaError)))
                    return
                } else {
                    onComplete(.failure(error))
                    return
                }
            }
        }
    }
    

    fileprivate func handleError(error: SolanaError) -> Error {
        if case .invalidResponse(let response) = error,
           response.message != nil {
            var message = response.message
            if let readableMessage = response.data?.logs
                .first(where: { $0.contains("Error:") })?
                .components(separatedBy: "Error: ")
                .last {
                message = readableMessage
            } else if let readableMessage = response.message?
                        .components(separatedBy: "Transaction simulation failed: ")
                        .last {
                message = readableMessage
            }
            return SolanaError.invalidResponse(ResponseError(code: response.code, message: message, data: response.data))
        }
        return error
    }
}

public extension ApiTemplates {
    struct SendTransaction: ApiTemplate {
        public init(serializedTransaction: String,
                    configs: RequestConfiguration = RequestConfiguration(encoding: "base64")!) {
            self.serializedTransaction = serializedTransaction
            self.configs = configs
        }
        
        public let serializedTransaction: String
        public let configs: RequestConfiguration
        
        public typealias Success = TransactionID
        
        public func perform(withConfigurationFrom apiClass: Api, completion: @escaping (Result<Success, Error>) -> Void) {
            apiClass.sendTransaction(serializedTransaction: serializedTransaction, configs: configs, startSendingTimestamp: Date(), onComplete: completion)
        }
    }
}

private extension Api {
    enum Constants {
        /// According to blockchain specifications and blockhain analytic
        static let retryTimeoutSeconds: TimeInterval = 18
        static let retryDelaySeconds: TimeInterval = 3
    }
}
