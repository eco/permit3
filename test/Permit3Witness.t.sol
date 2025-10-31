// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestBase } from "./utils/TestBase.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "../src/Permit3.sol";
import "../src/lib/TreeNodeLib.sol";

import "../src/interfaces/INonceManager.sol";
import "../src/interfaces/IPermit3.sol";

// Mock token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}

/**
 * @title Permit3WitnessTest
 * @notice Tests for Permit3 witness functionality
 */
contract Permit3WitnessTest is TestBase {
    using ECDSA for bytes32;

    // Witness data for testing
    bytes32 constant WITNESS = bytes32(uint256(0xDEADBEEF));
    string constant WITNESS_TYPE_STRING = "bytes32 witnessData)";
    string constant INVALID_WITNESS_TYPE_STRING = "bytes32 witnessData"; // Missing closing parenthesis

    bytes32 constant SIGNED_PERMIT3_WITNESS_TYPEHASH = keccak256(
        "SignedPermit3Witness(address owner,bytes32 salt,uint48 deadline,uint48 timestamp,bytes32 permitHash,bytes32 witnessTypeHash,bytes32 witness)"
    );

    function setUp() public override {
        super.setUp(); // Call TestBase setUp which initializes variables
    }

    function test_validateWitnessTypeString() public {
        // This should revert with InvalidWitnessTypeString
        vm.expectRevert(
            abi.encodeWithSelector(INonceManager.InvalidWitnessTypeString.selector, INVALID_WITNESS_TYPE_STRING)
        );
        permit3.permitWitness(
            _createBasicTransferPermit().permits,
            IPermit3.Witness({ witness: WITNESS, witnessTypeString: INVALID_WITNESS_TYPE_STRING }),
            IPermit3.Signature({
                owner: owner,
                salt: SALT,
                deadline: uint48(block.timestamp + 1 hours),
                timestamp: uint48(block.timestamp),
                signature: new bytes(65)
            })
        );
    }

    function test_permitWitness() public {
        // Create the permit
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        // Reset recipient balance
        deal(address(token), recipient, 0);

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature =
            _signWitnessPermit(chainPermits, deadline, timestamp, SALT, WITNESS, WITNESS_TYPE_STRING);

        // Execute permit
        permit3.permitWitness(
            chainPermits.permits,
            IPermit3.Witness({ witness: WITNESS, witnessTypeString: WITNESS_TYPE_STRING }),
            IPermit3.Signature({
                owner: owner, salt: SALT, deadline: deadline, timestamp: timestamp, signature: signature
            })
        );

        // Verify transfer happened
        assertEq(token.balanceOf(recipient), AMOUNT);

        // Verify nonce is used
        assertTrue(permit3.isNonceUsed(owner, SALT));
    }

    function test_permitWitnessExpired() public {
        // Create the permit
        IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();

        // Set deadline in the past
        uint48 deadline = uint48(block.timestamp - 1);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature =
            _signWitnessPermit(chainPermits, deadline, timestamp, SALT, WITNESS, WITNESS_TYPE_STRING);

        vm.expectRevert(
            abi.encodeWithSelector(INonceManager.SignatureExpired.selector, deadline, uint48(block.timestamp))
        );
        permit3.permitWitness(
            chainPermits.permits,
            IPermit3.Witness({ witness: WITNESS, witnessTypeString: WITNESS_TYPE_STRING }),
            IPermit3.Signature({
                owner: owner, salt: SALT, deadline: deadline, timestamp: timestamp, signature: signature
            })
        );
    }

    function test_permitWitnessWrongChain() public {
        // Create the permit with wrong chain ID
        IPermit3.ChainPermits memory chainPermits = _createWrongChainTransferPermit();

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature =
            _signWitnessPermit(chainPermits, deadline, timestamp, SALT, WITNESS, WITNESS_TYPE_STRING);

        // Should revert with InvalidSignature (signature was created for wrong chain ID)
        vm.expectRevert();
        permit3.permitWitness(
            chainPermits.permits,
            IPermit3.Witness({ witness: WITNESS, witnessTypeString: WITNESS_TYPE_STRING }),
            IPermit3.Signature({
                owner: owner, salt: SALT, deadline: deadline, timestamp: timestamp, signature: signature
            })
        );
    }

    // Helper struct for invalid signature test
    struct InvalidSignatureVars {
        IPermit3.ChainPermits chainPermits;
        uint48 deadline;
        uint48 timestamp;
        bytes32 permitDataHash;
        bytes32 typeHash;
        bytes32 structHash;
        bytes32 digest;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes signature;
    }

    function test_permitWitnessInvalidSignature() public {
        InvalidSignatureVars memory vars;

        // Create the permit
        vars.chainPermits = _createBasicTransferPermit();

        vars.deadline = uint48(block.timestamp + 1 hours);
        vars.timestamp = uint48(block.timestamp);

        // Create invalid signature by signing with wrong key
        // Get hash of permits data
        vars.permitDataHash = permit3.hashChainPermits(vars.chainPermits);

        // Compute witness-specific typehash
        vars.typeHash = keccak256(abi.encodePacked(permit3.PERMIT_WITNESS_TYPEHASH_STUB(), WITNESS_TYPE_STRING));

        // Compute the structured hash
        vars.structHash = keccak256(
            abi.encode(vars.typeHash, vars.permitDataHash, owner, SALT, vars.deadline, vars.timestamp, WITNESS)
        );

        // Get the EIP-712 digest
        vars.digest = _hashTypedDataV4(vars.structHash);

        // Sign with wrong key
        (vars.v, vars.r, vars.s) = vm.sign(0x5678, vars.digest); // Wrong private key
        vars.signature = abi.encodePacked(vars.r, vars.s, vars.v);

        // When signature is from wrong private key, the recovered signer will be different
        vm.expectRevert();
        permit3.permitWitness(
            vars.chainPermits.permits,
            IPermit3.Witness({ witness: WITNESS, witnessTypeString: WITNESS_TYPE_STRING }),
            IPermit3.Signature({
                owner: owner, salt: SALT, deadline: vars.deadline, timestamp: vars.timestamp, signature: vars.signature
            })
        );
    }

    function test_permitWitnessAllowance() public {
        // Create allowance permit
        IPermit3.ChainPermits memory chainPermits = _createAllowancePermit();

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);
        bytes memory signature =
            _signWitnessPermit(chainPermits, deadline, timestamp, SALT, WITNESS, WITNESS_TYPE_STRING);

        permit3.permitWitness(
            chainPermits.permits,
            IPermit3.Witness({ witness: WITNESS, witnessTypeString: WITNESS_TYPE_STRING }),
            IPermit3.Signature({
                owner: owner, salt: SALT, deadline: deadline, timestamp: timestamp, signature: signature
            })
        );

        // Verify allowance was set
        (uint160 allowance,,) = permit3.allowance(owner, address(token), spender);
        assertEq(allowance, AMOUNT);

        // Use allowance
        vm.prank(spender);
        permit3.transferFrom(owner, recipient, AMOUNT / 2, address(token));

        // Verify transfer and allowance decrease
        assertEq(token.balanceOf(recipient), AMOUNT / 2);
        (allowance,,) = permit3.allowance(owner, address(token), spender);
        assertEq(allowance, AMOUNT / 2);
    }

    function test_permitWitnessDifferentWitnesses() public {
        // First transfer with witness1
        {
            IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();
            bytes32 salt = bytes32(uint256(1));
            bytes32 witness = bytes32(uint256(0xDEADBEEF));

            uint48 deadline = uint48(block.timestamp + 1 hours);
            uint48 timestamp = uint48(block.timestamp);
            bytes memory signature =
                _signWitnessPermit(chainPermits, deadline, timestamp, salt, witness, WITNESS_TYPE_STRING);

            permit3.permitWitness(
                chainPermits.permits,
                IPermit3.Witness({ witness: witness, witnessTypeString: WITNESS_TYPE_STRING }),
                IPermit3.Signature({
                    owner: owner, salt: salt, deadline: deadline, timestamp: timestamp, signature: signature
                })
            );
        }

        // Second transfer with different witness
        {
            IPermit3.ChainPermits memory chainPermits = _createBasicTransferPermit();
            bytes32 salt = bytes32(uint256(2));
            bytes32 witness = bytes32(uint256(0xBEEFDEAD));

            uint48 deadline = uint48(block.timestamp + 1 hours);
            uint48 timestamp = uint48(block.timestamp);
            bytes memory signature =
                _signWitnessPermit(chainPermits, deadline, timestamp, salt, witness, WITNESS_TYPE_STRING);

            permit3.permitWitness(
                chainPermits.permits,
                IPermit3.Witness({ witness: witness, witnessTypeString: WITNESS_TYPE_STRING }),
                IPermit3.Signature({
                    owner: owner, salt: salt, deadline: deadline, timestamp: timestamp, signature: signature
                })
            );
        }

        // Verify both transfers occurred (should be 2000 total)
        assertEq(token.balanceOf(recipient), AMOUNT * 2);
    }

    // Test cross-chain witness functionality with tree structure
    function test_permitWitnessCrossChain() public {
        vm.warp(1000); // Set specific timestamp for reproducible results

        // Create permits for 2 chains (realistic cross-chain scenario)
        IPermit3.ChainPermits memory chain1 = _createBasicTransferPermit(); // Current chain

        // Create second chain permit (Arbitrum)
        IPermit3.ChainPermits memory chain2 = IPermit3.ChainPermits({
            chainId: 42_161, // Arbitrum
            permits: new IPermit3.AllowanceOrTransfer[](1)
        });
        chain2.permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0, // Immediate transfer
            tokenKey: bytes32(uint256(uint160(address(token)))),
            account: recipient,
            amountDelta: AMOUNT
        });

        // Build proper PermitNode tree (flat structure with 2 chain permits)
        IPermit3.ChainPermits[] memory permits = new IPermit3.ChainPermits[](2);
        permits[0] = chain1;
        permits[1] = chain2;
        IPermit3.PermitNode memory tree = IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: permits });

        uint48 deadline = uint48(block.timestamp + 1 hours);
        uint48 timestamp = uint48(block.timestamp);

        // Sign using proven helper that uses TestBase's _hashPermitNode
        bytes memory signature = _signWitnessTreePermit(tree, WITNESS, WITNESS_TYPE_STRING, SALT, deadline, timestamp);

        // Build proof for executing chain1 (current chain)
        // Proof contains the sibling (chain2) that needs to be combined
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = permit3.hashChainPermits(chain2); // Sibling chain permit hash
        bytes32 proofStructure = bytes32(0); // Both elements are leaves (no nodes)

        // Execute cross-chain permit
        permit3.permitWitness(
            IPermit3.PermitTree({ proofStructure: proofStructure, currentChainPermits: chain1, proof: proof }),
            IPermit3.Witness({ witness: WITNESS, witnessTypeString: WITNESS_TYPE_STRING }),
            IPermit3.Signature({
                owner: owner, salt: SALT, deadline: deadline, timestamp: timestamp, signature: signature
            })
        );

        // Verify transfer happened
        assertEq(token.balanceOf(recipient), AMOUNT);

        // Verify nonce is used
        assertTrue(permit3.isNonceUsed(owner, SALT));
    }

    /**
     * @notice Test deep tree (3+ levels) witness functionality
     * @dev Tree structure:
     *                      Root
     *                     /    \
     *                   N1      N2
     *                  /  \    /  \
     *                C1  C2  C3  C4
     *           (Eth)  (Arb) (Op) (Poly)
     *
     * Where C2 (Arbitrum, current chain) is executed with proof containing sibling C1 and uncle N2.
     */
    function test_permitWitnessDeepTree_ThreeLevels() public {
        vm.warp(1000); // Set specific timestamp for reproducibility

        address token2Addr;

        // Setup tokens in block to limit scope
        {
            MockToken token2 = new MockToken();
            MockToken token3 = new MockToken();
            MockToken token4 = new MockToken();

            token2Addr = address(token2);

            deal(token2Addr, owner, 10_000);
            deal(address(token3), owner, 10_000);
            deal(address(token4), owner, 10_000);

            vm.startPrank(owner);
            token2.approve(address(permit3), type(uint256).max);
            token3.approve(address(permit3), type(uint256).max);
            token4.approve(address(permit3), type(uint256).max);
            vm.stopPrank();
        }

        // Build tree structure with minimal stack usage
        IPermit3.PermitNode memory root;
        IPermit3.ChainPermits memory c1;
        IPermit3.ChainPermits memory c2;
        bytes32 c1Hash;
        bytes32 n2Hash;

        {
            // Reusable permits array
            IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);

            // C1: Ethereum mainnet
            permits[0] = IPermit3.AllowanceOrTransfer({
                modeOrExpiration: 0,
                tokenKey: bytes32(uint256(uint160(address(token)))),
                account: recipient,
                amountDelta: 1000
            });
            c1 = IPermit3.ChainPermits({ chainId: 1, permits: permits });
            c1Hash = permit3.hashChainPermits(c1);

            // C2: Current chain (will be executed)
            permits = new IPermit3.AllowanceOrTransfer[](1);
            permits[0] = IPermit3.AllowanceOrTransfer({
                modeOrExpiration: 0,
                tokenKey: bytes32(uint256(uint160(token2Addr))),
                account: recipient,
                amountDelta: 2000
            });
            c2 = IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: permits });

            // Build N1 with C1 and C2
            IPermit3.ChainPermits[] memory n1Permits = new IPermit3.ChainPermits[](2);
            n1Permits[0] = c1;
            n1Permits[1] = c2;
            IPermit3.PermitNode memory n1 =
                IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: n1Permits });

            // Build N2 with C3 and C4 in nested block
            IPermit3.PermitNode memory n2;
            {
                permits = new IPermit3.AllowanceOrTransfer[](1);
                // C3: Optimism
                permits[0] = IPermit3.AllowanceOrTransfer({
                    modeOrExpiration: 0,
                    tokenKey: bytes32(uint256(uint160(address(0xC3)))),
                    account: recipient,
                    amountDelta: 3000
                });
                IPermit3.ChainPermits memory c3 = IPermit3.ChainPermits({ chainId: 10, permits: permits });

                permits = new IPermit3.AllowanceOrTransfer[](1);
                // C4: Polygon
                permits[0] = IPermit3.AllowanceOrTransfer({
                    modeOrExpiration: 0,
                    tokenKey: bytes32(uint256(uint160(address(0xC4)))),
                    account: recipient,
                    amountDelta: 4000
                });
                IPermit3.ChainPermits memory c4 = IPermit3.ChainPermits({ chainId: 137, permits: permits });

                IPermit3.ChainPermits[] memory n2Permits = new IPermit3.ChainPermits[](2);
                n2Permits[0] = c3;
                n2Permits[1] = c4;
                n2 = IPermit3.PermitNode({ nodes: new IPermit3.PermitNode[](0), permits: n2Permits });
            }

            n2Hash = _hashPermitNode(n2);

            // Build root
            IPermit3.PermitNode[] memory rootNodes = new IPermit3.PermitNode[](2);
            rootNodes[0] = n1;
            rootNodes[1] = n2;
            root = IPermit3.PermitNode({ nodes: rootNodes, permits: new IPermit3.ChainPermits[](0) });
        }

        // Sign and execute in separate block
        {
            bytes32 witness = bytes32(uint256(0xDEEF7EEE));
            string memory witnessTypeString = "bytes32 witnessData)";

            uint48 deadline = uint48(block.timestamp + 1 hours);
            uint48 timestamp = uint48(block.timestamp);
            bytes32 salt = bytes32(uint256(0x123456));

            bytes memory signature = _signWitnessTreePermit(root, witness, witnessTypeString, salt, deadline, timestamp);

            // Build proof: [c1Hash, n2Hash]
            bytes32[] memory proof = new bytes32[](2);
            proof[0] = c1Hash;
            proof[1] = n2Hash;

            // ProofStructure: position=1, proof[0]=Leaf, proof[1]=Node
            bytes32 proofStructure = bytes32(uint256((1 << 248) | (1 << 246)));

            uint256 balanceBefore = ERC20(token2Addr).balanceOf(recipient);

            // Execute permitWitness
            permit3.permitWitness(
                IPermit3.PermitTree({ proofStructure: proofStructure, currentChainPermits: c2, proof: proof }),
                IPermit3.Witness({ witness: witness, witnessTypeString: witnessTypeString }),
                IPermit3.Signature({
                    owner: owner, salt: salt, deadline: deadline, timestamp: timestamp, signature: signature
                })
            );

            // Verify results
            assertEq(
                ERC20(token2Addr).balanceOf(recipient),
                balanceBefore + 2000,
                "Deep tree witness: recipient should receive 2000 tokens from C2"
            );
            assertTrue(permit3.isNonceUsed(owner, salt), "Deep tree witness: salt should be marked as used");
        }
    }

    // Helper Functions

    function _createWrongChainTransferPermit() internal pure returns (IPermit3.ChainPermits memory) {
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: 0, // Immediate transfer
            tokenKey: bytes32(0), // Doesn't matter for this test
            account: address(0),
            amountDelta: AMOUNT
        });

        return IPermit3.ChainPermits({
            chainId: 1, // Wrong chain ID
            permits: permits
        });
    }

    function _createAllowancePermit() internal view returns (IPermit3.ChainPermits memory) {
        IPermit3.AllowanceOrTransfer[] memory permits = new IPermit3.AllowanceOrTransfer[](1);
        permits[0] = IPermit3.AllowanceOrTransfer({
            modeOrExpiration: EXPIRATION, // Set expiration for allowance
            tokenKey: bytes32(uint256(uint160(address(token)))),
            account: spender,
            amountDelta: AMOUNT
        });

        return IPermit3.ChainPermits({ chainId: uint64(block.chainid), permits: permits });
    }

    // Helper struct for signing witness permits
    struct WitnessPermitVars {
        bytes32 permitDataHash;
        bytes32 typeHash;
        bytes32 structHash;
        bytes32 digest;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function _signWitnessPermit(
        IPermit3.ChainPermits memory chainPermits,
        uint48 deadline,
        uint48 timestamp,
        bytes32 salt,
        bytes32 witness,
        string memory witnessTypeString
    ) internal view returns (bytes memory) {
        WitnessPermitVars memory vars;

        // Get hash of permits data
        vars.permitDataHash = permit3.hashChainPermits(chainPermits);

        // Compute witness-specific typehash
        vars.typeHash = keccak256(abi.encodePacked(permit3.PERMIT_WITNESS_TYPEHASH_STUB(), witnessTypeString));

        // Compute the structured hash
        vars.structHash =
            keccak256(abi.encode(vars.typeHash, owner, salt, deadline, timestamp, vars.permitDataHash, witness));

        // Get the EIP-712 digest
        vars.digest = _hashTypedDataV4(vars.structHash);

        // Sign the digest
        (vars.v, vars.r, vars.s) = vm.sign(ownerPrivateKey, vars.digest);
        return abi.encodePacked(vars.r, vars.s, vars.v);
    }

    /// @notice Sign a PermitNode tree with witness data using proven TestBase helpers
    /// @dev Uses _hashPermitNode() from TestBase for correct tree hashing with sorting
    function _signWitnessTreePermit(
        IPermit3.PermitNode memory permitNode,
        bytes32 witness,
        string memory witnessTypeString,
        bytes32 salt,
        uint48 deadline,
        uint48 timestamp
    ) internal view returns (bytes memory) {
        // Use TestBase's proven tree hashing (includes sorting)
        bytes32 permitNodeHash = _hashPermitNode(permitNode);

        // Compute witness-specific typehash
        bytes32 typeHash = keccak256(abi.encodePacked(permit3.PERMIT_WITNESS_TYPEHASH_STUB(), witnessTypeString));

        // Create signed hash matching contract's _processTreeWitnessHash
        bytes32 signedHash = keccak256(abi.encode(typeHash, owner, salt, deadline, timestamp, permitNodeHash, witness));

        // Create EIP-712 digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit3.DOMAIN_SEPARATOR(), signedHash));

        // Sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", permit3.DOMAIN_SEPARATOR(), structHash));
    }
}
