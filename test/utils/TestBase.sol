// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Permit3.sol";
import "../../src/interfaces/IPermit3.sol";
import "../../src/lib/UnhingedMerkleTree.sol";
import "./TestUtils.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Test } from "forge-std/Test.sol";

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
            keccak256(abi.encode(permit3.SIGNED_PERMIT3_TYPEHASH(), owner, salt, deadline, timestamp, permitDataHash));

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // Helper struct to avoid stack too deep errors in _signUnhingedPermit
    struct UnhingedSignParams {
        bytes32 currentChainHash;
        uint120 subtreeProofCount;
        uint120 followingHashesCount;
        bool hasPreHash;
        bytes32 preHash;
        bytes32 subtreeRoot;
        bytes32 unhingedRoot;
        bytes32 signedHash;
        bytes32 digest;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 nodeIndex;
    }

    // Sign an unhinged permit
    function _signUnhingedPermit(
        IPermit3.UnhingedPermitProof memory proof,
        uint48 deadline,
        uint48 timestamp,
        bytes32 salt
    ) internal view returns (bytes memory) {
        UnhingedSignParams memory params;

        // Calculate the unhinged root the same way the contract would
        params.currentChainHash = IPermit3(address(permit3)).hashChainPermits(proof.permits);

        // Extract counts from packed data using the new format
        uint256 value = uint256(proof.unhingedProof.counts);
        params.subtreeProofCount = uint120(value >> 136); // First 120 bits
        params.followingHashesCount = uint120((value >> 16) & ((1 << 120) - 1)); // Next 120 bits
        params.hasPreHash = (value & 1) == 1; // Last bit

        params.nodeIndex = 0; // Track the current node index

        // Extract preHash if present
        if (params.hasPreHash) {
            params.preHash = proof.unhingedProof.nodes[params.nodeIndex++];
        } else {
            params.preHash = bytes32(0); // Use default value if no preHash
        }

        // Calculate subtree root using the proper method that matches the contract
        if (params.subtreeProofCount > 0) {
            // Create subtree proof array
            bytes32[] memory subtreeProof = new bytes32[](params.subtreeProofCount);
            for (uint256 i = 0; i < params.subtreeProofCount; i++) {
                subtreeProof[i] = proof.unhingedProof.nodes[params.nodeIndex + i];
            }

            // Use the balanced subtree verification logic
            params.subtreeRoot = params.currentChainHash;

            for (uint256 i = 0; i < params.subtreeProofCount; i++) {
                bytes32 proofElement = subtreeProof[i];

                if (params.subtreeRoot <= proofElement) {
                    params.subtreeRoot = keccak256(abi.encodePacked(params.subtreeRoot, proofElement));
                } else {
                    params.subtreeRoot = keccak256(abi.encodePacked(proofElement, params.subtreeRoot));
                }
            }
            params.nodeIndex += params.subtreeProofCount;
        } else {
            // If no subtree proof, the leaf is the subtree root
            params.subtreeRoot = params.currentChainHash;
        }

        // Calculate the unhinged root exactly as the contract does
        if (params.hasPreHash) {
            params.unhingedRoot = params.preHash;
            params.unhingedRoot = keccak256(abi.encodePacked(params.unhingedRoot, params.subtreeRoot));
        } else {
            params.unhingedRoot = params.subtreeRoot;
        }

        // Add all following chain hashes
        for (uint256 i = 0; i < params.followingHashesCount; i++) {
            params.unhingedRoot =
                keccak256(abi.encodePacked(params.unhingedRoot, proof.unhingedProof.nodes[params.nodeIndex + i]));
        }

        // Create the signature
        params.signedHash = keccak256(
            abi.encode(permit3.SIGNED_PERMIT3_TYPEHASH(), owner, salt, deadline, timestamp, params.unhingedRoot)
        );

        params.digest = _getDigest(params.signedHash);
        (params.v, params.r, params.s) = vm.sign(ownerPrivateKey, params.digest);
        return abi.encodePacked(params.r, params.s, params.v);
    }

    // Mock nonce manager for internal testing
    function exposed_hashTypedDataV4(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return _getDigest(structHash);
    }

    // Helper for nonce invalidation struct hash
    function _getInvalidationStructHash(
        address ownerAddress,
        uint48 deadline,
        INonceManager.NoncesToInvalidate memory invalidations
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                permit3.CANCEL_PERMIT3_TYPEHASH(), ownerAddress, deadline, permit3.hashNoncesToInvalidate(invalidations)
            )
        );
    }

    // Helper for unhinged invalidation struct hash
    function _getUnhingedInvalidationStructHash(
        address ownerAddress,
        uint48 deadline,
        INonceManager.UnhingedCancelPermitProof memory proof
    ) internal view returns (bytes32) {
        // For tests, manually calculate what the library would calculate
        // since we can't call library functions on memory structs
        bytes32 invalidationsHash = permit3.hashNoncesToInvalidate(proof.invalidations);
        // For a simple proof with no nodes, the root equals the leaf
        bytes32 unhingedRoot = invalidationsHash;
        return keccak256(abi.encode(permit3.CANCEL_PERMIT3_TYPEHASH(), ownerAddress, deadline, unhingedRoot));
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
        bytes32 unhingedRoot;
        INonceManager.UnhingedCancelPermitProof proof;
        uint48 deadline;
        bytes32 invalidationsHash;
        bytes32 signedHash;
        bytes32 digest;
        bytes signature;
    }
}
