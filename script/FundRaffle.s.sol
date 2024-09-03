
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";

import {MockERC20} from "../src/Mocks.sol";

contract FundRaffle is Script {
    function setUp() public {}
    function run() public {
      vm.startBroadcast();
      MockERC20 _opToken = MockERC20(0x306F0f79cD98a1448E94C9A3F996a1d6d5aE0626);
      _opToken.approve(0x30282Cf294eD607B837fa539E8F16B3a14c2d2Ae, 1 * 10 ** 18);
      SuperchainRaffle raffle = SuperchainRaffle(0x30282Cf294eD607B837fa539E8F16B3a14c2d2Ae);
      raffle.fundRaffle{value: 1 ether}(2, 1 * 10 ** 18);
      vm.stopBroadcast();
      }
}
