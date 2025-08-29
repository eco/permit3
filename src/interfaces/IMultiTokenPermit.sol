// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IMultiTokenPermit
 * @notice Interface for multi-token support (ERC20, ERC721, ERC1155) in the Permit3 system
 * @dev Extends the existing permit system to handle NFTs and semi-fungible tokens
 */
interface IMultiTokenPermit {
    /**
     * @notice Enum representing different token standards
     * @param ERC20 Standard fungible tokens with divisible amounts
     * @param ERC721 Non-fungible tokens with unique token IDs
     * @param ERC1155 Semi-fungible tokens with both ID and amount
     */
    enum TokenStandard {
        ERC20,
        ERC721,
        ERC1155
    }

    /**
     * @notice Transfer details for ERC721 tokens
     * @param from Token owner
     * @param to Token recipient
     * @param tokenId The specific NFT token ID
     * @param token The ERC721 contract address
     */
    struct ERC721TransferDetails {
        address from;
        address to;
        uint256 tokenId;
        address token;
    }

    /**
     * @notice Unified transfer details for any token type
     * @param from Token owner
     * @param to Transfer recipient
     * @param token Token contract address
     * @param tokenId Token ID (used for ERC721 and ERC1155, ignored for ERC20)
     * @param amount Transfer amount (used for ERC20 and ERC1155, must be 1 for ERC721)
     */
    struct MultiTokenTransfer {
        address from;
        address to;
        address token;
        uint256 tokenId;
        uint160 amount;
    }

    /**
     * @notice Batch ERC1155 transfer details
     * @param from Token owner
     * @param to Token recipient
     * @param tokenIds Array of ERC1155 token IDs
     * @param amounts Array of amounts corresponding to each token ID
     * @param token The ERC1155 contract address
     */
    struct ERC1155BatchTransferDetails {
        address from;
        address to;
        uint256[] tokenIds;
        uint256[] amounts;
        address token;
    }

    /**
     * @notice Multi-token transfer instruction
     * @param tokenType The type of token (ERC20, ERC721, or ERC1155)
     * @param transferDetails The transfer details
     */
    struct TokenTypeTransfer {
        TokenStandard tokenType;
        MultiTokenTransfer transfer;
    }

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
    ) external view returns (bool approved, uint128 amount, uint48 expiration, uint48 timestamp);

    /**
     * @notice Execute approved ERC721 token transfer
     * @param from Token owner
     * @param to Transfer recipient
     * @param tokenId The NFT token ID
     * @param token ERC721 token address
     */
    function transferFromERC721(address from, address to, uint256 tokenId, address token) external;

    /**
     * @notice Execute approved ERC1155 token transfer
     * @param from Token owner
     * @param to Transfer recipient
     * @param tokenId The ERC1155 token ID
     * @param amount Transfer amount
     * @param token ERC1155 token address
     */
    function transferFromERC1155(address from, address to, uint256 tokenId, uint128 amount, address token) external;

    /**
     * @notice Execute approved ERC1155 batch transfer
     * @param transfer Batch transfer details for multiple token IDs
     */
    function batchTransferFromERC1155(
        ERC1155BatchTransferDetails calldata transfer
    ) external;

    /**
     * @notice Execute multiple token transfers of any type in a single transaction
     * @param transfers Array of multi-token transfer instructions
     */
    function batchTransferFrom(
        TokenTypeTransfer[] calldata transfers
    ) external;
}
