//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

interface IRandomizerWrapper {
    // --------------------------
    // Functions
    // --------------------------
    function requestRandomNumber(
        address _raffle,
        uint256 _round
    ) external ;


    error OnlySuperchainRaffle();
}