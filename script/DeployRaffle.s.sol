// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperchainRaffle} from "../src/SuperchainRaffle.sol";
import {RandomizerWrapper} from "../src/RandomizerWrapper.sol";
import {MockERC20} from "../src/Mocks.sol";

contract DeployRaffle is Script {
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

        for (uint256 i = 0; i < 10; i++) {
            _freeTicketsPerLevel[i] = 1;
        }

        _payoutPercentage[0] = a;
        _payoutPercentage[1] = b;

        _numberOfWinners[0] = 1;
        _numberOfWinners[1] = 10;
    }
    function run() public {
        vm.startBroadcast();
        address beneficiary = msg.sender;
        address superChainModule = 0x37e4783e5AfE03A49520c48e103683574447a81f;
        MockERC20 _opToken = new MockERC20();
        RandomizerWrapper randomizerWrapper = RandomizerWrapper(
            payable(0x78934631a1899B5cd49BCEf57133e7f39d963F7C)
        );
        SuperchainRaffle raffle = new SuperchainRaffle(
            _numberOfWinners,
            _payoutPercentage,
            beneficiary,
            address(_opToken),
            superChainModule,
            address(randomizerWrapper)
        );
        raffle.setURI("http://localhost:3001/api/raffle?file=raffle-weekly-se");
        raffle.setFreeTicketsPerLevel(_freeTicketsPerLevel);
        randomizerWrapper.setWhitelistedRaffle(address(raffle), true);
        raffle.setStartTime(block.timestamp);
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
            string.concat(
                "RandomizerWrapper contract: ",
                vm.toString((address(randomizerWrapper)))
            )
        );
    }
}
