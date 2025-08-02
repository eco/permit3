// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Permit3Tester } from "./utils/Permit3Tester.sol";
import { UnhingedMerkleTreeTester } from "./utils/UnhingedMerkleTreeTester.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Test } from "forge-std/Test.sol";

import "../src/Permit3.sol";

import "../src/interfaces/INonceManager.sol";
import "../src/interfaces/IPermit.sol";
import "../src/interfaces/IPermit3.sol";
import "../src/interfaces/IUnhingedMerkleTree.sol";

// Mock token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}

/**
 * @title Permit3EdgeTest
 * @notice Additional edge case tests specifically for high code coverage
 */
contract Permit3EdgeTest is Test {
    using ECDSA for bytes32;

    // Contracts
    Permit3 permit3;
    Permit3Tester permit3Tester;
    UnhingedMerkleTreeTester unhingedTree;
    MockToken token;

    // Key roles
    uint256 ownerPrivateKey;
    address owner;
    address spender;
    address recipient;

    // Constants
    bytes32 constant SALT = bytes32(uint256(0));
    uint160 constant AMOUNT = 1000;
    uint48 constant EXPIRATION = 2000;
    uint48 constant TIMESTAMP = 1000;

    // Witness data for testing
    bytes32 constant WITNESS = bytes32(uint256(0xDEADBEEF));
    string constant WITNESS_TYPE_STRING = "bytes32 witnessData)";
    string constant INVALID_WITNESS_TYPE_STRING = "bytes32 witnessData"; // Missing closing parenthesis

    // Structs to avoid stack-too-deep errors
    struct TestParams {
        bytes32 witness;
        string witnessTypeString;
        bytes32 salt;
        uint48 deadline;
        uint48 timestamp;
        bytes signature;
    }

    struct PermitInputs {
        IPermit3.AllowanceOrTransfer[] permits;
        IPermit3.ChainPermits chainPermits;
    }

    struct UnhingedWitnessTestVars {
        bytes32 currentChainHash;
        bytes32 unhingedRoot;
        bytes32 typeHash;
        bytes32 signedHash;
        bytes32 digest;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32[] subtreeProof;
        bytes32[] followingHashes;
        IUnhingedMerkleTree.UnhingedProof merkleProof;
        IPermit3.UnhingedPermitProof unhingedProof;
    }

    function setUp() public {
        vm.warp(TIMESTAMP);
        permit3 = new Permit3();
        permit3Tester = new Permit3Tester();
        unhingedTree = new UnhingedMerkleTreeTester();
        token = new MockToken();

        ownerPrivateKey = 0x1234;
        owner = vm.addr(ownerPrivateKey);
        spender = address(0x2);
        recipient = address(0x3);

        deal(address(token), owner, 10_000);
        vm.prank(owner);
        token.approve(address(permit3), type(uint256).max);
    }

    function test_permitBatchWithEmptyArray() public {
        // Create empty permits array
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](0);
        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        TestParams memory params;
        params.salt = bytes32(uint256(0x123));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp);

        // Sign the permit
        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );
        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Execute permit with empty array - should succeed but do nothing
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify nonce is used
        assertTrue(permit3.isNonceUsed(owner, params.salt));
    }

    function test_permitWitnessInvalidTypeString() public {
        // Create test parameters with invalid witness type string
        TestParams memory params;
        params.witness = keccak256("witness data");
        params.witnessTypeString = "invalid(no closing parenthesis"; // Invalid - missing closing )
        params.salt = bytes32(uint256(0x456));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp);

        // Create a basic permit
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0,
            token: address(token),
            account: recipient,
            amountDelta: AMOUNT
        });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Create dummy signature (won't reach validation)
        params.signature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));

        // Should revert with InvalidWitnessTypeString
        vm.expectRevert(abi.encodeWithSelector(INonceManager.InvalidWitnessTypeString.selector));
        permit3.permitWitnessTransferFrom(
            owner,
            params.salt,
            params.deadline,
            params.timestamp,
            inputs.chainPermits,
            params.witness,
            params.witnessTypeString,
            params.signature
        );
    }

    function test_getUnhingedWitnessTypeHash() public {
        // Test the _getUnhingedWitnessTypeHash function through a witness permit
        TestParams memory params;
        params.witness = keccak256("witness data");
        params.witnessTypeString = "bytes32 customData)";
        params.salt = bytes32(uint256(0x789));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp);

        // Create basic transfer
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0,
            token: address(token),
            account: recipient,
            amountDelta: AMOUNT
        });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Create additional variables in a separate struct to avoid stack-too-deep
        UnhingedWitnessTestVars memory vars;

        // Create unhinged proof
        vars.subtreeProof = new bytes32[](0);
        vars.followingHashes = new bytes32[](0);

        // Create the optimized proof explicitly with no preHash flag
        bytes32[] memory emptyNodes = new bytes32[](0);
        vars.merkleProof = IUnhingedMerkleTree.UnhingedProof({
            nodes: emptyNodes,
            counts: unhingedTree.packCounts(0, 0, false) // No preHash
         });

        vars.unhingedProof =
            IPermit3.UnhingedPermitProof({ permits: inputs.chainPermits, unhingedProof: vars.merkleProof });

        // Calculate the unhinged root
        vars.currentChainHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        vars.unhingedRoot = permit3Tester.calculateUnhingedRoot(vars.currentChainHash, vars.merkleProof);

        // Create the witness typehash - identical to what the contract would compute internally
        vars.typeHash = keccak256(abi.encodePacked(permit3.PERMIT_WITNESS_TYPEHASH_STUB(), params.witnessTypeString));

        // Create the signed hash
        vars.signedHash = keccak256(
            abi.encode(
                vars.typeHash, owner, params.salt, params.deadline, params.timestamp, vars.unhingedRoot, params.witness
            )
        );

        vars.digest = _getDigest(vars.signedHash);
        (vars.v, vars.r, vars.s) = vm.sign(ownerPrivateKey, vars.digest);
        params.signature = abi.encodePacked(vars.r, vars.s, vars.v);

        // Reset recipient balance
        deal(address(token), recipient, 0);

        // Execute unhinged witness permit
        permit3.permitWitnessTransferFrom(
            owner,
            params.salt,
            params.deadline,
            params.timestamp,
            vars.unhingedProof,
            params.witness,
            params.witnessTypeString,
            params.signature
        );

        // Verify the transfer happened
        assertEq(token.balanceOf(recipient), AMOUNT);
    }

    function test_verifyUnhingedProofInvalid() public {
        // Test the _verifyUnhingedProof function with invalid input
        TestParams memory params;
        params.salt = bytes32(uint256(0xabc));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp);

        // Create basic transfer
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0,
            token: address(token),
            account: recipient,
            amountDelta: AMOUNT
        });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Create invalid unhinged proof - invalid due to array length
        bytes32[] memory nodes = new bytes32[](1); // only preHash, no subtree elements
        nodes[0] = bytes32(uint256(123)); // preHash

        // Pack counts indicating we need 2 elements
        bytes32 counts = unhingedTree.packCounts(1, 0, true); // 1 subtree element, 0 following hashes, with preHash

        IUnhingedMerkleTree.UnhingedProof memory invalidProof =
            IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: counts });

        IPermit3.UnhingedPermitProof memory unhingedProof =
            IPermit3.UnhingedPermitProof({ permits: inputs.chainPermits, unhingedProof: invalidProof });

        // Create a simple signature (won't reach validation)
        params.signature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));

        // Should revert with InvalidUnhingedProof since _verifyUnhingedProof will return false
        vm.expectRevert(abi.encodeWithSelector(IUnhingedMerkleTree.InvalidUnhingedProof.selector));
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, unhingedProof, params.signature);
    }

    // Additional struct to avoid stack-too-deep in test_zeroSubtreeProofCount
    struct ZeroSubtreeProofVars {
        bytes32 preHash;
        bytes32[] subtreeProof;
        bytes32[] followingHashes;
        IUnhingedMerkleTree.UnhingedProof proof;
        IPermit3.UnhingedPermitProof unhingedProof;
        bytes32 currentChainHash;
        bytes32 unhingedRoot;
        bytes32 signedHash;
        bytes32 digest;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function test_zeroSubtreeProofCount() public {
        // Test with zero subtree proof count to exercise specific code paths
        TestParams memory params;
        params.salt = bytes32(uint256(0xdef));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp);

        // Create basic transfer
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0,
            token: address(token),
            account: recipient,
            amountDelta: AMOUNT
        });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Move complex variable declarations to a struct to avoid stack-too-deep
        ZeroSubtreeProofVars memory vars;

        // Create valid unhinged proof with zero subtree proof count but with preHash
        vars.preHash = bytes32(uint256(42));
        vars.subtreeProof = new bytes32[](0);
        vars.followingHashes = new bytes32[](1);
        vars.followingHashes[0] = bytes32(uint256(100));

        // Create the nodes array manually
        bytes32[] memory nodes = new bytes32[](2); // 1 for preHash, 1 for following hash
        nodes[0] = vars.preHash;
        nodes[1] = vars.followingHashes[0];

        // Create the proof with explicit hasPreHash flag
        vars.proof = IUnhingedMerkleTree.UnhingedProof({
            nodes: nodes,
            counts: unhingedTree.packCounts(0, 1, true) // 0 subtree nodes, 1 following hash, with preHash
         });

        vars.unhingedProof = IPermit3.UnhingedPermitProof({ permits: inputs.chainPermits, unhingedProof: vars.proof });

        // Calculate the unhinged root
        vars.currentChainHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        vars.unhingedRoot = permit3Tester.calculateUnhingedRoot(vars.currentChainHash, vars.proof);

        // Create signature
        vars.signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                params.salt,
                params.deadline,
                params.timestamp,
                vars.unhingedRoot
            )
        );

        vars.digest = _getDigest(vars.signedHash);
        (vars.v, vars.r, vars.s) = vm.sign(ownerPrivateKey, vars.digest);
        params.signature = abi.encodePacked(vars.r, vars.s, vars.v);

        // Reset recipient balance
        deal(address(token), recipient, 0);

        // Execute unhinged permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, vars.unhingedProof, params.signature);

        // Verify the transfer happened
        assertEq(token.balanceOf(recipient), AMOUNT);
    }

    function test_increaseAllowanceWithZeroDelta() public {
        // Create an initial allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, 100, uint48(block.timestamp + 1 days));

        // Verify initial allowance
        (uint160 initialAmount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(initialAmount, 100);

        // Create a permit with zero delta but newer timestamp (should only update expiration)
        TestParams memory params;
        params.salt = bytes32(uint256(0xf00d));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp + 100); // Newer timestamp

        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(block.timestamp + 2 days), // New expiration
            token: address(token),
            account: spender,
            amountDelta: 0 // Zero amount delta
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Sign the permit
        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Execute the permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance - amount should stay the same, only expiration should update
        (uint160 newAmount, uint48 newExpiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(newAmount, 100); // Amount unchanged
        assertEq(newExpiration, uint48(block.timestamp + 2 days)); // Expiration updated
    }

    function test_maxAllowanceWithIncrease() public {
        // Create a max allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, type(uint160).max, uint48(block.timestamp + 1 days));

        // Try to increase it further - should remain at MAX_ALLOWANCE
        TestParams memory params;
        params.salt = bytes32(uint256(0xbeef));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp + 100); // Newer timestamp

        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(block.timestamp + 2 days), // New expiration
            token: address(token),
            account: spender,
            amountDelta: 1000 // Additional amount (should be ignored)
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Sign the permit
        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Execute the permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance - amount should remain at MAX_ALLOWANCE
        (uint160 newAmount, uint48 newExpiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(newAmount, type(uint160).max); // Still MAX_ALLOWANCE
        assertEq(newExpiration, uint48(block.timestamp + 2 days)); // Expiration updated
    }

    // Additional struct to avoid stack-too-deep in test_transactionOrderProtection
    struct TransactionOrderVars {
        bytes32 olderDataHash;
        bytes32 olderSignedHash;
        bytes32 olderDigest;
        uint8 olderV;
        bytes32 olderR;
        bytes32 olderS;
        bytes32 newerDataHash;
        bytes32 newerSignedHash;
        bytes32 newerDigest;
        uint8 newerV;
        bytes32 newerR;
        bytes32 newerS;
        uint160 amount;
        uint48 expiration;
        uint48 timestamp;
    }

    function test_transactionOrderProtection() public {
        // Test the transaction ordering protection in the permit system

        // First set up an initial allowance with a specific timestamp
        vm.warp(10_000); // Set block.timestamp to a known value

        vm.prank(owner);
        permit3.approve(address(token), spender, 1000, uint48(block.timestamp + 1 days));

        // Create two permits with different timestamps
        TestParams memory olderParams;
        olderParams.salt = bytes32(uint256(0x111));
        olderParams.deadline = uint48(block.timestamp + 1 hours);
        olderParams.timestamp = uint48(9000); // Older timestamp

        TestParams memory newerParams;
        newerParams.salt = bytes32(uint256(0x222));
        newerParams.deadline = uint48(block.timestamp + 1 hours);
        newerParams.timestamp = uint48(11_000); // Newer timestamp

        // Create permits with different values
        PermitInputs memory olderInputs;
        olderInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        olderInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(block.timestamp + 3 days), // Tries to set longer expiration
            token: address(token),
            account: spender,
            amountDelta: 5000 // Higher amount
         });

        olderInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: olderInputs.permits });

        PermitInputs memory newerInputs;
        newerInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        newerInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(block.timestamp + 2 days), // Shorter expiration
            token: address(token),
            account: spender,
            amountDelta: 3000 // Lower amount
         });

        newerInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: newerInputs.permits });

        // Use struct to avoid stack-too-deep
        TransactionOrderVars memory vars;

        // Sign both permits
        vars.olderDataHash = permit3Tester.hashChainPermits(olderInputs.chainPermits);
        vars.olderSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                olderParams.salt,
                olderParams.deadline,
                olderParams.timestamp,
                vars.olderDataHash
            )
        );

        vars.olderDigest = _getDigest(vars.olderSignedHash);
        (vars.olderV, vars.olderR, vars.olderS) = vm.sign(ownerPrivateKey, vars.olderDigest);
        olderParams.signature = abi.encodePacked(vars.olderR, vars.olderS, vars.olderV);

        vars.newerDataHash = permit3Tester.hashChainPermits(newerInputs.chainPermits);
        vars.newerSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                newerParams.salt,
                newerParams.deadline,
                newerParams.timestamp,
                vars.newerDataHash
            )
        );

        vars.newerDigest = _getDigest(vars.newerSignedHash);
        (vars.newerV, vars.newerR, vars.newerS) = vm.sign(ownerPrivateKey, vars.newerDigest);
        newerParams.signature = abi.encodePacked(vars.newerR, vars.newerS, vars.newerV);

        // First apply the newer permit
        permit3.permit(
            owner,
            newerParams.salt,
            newerParams.deadline,
            newerParams.timestamp,
            newerInputs.chainPermits,
            newerParams.signature
        );

        // Check allowance - should be set by newer permit
        (vars.amount, vars.expiration, vars.timestamp) = permit3.allowance(owner, address(token), spender);
        assertEq(vars.amount, 4000); // 1000 original + 3000 from newer permit
        assertEq(vars.expiration, uint48(block.timestamp + 2 days)); // From newer permit
        assertEq(vars.timestamp, newerParams.timestamp); // Updated to newer timestamp

        // Now apply the older permit
        permit3.permit(
            owner,
            olderParams.salt,
            olderParams.deadline,
            olderParams.timestamp,
            olderInputs.chainPermits,
            olderParams.signature
        );

        // Check allowance again - older permit should only update amount, not expiration or timestamp
        (vars.amount, vars.expiration, vars.timestamp) = permit3.allowance(owner, address(token), spender);
        assertEq(vars.amount, 9000); // 4000 + 5000 from older permit
        assertEq(vars.expiration, uint48(block.timestamp + 2 days)); // Still from newer permit
        assertEq(vars.timestamp, newerParams.timestamp); // Still from newer permit
    }

    function test_calculateUnhingedRootInvalidLength() public {
        // Create an unhinged proof with invalid array length
        bytes32[] memory nodes = new bytes32[](2); // Only 2 nodes total
        nodes[0] = bytes32(uint256(1)); // preHash
        nodes[1] = bytes32(uint256(2)); // First subtree element

        // Pack counts indicating more nodes than actually in the array
        bytes32 counts = unhingedTree.packCounts(1, 2, true); // 1 subtree proof, 2 following hashes, with preHash

        IUnhingedMerkleTree.UnhingedProof memory invalidProof =
            IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: counts });

        // Try to calculate the root, should revert with InvalidNodeArrayLength
        bytes32 leaf = keccak256("leaf");
        vm.expectRevert(abi.encodeWithSelector(IUnhingedMerkleTree.InvalidNodeArrayLength.selector, 4, 2));
        permit3Tester.calculateUnhingedRoot(leaf, invalidProof);
    }

    function test_typehashStubs() public view {
        // Test the view functions for typehash stubs
        string memory permitStub = permit3.PERMIT_WITNESS_TYPEHASH_STUB();

        // Verify stubs match expected values
        assertEq(
            permitStub,
            "PermitWitnessTransferFrom(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 unhingedRoot,"
        );
    }

    function test_lockAndDecrease() public {
        // First set up an initial allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, 2000, uint48(block.timestamp + 1 days));

        // Create a permit to lock the allowance
        PermitInputs memory lockInputs;
        lockInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        lockInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Lock), // Lock mode (2)
            token: address(token),
            account: spender,
            amountDelta: 0 // Not used for lock
         });

        lockInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: lockInputs.permits });

        TestParams memory lockParams;
        lockParams.salt = bytes32(uint256(0x444));
        lockParams.deadline = uint48(block.timestamp + 1 hours);
        lockParams.timestamp = uint48(block.timestamp);

        // Sign the lock permit
        bytes32 lockDataHash = permit3Tester.hashChainPermits(lockInputs.chainPermits);
        bytes32 lockSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                lockParams.salt,
                lockParams.deadline,
                lockParams.timestamp,
                lockDataHash
            )
        );

        bytes32 lockDigest = _getDigest(lockSignedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, lockDigest);
        lockParams.signature = abi.encodePacked(r, s, v);

        // Execute the lock permit
        permit3.permit(
            owner,
            lockParams.salt,
            lockParams.deadline,
            lockParams.timestamp,
            lockInputs.chainPermits,
            lockParams.signature
        );

        // Check allowance is now locked
        (uint160 amount, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 0);
        assertEq(expiration, 2); // LOCKED_ALLOWANCE is 2

        // Now try to decrease the locked allowance - should revert
        PermitInputs memory decreaseInputs;
        decreaseInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        decreaseInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Decrease), // Decrease mode (1)
            token: address(token),
            account: spender,
            amountDelta: 100 // Value to decrease by
         });

        decreaseInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: decreaseInputs.permits });

        TestParams memory decreaseParams;
        decreaseParams.salt = bytes32(uint256(0x555));
        decreaseParams.deadline = uint48(block.timestamp + 1 hours);
        decreaseParams.timestamp = uint48(block.timestamp);

        // Sign the decrease permit
        bytes32 decreaseDataHash = permit3Tester.hashChainPermits(decreaseInputs.chainPermits);
        bytes32 decreaseSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                decreaseParams.salt,
                decreaseParams.deadline,
                decreaseParams.timestamp,
                decreaseDataHash
            )
        );

        bytes32 decreaseDigest = _getDigest(decreaseSignedHash);
        (v, r, s) = vm.sign(ownerPrivateKey, decreaseDigest);
        decreaseParams.signature = abi.encodePacked(r, s, v);

        // Should revert due to locked allowance
        vm.expectRevert(abi.encodeWithSelector(IPermit.AllowanceLocked.selector));
        permit3.permit(
            owner,
            decreaseParams.salt,
            decreaseParams.deadline,
            decreaseParams.timestamp,
            decreaseInputs.chainPermits,
            decreaseParams.signature
        );
    }

    function test_lockAndUnlockAllowance() public {
        // First set up an initial allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, 2000, uint48(block.timestamp + 1 days));

        // Create a permit to lock the allowance
        PermitInputs memory lockInputs;
        lockInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        lockInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Lock), // Lock mode (2)
            token: address(token),
            account: spender,
            amountDelta: 0 // Not used for lock
         });

        lockInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: lockInputs.permits });

        TestParams memory lockParams;
        lockParams.salt = bytes32(uint256(0x666));
        lockParams.deadline = uint48(block.timestamp + 1 hours);
        lockParams.timestamp = uint48(block.timestamp);

        // Sign the lock permit
        bytes32 lockDataHash = permit3Tester.hashChainPermits(lockInputs.chainPermits);
        bytes32 lockSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                lockParams.salt,
                lockParams.deadline,
                lockParams.timestamp,
                lockDataHash
            )
        );

        bytes32 lockDigest = _getDigest(lockSignedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, lockDigest);
        lockParams.signature = abi.encodePacked(r, s, v);

        // Execute the lock permit
        permit3.permit(
            owner,
            lockParams.salt,
            lockParams.deadline,
            lockParams.timestamp,
            lockInputs.chainPermits,
            lockParams.signature
        );

        // Check allowance is now locked
        (uint160 amount, uint48 expiration, uint48 ts) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 0);
        assertEq(expiration, 2); // LOCKED_ALLOWANCE is 2
        assertEq(ts, lockParams.timestamp);

        // Now create a permit to unlock with a newer timestamp
        PermitInputs memory unlockInputs;
        unlockInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        unlockInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Unlock), // Unlock mode (3)
            token: address(token),
            account: spender,
            amountDelta: 3000 // New amount after unlock
         });

        unlockInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: unlockInputs.permits });

        TestParams memory unlockParams;
        unlockParams.salt = bytes32(uint256(0x777));
        unlockParams.deadline = uint48(block.timestamp + 1 hours);
        unlockParams.timestamp = uint48(block.timestamp + 100); // Newer timestamp

        // Sign the unlock permit
        bytes32 unlockDataHash = permit3Tester.hashChainPermits(unlockInputs.chainPermits);
        bytes32 unlockSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                unlockParams.salt,
                unlockParams.deadline,
                unlockParams.timestamp,
                unlockDataHash
            )
        );

        bytes32 unlockDigest = _getDigest(unlockSignedHash);
        (v, r, s) = vm.sign(ownerPrivateKey, unlockDigest);
        unlockParams.signature = abi.encodePacked(r, s, v);

        // Execute the unlock permit
        permit3.permit(
            owner,
            unlockParams.salt,
            unlockParams.deadline,
            unlockParams.timestamp,
            unlockInputs.chainPermits,
            unlockParams.signature
        );

        // Check allowance is now unlocked
        (amount, expiration, ts) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 3000); // New amount from unlock
        assertEq(expiration, 0); // No expiration
        assertEq(ts, unlockParams.timestamp); // Updated timestamp
    }

    function test_attemptUnlockWithOlderTimestamp() public {
        // First set up an initial allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, 2000, uint48(block.timestamp + 1 days));

        // Create a permit to lock the allowance
        PermitInputs memory lockInputs;
        lockInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        lockInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Lock), // Lock mode (2)
            token: address(token),
            account: spender,
            amountDelta: 0 // Not used for lock
         });

        lockInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: lockInputs.permits });

        TestParams memory lockParams;
        lockParams.salt = bytes32(uint256(0x888));
        lockParams.deadline = uint48(block.timestamp + 1 hours);
        lockParams.timestamp = uint48(block.timestamp);

        // Sign the lock permit
        bytes32 lockDataHash = permit3Tester.hashChainPermits(lockInputs.chainPermits);
        bytes32 lockSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                lockParams.salt,
                lockParams.deadline,
                lockParams.timestamp,
                lockDataHash
            )
        );

        bytes32 lockDigest = _getDigest(lockSignedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, lockDigest);
        lockParams.signature = abi.encodePacked(r, s, v);

        // Execute the lock permit
        permit3.permit(
            owner,
            lockParams.salt,
            lockParams.deadline,
            lockParams.timestamp,
            lockInputs.chainPermits,
            lockParams.signature
        );

        // Now create a permit to unlock with an older timestamp - this should fail
        PermitInputs memory unlockInputs;
        unlockInputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        unlockInputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Unlock), // Unlock mode (3)
            token: address(token),
            account: spender,
            amountDelta: 3000 // New amount after unlock
         });

        unlockInputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: unlockInputs.permits });

        TestParams memory unlockParams;
        unlockParams.salt = bytes32(uint256(0x999));
        unlockParams.deadline = uint48(block.timestamp + 1 hours);
        unlockParams.timestamp = uint48(block.timestamp - 100); // Older timestamp

        // Sign the unlock permit
        bytes32 unlockDataHash = permit3Tester.hashChainPermits(unlockInputs.chainPermits);
        bytes32 unlockSignedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(),
                owner,
                unlockParams.salt,
                unlockParams.deadline,
                unlockParams.timestamp,
                unlockDataHash
            )
        );

        bytes32 unlockDigest = _getDigest(unlockSignedHash);
        (v, r, s) = vm.sign(ownerPrivateKey, unlockDigest);
        unlockParams.signature = abi.encodePacked(r, s, v);

        // Should revert due to older timestamp
        vm.expectRevert(abi.encodeWithSelector(IPermit.AllowanceLocked.selector));
        permit3.permit(
            owner,
            unlockParams.salt,
            unlockParams.deadline,
            unlockParams.timestamp,
            unlockInputs.chainPermits,
            unlockParams.signature
        );
    }

    function _getDigest(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", permit3.DOMAIN_SEPARATOR(), structHash));
    }

    function test_decreaseMaxAllowance() public {
        // Set up MAX_ALLOWANCE
        vm.prank(owner);
        permit3.approve(address(token), spender, type(uint160).max, uint48(block.timestamp + 1 days));

        // Verify MAX_ALLOWANCE
        (uint160 initialAmount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(initialAmount, type(uint160).max);

        // Create a permit to decrease the max allowance
        TestParams memory params;
        params.salt = bytes32(uint256(0xaaa));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp + 100);

        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Decrease), // Decrease mode (1)
            token: address(token),
            account: spender,
            amountDelta: type(uint160).max // Try to decrease by MAX_ALLOWANCE
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Sign the permit
        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Execute the permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance was reduced to 0
        (uint160 newAmount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(newAmount, 0); // Should be reduced to 0
    }

    function test_decreaseRegularAllowanceByMaxAmount() public {
        // Set up regular allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, 5000, uint48(block.timestamp + 1 days));

        // Create a permit to decrease by MAX_ALLOWANCE (should set to 0)
        TestParams memory params;
        params.salt = bytes32(uint256(0xbbb));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp + 100);

        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Decrease), // Decrease mode (1)
            token: address(token),
            account: spender,
            amountDelta: type(uint160).max // Decrease by MAX_ALLOWANCE
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Sign the permit
        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Execute the permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance was reduced to 0
        (uint160 newAmount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(newAmount, 0); // Should be reduced to 0
    }

    function test_verifyBalancedSubtreeOrdering() public {
        // Test the ordering comparison in _verifyBalancedSubtree function
        // This tests both paths of the if (computedHash <= proofElement) branch

        // Create two leaf nodes where one is less than the other
        bytes32 smallerLeaf = bytes32(uint256(100));
        bytes32 largerLeaf = bytes32(uint256(200));

        // Test verification with different orders to cover both branches
        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = largerLeaf; // This will take the "computedHash <= proofElement" branch

        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = smallerLeaf; // This will take the "else" branch

        // Create a tester instance to access internal functions
        Permit3Tester testerContract = new Permit3Tester();

        // Verify smaller leaf with larger proof element (computedHash <= proofElement)
        bytes32 root1 = testerContract.verifyBalancedSubtree(smallerLeaf, proof1);

        // Verify larger leaf with smaller proof element (computedHash > proofElement)
        bytes32 root2 = testerContract.verifyBalancedSubtree(largerLeaf, proof2);

        // Compute the expected roots manually
        bytes32 expectedRoot1 = keccak256(abi.encodePacked(smallerLeaf, largerLeaf));
        bytes32 expectedRoot2 = keccak256(abi.encodePacked(smallerLeaf, largerLeaf));

        // Verify both results
        assertEq(root1, expectedRoot1);
        assertEq(root2, expectedRoot2);
    }

    function test_increaseMaxAllowanceWithMaxDelta() public {
        // Set up initial allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, 1000, uint48(block.timestamp + 1 days));

        // Create a permit to increase with MAX_ALLOWANCE
        TestParams memory params;
        params.salt = bytes32(uint256(0xccc));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp + 100);

        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(block.timestamp + 2 days), // Expiration
            token: address(token),
            account: spender,
            amountDelta: type(uint160).max // Set to MAX_ALLOWANCE
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Sign the permit
        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Execute the permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance is set to MAX_ALLOWANCE
        (uint160 newAmount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(newAmount, type(uint160).max); // Should be set to MAX_ALLOWANCE
    }

    function test_decreaseAllowanceSmallerThanExisting() public {
        // Set up initial allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, 1000, uint48(block.timestamp + 1 days));

        // Create a permit to decrease by less than the current allowance
        TestParams memory params;
        params.salt = bytes32(uint256(0xddd));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp + 100);

        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Decrease), // Decrease mode (1)
            token: address(token),
            account: spender,
            amountDelta: 500 // Decrease by 500 (from 1000)
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Sign the permit
        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Execute the permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance was reduced correctly
        (uint160 newAmount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(newAmount, 500); // 1000 - 500 = 500
    }

    function test_emptyProofHandling() public view {
        // Test with a proof that has no subtree elements and no following hashes,
        // but includes a preHash node with a non-zero value
        bytes32[] memory nodes = new bytes32[](1);
        nodes[0] = bytes32(uint256(0x12345)); // preHash (non-zero to avoid the InconsistentPreHashFlag error)

        // Pack counts indicating zero for both but with preHash flag set to true
        bytes32 counts = unhingedTree.packCounts(0, 0, true); // With preHash in this case

        IUnhingedMerkleTree.UnhingedProof memory emptyProof =
            IUnhingedMerkleTree.UnhingedProof({ nodes: nodes, counts: counts });

        // Test it with leaf node
        bytes32 leaf = keccak256("test leaf");

        // Calculate the unhinged root directly - should hash preHash with leaf
        bytes32 expectedRoot = keccak256(abi.encodePacked(nodes[0], leaf));
        bytes32 calculatedRoot = permit3Tester.calculateUnhingedRoot(leaf, emptyProof);

        // Verify the root calculation
        assertEq(calculatedRoot, expectedRoot);

        // Also verify that the proof is valid
        bool isValid = permit3Tester.verifyUnhingedProof(leaf, emptyProof);
        assertTrue(isValid);
    }

    function test_multiplePermitModes() public {
        // Test with multiple permit modes in a single permit call
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](3);

        // 1. Transfer
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Transfer), // Transfer (0)
            token: address(token),
            account: recipient,
            amountDelta: 100 // Transfer 100
         });

        // 2. Decrease
        inputs.permits[1] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Decrease), // Decrease (1)
            token: address(token),
            account: spender,
            amountDelta: 50 // Decrease by 50
         });

        // 3. Increase allowance with expiration
        inputs.permits[2] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(block.timestamp + 3 days), // Expiration
            token: address(token),
            account: spender,
            amountDelta: 200 // Increase by 200
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        // Set up initial allowance for decrease operation to work
        vm.prank(owner);
        permit3.approve(address(token), spender, 100, uint48(block.timestamp + 1 days));

        // Setup and sign the permit
        TestParams memory params;
        params.salt = bytes32(uint256(0xabcdef));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp + 10);

        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Reset recipient balance to verify transfer later
        deal(address(token), recipient, 0);

        // Execute the permit
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify the operations:

        // 1. Transfer happened
        assertEq(token.balanceOf(recipient), 100);

        // 2. Decrease worked and increase happened too
        (uint160 newAmount, uint48 newExpiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(newAmount, 250); // 100 - 50 + 200
        assertEq(newExpiration, uint48(block.timestamp + 3 days));
    }

    function test_permitExpiredSignature() public {
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Transfer), // Transfer
            token: address(token),
            account: recipient,
            amountDelta: AMOUNT
        });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        TestParams memory params;
        params.salt = bytes32(uint256(0x1337));
        params.deadline = uint48(block.timestamp - 1); // Expired deadline
        params.timestamp = uint48(block.timestamp);

        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        // Should revert with SignatureExpired
        vm.expectRevert(abi.encodeWithSelector(INonceManager.SignatureExpired.selector));
        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);
    }

    function test_decreaseMaxAllowanceToZero() public {
        // First approve max allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, type(uint160).max, EXPIRATION);

        // Create permit for decreasing max allowance to zero
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Decrease),
            token: address(token),
            account: spender,
            amountDelta: type(uint160).max
        });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        TestParams memory params;
        params.salt = bytes32(uint256(0x1337));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp);

        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance is now zero
        (uint160 amount,,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, 0);
    }

    function test_unlockedAllowanceAfterLockWithNewerTimestamp() public {
        // First approve regular allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, AMOUNT, EXPIRATION);

        // Lock the allowance
        IPermit.TokenSpenderPair[] memory pairs = new IPermit.TokenSpenderPair[](1);
        pairs[0] = IPermit.TokenSpenderPair({ token: address(token), spender: spender });

        vm.prank(owner);
        permit3.lockdown(pairs);

        // Create unlock permit with newer timestamp
        uint48 newerTimestamp = uint48(block.timestamp) + 1;

        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: uint48(IPermit3.PermitType.Unlock),
            token: address(token),
            account: spender,
            amountDelta: AMOUNT
        });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        TestParams memory params;
        params.salt = bytes32(uint256(0x1337));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = newerTimestamp;

        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance is unlocked and equal to AMOUNT
        (uint160 amount, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, AMOUNT);
        assertEq(expiration, 0);
    }

    function test_zeroAmountDeltaForIncreaseOperation() public {
        // First set a normal allowance
        vm.prank(owner);
        permit3.approve(address(token), spender, AMOUNT, EXPIRATION);

        // Create permit for increasing by zero (should keep original amount)
        PermitInputs memory inputs;
        inputs.permits = new IPermit3.AllowanceOrTransfer[](1);
        inputs.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION + 100, // Increase mode (greater than 3)
            token: address(token),
            account: spender,
            amountDelta: 0 // Zero delta
         });

        inputs.chainPermits = IPermit3.ChainPermits({ chainId: block.chainid, permits: inputs.permits });

        TestParams memory params;
        params.salt = bytes32(uint256(0x1337));
        params.deadline = uint48(block.timestamp + 1 hours);
        params.timestamp = uint48(block.timestamp);

        bytes32 permitDataHash = permit3Tester.hashChainPermits(inputs.chainPermits);
        bytes32 signedHash = keccak256(
            abi.encode(
                permit3.SIGNED_PERMIT3_TYPEHASH(), owner, params.salt, params.deadline, params.timestamp, permitDataHash
            )
        );

        bytes32 digest = _getDigest(signedHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        params.signature = abi.encodePacked(r, s, v);

        permit3.permit(owner, params.salt, params.deadline, params.timestamp, inputs.chainPermits, params.signature);

        // Verify allowance amount remains the same
        // Note: The expiration doesn't get updated because the timestamp is the same as the original approval
        (uint160 amount, uint48 expiration,) = permit3.allowance(owner, address(token), spender);
        assertEq(amount, AMOUNT);
        assertEq(expiration, EXPIRATION);
    }
}
