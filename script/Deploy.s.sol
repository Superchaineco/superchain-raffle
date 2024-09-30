// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {RandomizerWrapper} from "../src/RandomizerWrapper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Deploy is Script {
    uint256[] _numberOfWinners = new uint256[](2);
    uint256[][] _payoutPercentage = new uint256[][](2);
    uint256[] _freeTicketsPerLevel = new uint256[](10);
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
        for (uint256 i = 0; i < 10; i++) {
            _freeTicketsPerLevel[i] = i + 1;
        }
    }
    function run() public {
        vm.startBroadcast();
        address beneficiary = msg.sender;
        address superChainModule = 0x1Ee397850c3CA629d965453B3cF102E9A8806Ded;
        ERC20 _opToken = ERC20(0x4200000000000000000000000000000000000042);
        RandomizerWrapper randomizerWrapper = new RandomizerWrapper(
            beneficiary,
            0x600EB8D9Cf9aB34302c8A089B0eb3cad988e7303,
            beneficiary
        );
        SuperchainRaffle raffle = new SuperchainRaffle(
            _numberOfWinners,
            _payoutPercentage,
            beneficiary,
            address(_opToken),
            superChainModule,
            address(randomizerWrapper)
        );
        raffle.setURI("https://raffle.superchain.eco/api/raffle?file=raffle-weekly-se");
        raffle.setFreeTicketsPerLevel(_freeTicketsPerLevel);
        randomizerWrapper.setWhitelistedRaffle(address(raffle), true);
        raffle.setStartTime(block.timestamp);

        vm.stopBroadcast();
        console.logString(
            string.concat("Raffle contract: ", vm.toString((address(raffle))))
        );
        console.logString(
            string.concat("Op token: ", vm.toString((address(_opToken))))
        );
        console.logString(
            string.concat(
                "RandomizerWrapper contract: ",
                vm.toString((address(randomizerWrapper)))
            )
        );
    }
}
