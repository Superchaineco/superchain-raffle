//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

interface ISuperchainRafflePoints {
    // --------------------------
    // Events
    // --------------------------

    event SuperchainRafflePointsGiven(
        address indexed receiver,
        uint256 indexed amount,
        uint256 indexed timestamp
    );

    // --------------------------
    // Functions
    // --------------------------

    /**
     *
     * @dev Adds points to the winners address
     */
    function mintSuperchainRafflePoints(
        address _raffleWinner,
        uint256 _amount
    ) external returns (bool);

    function withdraw() external;

    // --------------------------
    // Errors
    // --------------------------

    error InvalidAddressInput();
    error OnlySuperchainRaffle();
    error InvalidWinnerPoints();
    error PointsNotInteger();
    error NonTransferrable();
    error SuperchainRafflePoints__FailedToSentEther();
}