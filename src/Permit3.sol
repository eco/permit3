// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "./lib/EIP712.sol";
import { IPermit3 } from "./interfaces/IPermit3.sol";

contract Permit3 is IPermit3, EIP712 {
    using ECDSA for bytes32;

    mapping(address => mapping(address => mapping(address => Allowance))) public allowances;
    mapping(address => mapping(uint48 => uint256)) public usedNonces;

    bytes32 public constant CHAIN_PERMITS_TYPEHASH = keccak256(
        "ChainPermits(uint64 chainId,uint48 nonce,SpendTransferPermit[] permits)SpendTransferPermit(uint48 transferOrExpiration,address token,address spender,uint160 amount)"
    );

    bytes32 public constant SIGNED_PERMIT3_TYPEHASH = keccak256(
        "SignedPermit3(address owner,uint256 deadline,bytes32 chainedPermitsHashes)"
    );

    constructor() EIP712("Permit3", "1") {}

    function permit(address owner, uint256 deadline, ChainPermits memory permits, bytes calldata signature) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 signedHash = keccak256(abi.encode(
        keccak256(abi.encode(SIGNED_PERMIT3_TYPEHASH, owner, deadline, _hashChainPermits(permits))
        )));

        _verifySignature(owner, signedHash, signature);
        _processChainPermits(owner, permits);
    }

    function permit(address owner, uint256 deadline, Permit3Proof memory batch, bytes calldata signature) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 batchHash = batch.preHash;
        batchHash = keccak256(abi.encodePacked(batchHash, _hashChainPermits(batch.permits)));

        for (uint256 i = 0; i < batch.followingHashes.length; i++) {
            batchHash = keccak256(abi.encodePacked(batchHash, batch.followingHashes[i]));
        }

        bytes32 signedHash = keccak256(abi.encode(
            SIGNED_PERMIT3_TYPEHASH,
            owner,
            deadline,
            batchHash
        ));

        _verifySignature(owner, signedHash, signature);
        _processChainPermits(owner, batch.permits);
    }

    function _processChainPermits(address owner, ChainPermits memory permits) internal {
        require(usedNonces[owner][permits.nonce] == 0, "Nonce already used");
        usedNonces[owner][permits.nonce] = 1;

        for (uint256 i = 0; i < permits.permits.length; i++) {
            SpendTransferPermit memory p = permits.permits[i];

            if (p.transferOrExpiration == 1) {
                _transferFrom(owner, p.spender, p.amount, p.token);
            } else {
                allowances[owner][p.token][p.spender] = Allowance({
                    amount: p.amount,
                    expiration: p.transferOrExpiration,
                    nonce: permits.nonce
                });

                emit Permit(
                    owner,
                    p.token,
                    p.spender,
                    p.amount,
                    p.transferOrExpiration,
                    permits.nonce
                );
            }
        }
    }

    function _transferFrom(address from, address to, uint160 amount, address token) internal {
        require(IERC20(token).transferFrom(from, to, amount), "Transfer failed");
    }

    function _hashChainPermits(ChainPermits memory permits) internal pure returns (bytes32) {
        bytes32[] memory permitHashes = new bytes32[](permits.permits.length);
        for (uint256 i = 0; i < permits.permits.length; i++) {
            permitHashes[i] = keccak256(abi.encode(
                permits.permits[i].transferOrExpiration,
                permits.permits[i].token,
                permits.permits[i].spender,
                permits.permits[i].amount
            ));
        }

        return keccak256(abi.encode(
            CHAIN_PERMITS_TYPEHASH,
            permits.chainId,
            permits.nonce,
            keccak256(abi.encodePacked(permitHashes))
        ));
    }

    function _verifySignature(address owner, bytes32 structHash, bytes calldata signature) internal view {
        bytes32 digest = _hashTypedDataV4(structHash);
        require(digest.recover(signature) == owner, "Invalid signature");
    }

    function allowance(
        address user,
        address token,
        address spender
    ) external view returns (uint160 amount, uint48 expiration, uint48 nonce) {
        Allowance memory allowed = allowances[user][token][spender];
        return (allowed.amount, allowed.expiration, allowed.nonce);
    }

    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        allowances[msg.sender][token][spender] = Allowance({
            amount: amount,
            expiration: expiration,
            nonce: 0
        });

        emit Approval(msg.sender, token, spender, amount, expiration);
    }

    function transferFrom(address from, address to, uint160 amount, address token) external {
        Allowance storage allowed = allowances[from][token][msg.sender];
        require(block.timestamp <= allowed.expiration || allowed.expiration == 0, "Allowance expired");

        if (allowed.amount != type(uint160).max) {
            require(allowed.amount >= amount, "Insufficient allowance");
            allowed.amount -= amount;
        }

        require(IERC20(token).transferFrom(from, to, amount), "Transfer failed");
    }

    function transferFrom(AllowanceTransferDetails[] calldata transfers) external {
        for (uint256 i = 0; i < transfers.length; i++) {
            _transferFrom(
                transfers[i].from,
                transfers[i].to,
                transfers[i].amount,
                transfers[i].token
            );
        }
    }

    function lockdown(TokenSpenderPair[] calldata approvals) external {
        for (uint256 i = 0; i < approvals.length; i++) {
            address token = approvals[i].token;
            address spender = approvals[i].spender;

            delete allowances[msg.sender][token][spender];
            emit Lockdown(msg.sender, token, spender);
        }
    }

    function invalidateNonces(uint48[] calldata noncesToInvalidate) external {
        for (uint256 i = 0; i < noncesToInvalidate.length; i++) {
            usedNonces[msg.sender][noncesToInvalidate[i]] = 1;
        }
    }
}