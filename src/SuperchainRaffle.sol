//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISuperchainRaffle} from "./interfaces/ISuperchainRaffle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperchainRafflePoints} from "./interfaces/ISuperchainRafflePoints.sol";
import {ISuperchainModule} from "./interfaces/ISuperchainModule.sol";
import {IRandomizerWrapper} from "./interfaces/IRandomizerWrapper.sol";

enum RaffleType {
    regular,
    sponsored
}

contract SuperchainRaffle is ISuperchainRaffle, Pausable, Ownable {
    address public beneficiary;
    // Basis points used for percentage calculation
    uint256 public immutable BPS = 10_000;
    // Maximum number of play tickets per round
    uint256 public maxAmountTickets = 250;
    // Maximum number of play tickets per address, per round
    uint256 public maxTicketsPerWallet = 10;
    // Round => ticket number => Address;
    mapping(uint256 => mapping(uint256 => address))
        public ticketPerAddressPerRound;
    // Round => Address => Number of tickets bought
    mapping(uint256 => mapping(address => uint256)) public ticketsPerWallet;
    // Round => number of tickets sold
    mapping(uint256 => uint256) public ticketsSoldPerRound;
    // Round => address => multiplier
    mapping(uint256 => mapping(address => uint256)) public multiplierPerRound;
    // Round => Address => uint256
    mapping(uint256 => mapping(address => uint256)) public winningClaimed;
    mapping(uint256 => uint256) public randomizerFeePaidForRound;
    // Winners logic used to store superchainRaffle Points and ETH payout configurations
    mapping(uint256 => WinningLogic) private winningLogic;
    //RaffleType
    RaffleType public raffleType;
    // Sponsor
    address public sponsor;
    // Track rounds
    uint256 public startTime;
    // Single ticket price
    uint256 public ticketPrice = 0.002 ether;
    // Address of the superchainRafflePts ERC20
    address public superchainRafflePoints;
    // SafeModule for SuperchainSmartAccount
    ISuperchainModule public superchainModule;
    // Contract with which wrappes the Randomizer
    address public randomizerWrapper;

    // Multiplier percentage, expressed in basis points, i.e. 2 rounds = 20000.
    //  The index should be used to get the specific day -1, i.e. day 5 is multiplier[5 - 1]
    uint256[] public multiplier;
    // Points per ticket played, expressed in 18 decimals as per superchainRafflePoints contract
    uint256 public superchainRafflePointsPerTicket;
    // Value used to check if the Mainnet VRF is used, or a pseudo randomizer
    bool public mainnetRandomizedWrapper;
    // Percentage protocolFee encured for playing superchainRafflePlay, expressed in BPS
    uint256 public protocolFee;

    // --------------------------
    // Modifier
    // --------------------------

    /**
     * @dev Modifier to ensure that the provided Ether value
     * matches the cost for the desired number of play tickets.
     *
     * Requirements:
     *
     * - The provided Ether value must be at least equal to `_numberOfTickets`
     * multiplied by `ticketPrice`.
     */
    modifier validEthAmount(uint256 _numberOfTickets) {
        if (_numberOfTickets * ticketPrice > msg.value)
            revert SuperchainRaffle__NotEnoughEtherSend();
        _;
    }

    modifier onlySuperchainRaffle() {
        if (raffleType != RaffleType.sponsored)
            revert SuperchainRaffle__NotSponsoredRaffle();
        _;
    }

    constructor(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _superchainRafflePoints,
        uint256[][] memory _payoutPercentage,
        uint256[] memory _multiplier,
        address _beneficiary,
        uint256 _superchainRafflePointsPerTicket,
        ISuperchainModule _superchainModule,
        uint256 _fee,
        RaffleType _raffleType
    ) Ownable(msg.sender) {
        _setWinningLogic(
            _numberOfWinners,
            _superchainRafflePoints,
            _payoutPercentage
        );
        _setMultiplier(_multiplier);
        _setBeneficiary(_beneficiary);
        _setSuperchainRafflePointsPerTicket(_superchainRafflePointsPerTicket);
        _setProtocolFee(_fee);
        _setSuperchainModule(_superchainModule);
        raffleType = _raffleType;
    }

    // --------------------------
    // Public Functions
    // --------------------------

    /**
     * @dev Calculates the number of consecutive play rounds in
     * which the given user has participated.
     *
     * @param user The address of the user for whom the consecutive round count is being calculated.
     * @return The number of consecutive play rounds the user has participated in.
     */
    function calculateNumberOfRoundsPlayed(
        address user
    ) public view returns (uint256) {
        uint256 round = _roundsSinceStart();
        return _calculateNumberOfRoundsPlayed(user, round);
    }

    function roundsSinceStart() public view returns (uint256) {
        return _roundsSinceStart();
    }

    /**
     * @dev Fetches the winning ticket numbers for a specific play round.
     *
     * @param _round The play round number.
     * @return An array of winning ticket numbers for the specified play round.
     */
    function getWinningTicketsByRound(
        uint256 _round
    ) external view returns (uint256[] memory) {
        return
            IRandomizerWrapper(randomizerWrapper).getWinningTicketsByRound(
                _round
            );
    }

    /**
     * @dev Allows a user to buy play tickets.
     *
     * This function allows the sender to buy a specified number of play tickets. The function also keeps track of
     * tickets purchased per round, per wallet, and calculates the multiplier based on the number of consecutive rounds
     * played by the sender. If the sender buys tickets exceeding the maximum allowed per round, the function reverts.
     *
     * Emits a {TicketsPurchased} event when tickets are successfully purchased.
     *
     * Requirements:
     *
     * - The provided Ether value must match the cost of the number of tickets being bought (validated by `validEthAmount`).
     * - The total number of tickets bought by the sender in the current round should not exceed `maxTicketsPerWallet`.
     *
     * @param _numberOfTickets The number of tickets the sender wants to buy.
     */
    function enterRaffle(
        uint256 _numberOfTickets
    ) external payable validEthAmount(_numberOfTickets) whenNotPaused {
        if (
            superchainModule.superChainAccount(msg.sender).smartAccount ==
            address(0)
        ) {
            revert SuperchainRaffle__SenderIsNotSCSA();
        }
        // Get current round
        uint256 round = _roundsSinceStart();
        // Check if max amount of tickets buyable per round is not reached
        if (ticketsSoldPerRound[round] + _numberOfTickets > maxAmountTickets)
            revert SuperchainRaffle__MaxNumberOfTicketsReached();
        // Get number of bought tickets for round
        uint256 currentBoughtTickets = ticketsPerWallet[round][msg.sender];
        // Validate if current bought + desired buy amount <= Max buyable amount per round = 10
        if (currentBoughtTickets + _numberOfTickets > maxTicketsPerWallet)
            revert MaxTicketsBoughtForRound();
        uint256 numberOfConsecutiveRounds = _calculateNumberOfRoundsPlayed(
            msg.sender,
            round
        );
        // If number of consecutive rouns played is 0 then keep it like that, otherwise subtract 1 because the number should correspond to array index
        numberOfConsecutiveRounds = numberOfConsecutiveRounds > 0
            ? numberOfConsecutiveRounds - 1
            : 0;
        // Get current number of tickets sold
        uint256 currentNumberOfTicketsSold = ticketsSoldPerRound[round];
        // Calculate new tickets sold for the play round
        uint256 newTicketsSold = currentNumberOfTicketsSold + _numberOfTickets;
        // Update tickets sold for round with new ticket amount;
        ticketsSoldPerRound[round] = newTicketsSold;
        // Update amount of tickets bought for address
        ticketsPerWallet[round][msg.sender] =
            currentBoughtTickets +
            _numberOfTickets;
        // Store multiplier for round for address. If number of consecutive rounds played > number of multipliers defined
        // then take the max multiplier.
        multiplierPerRound[round][msg.sender] = numberOfConsecutiveRounds >
            multiplier.length
            ? multiplier[multiplier.length]
            : multiplier[numberOfConsecutiveRounds];
        // Update last token bought with address
        ticketPerAddressPerRound[round][newTicketsSold] = msg.sender;
        // Emit event
        emit TicketsPurchased(
            msg.sender,
            currentNumberOfTicketsSold,
            _numberOfTickets,
            round
        );
    }

    function claimFor(address user) external whenNotPaused {
        (uint256 amountEth, uint256 amountSuperchainPoints) = _claimableAmounts(
            user
        );
        if (amountEth > 0) {
            _transferWinnings(msg.sender, amountSuperchainPoints, amountEth);
        }
    }

    function claim() external whenNotPaused {
        (uint256 amountEth, uint256 amountSuperchainPoints) = _claimableAmounts(
            msg.sender
        );
        if (amountEth > 0) {
            _transferWinnings(msg.sender, amountSuperchainPoints, amountEth);
        }
        emit Claim(msg.sender, amountEth, amountSuperchainPoints);
    }

    function getClaimableAmounts(
        address user
    ) external view whenNotPaused returns (uint256, uint256) {
        return _getClaimableAmounts(user);
    }

    function getSuperchainPointsMultiplier(
        address user
    ) public view whenNotPaused returns (uint256) {
        uint256 round = _roundsSinceStart() - 1; // Exclude current round
        return multiplierPerRound[round][user];
    }

    function getUserTicketsPerRound(
        address user,
        uint256 round
    ) external view whenNotPaused returns (uint256) {
        return ticketsPerWallet[round][user];
    }

    function getTotalTicketsPerRound(
        uint256 round
    ) external view whenNotPaused returns (uint256) {
        return ticketsSoldPerRound[round];
    }

    /// @notice Calculate the total number of rounds played by a user
    /// within a specified range of rounds.
    /// @dev Iterates through the rounds and checks if the user
    /// bought tickets in each round to count it as played.
    /// @param _user The address of the user for whom the total rounds played is being calculated.
    /// @param _startRound The starting round number for calculation.
    /// @param _endRound The ending round number for calculation.
    /// @return roundsPlayed The total number of rounds played by the user in the specified range.
    function totalRoundsPlayed(
        address _user,
        uint256 _startRound,
        uint256 _endRound
    ) external view returns (uint256 roundsPlayed) {
        // Check that end round is within rounds played
        if (_endRound > roundsSinceStart() - 1)
            revert SuperchainRaffle__InvalidEndRound();
        // Loop through each round in range and check if tickets have been bought. If so then round has been played
        for (_startRound; _startRound <= _endRound; _startRound++) {
            if (ticketsPerWallet[_startRound][_user] != 0) roundsPlayed++;
        }
    }

    /// @notice Calculates and returns the total Ether claimed by a user within a
    /// specified range of rounds.
    /// @dev The function iterates through the rounds and sums up all Ether amounts
    /// claimed, excluding the cases where
    /// ethWon is 0 (not claimed) or 1 (claimed but nothing won). Reverts if the specified
    /// end round is not valid.
    /// @param _user The address of the user for whom the total claimed Ether will be calculated.
    /// @param _startRound The round from which to start calculating the total claimed Ether.
    /// @param _endRound The round until which to calculate the total claimed Ether.
    /// @return ethAmountClaimed Total amount of Ether claimed by the user within the specified
    /// range of rounds.
    function totalEthClaimed(
        address _user,
        uint256 _startRound,
        uint256 _endRound
    ) external view returns (uint256 ethAmountClaimed) {
        // Check that end round is within rounds played
        if (_endRound > roundsSinceStart() - 1)
            revert SuperchainRaffle__InvalidEndRound();
        // Loop through each round in range and add all eth claimed within rounds excluding 0, i.e. not claimed
        // and 1, i.e. claimed but nothing won
        for (_startRound; _startRound <= _endRound; _startRound++) {
            uint256 ethWon = winningClaimed[_startRound][_user];
            if (ethWon != 0 && ethWon != 1) ethAmountClaimed += ethWon;
        }
    }

    /// @notice Retrieves detailed winning information for a specified round of the game.
    /// @dev This function calls `getWinningTicketsByRound` from an external contract identified
    /// by `randomizerWrapper`.
    /// It subsequently computes various winning metrics based on the retrieved winning tickets and the internal state
    /// managed by this contract, including ETH and ZK-Points awarded per ticket. The computed metrics are returned in
    /// multiple arrays, each array's indices correspond to a particular winning ticket.
    /// @param _round The round for which the winning information is requested.
    /// @return _winningTickets An array of ticket numbers that won in the specified round.
    /// @return _winningAddresses An array of addresses that own the winning tickets.
    /// @return _ethPerTicket An array of ETH amounts awarded per winning ticket.
    /// @return _superchainRafflePointsPerTicket An array of ZK-Points awarded per winning ticket, considering all factors including any multipliers.
    function getWinningTicketsAndAddresses(
        uint256 _round
    )
        external
        view
        returns (
            uint256[] memory _winningTickets,
            address[] memory _winningAddresses,
            uint256[] memory _ethPerTicket,
            uint256[] memory _superchainRafflePointsPerTicket
        )
    {
        _winningTickets = IRandomizerWrapper(randomizerWrapper)
            .getWinningTicketsByRound(_round);
        // Number of winning tickets
        uint256 nOfWinningTickets = _winningTickets.length;
        _winningAddresses = new address[](nOfWinningTickets);
        _ethPerTicket = new uint256[](nOfWinningTickets);
        _superchainRafflePointsPerTicket = new uint256[](nOfWinningTickets);
        // Get winning logic for number of winning tickets
        WinningLogic memory logic = winningLogic[nOfWinningTickets];
        for (uint256 i = 0; i < nOfWinningTickets; ++i) {
            // Get winning address for ticket on index 'i'
            address winningAddress = _getTicketBuyerAddress(
                _winningTickets[i],
                ticketsSoldPerRound[_round],
                _round
            );
            // Store winning address in return array
            _winningAddresses[i] = winningAddress;
            // Get superchainRafflepoints won from winning ticket.  Amount winning points corresponds
            /// with index in array and ticket index i.e. if your ticket is number 2 in
            /// array, then you get reward of SuperchainPoints
            uint256 superchainRafflePointsFromWinningTicket = logic
                .superchainRafflePoints[i];
            // Calculate and add amount of ETH won in the following manner:
            // 1. Percentage won for this ticket, of total ETH of round corresponds with
            // index in array, i.e. if ticket number 1 wins 75%, then index 0 in array has
            // 75% in BPS stored
            // 2. Sent percentage plus round to calculate total amount of ETH won
            _ethPerTicket[i] = _getETHAmount(logic.payoutPercentage[i], _round);
            // Calculate superchainRafflePoints user get for each ticket bought in this round + superchainRafflePoints from winning, if applicable (by default 0)
            uint256 totalSuperchainRafflePointsForRoundForTicket = (ticketsPerWallet[
                    _round
                ][winningAddress] * superchainRafflePointsPerTicket) +
                    superchainRafflePointsFromWinningTicket;
            // Pass total superchainRafflePoints for round plus multiplier for round and add result to total
            // amount which gets stored in return array
            _superchainRafflePointsPerTicket[
                i
            ] = _getMultipliedSuperchainPoints(
                totalSuperchainRafflePointsForRoundForTicket,
                multiplierPerRound[_round][winningAddress]
            );
        }
    }

    /// @notice Retrieves the ticket numbers a user has for the current round.
    /// @dev This function loops backward through the tickets sold in the round to compile the ticket numbers for the given user.
    /// If the user hasn't bought any tickets for the round, an empty array is returned.
    /// @param _user The address of the user whose ticket numbers are to be retrieved.
    /// @return ticketsBought An array of ticket numbers the user has for the current round.
    function getUserTicketNumbersOfCurrentRound(
        address _user
    ) external view returns (uint256[] memory ticketsBought) {
        // Get current round
        uint256 round = _roundsSinceStart();
        // Get number of tickets bought by user for given round
        uint256 numberOfTicketsBought = ticketsPerWallet[round][_user];
        // Initiate dynamic array equal to number of tickets bought
        ticketsBought = new uint256[](numberOfTicketsBought);

        // If no tickets has been bought, return empty values
        if (numberOfTicketsBought == 0) return ticketsBought;

        // Get total tickets sold for round
        uint256 nOfTicketsSold = ticketsSoldPerRound[round];
        // Return array index
        uint256 ticketIndex = 0;

        // Loop through all tickets sold backward until the first ticket, number 1
        while (nOfTicketsSold > 0) {
            // If ticket number is mapped to user address
            if (ticketPerAddressPerRound[round][nOfTicketsSold] == _user) {
                // Store the ticket number
                ticketsBought[ticketIndex] = nOfTicketsSold;
                ticketIndex++;
                nOfTicketsSold--;

                // Keep adding tickets mapped to address(0) until all tickets have been checked, or
                // ticket is mapped to different address
                while (
                    nOfTicketsSold > 0 &&
                    ticketPerAddressPerRound[round][nOfTicketsSold] ==
                    address(0)
                ) {
                    ticketsBought[ticketIndex] = nOfTicketsSold;
                    ticketIndex++;
                    nOfTicketsSold--;
                }
            } else {
                nOfTicketsSold--;
            }
            // Break out loop when all tickets are collected before reaching ticket number 1
            if (ticketIndex == numberOfTicketsBought) {
                break;
            }
        }

        return ticketsBought;
    }

    /**
     * @dev Determines the winning tickets for previous play rounds.
     *
     * This function loops through past play rounds, starting from the most recent, and for each round, it queries the
     * `IRandomizerWrapper` contract to obtain the winning tickets. If a round does not have winning tickets, the function
     * requests the `IRandomizerWrapper` to draw winners for that round. The process continues until a round with winning
     * tickets is found or all past rounds have been checked.
     *
     * Note: The cost for the VRF function gets subtracted from the balance of this contract
     *
     * Emits a {RoundWinners} event for each round where winning tickets are determined.
     */
    function raffle() external whenNotPaused {
        // Get most recent round, excluding this round
        uint256 round = _roundsSinceStart() - 1;
        uint256 randomizerFee;

        // Loop through all the past rounds
        for (round; round > 0; round--) {
            if (randomizerFeePaidForRound[round] == 0) {
                // Get number of sold tickets for round
                uint256 ticketsSold = ticketsSoldPerRound[round];
                if (
                    ticketsSold == 0 ||
                    ticketsSold == 1 ||
                    mainnetRandomizedWrapper == false
                ) {
                    randomizerFee = 0;
                } else {
                    // Calculate randomizer fee
                    randomizerFee = IRandomizerWrapper(randomizerWrapper)
                        .estimateRandomizerFee();
                }
                //  Call Randomizer wrapper to get request number and sent value as msg.value to randomizerWrapper
                IRandomizerWrapper(randomizerWrapper).requestRandomNumber{
                    value: randomizerFee
                }(round, ticketsSold);
                randomizerFeePaidForRound[round] = randomizerFee == 0
                    ? 1
                    : randomizerFee; // Set fee to 1 if randomizerFee = 0
                if (protocolFee != 0) {
                    // Total protocolFee collected for round * protocolFee / BPS to get amount
                    uint256 totalFee = ((ticketsSold * ticketPrice) *
                        protocolFee) / BPS;
                    _transferEth(beneficiary, totalFee);
                }
            } else break;
        }
    }

    function canRaffle() external view returns (bool isRaffleable) {
        uint256 round = _roundsSinceStart() - 1;

        // Loop through all the past rounds
        for (round; round > 0; round--) {
            if (randomizerFeePaidForRound[round] == 0) {
                isRaffleable = true;
                return isRaffleable;
            }
        }
    }

    // --------------------------
    // Restricted Functions
    // --------------------------

    // To Do: Create restricted function to update winning logic

    /**
     * @dev Set address of the SuperchainRafflePoints contract
     */
    function setSuperchainRafflePlayPoints(
        address _newSuperchainRafflePlayPoints
    ) external onlyOwner {
        _setSuperchainRafflePoints(_newSuperchainRafflePlayPoints);
    }

    function setSponsor(address _sponsor) external onlyOwner onlySuperchainRaffle {
        sponsor = _sponsor;
    }

    function setMaxAmountTicketsPerRound(
        uint256 _amountTickets
    ) external onlyOwner {
        _setMaxAmountTicketsPerRound(_amountTickets);
    }

    function setBeneficiary(address _beneficiary) external onlyOwner {
        _setBeneficiary(_beneficiary);
    }

    function setRandomizerWrapper(
        address _newRandomizerWrapper,
        bool _mainnetWrapper
    ) external onlyOwner {
        _setRandomizerWrapper(_newRandomizerWrapper, _mainnetWrapper);
    }

    function setMultiplier(uint256[] memory _multiplier) external onlyOwner {
        _setMultiplier(_multiplier);
    }

    function setStartTime(uint256 _timeStamp) external onlyOwner {
        startTime = _timeStamp;
    }

    // function setRandomizerContract(address _randomizer) external onlyOwner {
    //     _setRandomizerContract(_randomizer);
    // }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw(uint256 _amount) external onlyOwner {
        if (_amount > address(this).balance)
            revert SuperchainRaffle__NotEnoughEtherInContract();
        (bool sent, ) = payable(beneficiary).call{value: _amount}("");
        if (!sent) revert SuperchainRaffle__FailedToSentEther();
    }

    function setSuperchainRafflePointsPerTicket(
        uint256 _points
    ) external onlyOwner {
        _setSuperchainRafflePointsPerTicket(_points);
    }

    function setProtocolFee(uint256 _fee) external onlyOwner {
        _setProtocolFee(_fee);
    }

    function setTicketPrice(uint256 _price) external onlyOwner {
        _setTicketPrice(_price);
    }

    function setMaxTicketsPerWallet(uint256 _amount) external onlyOwner {
        _setMaxTicketsPerWallet(_amount);
    }

    // --------------------------
    // Internal
    // --------------------------

    /**
     * @dev Calculates the total amount of ETH and SuperchainPoints that a user can claim from past play rounds.
     * [IMPORTANT]: This function writes state by setting the round as claimed. It should only be used
     * when this effect is required
     *
     * This function iterates through previous play rounds in reverse order, checking if the provided user
     * has any unclaimed winnings. If the user has already claimed for a particular round, the function stops.
     * For each round, it checks the winning tickets against the user's tickets and calculates the user's potential
     * winnings based on the winning logic. The total claimable ETH and SuperchainPoints are aggregated and returned.
     *
     * @param user The address of the user for whom the claimable amounts are being calculated.
     * @return amountEth The total amount of ETH that the user can claim.
     * @return amountSuperchainPoints The total amount of SuperchainPoints that the user can claim.
     */
    function _claimableAmounts(
        address user
    ) internal returns (uint256 amountEth, uint256 amountSuperchainPoints) {
        // Get most recent round, excluding this round
        uint256 round = (_roundsSinceStart() - 1);
        // Loop through rounds backwards
        for (round; round > 0; round--) {
            // If there has already been a claim for this round then it is not claimable, then stop the
            // claim function. The assumption here is that as soon as the function encounters an
            // earlier claim, then it has claimed all that is possible
            if (winningClaimed[round][user] != 0) break;
            // Skip if no winning ticket has been drawn for given round yet, which means no fee paid yet
            if (randomizerFeePaidForRound[round] != 0) {
                // Get winning tickets of round
                uint256[] memory winningTickets = IRandomizerWrapper(
                    randomizerWrapper
                ).getWinningTicketsByRound(round);
                // Number of winning tickets
                uint256 nOfWinningTickets = winningTickets.length;
                // Get winning logic for number of winning tickets
                WinningLogic memory logic = winningLogic[nOfWinningTickets];
                // Loop through winning tickets of this round
                uint256 superchainRafflePointsFromWinningTicket = 0;
                for (uint256 i; i < nOfWinningTickets; ++i) {
                    // If buy of ticket in array == user
                    if (
                        _getTicketBuyerAddress(
                            winningTickets[i],
                            ticketsSoldPerRound[round],
                            round
                        ) == user
                    ) {
                        // Get superchainRafflepoints won from winning ticket.  Amount winning points corresponds
                        /// with index in array and ticket index i.e. if your ticket is number 2 in
                        /// array, then you get reward of SuperchainPoints
                        superchainRafflePointsFromWinningTicket += logic
                            .superchainRafflePoints[i];

                        // Calculate and add amount of ETH won in the following manner:
                        // 1. Percentage won for this ticket, of total ETH of round corresponds with
                        // index in array, i.e. if ticket number 1 wins 75%, then index 0 in array has
                        // 75% in BPS stored
                        // 2. Sent percentage plus round to calculate total amount of ETH won
                        amountEth += _getETHAmount(
                            logic.payoutPercentage[i],
                            round
                        );
                    }
                }
                // Calculate superchainRafflePoints user get for each ticket bought in this round + superchainRafflePoints from winning, if applicable (by default 0)
                uint256 totalSuperchainRafflePointsForRound = (ticketsPerWallet[
                    round
                ][user] * superchainRafflePointsPerTicket) +
                    superchainRafflePointsFromWinningTicket;
                // Pass total superchainRafflePoints for round plus multiplier for round and add result to total
                // amount which gets transferred
                amountSuperchainPoints += _getMultipliedSuperchainPoints(
                    totalSuperchainRafflePointsForRound,
                    multiplierPerRound[round][user]
                );
                // Set the amount eth won which is used in the UI. The number 1. here represents if the round has been claimed, but no ETH
                // has been won
                winningClaimed[round][user] = amountEth != 0 ? amountEth : 1;
            }
        }
    }

    /**
     * @dev Calculates the total amount of ETH and SuperchainPoints that a user can claim from past play rounds.
     *
     * This function iterates through previous play rounds in reverse order, checking if the provided user
     * has any unclaimed winnings. If the user has already claimed for a particular round, the function stops.
     * For each round, it checks the winning tickets against the user's tickets and calculates the user's potential
     * winnings based on the winning logic. The total claimable ETH and SuperchainPoints are aggregated and returned.
     *
     * @param user The address of the user for whom the claimable amounts are being calculated.
     * @return amountEth The total amount of ETH that the user can claim.
     * @return amountSuperchainPoints The total amount of SuperchainPoints that the user can claim.
     */
    function _getClaimableAmounts(
        address user
    )
        internal
        view
        returns (uint256 amountEth, uint256 amountSuperchainPoints)
    {
        // Get most recent round, excluding this round
        uint256 round = (_roundsSinceStart() - 1);
        // Loop through rounds backwards
        for (round; round > 0; round--) {
            // If there has already been a claim for this round then it is not claimable, then stop the
            // claim function. The assumption here is that as soon as the function encounters an
            // earlier claim, then it has claimed all that is possible
            if (winningClaimed[round][user] != 0) break;
            // Skip if no winning ticket has been drawn for given round yet, which means no fee paid yet
            if (randomizerFeePaidForRound[round] != 0) {
                // Get winning tickets of round
                uint256[] memory winningTickets = IRandomizerWrapper(
                    randomizerWrapper
                ).getWinningTicketsByRound(round);
                // Number of winning tickets
                uint256 nOfWinningTickets = winningTickets.length;
                // Get winning logic for number of winning tickets
                WinningLogic memory logic = winningLogic[nOfWinningTickets];
                // Loop through winning tickets of this round
                uint256 superchainRafflePointsFromWinningTicket = 0;
                for (uint256 i; i < nOfWinningTickets; ++i) {
                    // If buy of ticket in array == user
                    if (
                        _getTicketBuyerAddress(
                            winningTickets[i],
                            ticketsSoldPerRound[round],
                            round
                        ) == user
                    ) {
                        // Get superchainRafflepoints won from winning ticket.  Amount winning points corresponds
                        /// with index in array and ticket index i.e. if your ticket is number 2 in
                        /// array, then you get reward of SuperchainPoints
                        superchainRafflePointsFromWinningTicket += logic
                            .superchainRafflePoints[i];

                        // Calculate and add amount of ETH won in the following manner:
                        // 1. Percentage won for this ticket, of total ETH of round corresponds with
                        // index in array, i.e. if ticket number 1 wins 75%, then index 0 in array has
                        // 75% in BPS stored
                        // 2. Sent percentage plus round to calculate total amount of ETH won
                        amountEth += _getETHAmount(
                            logic.payoutPercentage[i],
                            round
                        );
                    }
                }
                // Calculate superchainRafflePoints user get for each ticket bought in this round + superchainRafflePoints from winning, if applicable (by default 0)
                uint256 totalSuperchainRafflePointsForRound = (ticketsPerWallet[
                    round
                ][user] * superchainRafflePointsPerTicket) +
                    superchainRafflePointsFromWinningTicket;
                // Pass total superchainRafflePoints for round plus multiplier for round and add result to total
                // amount which gets transferred
                amountSuperchainPoints += _getMultipliedSuperchainPoints(
                    totalSuperchainRafflePointsForRound,
                    multiplierPerRound[round][user]
                );
            }
        }
    }

    function _transferWinnings(
        address _to,
        uint256 _amountSuperchainPoints,
        uint256 _amountETH
    ) internal {
        _mintSuperchainRafflePoints(_to, _amountSuperchainPoints);
        _transferEth(_to, _amountETH);
    }

    function _mintSuperchainRafflePoints(
        address _to,
        uint256 _amountSuperchainPoints
    ) internal {
        try
            ISuperchainRafflePoints(superchainRafflePoints)
                .mintSuperchainRafflePoints(_to, _amountSuperchainPoints)
        returns (bool success) {
            require(success, "SuperchainRaffle Points minted");
        } catch {
            revert SuperchainRafflePointsTransferFailed();
        }
    }

    function _transferEth(address _to, uint256 _amountETH) internal {
        (bool sent, ) = _to.call{value: _amountETH}("");
        if (sent == false) revert EthTransferFailed();
    }

    function _getETHAmount(
        uint256 _percentage,
        uint256 _round
    ) internal view returns (uint256) {
        // Total ETH amoutn is calculated as: Number of tickets sold for given round * ticket price
        uint256 totalEthCollected = ticketsSoldPerRound[_round] * ticketPrice;
        // Calculte protocol fee amount in ETH if fee percentage > 0. Amount calculate as percentage
        // of total ETH collected for round.
        uint256 protocolFeeAmount = protocolFee == 0
            ? 0
            : (totalEthCollected * protocolFee) / BPS;
        // Get randomizer fee amount in ETH paid for given round. We check for value 1 beause it is
        // used to signal that the round has been raffled, but the randomizerWrapper cost was 0.
        // However we don't want to subtract the value, so we set it to 0 again.
        uint256 randomizerFeeAmountPaidForRound = randomizerFeePaidForRound[
            _round
        ] == 1
            ? 0
            : randomizerFeePaidForRound[_round];
        // Total prize pool
        uint256 totalWinnableETHPrizeForRound = (totalEthCollected -
            randomizerFeeAmountPaidForRound) - protocolFeeAmount;

        // TODO: because of loss of percision, might all winnings not add up to a round number?
        return ((totalWinnableETHPrizeForRound * _percentage) / BPS) - 1;
    }

    function _getMultipliedSuperchainPoints(
        uint256 _amount,
        uint256 _multiplier
    ) internal pure returns (uint256) {
        if (_multiplier == 0 || _amount == 0) return _amount;
        else return (_amount * _multiplier) / BPS;
    }

    function _getTicketBuyerAddress(
        uint256 _winningTicket,
        uint256 _ticketSold,
        uint256 _round
    ) internal view returns (address winner) {
        for (uint256 i = _winningTicket; i <= _ticketSold; ++i) {
            address temp = ticketPerAddressPerRound[_round][i];
            if (temp != address(0)) {
                winner = temp;
                break;
            }
        }
    }

    function _calculateNumberOfRoundsPlayed(
        address _user,
        uint256 _round
    ) internal view returns (uint256 roundsPlayed) {
        uint256 maxRounds = multiplier.length;
        _round -= 1; // Current round is not counted
        for (uint256 i; i < maxRounds; ++i) {
            // If we've reached round 1 after decrementing, break out of loop
            if (_round < 1) {
                break;
            }
            // Check if the user has tickets for this round
            if (ticketsPerWallet[_round][_user] > 0) {
                roundsPlayed++;

                // Decrement round number for next iteration
                _round--;
            } else {
                // If no tickets are found for this round, break out of the loop
                break;
            }
        }
    }

    function _roundsSinceStart() internal view returns (uint256) {
        if (block.timestamp < startTime)
            revert SuperchainRaffle__SuperchainRaffleNotStartedYet();
        return ((block.timestamp - startTime) / 1 days) + 1;
    }

    function _setBeneficiary(address _beneficiary) internal {
        beneficiary = _beneficiary;
    }

    function _setSuperchainRafflePoints(
        address _newSuperchainRafflePoints
    ) internal {
        if (_newSuperchainRafflePoints == address(0))
            revert InvalidAddressInput();
        superchainRafflePoints = _newSuperchainRafflePoints;
    }

    function _setSuperchainModule(
        ISuperchainModule _newSuperchainModule
    ) internal {
        superchainModule = _newSuperchainModule;
    }

    function _setRandomizerWrapper(
        address _newRandomizerWrapper,
        bool _mainnetWrapper
    ) internal {
        if (_newRandomizerWrapper == address(0)) revert InvalidAddressInput();
        randomizerWrapper = _newRandomizerWrapper;
        mainnetRandomizedWrapper = _mainnetWrapper;
    }

    // function _setRandomizerContract(address _randomizer) internal {
    //     IRandomizerWrapper(randomizerWrapper).setRandomizerContract(
    //         _randomizer
    //     );
    // }

    function _setNewStartTime(uint256 _startTime) internal {
        startTime = _startTime;
    }

    function _setMultiplier(uint256[] memory _multiplier) internal {
        uint256 arrayLength = _multiplier.length;
        // If multiplier has already values stored, i.e. it is called to update multiplier
        // then delete multiplier first
        if (multiplier.length != 0) {
            delete multiplier;
        }
        for (uint256 i; i < arrayLength; ++i) {
            multiplier.push(uint256(_multiplier[i]));
        }
    }

    function _setSuperchainRafflePointsPerTicket(uint256 _points) internal {
        superchainRafflePointsPerTicket = _points;
    }

    function _setMaxAmountTicketsPerRound(uint256 _maxAmount) internal {
        maxAmountTickets = _maxAmount;
    }

    function _setProtocolFee(uint256 _fee) internal {
        protocolFee = _fee;
    }

    function _setTicketPrice(uint256 _price) internal {
        ticketPrice = _price;
    }

    function _setMaxTicketsPerWallet(uint256 _amount) internal {
        maxTicketsPerWallet = _amount;
    }

    function _setWinningLogic(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _superchainRafflePoints,
        uint256[][] memory _payoutPercentage
    ) internal {
        uint256 arrayLength = _numberOfWinners.length;
        for (uint256 i; i < arrayLength; ++i) {
            WinningLogic storage logic = winningLogic[
                uint256(_numberOfWinners[i])
            ];
            // If values have already been stored, i.e. this function is called for an updated
            // then delete values first
            if (
                winningLogic[uint256(_numberOfWinners[i])]
                    .superchainRafflePoints
                    .length != 0
            ) {
                delete logic.superchainRafflePoints;
                delete logic.payoutPercentage;
            }
            uint256 innerArrayLength = _superchainRafflePoints[i].length;
            for (uint256 j; j < innerArrayLength; ++j) {
                logic.superchainRafflePoints.push(
                    uint256(_superchainRafflePoints[i][j])
                );
                logic.payoutPercentage.push(uint256(_payoutPercentage[i][j]));
            }
        }
    }
}
