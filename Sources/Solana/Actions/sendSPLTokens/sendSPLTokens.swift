import Foundation

extension Action {
    public func sendSPLTokens(
        mintAddress: String,
        tokenProgramId: PublicKey,
        decimals: Decimals,
        from fromPublicKey: String,
        to destinationAddress: String,
        amount: UInt64,
        allowUnfundedRecipient: Bool = false,
        signer: Signer,
        onComplete: @escaping (Result<TransactionID, Error>) -> Void
    ) {
        ContResult.init { cb in
            self.findSPLTokenDestinationAddress(
                mintAddress: mintAddress,
                tokenProgramId: tokenProgramId,
                destinationAddress: destinationAddress,
                allowUnfundedRecipient: allowUnfundedRecipient
            ) { cb($0) }
        }.flatMap { (destination, isUnregisteredAsocciatedToken) in

            let toPublicKey = destination

            // catch error
            guard fromPublicKey != toPublicKey.base58EncodedString else {
                return .failure(SolanaError.invalidPublicKey)
            }

            guard let fromPublicKey = PublicKey(string: fromPublicKey) else {
                return .failure( SolanaError.invalidPublicKey)
            }
            
            guard let mint = PublicKey(string: mintAddress) else {
                return .failure(SolanaError.invalidPublicKey)
            }
            
            var instructions = [TransactionInstruction]()

            // create associated token address
            if isUnregisteredAsocciatedToken {
                guard let mint = PublicKey(string: mintAddress) else {
                    return .failure(SolanaError.invalidPublicKey)
                }
                guard let owner = PublicKey(string: destinationAddress) else {
                    return .failure(SolanaError.invalidPublicKey)
                }

                let createATokenInstruction = AssociatedTokenProgram.createAssociatedTokenAccountInstruction(
                    programId: tokenProgramId,
                    mint: mint,
                    associatedAccount: toPublicKey,
                    owner: owner,
                    payer: signer.publicKey
                )
                instructions.append(createATokenInstruction)
            }

            // send instruction
            let sendInstruction = TokenProgram.transferInstruction(
                tokenProgramId: tokenProgramId,
                source: fromPublicKey,
                mint: mint,
                destination: toPublicKey,
                owner: signer.publicKey,
                decimals: decimals,
                amount: amount
            )

            instructions.append(sendInstruction)
            return .success((instructions: instructions, account: signer))

        }.flatMap { (instructions, account) in
            ContResult.init { cb in
                self.serializeAndSendWithFee(instructions: instructions, signers: [account]) {
                    cb($0)
                }
            }
        }.run(onComplete)
    }
}

extension ActionTemplates {
    public struct SendSPLTokens: ActionTemplate {
        public let mintAddress: String
        public let tokenProgramId: PublicKey
        public let fromPublicKey: String
        public let destinationAddress: String
        public let amount: UInt64
        public let decimals: Decimals
        public let allowUnfundedRecipient: Bool
        public let signer: Signer

        public typealias Success = TransactionID

        public func perform(withConfigurationFrom actionClass: Action, completion: @escaping (Result<TransactionID, Error>) -> Void) {
            actionClass.sendSPLTokens(mintAddress: mintAddress, tokenProgramId: tokenProgramId, decimals: decimals, from: fromPublicKey, to: destinationAddress, amount: amount, allowUnfundedRecipient: allowUnfundedRecipient, signer: signer, onComplete: completion)
        }
    }
}
