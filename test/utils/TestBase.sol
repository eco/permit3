// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Test } from "forge-std/Test.sol";

import "../../src/Permit3.sol";
import "../../src/interfaces/IPermit3.sol";

import "./TestUtils.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title TestBase
 * @notice Unified base test contract for all Permit3 tests
 * @dev Contains common setup and helper functions to reduce duplication
 */
contract TestBase is Test {
    using ECDSA for bytes32;
    using Permit3TestUtils for Permit3;

    // Contracts
    Permit3 permit3;
    MockToken token;

    // Test accounts
    uint256 ownerPrivateKey;
    address owner;
    address spender;
    address recipient;

    // Constants
    bytes32 constant SALT = bytes32(uint256(0));
    uint160 constant AMOUNT = 1000;
    uint48 constant EXPIRATION = 1000;
    uint48 constant NOW = 1000;

    // Events
    event NonceUsed(address indexed owner, bytes32 indexed salt);
    event Approval(
        address indexed owner, address indexed token, address indexed spender, uint160 amount, uint48 expiration
    );
    event Lockdown(address indexed owner, address indexed token, address indexed spender);

    function setUp() public virtual {
        vm.warp(NOW);
        permit3 = new Permit3();
        token = new MockToken();

        ownerPrivateKey = 0x1234;
        owner = vm.addr(ownerPrivateKey);
        spender = address(0x2);
        recipient = address(0x3);

        deal(address(token), owner, 10_000);
        vm.prank(owner);
        token.approve(address(permit3), type(uint256).max);
    }

    // Common helper functions
    function _getDigest(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", permit3.DOMAIN_SEPARATOR(), structHash));
    }

    // Use permit3.hashChainPermits directly instead of this function

    // Create a basic transfer permit
    function _createBasicTransferPermit() internal view returns (IPermit3.ChainPermits memory) {
        return Permit3TestUtils.createTransferPermit(address(token), recipient, AMOUNT);
    }

    // Sign a permit
    function _signPermit(
        IPermit3.ChainPermits memory chainPermits,
        uint48 deadline,
        uint48 timestamp,
        bytes32 salt
    ) internal view returns (bytes memory) {
        bytes32 permitDataHash = IPermit3(address(permit3)).hashChainPermits(chainPermits);

        bytes32 signedHash =
            keccak256(abi.encode(permit3.PERMIT3_TYPEHASH(), owner, salt, deadline, timestamp, permitDataHash));

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // Sign an unbalanced permit
    function _signUnbalancedPermit(
        IPermit3.ChainPermits memory permits,
        bytes32[] memory proof,
        uint48 deadline,
        uint48 timestamp,
        bytes32 salt
    ) internal view returns (bytes memory) {
        // Calculate the current chain hash (leaf)
        bytes32 currentChainHash = IPermit3(address(permit3)).hashChainPermits(permits);

        // Calculate the merkle root using standard merkle tree logic
        bytes32 merkleRoot = currentChainHash;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            // Standard merkle ordering: smaller value first
            if (merkleRoot <= proofElement) {
                merkleRoot = keccak256(abi.encodePacked(merkleRoot, proofElement));
            } else {
                merkleRoot = keccak256(abi.encodePacked(proofElement, merkleRoot));
            }
        }

        // Create the signature
        bytes32 signedHash =
            keccak256(abi.encode(permit3.PERMIT3_TYPEHASH(), owner, salt, deadline, timestamp, merkleRoot));

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // Mock nonce manager for internal testing
    function exposed_hashTypedDataV4(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return _getDigest(structHash);
    }

    // Helper struct for witness tests
    struct WitnessTestParams {
        bytes32 salt;
        uint48 deadline;
        uint48 timestamp;
        IPermit3.ChainPermits chainPermits;
        bytes32 witness;
        string witnessTypeString;
        bytes signature;
    }

    // Helper struct for nonce invalidation tests to avoid stack too deep
    struct WithProofParams {
        bytes32 testSalt;
        bytes32[] salts;
        INonceManager.NoncesToInvalidate invalidations;
        bytes32 merkleRoot;
        bytes32[] proof;
        uint48 deadline;
        bytes32 invalidationsHash;
        bytes32 signedHash;
        bytes32 digest;
        bytes signature;
    }

    // Helper for nonce invalidation struct hash
    function _getInvalidationStructHash(
        address ownerAddress,
        uint48 deadline,
        INonceManager.NoncesToInvalidate memory invalidations
    ) internal view returns (bytes32) {
        // For simple signed invalidation, hash the NoncesToInvalidate struct according to EIP-712
        bytes32 invalidationsHash = keccak256(
            abi.encode(
                permit3.NONCES_TO_INVALIDATE_TYPEHASH(),
                invalidations.chainId,
                keccak256(abi.encodePacked(invalidations.salts))
            )
        );
        return keccak256(abi.encode(permit3.INVALIDATE_NONCES_TYPEHASH(), ownerAddress, deadline, invalidationsHash));
    }

    // Helper for tree-based invalidation struct hash (multi-chain with proof)
    function _getUnbalancedInvalidationStructHash(
        address ownerAddress,
        uint48 deadline,
        INonceManager.NoncesToInvalidate memory invalidations,
        bytes32[] memory proof
    ) internal view returns (bytes32) {
        // For tree-based multi-chain invalidation:
        // 1. Hash the current chain's nonces to get the leaf hash
        bytes32 currentNoncesHash = permit3.hashNoncesToInvalidate(invalidations);

        // 2. For tests with empty proof, the tree hash equals the leaf hash
        // In real usage, TreeNodeLib.computeTreeHash would reconstruct the full tree
        bytes32 treeHash = currentNoncesHash;

        // 3. Sign over the tree hash using MULTICHAIN_INVALIDATE_NONCES_TYPEHASH
        return keccak256(abi.encode(permit3.MULTICHAIN_INVALIDATE_NONCES_TYPEHASH(), ownerAddress, deadline, treeHash));
    }

    // Helper function for witness signing
    function _signWitnessPermit(
        IPermit3.ChainPermits memory chainPermits,
        bytes32 witness,
        string memory witnessTypeString,
        uint48 deadline,
        uint48 timestamp,
        bytes32 salt
    ) internal view returns (bytes memory) {
        bytes32 permitDataHash = IPermit3(address(permit3)).hashChainPermits(chainPermits);

        // Get witness type hash
        bytes32 typeHash = keccak256(abi.encodePacked(permit3.PERMIT_WITNESS_TYPEHASH_STUB(), witnessTypeString));

        // Create signed hash
        bytes32 signedHash = keccak256(abi.encode(typeHash, owner, salt, deadline, timestamp, permitDataHash, witness));

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // ============================================
    // Tree-based Nonce Cancellation Helpers
    // ============================================

    /**
     * @dev Sign a NonceNode tree for cancellation
     * @param ownerAddress Whose nonces are being cancelled
     * @param deadline Signature expiration
     * @param nonceNodeHash Hash of the NonceNode tree
     * @return signature EIP-712 signature
     */
    function _signNonceTreeCancellation(
        address ownerAddress,
        uint48 deadline,
        bytes32 nonceNodeHash
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(permit3.MULTICHAIN_INVALIDATE_NONCES_TYPEHASH(), ownerAddress, deadline, nonceNodeHash)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit3.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /**
     * @dev Helper to compute NonceNode hash manually in tests
     * @dev IMPORTANT: Must match TreeNodeLib reconstruction behavior for tree-based nonce cancellation
     * @dev SORTS hashes to match TreeNodeLib.combineLeafAndLeaf and combineNodeAndNode
     */
    function _hashNonceNode(
        INonceManager.NonceNode memory nonceNode
    ) internal view returns (bytes32) {
        bytes32 nodesArrayHash;
        bytes32 noncesArrayHash;

        {
            bytes32[] memory nodeHashes = new bytes32[](nonceNode.nodes.length);
            for (uint256 i = 0; i < nonceNode.nodes.length; i++) {
                nodeHashes[i] = _hashNonceNode(nonceNode.nodes[i]);
            }
            // Sort node hashes to match TreeNodeLib.combineNodeAndNode behavior
            _sortBytes32Array(nodeHashes);
            nodesArrayHash = keccak256(abi.encodePacked(nodeHashes));
        }

        {
            bytes32[] memory nonceHashes = new bytes32[](nonceNode.nonces.length);
            for (uint256 i = 0; i < nonceNode.nonces.length; i++) {
                // Hash each NoncesToInvalidate struct
                // For single nonce, use the nonce directly (matches hashNoncesToInvalidate logic)
                if (nonceNode.nonces[i].salts.length == 1) {
                    nonceHashes[i] = nonceNode.nonces[i].salts[0];
                } else {
                    // Multiple nonces - sort and hash as NoncesToInvalidate struct
                    bytes32[] memory sortedSalts = new bytes32[](nonceNode.nonces[i].salts.length);
                    for (uint256 j = 0; j < nonceNode.nonces[i].salts.length; j++) {
                        sortedSalts[j] = nonceNode.nonces[i].salts[j];
                    }
                    _sortBytes32Array(sortedSalts);

                    nonceHashes[i] = keccak256(
                        abi.encode(
                            permit3.NONCES_TO_INVALIDATE_TYPEHASH(),
                            nonceNode.nonces[i].chainId,
                            keccak256(abi.encodePacked(sortedSalts))
                        )
                    );
                }
            }
            // Sort nonce hashes to match TreeNodeLib.combineLeafAndLeaf behavior
            _sortBytes32Array(nonceHashes);
            noncesArrayHash = keccak256(abi.encodePacked(nonceHashes));
        }

        bytes32 NONCE_NODE_TYPEHASH = keccak256(
            "NonceNode(NonceNode[] nodes,NoncesToInvalidate[] nonces)NoncesToInvalidate(uint64 chainId,bytes32[] salts)"
        );

        return keccak256(abi.encode(NONCE_NODE_TYPEHASH, nodesArrayHash, noncesArrayHash));
    }

    /**
     * @dev Helper to sort an array of bytes32 values (bubble sort for simplicity)
     */
    function _sortBytes32Array(
        bytes32[] memory arr
    ) internal pure {
        uint256 n = arr.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (arr[i] > arr[j]) {
                    bytes32 temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
    }

    /**
     * @dev Helper to build NonceNode with just nonces (no child nodes)
     * @dev Creates a single NoncesToInvalidate struct containing all salts for the current chain
     */
    function _buildNonceNodeWithNonces(
        bytes32[] memory salts
    ) internal view returns (INonceManager.NonceNode memory) {
        // Create a single NoncesToInvalidate struct containing all salts for this chain
        // This is the correct structure: one struct per chain, not one per nonce
        INonceManager.NoncesToInvalidate[] memory nonces = new INonceManager.NoncesToInvalidate[](1);
        nonces[0] = INonceManager.NoncesToInvalidate({ chainId: uint64(block.chainid), salts: salts });
        INonceManager.NonceNode memory node =
            INonceManager.NonceNode({ nodes: new INonceManager.NonceNode[](0), nonces: nonces });
        return node;
    }

    /**
     * @notice Unwrap single-child nodes to find the effective root for signing
     * @dev When a NonceNode has exactly one child node and no nonces, it's a wrapper
     *      that doesn't contribute to the Merkle proof. This function unwraps such nodes
     *      to find the first node with meaningful structure (has siblings or nonces).
     * @param node The NonceNode tree to unwrap
     * @return The unwrapped NonceNode (first node with siblings or the leaf node)
     */
    function _unwrapTree(
        INonceManager.NonceNode memory node
    ) internal pure returns (INonceManager.NonceNode memory) {
        // Keep unwrapping while node has exactly 1 child and no nonces
        while (node.nodes.length == 1 && node.nonces.length == 0) {
            node = node.nodes[0];
        }
        return node;
    }

    /**
     * @notice Generate proof and proof structure encoding for NonceNode
     * @dev This function implements the algorithm from permitNodeHelpers.js (findNonceMerklePath)
     * @dev IMPORTANT: This function unwraps single-child wrapper nodes. The returned proof
     *      is relative to the unwrapped tree, and the hash to sign should be computed from
     *      the unwrapped tree using _unwrapTree().
     * @param nonceTree Complete NonceNode tree structure
     * @param targetNonces Array of nonces to prove
     * @return proof Array of sibling hashes (leaf to root)
     * @return proofStructure Encoded position + type flags
     * @return position Position in sibling array
     */
    function _generateNonceProof(
        INonceManager.NonceNode memory nonceTree,
        bytes32[] memory targetNonces
    ) internal view returns (bytes32[] memory proof, bytes32 proofStructure, uint256 position) {
        // Unwrap single-child wrapper nodes first
        INonceManager.NonceNode memory unwrappedTree = _unwrapTree(nonceTree);

        // Find the path to the target nonces in the unwrapped tree
        (bool found, bytes32[] memory proofPath, uint256[] memory typeFlags, uint256 pos) =
            _findNoncePath(unwrappedTree, targetNonces, 0);

        require(found, "Target nonces not found in tree");

        proof = proofPath;
        position = pos;

        // Encode proofStructure: position (byte 0) + type flags (bits 247-i)
        uint256 proofStructureValue = position << 248;

        // Pack type flags starting from bit 247 down
        for (uint256 i = 0; i < typeFlags.length; i++) {
            if (typeFlags[i] == 1) {
                // Bit position: 255 - 8 - i = 247 - i
                uint256 bitPosition = 247 - i;
                proofStructureValue |= (1 << bitPosition);
            }
        }

        proofStructure = bytes32(proofStructureValue);
    }

    /**
     * @dev Internal recursive function to find nonces in the tree
     * @return found Whether the nonces were found
     * @return proof Array of sibling hashes
     * @return typeFlags Array of type flags (0=nonce, 1=node)
     * @return position Position index
     */
    function _findNoncePath(
        INonceManager.NonceNode memory node,
        bytes32[] memory targetNonces,
        uint256 depth
    ) internal view returns (bool found, bytes32[] memory proof, uint256[] memory typeFlags, uint256 position) {
        // Check if targetNonces match this node's nonces exactly
        if (_arrayEquals(node.nonces, targetNonces)) {
            // Found the target! Build the proof path
            proof = new bytes32[](0);
            typeFlags = new uint256[](0);
            position = 0;

            // Check if there are nodes at this level (mixed Node+Nonce case)
            if (node.nodes.length > 0 && node.nonces.length > 0) {
                // Node+Nonce combination: sibling is the node
                proof = new bytes32[](1);
                proof[0] = _hashNonceNode(node.nodes[0]);
                typeFlags = new uint256[](1);
                typeFlags[0] = 1; // Sibling is a Node
            } else if (
                node.nonces.length == 1 && node.nonces[0].salts.length == 2 && targetNonces.length == 1
                    && node.nodes.length == 0
            ) {
                // Nonce+Nonce combination: sibling is the other nonce (within the same NoncesToInvalidate struct)
                int256 targetIndex = _findNonceIndex(node.nonces, targetNonces[0]);
                if (targetIndex >= 0) {
                    uint256 siblingIndex = uint256(targetIndex) == 0 ? 1 : 0;
                    proof = new bytes32[](1);
                    proof[0] = node.nonces[0].salts[siblingIndex];
                    typeFlags = new uint256[](1);
                    typeFlags[0] = 0; // Sibling is a Nonce
                    position = uint256(targetIndex);
                }
            }

            return (true, proof, typeFlags, position);
        }

        // Check if targetNonces is a subset of this node's nonces array
        if (node.nonces.length > 0 && _isSubset(targetNonces, node.nonces)) {
            // Found target nonces in this node's nonces array
            // Build proof with remaining nonces
            bytes32[] memory remainingNonces = _getRemainingNonces(node.nonces, targetNonces);

            proof = remainingNonces;
            typeFlags = new uint256[](remainingNonces.length);
            // All remaining elements are nonces (type = 0)
            for (uint256 i = 0; i < remainingNonces.length; i++) {
                typeFlags[i] = 0;
            }

            position = 0; // For multi-nonce cancellation, position is 0

            // If there are also nodes at this level, add them to the proof
            if (node.nodes.length > 0) {
                uint256 oldProofLength = proof.length;
                uint256 newProofLength = oldProofLength + node.nodes.length;
                bytes32[] memory newProof = new bytes32[](newProofLength);
                uint256[] memory newTypeFlags = new uint256[](newProofLength);

                // Copy existing nonces
                for (uint256 i = 0; i < oldProofLength; i++) {
                    newProof[i] = proof[i];
                    newTypeFlags[i] = typeFlags[i];
                }

                // Add node hashes
                for (uint256 i = 0; i < node.nodes.length; i++) {
                    newProof[oldProofLength + i] = _hashNonceNode(node.nodes[i]);
                    newTypeFlags[oldProofLength + i] = 1; // Node type
                }

                proof = newProof;
                typeFlags = newTypeFlags;
            }

            return (true, proof, typeFlags, position);
        }

        // Not found in direct nonces, search in child nodes
        for (uint256 i = 0; i < node.nodes.length; i++) {
            (bool childFound, bytes32[] memory childProof, uint256[] memory childTypeFlags, uint256 childPos) =
                _findNoncePath(node.nodes[i], targetNonces, depth + 1);

            if (childFound) {
                // Found in this child! Build the return proof
                return _buildProofFromChild(node, i, childProof, childTypeFlags, childPos);
            }
        }

        // Not found in this subtree
        return (false, new bytes32[](0), new uint256[](0), 0);
    }

    /**
     * @dev Helper to build proof when found in a child node
     */
    function _buildProofFromChild(
        INonceManager.NonceNode memory node,
        uint256 childIndex,
        bytes32[] memory childProof,
        uint256[] memory childTypeFlags,
        uint256 childPos
    ) internal view returns (bool found, bytes32[] memory proof, uint256[] memory typeFlags, uint256 position) {
        // Check if there's a sibling at this level
        bytes32 siblingHash;
        uint256 siblingType;
        bool hasSibling = false;

        if (node.nodes.length == 2 && node.nonces.length == 0) {
            // Two nodes, no nonces
            siblingHash = _hashNonceNode(node.nodes[childIndex == 0 ? 1 : 0]);
            siblingType = 1;
            hasSibling = true;
        } else if (node.nodes.length == 1 && node.nonces.length > 0) {
            // One node + nonces - create a wrapper node for the nonces array
            INonceManager.NonceNode memory noncesNode =
                INonceManager.NonceNode({ nodes: new INonceManager.NonceNode[](0), nonces: node.nonces });
            siblingHash = _hashNonceNode(noncesNode);
            siblingType = 1; // Sibling is a Node (wrapped nonces array)
            hasSibling = true;
        }

        // Build proof array
        uint256 newLen = hasSibling ? childProof.length + 1 : childProof.length;
        proof = new bytes32[](newLen);
        typeFlags = new uint256[](newLen);

        // Copy child proof
        for (uint256 j = 0; j < childProof.length; j++) {
            proof[j] = childProof[j];
            typeFlags[j] = childTypeFlags[j];
        }

        // Add sibling if present
        if (hasSibling) {
            proof[newLen - 1] = siblingHash;
            typeFlags[newLen - 1] = siblingType;
        }

        return (true, proof, typeFlags, childPos);
    }

    /**
     * @dev Helper to check if two nonce arrays are equal (comparing NoncesToInvalidate[] against target bytes32[])
     */
    function _arrayEquals(
        INonceManager.NoncesToInvalidate[] memory noncesArray,
        bytes32[] memory targetSalts
    ) internal pure returns (bool) {
        // Check if noncesArray has exactly one element and its salts match targetSalts
        if (noncesArray.length != 1) {
            return false;
        }

        bytes32[] memory salts = noncesArray[0].salts;
        if (salts.length != targetSalts.length) {
            return false;
        }

        // For small arrays, we can do a simple comparison
        // We assume arrays are in the same order as provided
        for (uint256 i = 0; i < salts.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < targetSalts.length; j++) {
                if (salts[i] == targetSalts[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Helper to find index of a nonce in NoncesToInvalidate array
     * @return Index as int256, or -1 if not found
     */
    function _findNonceIndex(
        INonceManager.NoncesToInvalidate[] memory noncesArray,
        bytes32 target
    ) internal pure returns (int256) {
        // Search in the first NoncesToInvalidate struct's salts
        if (noncesArray.length == 0) {
            return -1;
        }
        bytes32[] memory salts = noncesArray[0].salts;
        for (uint256 i = 0; i < salts.length; i++) {
            if (salts[i] == target) {
                return int256(i);
            }
        }
        return -1;
    }

    /**
     * @dev Helper to check if targetNonces is a subset of nonces
     */
    function _isSubset(
        bytes32[] memory targetNonces,
        INonceManager.NoncesToInvalidate[] memory noncesArray
    ) internal pure returns (bool) {
        if (noncesArray.length == 0) {
            return false;
        }
        bytes32[] memory salts = noncesArray[0].salts;

        if (targetNonces.length > salts.length) {
            return false;
        }
        if (targetNonces.length == 0) {
            return false;
        }

        for (uint256 i = 0; i < targetNonces.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < salts.length; j++) {
                if (targetNonces[i] == salts[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Helper to get remaining nonces after removing targetNonces
     */
    function _getRemainingNonces(
        INonceManager.NoncesToInvalidate[] memory noncesArray,
        bytes32[] memory targetNonces
    ) internal pure returns (bytes32[] memory) {
        if (noncesArray.length == 0) {
            return new bytes32[](0);
        }
        bytes32[] memory salts = noncesArray[0].salts;

        // Count how many nonces remain
        uint256 remainingCount = 0;
        for (uint256 i = 0; i < salts.length; i++) {
            bool isTarget = false;
            for (uint256 j = 0; j < targetNonces.length; j++) {
                if (salts[i] == targetNonces[j]) {
                    isTarget = true;
                    break;
                }
            }
            if (!isTarget) {
                remainingCount++;
            }
        }

        // Build remaining array
        bytes32[] memory remaining = new bytes32[](remainingCount);
        uint256 idx = 0;
        for (uint256 i = 0; i < salts.length; i++) {
            bool isTarget = false;
            for (uint256 j = 0; j < targetNonces.length; j++) {
                if (salts[i] == targetNonces[j]) {
                    isTarget = true;
                    break;
                }
            }
            if (!isTarget) {
                remaining[idx] = salts[i];
                idx++;
            }
        }

        return remaining;
    }

    /**
     * @dev Helper to hash a PermitNode tree structure
     * @dev Recursively computes EIP-712 hash with proper sorting
     */
    function _hashPermitNode(
        IPermit3.PermitNode memory permitNode
    ) internal view returns (bytes32) {
        bytes32 nodesArrayHash;
        bytes32 permitsArrayHash;

        {
            bytes32[] memory nodeHashes = new bytes32[](permitNode.nodes.length);
            for (uint256 i = 0; i < permitNode.nodes.length; i++) {
                nodeHashes[i] = _hashPermitNode(permitNode.nodes[i]);
            }
            // Sort node hashes to match TreeNodeLib.combineNodeAndNode behavior
            _sortBytes32Array(nodeHashes);
            nodesArrayHash = keccak256(abi.encodePacked(nodeHashes));
        }

        {
            bytes32[] memory permitHashes = new bytes32[](permitNode.permits.length);
            for (uint256 i = 0; i < permitNode.permits.length; i++) {
                permitHashes[i] = IPermit3(address(permit3)).hashChainPermits(permitNode.permits[i]);
            }
            // Sort permit hashes to match TreeNodeLib.combineLeafAndLeaf behavior
            _sortBytes32Array(permitHashes);
            permitsArrayHash = keccak256(abi.encodePacked(permitHashes));
        }

        bytes32 PERMIT_NODE_TYPEHASH = keccak256(
            "PermitNode(PermitNode[] nodes,ChainPermits[] permits)AllowanceOrTransfer(uint48 modeOrExpiration,bytes32 tokenKey,address account,uint160 amountDelta)ChainPermits(uint64 chainId,AllowanceOrTransfer[] permits)"
        );

        return keccak256(abi.encode(PERMIT_NODE_TYPEHASH, nodesArrayHash, permitsArrayHash));
    }

    /**
     * @dev Helper to sort an array of bytes32 values (bubble sort for simplicity)
     */
    function _sortBytes32Array(
        bytes32[] memory arr
    ) internal pure {
        uint256 n = arr.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (arr[i] > arr[j]) {
                    bytes32 temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
    }
}
