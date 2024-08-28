//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISuperchainRaffle} from "./interfaces/ISuperchainRaffle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperchainRafflePoints} from "./interfaces/ISuperchainRafflePoints.sol";
import {ISuperchainModule} from "./interfaces/ISuperchainModule.sol";
import {IRandomizerWrapper} from "./interfaces/IRandomizerWrapper.sol";

contract SuperchainRaffle is ISuperchainRaffle, Pausable, Ownable {
    address public beneficiary;
    IERC20 public opToken;
    string public uri;
    // Track rounds
    uint256 public startTime;
    // SafeModule for SuperchainSmartAccount
    address public superchainModule;
    // Contract with which wrappes the Randomizer
    address public randomizerWrapper;
    // Value used to check if the Mainnet VRF is used, or a pseudo randomizer
    bool public mainnetRandomizedWrapper;
    // Percentage protocolFee encured for playing superchainRafflePlay, expressed in BPS
    uint256 public protocolFee;
    // Basis points used for percentage calculation
    uint256 public immutable BPS = 10_000;
    // Maximum number of play tickets per round
    uint256 public maxAmountTickets = 250;
    // Maximum number of play tickets per address, per round
    mapping(uint256 => RoundPrize) public roundPrizes;
    // Round => ticket number => Address;
    mapping(uint256 => mapping(uint256 => address))
        public ticketPerAddressPerRound;
    // Round => Address => Number of tickets bought
    mapping(uint256 => mapping(address => uint256)) public ticketsPerWallet;
    // Round => number of tickets sold
    mapping(uint256 => uint256) public ticketsSoldPerRound;
    // Round => Address => uint256
    mapping(uint256 => mapping(address => uint256)) public winningClaimed;
    mapping(uint256 => uint256) public randomizerFeePaidForRound;
    // Winners logic used to store superchainRaffle Points and ETH payout configurations
    mapping(uint256 => WinningLogic) private winningLogic;

    // --------------------------
    // Modifier
    // --------------------------

    constructor(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _payoutPercentage,
        address _beneficiary,
        address _opToken,
        address _superchainModule,
        uint256 _fee
    ) Ownable(msg.sender) {
        _setWinningLogic(_numberOfWinners, _payoutPercentage);
        _setBeneficiary(_beneficiary);
        opToken = IERC20(_opToken);
        _setProtocolFee(_fee);
        _setSuperchainModule(_superchainModule);
    }

    // --------------------------
    // Public Functions
    // --------------------------

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
    function enterRaffle(uint256 _numberOfTickets) external whenNotPaused {
        if (
            ISuperchainModule(superchainModule)
                .superChainAccount(msg.sender)
                .smartAccount == address(0)
        ) {
            revert SuperchainRaffle__SenderIsNotSCSA();
        }
        // Get current round
        uint256 round = _roundsSinceStart();
        uint256 ticketsRemaining = freeTicketsRemaining();

        if (_numberOfTickets > ticketsRemaining) {
            revert SuperchainRaffle__NotEnoughFreeTickets();
        }

        // Check if max amount of tickets buyable per round is not reached
        if (ticketsSoldPerRound[round] + _numberOfTickets > maxAmountTickets)
            revert SuperchainRaffle__MaxNumberOfTicketsReached();
        // Get number of bought tickets for round
        uint256 currentBoughtTickets = ticketsPerWallet[round][msg.sender];
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

    function freeTicketsRemaining() public view returns (uint256) {
        uint256 round = _roundsSinceStart();

        uint256 userLevel = ISuperchainModule(superchainModule)
            .getSuperChainAccount(msg.sender)
            .level;
        uint256 ticketsBought = ticketsPerWallet[round][msg.sender];
        if (ticketsBought >= userLevel) {
            return 0;
        } else {
            return userLevel - ticketsBought;
        }
    }

    function claimFor(address user) external whenNotPaused {
        (uint256 amountETH, uint256 amountOP) = _claimableAmounts(user);
        if (amountETH > 0) {
            _transferWinnings(msg.sender, amountOP, amountETH);
        }
    }

    function claim() external whenNotPaused {
        (uint256 amountETH, uint256 amountOP) = _claimableAmounts(msg.sender);
        if (amountETH > 0) {
            _transferWinnings(msg.sender, amountOP, amountETH);
        }
        emit Claim(msg.sender, amountETH, amountOP);
    }

    function getClaimableAmounts(
        address user
    ) external view whenNotPaused returns (uint256, uint256) {
        return _getClaimableAmounts(user);
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

    // /// @notice Retrieves detailed winning information for a specified round of the game.
    // /// @dev This function calls `getWinningTicketsByRound` from an external contract identified
    // /// by `randomizerWrapper`.
    // /// It subsequently computes various winning metrics based on the retrieved winning tickets and the internal state
    // /// managed by this contract, including ETH and ZK-Points awarded per ticket. The computed metrics are returned in
    // /// multiple arrays, each array's indices correspond to a particular winning ticket.
    // /// @param _round The round for which the winning information is requested.
    // /// @return _winningTickets An array of ticket numbers that won in the specified round.
    // /// @return _winningAddresses An array of addresses that own the winning tickets.
    // /// @return _ethPerTicket An array of ETH amounts awarded per winning ticket.
    // /// @return _superchainRafflePointsPerTicket An array of ZK-Points awarded per winning ticket, considering all factors including any multipliers.
    // function getWinningTicketsAndAddresses(
    //     uint256 _round
    // )
    //     external
    //     view
    //     returns (
    //         uint256[] memory _winningTickets,
    //         address[] memory _winningAddresses,
    //         uint256[] memory _ethPerTicket,
    //         uint256[] memory _superchainRafflePointsPerTicket
    //     )
    // {
    //     _winningTickets = IRandomizerWrapper(randomizerWrapper)
    //         .getWinningTicketsByRound(_round);
    //     // Number of winning tickets
    //     uint256 nOfWinningTickets = _winningTickets.length;
    //     _winningAddresses = new address[](nOfWinningTickets);
    //     _ethPerTicket = new uint256[](nOfWinningTickets);
    //     _superchainRafflePointsPerTicket = new uint256[](nOfWinningTickets);
    //     // Get winning logic for number of winning tickets
    //     WinningLogic memory logic = winningLogic[nOfWinningTickets];
    //     for (uint256 i = 0; i < nOfWinningTickets; ++i) {
    //         // Get winning address for ticket on index 'i'
    //         address winningAddress = _getTicketBuyerAddress(
    //             _winningTickets[i],
    //             ticketsSoldPerRound[_round],
    //             _round
    //         );
    //         // Store winning address in return array
    //         _winningAddresses[i] = winningAddress;
    //         // Get superchainRafflepoints won from winning ticket.  Amount winning points corresponds
    //         /// with index in array and ticket index i.e. if your ticket is number 2 in
    //         /// array, then you get reward of SuperchainPoints
    //         uint256 superchainRafflePointsFromWinningTicket = logic
    //             .superchainRafflePoints[i];
    //         // Calculate and add amount of ETH won in the following manner:
    //         // 1. Percentage won for this ticket, of total ETH of round corresponds with
    //         // index in array, i.e. if ticket number 1 wins 75%, then index 0 in array has
    //         // 75% in BPS stored
    //         // 2. Sent percentage plus round to calculate total amount of ETH won
    //         _ethPerTicket[i] = _getETHAmount(logic.payoutPercentage[i], _round);
    //         // Calculate superchainRafflePoints user get for each ticket bought in this round + superchainRafflePoints from winning, if applicable (by default 0)
    //         uint256 totalSuperchainRafflePointsForRoundForTicket = (ticketsPerWallet[
    //                 _round
    //             ][winningAddress] * superchainRafflePointsPerTicket) +
    //                 superchainRafflePointsFromWinningTicket;
    //         // Pass total superchainRafflePoints for round plus multiplier for round and add result to total
    //         // amount which gets stored in return array
    //         _superchainRafflePointsPerTicket[
    //             i
    //         ] = totalSuperchainRafflePointsForRoundForTicket;
    //     }
    // }

    // /// @notice Retrieves the ticket numbers a user has for the current round.
    // /// @dev This function loops backward through the tickets sold in the round to compile the ticket numbers for the given user.
    // /// If the user hasn't bought any tickets for the round, an empty array is returned.
    // /// @param _user The address of the user whose ticket numbers are to be retrieved.
    // /// @return ticketsBought An array of ticket numbers the user has for the current round.
    // function getUserTicketNumbersOfCurrentRound(
    //     address _user
    // ) external view returns (uint256[] memory ticketsBought) {
    //     // Get current round
    //     uint256 round = _roundsSinceStart();
    //     // Get number of tickets bought by user for given round
    //     uint256 numberOfTicketsBought = ticketsPerWallet[round][_user];
    //     // Initiate dynamic array equal to number of tickets bought
    //     ticketsBought = new uint256[](numberOfTicketsBought);

    //     // If no tickets has been bought, return empty values
    //     if (numberOfTicketsBought == 0) return ticketsBought;

    //     // Get total tickets sold for round
    //     uint256 nOfTicketsSold = ticketsSoldPerRound[round];
    //     // Return array index
    //     uint256 ticketIndex = 0;

    //     // Loop through all tickets sold backward until the first ticket, number 1
    //     while (nOfTicketsSold > 0) {
    //         // If ticket number is mapped to user address
    //         if (ticketPerAddressPerRound[round][nOfTicketsSold] == _user) {
    //             // Store the ticket number
    //             ticketsBought[ticketIndex] = nOfTicketsSold;
    //             ticketIndex++;
    //             nOfTicketsSold--;

    //             // Keep adding tickets mapped to address(0) until all tickets have been checked, or
    //             // ticket is mapped to different address
    //             while (
    //                 nOfTicketsSold > 0 &&
    //                 ticketPerAddressPerRound[round][nOfTicketsSold] ==
    //                 address(0)
    //             ) {
    //                 ticketsBought[ticketIndex] = nOfTicketsSold;
    //                 ticketIndex++;
    //                 nOfTicketsSold--;
    //             }
    //         } else {
    //             nOfTicketsSold--;
    //         }
    //         // Break out loop when all tickets are collected before reaching ticket number 1
    //         if (ticketIndex == numberOfTicketsBought) {
    //             break;
    //         }
    //     }

    //     return ticketsBought;
    // }

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
                // if (protocolFee != 0) {
                //     // Total protocolFee collected for round * protocolFee / BPS to get amount
                //     uint256 totalFee = ((ticketsSold * ticketPrice) *
                //         protocolFee) / BPS;
                //     _transferEth(beneficiary, totalFee);
                // }
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

    function fundRaffle(
        uint256 rounds,
        uint256 OpAmount
    ) external payable whenNotPaused {
        uint256 EthAmount = msg.value;
        _transferOP(address(this), OpAmount);
        uint256 currentRound = _roundsSinceStart();
        for (uint256 i = currentRound; i < currentRound + rounds; i++) {
            roundPrizes[i].EthAmount += (EthAmount / rounds);
            roundPrizes[i].OpAmount += (OpAmount / rounds);
              emit RaffleFunded(i, EthAmount / rounds, OpAmount / rounds);
        }
    }

    // --------------------------
    // Restricted Functions
    // --------------------------

    // To Do: Create restricted function to update winning logic

    function setMaxAmountTicketsPerRound(
        uint256 _amountTickets
    ) external onlyOwner {
        _setMaxAmountTicketsPerRound(_amountTickets);
    }

    function setURI(string memory _uri) external onlyOwner {
        uri = _uri;
    }

    function _setURI(string memory _uri) internal {
        uri = _uri;
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

    function setStartTime(uint256 _timeStamp) external onlyOwner {
        startTime = _timeStamp;
        emit RaffleStarted(_timeStamp);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw(
        uint256 _amountEth,
        uint256 _amountOp
    ) external onlyOwner {
        if (_amountEth > address(this).balance)
            revert SuperchainRaffle__NotEnoughEtherInContract();
        (bool sent, ) = payable(beneficiary).call{value: _amountEth}("");
        if (!sent) revert SuperchainRaffle__FailedToSentEther();
        if (_amountOp > opToken.balanceOf(address(this))) {
            revert SuperchainRaffle__NotEnoughOpInContract();
        }
        bool opSent = IERC20(opToken).transfer(beneficiary, _amountOp);
        if (!opSent) revert SuperchainRaffle__FailedToSentOp();
    }

    function setProtocolFee(uint256 _fee) external onlyOwner {
        _setProtocolFee(_fee);
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
     * @return amountETH The total amount of ETH that the user can claim.
     * @return amountOP The total amount of SuperchainPoints that the user can claim.
     */
    function _claimableAmounts(
        address user
    ) internal returns (uint256 amountETH, uint256 amountOP) {
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
                for (uint256 i; i < nOfWinningTickets; ++i) {
                    // If buy of ticket in array == user
                    if (
                        _getTicketBuyerAddress(
                            winningTickets[i],
                            ticketsSoldPerRound[round],
                            round
                        ) == user
                    ) {
                        // Calculate and add amount of ETH won in the following manner:
                        // 1. Percentage won for this ticket, of total ETH of round corresponds with
                        // index in array, i.e. if ticket number 1 wins 75%, then index 0 in array has
                        // 75% in BPS stored
                        // 2. Sent percentage plus round to calculate total amount of ETH won
                        amountETH += _getETHAmount(
                            logic.payoutPercentage[i],
                            round
                        );
                        amountOP += _getOPAmount(
                            logic.payoutPercentage[i],
                            round
                        );
                    }
                }
                // Set the amount eth won which is used in the UI. The number 1. here represents if the round has been claimed, but no ETH
                // has been won
                winningClaimed[round][user] = amountETH != 0 ? amountETH : 1;
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
     * @return amountETH The total amount of ETH that the user can claim.
     * @return amountOP The total amount of SuperchainPoints that the user can claim.
     */
    function _getClaimableAmounts(
        address user
    ) internal view returns (uint256 amountETH, uint256 amountOP) {
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

                for (uint256 i; i < nOfWinningTickets; ++i) {
                    // If buy of ticket in array == user
                    if (
                        _getTicketBuyerAddress(
                            winningTickets[i],
                            ticketsSoldPerRound[round],
                            round
                        ) == user
                    ) {
                        amountETH += _getETHAmount(
                            logic.payoutPercentage[i],
                            round
                        );
                        amountOP += _getOPAmount(
                            logic.payoutPercentage[i],
                            round
                        );
                    }
                }
            }
        }
    }

    function _transferWinnings(
        address _to,
        uint256 _amountOP,
        uint256 _amountETH
    ) internal {
        _transferOP(_to, _amountOP);
        _transferEth(_to, _amountETH);
    }

    function _transferOP(address _to, uint256 _amountOP) internal {
        if (_to == address(this)) {
            require(
                opToken.transferFrom(msg.sender, _to, _amountOP),
                "OP transfer failed"
            );
        } else {
            require(opToken.transfer(_to, _amountOP), "OP transfer failed");
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
        uint256 totalEthCollected = roundPrizes[_round].EthAmount;
        if (totalEthCollected == 0) {
            return 0;
        }

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
        return ((totalWinnableETHPrizeForRound * _percentage) / BPS);
    }

    function _getOPAmount(
        uint256 _percentage,
        uint256 _round
    ) internal view returns (uint256) {
        uint256 totalOPCollected = roundPrizes[_round].OpAmount;
        if (totalOPCollected == 0) {
            return 0;
        }

        return ((totalOPCollected * _percentage) / BPS);
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

    function _roundsSinceStart() internal view returns (uint256) {
        if (block.timestamp < startTime)
            revert SuperchainRaffle__SuperchainRaffleNotStartedYet();
        return ((block.timestamp - startTime) / 1 weeks) + 1;
    }

    function _setBeneficiary(address _beneficiary) internal {
        beneficiary = _beneficiary;
    }

    function _setSuperchainModule(address _newSuperchainModule) internal {
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

    function _setNewStartTime(uint256 _startTime) internal {
        startTime = _startTime;
    }

    function _setMaxAmountTicketsPerRound(uint256 _maxAmount) internal {
        maxAmountTickets = _maxAmount;
    }

    function _setProtocolFee(uint256 _fee) internal {
        protocolFee = _fee;
    }

    function _setWinningLogic(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _payoutPercentage
    ) internal {
        uint256 arrayLength = _numberOfWinners.length;
        for (uint256 i; i < arrayLength; ++i) {
            WinningLogic storage logic = winningLogic[_numberOfWinners[i]];
            if (
                winningLogic[uint256(_numberOfWinners[i])]
                    .payoutPercentage
                    .length != 0
            ) {
                delete logic.payoutPercentage;
            }
            uint256 innerArrayLength = _payoutPercentage[i].length;
            for (uint256 j; j < innerArrayLength; ++j) {
                logic.payoutPercentage.push(uint256(_payoutPercentage[i][j]));
            }
        }
    }
}
