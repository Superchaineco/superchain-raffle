// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RandomTest} from "../src/RandomTest.sol";
contract DeployRandomTest is Script {
    function setUp() public {}
    function run() public {
        vm.startBroadcast();
        RandomTest randomTest = new RandomTest(
            0x600EB8D9Cf9aB34302c8A089B0eb3cad988e7303
        );
        vm.stopBroadcast();
        console.logString( vm.toString((address(randomTest))));
    }
}
