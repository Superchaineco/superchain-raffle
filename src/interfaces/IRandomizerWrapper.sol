//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

interface IRandomizerWrapper {
    // --------------------------
    // Functions
    // --------------------------
    function requestRandomNumber(
        uint256 _day,
        uint256 _numberOfTicketsSold
    ) external payable;


    function getWinningTicketsByRound(
        uint256 _round
    ) external view returns (uint256[] memory);

    function withdraw() external;

    function estimateRandomizerFee() external returns (uint);

    event RandomizerWrapper__RoundWinners(
        uint indexed round,
        uint indexed numberOfTicketsSold,
        uint[] indexed winningNumbers
    );
    // --------------------------
    // Errors
    // --------------------------
    error OnlySuperchainRaffle();
    error RandomizerWrapper__NotEnoughEtherSend();
    error RandomizerWrapper__RoundAlreadyHasWinners();
    error RandomizerWrapper__FailedToSentEther();
}
