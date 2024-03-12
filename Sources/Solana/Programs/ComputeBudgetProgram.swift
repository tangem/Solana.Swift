//
//  ComputeBudgetProgram.swift
//  Solana.Swift
//
//  Created by Andrey Chukavin on 12.03.2024.
//

import Foundation

enum ComputeBudgetProgram {
    private enum Index: UInt8, BytesEncodable {
        case SetComputeUnitPrice = 2
        case SetComputeUnitLimit = 3
    }

    static func setComputeUnitLimitInstruction(units: UInt32) -> TransactionInstruction {
        return TransactionInstruction(
            keys: [],
            programId: PublicKey.computeBudgetProgramId,
            data: [UInt8(2), units]
        )
    }

    static func setComputeUnitPriceInstruction(microLamports: UInt64) -> TransactionInstruction {
        return TransactionInstruction(
            keys: [],
            programId: PublicKey.computeBudgetProgramId,
            data: [UInt8(3), microLamports]
        )
    }
}
