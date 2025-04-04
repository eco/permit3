pragma solidity ^0.8.0;

import {Permit3} from "../src/Permit3.sol";
import {CommonBase} from "forge-std/Base.sol";
import {Script} from "forge-std/Script.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";

contract Deploy is Script {
    address public constant create2Factory = 0xce0042B868300000d44A59004Da54A005ffdcf9f;

    function run() external {
        bytes32 salt = vm.envBytes32("SALT");
        vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast();

        // Intent Source
        address permit3 = deploy(type(Permit3).creationCode, salt);
        console.log("Permit3 :", address(permit3));

        vm.stopBroadcast();
    }

    function deploy(bytes memory initCode, bytes32 salt) public returns (address) {
        bytes4 selector = bytes4(keccak256("deploy(bytes,bytes32)"));
        bytes memory args = abi.encode(initCode, salt);
        bytes memory data = abi.encodePacked(selector, args);
        (bool success, bytes memory returnData) = create2Factory.call(data);
        require(success, "Failed to deploy contract");
        return abi.decode(returnData, (address));
    }
}
