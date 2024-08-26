// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISuperchainRaffleFactory {
    event SuperchainRaffleCreated(address superchainRaffle);

    function createSuperchainRaffle(
        uint[] memory _numberOfWinners,
        uint[][] memory _superchainRafflePoints,
        uint[][] memory _payoutPercentage,
        uint[] memory _multiplier,
        address _beneficiary,
        uint256 _superchainRafflePointsPerTicket,
        uint _fee
    ) external;

    function setSuperchainModule(address superchainModule) external;

    function getRaffle(uint index) external view returns (address);
}
