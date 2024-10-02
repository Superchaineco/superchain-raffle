
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FundRaffle is Script {
    function setUp() public {}
    function run() public {
      vm.startBroadcast();
      ERC20 _opToken = ERC20(0x4200000000000000000000000000000000000042);
      _opToken.approve(0x39987445BC31823c8BE2d0AA4577CA44d7233A6F, 5 * 10 ** 18);
      SuperchainRaffle raffle = SuperchainRaffle(payable(0x39987445BC31823c8BE2d0AA4577CA44d7233A6F));
      raffle.fundRaffle{value: 0.002 ether}(2, 5 * 10 ** 18);
      vm.stopBroadcast();
      }
}
