//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

interface ISuperchainRaffle {
    // --------------------------
    // Structs
    // --------------------------
    struct WinningLogic {
        uint256[] superchainRafflePoints;
        uint256[] payoutPercentage;
    }

    struct RoundPrize{
        uint256 OpAmount;
        uint256 EthAmount;
    }

    // --------------------------
    // Events
    // --------------------------
    event TicketsPurchased(
        address indexed buyer,
        uint256 startingTicketNumber,
        uint256 numberOfTicketsBought,
        uint256 indexed round
    );
    event RoundWinners(
        uint256 indexed round,
        uint256 ticketsSold,
        uint256[] winningTickets
    );
    event Claim(
        address indexed user,
        uint256 amountEth,
        uint256 amountSuperchainRafflePoints
    );

    // --------------------------
    // Errors
    // --------------------------
    error MaxPlayersReached();
    error InvalidAddressInput();
    error SuperchainRaffle__NotEnoughEtherSend();
    error MaxTicketsBoughtForRound();
    error InvalidRandomNumber();
    error InvalidEtherAmount();
    error EthTransferFailed();
    error SuperchainRafflePointsTransferFailed();
    error SuperchainRaffle__NotSponsoredRaffle();
    error SuperchainRaffle__NotEnoughEtherInContract();
    error SuperchainRaffle__FailedToSentEther();
    error SuperchainRaffle__SuperchainRaffleNotStartedYet();
    error SuperchainRaffle__InvalidEndRound();
    error SuperchainRaffle__SenderIsNotSCSA();
    error SuperchainRaffle__MaxNumberOfTicketsReached();
}