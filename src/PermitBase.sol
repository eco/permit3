// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import { IMultiTokenPermit } from "./interfaces/IMultiTokenPermit.sol";
import { IPermit } from "./interfaces/IPermit.sol";
import { TokenType } from "./lib/TokenType.sol";

/**
 * @title PermitBase
 * @notice Base implementation for token approvals and transfers
 * @dev Core functionality for managing token permissions
 */
contract PermitBase is IPermit, IMultiTokenPermit {
    using SafeERC20 for IERC20;

    /// @dev Special value representing a locked allowance that cannot be used
    /// @dev Value of 2 is chosen to distinguish from 0 (no expiration) and 1 (expired)
    uint48 internal constant LOCKED_ALLOWANCE = 2;

    /// @dev Maximum value for uint160, representing unlimited/infinite allowance
    /// @dev Using uint160 instead of uint256 to save gas on storage operations
    uint160 internal constant MAX_ALLOWANCE = type(uint160).max;

    /**
     * @dev Core data structure for tracking token permissions
     * Maps: owner => token => spender => {amount, expiration, timestamp}
     */
    mapping(address => mapping(address => mapping(address => Allowance))) internal allowances;

    /**
     * @notice Query current token allowance
     * @dev Retrieves full allowance details including expiration
     * @param user Token owner
     * @param token ERC20 token address
     * @param spender Approved spender
     * @return amount Current approved amount
     * @return expiration Timestamp when approval expires
     * @return timestamp Timestamp when approval was set
     */
    function allowance(
        address user,
        address token,
        address spender
    ) external view returns (uint160 amount, uint48 expiration, uint48 timestamp) {
        Allowance memory allowed = allowances[user][token][spender];
        return (allowed.amount, allowed.expiration, allowed.timestamp);
    }

    /**
     * @notice Direct allowance approval without signature
     * @dev Alternative to permit() for simple approvals
     * @param token ERC20 token address
     * @param spender Address to approve
     * @param amount Approval amount
     * @param expiration Optional expiration timestamp
     */
    function approve(address token, address spender, uint160 amount, uint48 expiration) external override {
        // Prevent overriding locked allowances
        if (allowances[msg.sender][token][spender].expiration == LOCKED_ALLOWANCE) {
            revert AllowanceLocked(msg.sender, token, spender);
        }

        if (token == address(0)) {
            revert ZeroToken();
        }
        if (spender == address(0)) {
            revert ZeroSpender();
        }
        if (expiration != 0 && expiration <= block.timestamp) {
            revert InvalidExpiration(expiration);
        }

        allowances[msg.sender][token][spender] =
            Allowance({ amount: amount, expiration: expiration, timestamp: uint48(block.timestamp) });

        emit Approval(msg.sender, token, spender, amount, expiration);
    }

    /**
     * @notice Execute approved token transfer
     * @dev Checks allowance and expiration before transfer
     * @param from Token owner
     * @param token ERC20 token address
     * @param to Transfer recipient
     * @param amount Transfer amount
     */
    function transferFrom(address from, address to, uint160 amount, address token) public {
        (, bytes memory revertData) = _updateAllowance(from, token, msg.sender, amount);
        if (revertData.length > 0) {
            _revert(revertData);
        }
        _transferFrom(from, to, amount, token);
    }

    /**
     * @notice Execute multiple approved transfers
     * @dev Batch version of transferFrom()
     * @param transfers Array of transfer instructions
     */
    function transferFrom(
        AllowanceTransferDetails[] calldata transfers
    ) external {
        uint256 transfersLength = transfers.length;
        if (transfersLength == 0) {
            revert EmptyArray();
        }

        for (uint256 i = 0; i < transfersLength; i++) {
            transferFrom(transfers[i].from, transfers[i].to, transfers[i].amount, transfers[i].token);
        }
    }

    /**
     * @notice Revoke multiple token approvals
     * @dev Emergency function to quickly remove permissions
     * @param approvals Array of token-spender pairs to revoke
     */
    function lockdown(
        TokenSpenderPair[] calldata approvals
    ) external {
        uint256 approvalsLength = approvals.length;
        if (approvalsLength == 0) {
            revert EmptyArray();
        }

        for (uint256 i = 0; i < approvalsLength; i++) {
            address token = approvals[i].token;
            address spender = approvals[i].spender;

            if (token == address(0)) {
                revert ZeroToken();
            }
            if (spender == address(0)) {
                revert ZeroSpender();
            }

            allowances[msg.sender][token][spender] =
                Allowance({ amount: 0, expiration: LOCKED_ALLOWANCE, timestamp: uint48(block.timestamp) });

            emit Lockdown(msg.sender, token, spender);
        }
    }

    /**
     * @dev Internal function to revert with custom error data
     * @param revertData The encoded error data to revert with
     */
    function _revert(
        bytes memory revertData
    ) internal pure {
        assembly {
            revert(add(32, revertData), mload(revertData))
        }
    }

    /**
     * @notice Updates allowance after checking validity and sufficiency
     * @param from Token owner address
     * @param token Token address
     * @param spender Spender address
     * @param amount Amount to deduct from allowance
     * @return allowed Updated allowance struct
     * @return revertData Encoded error data if validation fails, empty otherwise
     */
    function _updateAllowance(
        address from,
        address token,
        address spender,
        uint160 amount
    ) internal returns (Allowance memory allowed, bytes memory revertData) {
        allowed = allowances[from][token][spender];

        if (allowed.expiration == LOCKED_ALLOWANCE) {
            revertData = abi.encodeWithSelector(AllowanceLocked.selector, from, token, spender);
            return;
        }

        if (allowed.expiration != 0 && block.timestamp > allowed.expiration) {
            revertData = abi.encodeWithSelector(AllowanceExpired.selector, allowed.expiration);
            return;
        }

        if (allowed.amount != MAX_ALLOWANCE) {
            if (allowed.amount < amount) {
                revertData = abi.encodeWithSelector(InsufficientAllowance.selector, amount, allowed.amount);
                return;
            }
            /**
             * @dev SAFETY: This unchecked block is safe from underflow because:
             * 1. The require statement immediately above guarantees that allowed.amount >= amount
             * 2. When subtracting amount from allowed.amount, the result will always be >= 0
             * 3. Both allowed.amount and amount are uint160 types, ensuring type consistency
             * 4. The subtraction can never underflow since we've verified the allowance is sufficient
             *
             * This optimization saves gas by avoiding redundant underflow checks that Solidity
             * would normally perform, since we've already validated the operation will succeed.
             */
            unchecked {
                allowed.amount -= amount;
            }

            allowances[from][token][spender] = allowed;
        }
    }

    /**
     * @dev Execute token transfer with safety checks using SafeERC20
     * @param from Token sender address that must have approved this contract
     * @param token ERC20 token contract address to transfer
     * @param to Token recipient address that will receive the tokens
     * @param amount Transfer amount in token units (max uint160)
     * @notice This function uses SafeERC20.safeTransferFrom to handle tokens that:
     *         - Don't return a boolean value
     *         - Return false on failure instead of reverting
     *         - Have other non-standard transfer implementations
     * @notice The function assumes the caller has already verified allowances
     *         and will revert if the transfer fails for any reason
     */
    function _transferFrom(address from, address to, uint160 amount, address token) internal {
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    // ========== MULTI-TOKEN FUNCTIONS ==========

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
                from, encodedId, msg.sender, 1
            );
            if (revertDataWildcard.length > 0) {
                // TODO if revertDataPerId.selector == InsufficientAllowance.selector, we should revert with revertDataWildcard
                _revert(revertDataPerId);
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
                // TODO if revertDataPerId.selector == InsufficientAllowance.selector, we should revert with revertDataWildcard
                _revert(revertDataPerId);
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
    ) external override {
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
    ) external override {
        uint256 transfersLength = transfers.length;
        if (transfersLength == 0) {
            revert EmptyArray();
        }

        for (uint256 i = 0; i < transfersLength; i++) {
            transferFromERC1155(
                transfers[i].from, transfers[i].to, transfers[i].tokenId, transfers[i].amount, transfers[i].token
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
            revert IvalidArrayLength();
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
