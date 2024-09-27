
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";

import {MockERC20} from "../src/Mocks.sol";

contract FundRaffle is Script {
    function setUp() public {}
    function run() public {
      vm.startBroadcast();
      MockERC20 _opToken = MockERC20(0x9a0D7F73F297b1901e3bCBe052c52e383EeAef90);
      _opToken.approve(0x7997454073d9e80fd0b6FcD0308B9068C7522448, 1 * 10 ** 18);
      SuperchainRaffle raffle = SuperchainRaffle(payable(0x7997454073d9e80fd0b6FcD0308B9068C7522448));
      raffle.fundRaffle{value: 0.1 ether}(1, 0.1 * 10 ** 18);
      vm.stopBroadcast();
      }
}
