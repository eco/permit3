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
            // For ERC721/ERC1155, encode the token ID and check allowance
            address encodedId = address(uint160(uint256(keccak256(abi.encodePacked(token, tokenId)))));
            Allowance memory allowed = allowances[owner][encodedId][spender];
            
            // Fall back to collection-wide allowance if specific token ID has no allowance
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
     * @param from Token owner
     * @param to Transfer recipient
     * @param tokenId The NFT token ID
     * @param token ERC721 token address
     */
    function transferFromERC721(address from, address to, uint256 tokenId, address token) public override {
        address encodedId = address(uint160(uint256(keccak256(abi.encodePacked(token, tokenId)))));

        // First, try to update allowance for the specific token ID
        (, bytes memory revertDataPerId) = _updateAllowance(
            from, encodedId, msg.sender, 1
        );

        if (revertDataPerId.length > 0) {
            // If that fails, fall back to the wildcard token address
            (, bytes memory revertDataWildcard) = _updateAllowance(
                from, token, msg.sender, 1
            );
            if (revertDataWildcard.length > 0) {
                // If revertDataPerId.selector == InsufficientAllowance.selector, we should revert with revertDataWildcard
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
     * @param from Token owner
     * @param to Transfer recipient
     * @param tokenId The ERC1155 token ID
     * @param amount Transfer amount
     * @param token ERC1155 token address
     */
    function transferFromERC1155(
        address from,
        address to,
        uint256 tokenId,
        uint128 amount,
        address token
    ) public override {
        // Create a unique identifier for this specific token ID
        address encodedId = address(uint160(uint256(keccak256(abi.encodePacked(token, tokenId)))));
        
        // First, try to update allowance for the specific token ID
        (, bytes memory revertDataPerId) = _updateAllowance(
            from, encodedId, msg.sender, uint160(amount)
        );
        
        if (revertDataPerId.length > 0) {
            // If that fails, fall back to the collection-wide token address allowance
            (, bytes memory revertDataWildcard) = _updateAllowance(
                from, token, msg.sender, uint160(amount)
            );
            if (revertDataWildcard.length > 0) {
                // If revertDataPerId.selector == InsufficientAllowance.selector, we should revert with revertDataWildcard
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
     * @notice Execute multiple approved ERC721 transfers
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
     * @notice Execute multiple approved ERC1155 transfers
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
     * @notice Execute approved ERC1155 batch transfer
     * @param transfer Batch transfer details for multiple token IDs
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

        // Execute batch transfer using individual transfers to leverage allowance logic
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
                // For ERC20, ignore tokenId and use amount
                transferFrom(transfer.from, transfer.to, transfer.amount, transfer.token);
            } else if (typeTransfer.tokenType == TokenStandard.ERC721) {
                // For ERC721, use tokenId and ignore amount (should be 1)
                transferFromERC721(transfer.from, transfer.to, transfer.tokenId, transfer.token);
            } else if (typeTransfer.tokenType == TokenStandard.ERC1155) {
                // For ERC1155, use both tokenId and amount
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