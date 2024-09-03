// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {RandomizerWrapper} from "../src/RandomizerWrapper.sol";
import {SuperchainRaffleFactory} from "../src/SuperchainRaffleFactory.sol";
import {MockERC20} from "../src/Mocks.sol";
contract Deploy is Script {
    uint256[] _numberOfWinners = new uint256[](2);
    uint256[][] _payoutPercentage = new uint256[][](2);
    function setUp() public {
        uint256[] memory a = new uint256[](1);
        a[0] = 10000;
        uint256[] memory b = new uint256[](10);
        b[0] = 7500;
        b[1] = 500;
        b[2] = 500;
        b[3] = 500;
        b[4] = 500;
        b[5] = 100;
        b[6] = 100;
        b[7] = 100;
        b[8] = 100;

        _payoutPercentage[0] = a;
        _payoutPercentage[1] = b;

        _numberOfWinners[0] = 1;
        _numberOfWinners[1] = 10;
    }
    function run() public {
        vm.startBroadcast();
        address beneficiary = msg.sender;
        MockERC20 _opToken = new MockERC20();
        SuperchainRaffleFactory factory = new SuperchainRaffleFactory(
           0x48D64d3f2B43f68d3F26384809e18bF90E4F2a31 ,
            address(_opToken)
        );
        factory.createSuperchainRaffle(_numberOfWinners, _payoutPercentage, beneficiary,0, "http://localhost:3000/api/raffle?file=raffle-weekly-se");
        address raffle = factory.getRaffle(0);
        RandomizerWrapper randomizerWrapper = new RandomizerWrapper(
            raffle,
            beneficiary,
            0x600EB8D9Cf9aB34302c8A089B0eb3cad988e7303
        );
        SuperchainRaffle(raffle).setRandomizerWrapper(address(randomizerWrapper), true);
        SuperchainRaffle(raffle).setStartTime(block.timestamp);
        _opToken.mint(msg.sender, 100000000000000 * 10 ** 18);
        _opToken.approve(msg.sender, 100000000000000 * 10 ** 18);

        vm.stopBroadcast();
        console.logString(
            string.concat("Raffle contract: ", vm.toString((address(raffle))))
    );
    console.logString(
      string.concat("Op token: ", vm.toString((address(_opToken))))
    );
        console.logString(
            string.concat("RandomizerWrapper contract: ", vm.toString((address(randomizerWrapper))))
        );
        console.logString(
            string.concat("Factory contract: ", vm.toString((address(factory))))
        );
    }
}
