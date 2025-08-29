// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import { PermitBase } from "./PermitBase.sol";
import { IMultiTokenPermit } from "./interfaces/IMultiTokenPermit.sol";
import { InvalidTokenData, InvalidArrayLength } from "./lib/TokenType.sol";

/**
 * @title MultiTokenPermit
 * @notice Multi-token support (ERC20, ERC721, ERC1155) for the Permit3 system
 * @dev Extends PermitBase with NFT and semi-fungible token functionality
 */
abstract contract MultiTokenPermit is PermitBase, IMultiTokenPermit {
    /**
     * @notice Query multi-token allowance for a specific token ID
     * @param owner Token owner
     * @param token Token contract address
     * @param spender Approved spender
     * @param tokenId Token ID (0 for ERC20)
     * @return approved Whether spender is approved
     * @return amount Approved amount (relevant for ERC1155)
     * @return expiration Timestamp when approval expires
     * @return timestamp Timestamp when approval was set
     */
    function multiTokenAllowance(
        address owner,
        address token,
        address spender,
        uint256 tokenId
    ) external view override returns (bool approved, uint128 amount, uint48 expiration, uint48 timestamp) {
        if (tokenId == 0) {
            // For ERC20 tokens, use the standard allowance
            Allowance memory allowed = allowances[owner][token][spender];
            return (
                allowed.amount > 0,
                uint128(allowed.amount > type(uint128).max ? type(uint128).max : allowed.amount),
                allowed.expiration,
                allowed.timestamp
            );
        } else {
            // For ERC721/ERC1155, create unique identifier by hashing token address + tokenId
            // This creates a deterministic address-like identifier for the specific token ID
            address encodedId = address(uint160(uint256(keccak256(abi.encodePacked(token, tokenId)))));
            Allowance memory allowed = allowances[owner][encodedId][spender];
            
            // Fallback mechanism: if no specific token ID allowance exists, use collection-wide allowance
            // This enables both per-token-id and wildcard (entire collection) approval patterns
            if (allowed.amount == 0) {
                allowed = allowances[owner][token][spender];
            }
            
            return (
                allowed.amount > 0,
                uint128(allowed.amount > type(uint128).max ? type(uint128).max : allowed.amount),
                allowed.expiration,
                allowed.timestamp
            );
        }
    }

    /**
     * @notice Execute approved ERC721 token transfer
     * @dev Uses the dual-allowance system: tries per-token allowance first, falls back to collection-wide
     * @param from Token owner address
     * @param to Transfer recipient address
     * @param tokenId The unique NFT token ID
     * @param token ERC721 contract address
     */
    function transferFromERC721(address from, address to, uint256 tokenId, address token) public override {
        // Create unique encoded identifier for this specific token ID
        // Uses keccak256(token || tokenId) truncated to address for deterministic mapping
        address encodedId = address(uint160(uint256(keccak256(abi.encodePacked(token, tokenId)))));

        // First, try to update allowance for the specific token ID
        (, bytes memory revertDataPerId) = _updateAllowance(
            from, encodedId, msg.sender, 1
        );

        if (revertDataPerId.length > 0) {
            // Fallback: try collection-wide allowance if per-token-id allowance fails
            (, bytes memory revertDataWildcard) = _updateAllowance(
                from, token, msg.sender, 1
            );
            if (revertDataWildcard.length > 0) {
                // Priority error handling: show collection-wide error for insufficient allowance,
                // otherwise show the more specific per-token error
                bytes4 perIdSelector = bytes4(revertDataPerId);
                if (perIdSelector == InsufficientAllowance.selector) {
                    _revert(revertDataWildcard);
                } else {
                    _revert(revertDataPerId);
                }
            }
        }
        IERC721(token).safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice Execute approved ERC1155 token transfer
     * @dev Uses the dual-allowance system: tries per-token allowance first, falls back to collection-wide
     * @param from Token owner address
     * @param to Transfer recipient address
     * @param tokenId The specific ERC1155 token ID
     * @param amount Number of tokens to transfer (must not exceed uint128)
     * @param token ERC1155 contract address
     */
    function transferFromERC1155(
        address from,
        address to,
        uint256 tokenId,
        uint128 amount,
        address token
    ) public override {
        // Create unique encoded identifier for this specific token ID
        // Uses keccak256(token || tokenId) truncated to address for deterministic mapping
        address encodedId = address(uint160(uint256(keccak256(abi.encodePacked(token, tokenId)))));
        
        // First, try to update allowance for the specific token ID
        (, bytes memory revertDataPerId) = _updateAllowance(
            from, encodedId, msg.sender, uint160(amount)
        );
        
        if (revertDataPerId.length > 0) {
            // Fallback: try collection-wide allowance if per-token-id allowance fails
            (, bytes memory revertDataWildcard) = _updateAllowance(
                from, token, msg.sender, uint160(amount)
            );
            if (revertDataWildcard.length > 0) {
                // Priority error handling: show collection-wide error for insufficient allowance,
                // otherwise show the more specific per-token error
                bytes4 perIdSelector = bytes4(revertDataPerId);
                if (perIdSelector == InsufficientAllowance.selector) {
                    _revert(revertDataWildcard);
                } else {
                    _revert(revertDataPerId);
                }
            }
        }
        
        // Execute the ERC1155 transfer
        IERC1155(token).safeTransferFrom(from, to, tokenId, amount, "");
    }

    /**
     * @notice Execute multiple approved ERC721 transfers in a single transaction
     * @dev Each transfer uses the dual-allowance system independently
     * @param transfers Array of ERC721 transfer instructions
     */
    function transferFromERC721(
        ERC721TransferDetails[] calldata transfers
    ) external {
        uint256 transfersLength = transfers.length;
        if (transfersLength == 0) {
            revert EmptyArray();
        }

        for (uint256 i = 0; i < transfersLength; i++) {
            transferFromERC721(transfers[i].from, transfers[i].to, transfers[i].tokenId, transfers[i].token);
        }
    }

    /**
     * @notice Execute multiple approved ERC1155 transfers in a single transaction
     * @dev Each transfer uses the dual-allowance system independently
     * @param transfers Array of ERC1155 transfer instructions
     */
    function transferFromERC1155(
        MultiTokenTransfer[] calldata transfers
    ) external {
        uint256 transfersLength = transfers.length;
        if (transfersLength == 0) {
            revert EmptyArray();
        }

        for (uint256 i = 0; i < transfersLength; i++) {
            transferFromERC1155(
                transfers[i].from, transfers[i].to, transfers[i].tokenId, uint128(transfers[i].amount), transfers[i].token
            );
        }
    }

    /**
     * @notice Execute approved ERC1155 batch transfer for multiple token IDs to a single recipient
     * @dev Processes each token ID individually through the dual-allowance system
     * @param transfer Batch transfer details containing arrays of token IDs and amounts
     */
    function batchTransferFromERC1155(
        ERC1155BatchTransferDetails calldata transfer
    ) external override {
        uint256 tokenIdsLength = transfer.tokenIds.length;
        if (tokenIdsLength == 0) {
            revert EmptyArray();
        }
        if (tokenIdsLength != transfer.amounts.length) {
            revert InvalidArrayLength();
        }

        // Execute batch by processing each token ID individually to leverage dual-allowance logic
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            transferFromERC1155(
                transfer.from,
                transfer.to,
                transfer.tokenIds[i],
                uint128(transfer.amounts[i]),
                transfer.token
            );
        }
    }

    /**
     * @notice Execute multiple token transfers of any type in a single transaction
     * @dev Routes each transfer to the appropriate function based on token type
     * @param transfers Array of multi-token transfer instructions
     */
    function batchTransferFrom(
        TokenTypeTransfer[] calldata transfers
    ) external override {
        uint256 transfersLength = transfers.length;
        if (transfersLength == 0) {
            revert EmptyArray();
        }

        for (uint256 i = 0; i < transfersLength; i++) {
            TokenTypeTransfer calldata typeTransfer = transfers[i];
            MultiTokenTransfer calldata transfer = typeTransfer.transfer;
            
            if (typeTransfer.tokenType == TokenStandard.ERC20) {
                // ERC20: Use amount field, tokenId is ignored
                transferFrom(transfer.from, transfer.to, transfer.amount, transfer.token);
            } else if (typeTransfer.tokenType == TokenStandard.ERC721) {
                // ERC721: Use tokenId field, amount should be 1 (but not enforced)
                transferFromERC721(transfer.from, transfer.to, transfer.tokenId, transfer.token);
            } else if (typeTransfer.tokenType == TokenStandard.ERC1155) {
                // ERC1155: Use both tokenId and amount, but amount must fit in uint128
                if (transfer.amount > type(uint128).max) {
                    revert InvalidTokenData(TokenStandard.ERC1155, abi.encode(transfer.tokenId, transfer.amount));
                }
                transferFromERC1155(
                    transfer.from,
                    transfer.to,
                    transfer.tokenId,
                    uint128(transfer.amount),
                    transfer.token
                );
            }
        }
    }
}