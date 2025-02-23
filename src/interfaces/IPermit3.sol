// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPermit } from "./IPermit.sol";

interface IPermit3 is IPermit {

    struct SpendTransferPermit {
        uint48 transferOrExpiration; // 1 immediate transfer, 0 permanent approval, 2+ approval expiration
        address token;
        address spender;
        uint160 amount; // 0 - remove approval, type(uint160).max - unlimited approval
    }

    struct ChainPermits {
        uint64 chainId;
        uint48 nonce; // random nonce, nonce values are not ordered
        SpendTransferPermit[] permits;
    }

    /// @dev chain batches better be ordered by calldata/blob gas cost
    struct Permit3Proof {
        bytes32 preHash; // previous batches chain-hashed keccak256(keccak256(keccak256(chain1), chain2), chain3)
        ChainPermits permits; // chain4
        bytes32[] followingHashes; // chain5, chain6, chain7
    }

    struct Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 nonce; // last used nonce, nonce values are not ordered
    }

    function permit(address owner, uint256 deadline, ChainPermits memory permits, bytes calldata signature) external;

    function permit(address owner, uint256 deadline, Permit3Proof memory batch, bytes calldata signature) external;

    function invalidateNonces(uint48[] calldata noncesToInvalidate) external;
}
