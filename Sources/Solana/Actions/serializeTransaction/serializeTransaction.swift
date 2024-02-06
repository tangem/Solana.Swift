import Foundation

extension Action {
    public func serializeTransaction(
        instructions: [TransactionInstruction],
        recentBlockhash: String? = nil,
        signers: [Signer],
        feePayer: PublicKey? = nil,
        onComplete: @escaping ((Result<String, Error>) -> Void)
    ) {

        guard let feePayer = feePayer ?? signers.first?.publicKey else {
            onComplete(.failure(SolanaError.invalidRequest(reason: "Fee-payer not found")))
            return
        }

        let getRecentBlockhashRequest: (Result<String, Error>) -> Void = { result in
            switch result {
            case .success(let recentBlockhash):
                let queue = DispatchQueue.global()
                queue.async {
                    let transaction = Transaction(
                        feePayer: feePayer,
                        instructions: instructions,
                        recentBlockhash: recentBlockhash
                    )

                    transaction.sign(signers: signers, queue: queue) { result in
                        result
                            .flatMap { transaction.serialize() }
                            .flatMap {
                                let base64 = $0.bytes.toBase64()
                                return .success(base64)
                            }
                            .onSuccess { onComplete(.success($0)) }
                            .onFailure { onComplete(.failure($0)) }
                    }
                }
            case .failure(let error):
                onComplete(.failure(error))
                return
            }
        }

        if let recentBlockhash = recentBlockhash {
            getRecentBlockhashRequest(.success(recentBlockhash))
        } else {
            self.api.getRecentBlockhash { getRecentBlockhashRequest($0) }
        }
    }
}

extension ActionTemplates {
    public struct SerializeTransaction: ActionTemplate {
        public init(instructions: [TransactionInstruction], signers: [Account], recentBlockhash: String? = nil, feePayer: PublicKey? = nil) {
            self.instructions = instructions
            self.recentBlockhash = recentBlockhash
            self.signers = signers
            self.feePayer = feePayer
        }

        public typealias Success = String

        public let instructions: [TransactionInstruction]
        public let recentBlockhash: String?
        public let signers: [Account]
        public let feePayer: PublicKey?

        public func perform(withConfigurationFrom actionClass: Action, completion: @escaping (Result<String, Error>) -> Void) {
            actionClass.serializeTransaction(instructions: instructions, recentBlockhash: recentBlockhash, signers: signers, feePayer: feePayer, onComplete: completion)
        }
    }
}
