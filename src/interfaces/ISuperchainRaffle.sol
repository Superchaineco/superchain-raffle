//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

interface ISuperchainRaffle {
    // --------------------------
    // Structs
    // --------------------------
    struct WinningLogic {
        uint256[] payoutPercentage;
    }

    struct RoundPrize {
        uint256 OpAmount;
        uint256 EthAmount;
    }
    struct RandomValueThreshold {
        uint256 ticketThreshold;
        uint256 randomValues;
    }

    struct Winner {
        uint256 ticketNumber;
        address user;
        uint256 opAmount;
        uint256 ethAmount;
    }

    // --------------------------
    // Events
    // --------------------------
    event TicketsPurchased(
        address indexed user,
        uint256 ticketsSold,
        uint256 numberOfTickets,
        uint256 round
    );
    event Claim(address indexed user, uint256 amountETH, uint256 amountOP);
    event RaffleFunded(
        uint256 indexed round,
        uint256 ethAmount,
        uint256 opAmount
    );
    event RaffleFundMoved(uint256 indexed roundFrom, uint256 indexed roundTo);
    event RaffleStarted(uint256 timestamp);
    event RoundWinners(
        uint256 indexed round,
        uint256 ticketsSold,
        Winner[] winners
    );
    event URIChanged(string uri);
    event FreeTicketsPerLevelChanged(uint256[] freeTicketsPerLevel);


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
    error SuperchainRaffle__NotEnoughFreeTickets();
    error SuperchainRaffle__NotSponsoredRaffle();
    error SuperchainRaffle__NotEnoughEtherInContract();
    error SuperchainRaffle__NotEnoughOpInContract();
    error SuperchainRaffle__FailedToSentOp();
    error SuperchainRaffle__FailedToSentEther();
    error SuperchainRaffle__SuperchainRaffleNotStartedYet();
    error SuperchainRaffle__InvalidEndRound();
    error SuperchainRaffle__SenderIsNotSCSA();
    error SuperchainRaffle__MaxNumberOfTicketsReached();
    error SuperchainRaffle__OnlyRandomizerWrapper();
    // --------------------------
    // Functions
    // --------------------------
    function roundsSinceStart() external view returns (uint256);

    function enterRaffle(uint256 _numberOfTickets) external;

    function freeTicketsRemaining(address user) external view returns (uint256);

    function claimFor(address user) external;

    function claim() external;

    function raffle() external;

    function canRaffle() external view returns (bool isRaffleable);

    function fundRaffle(uint256 rounds, uint256 OpAmount) external payable;

    function setMaxAmountTicketsPerRound(uint256 _amountTickets) external;

    function setURI(string memory _uri) external;

    function setBeneficiary(address _beneficiary) external;

    function setSuperchainModule(address _newSuperchainModule) external;

    function setStartTime(uint256 _timeStamp) external;

    function pause() external;

    function unpause() external;

    function withdraw(uint256 _amountEth, uint256 _amountOp) external;

    function getClaimableAmounts(
        address user
    ) external view returns (uint256, uint256);

    function getUserTicketsPerRound(
        address user,
        uint256 round
    ) external view returns (uint256);

    function getTicketsSoldPerRound(
        uint256 round
    ) external view returns (uint256);

    function totalRoundsPlayed(
        address _user,
        uint256 _startRound,
        uint256 _endRound
    ) external view returns (uint256 roundsPlayed);

    function randomizerCallback(uint256 _round, uint256 randomness) external;
}
