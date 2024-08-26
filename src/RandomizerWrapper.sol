//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {GelatoVRFConsumerBase} from "vrf-contracts/GelatoVRFConsumerBase.sol";
import {IRandomizerWrapper} from "./interfaces/IRandomizerWrapper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RandomizerWrapper is
    IRandomizerWrapper,
    Ownable,
    GelatoVRFConsumerBase
{
    mapping(uint256 => uint256[]) public roundToWinningNumbers;
    mapping(uint256 => uint256) public roundToTicketsSold;
    mapping(uint256 => uint256) public roundToRequestId;
    address private _operatorAddr;
    address public superchainRaffle;
    address public beneficiary;

    // --------------------------
    // Modifiers
    // --------------------------

    modifier onlySuperchainRaffle() {
        if (msg.sender != superchainRaffle) revert OnlySuperchainRaffle();
        _;
    }

    constructor(
        address _superchainRaffle,
        address _beneficiary,
        address operator
    ) Ownable(msg.sender) {
        _setSuperchainRaffle(_superchainRaffle);
        _setBeneficiary(_beneficiary);
        _operatorAddr = operator;
    }

    // --------------------------
    // Public Functions
    // --------------------------

    /**
     * @dev Retrieves the winning ticket numbers for a specific play round.
     *
     * @param _round The play round number.
     * @return An array of winning ticket numbers for the specified play round.
     */
    function getWinningTicketsByRound(
        uint256 _round
    ) external view returns (uint256[] memory) {
        return roundToWinningNumbers[_round];
    }

    // --------------------------
    // Restricted Functions
    // --------------------------

    /**
     * @dev Requests random number from the Randomizer contract.
     *
     * This function requests one true random number from the Randomizer contract. The randomizer contract
     * will call the callback function in the contract, depositing the random number and drawing the winning
     * numbers in the process.
     * as much needed pseudo-random numbers derived from the true random number. These numbers
     * represent winning tickets. The winning numbers are unique and no round has multiple sets of winning numbers.
     *
     * Requirements:
     *
     * - The function caller must be the superchainRaffle.
     * - The correct amount of ETH to cover the VRF cost must be sent.
     * - The play round must not already have winning numbers.
     * - The number of tickets sold must be bigger than zero
     *
     * @param _round The play round for which the winners are to be drawn.
     * @param _numberOfTicketsSold The total number of tickets sold for the play round.
     */
    function requestRandomNumber(
        uint256 _round,
        uint256 _numberOfTicketsSold
    ) external payable onlySuperchainRaffle {
        require(
            roundToRequestId[_round] == 0,
            "Round already has requested random number"
        );
        // Don't call randomizer if no tickets have been sold, saving randomizer fee
        if (_numberOfTicketsSold == 0) return;
        // Set ticket number 1 as winner if only one ticket has been sold, saving Randomizer fee
        else if (_numberOfTicketsSold == 1) {
            roundToWinningNumbers[_round].push(1); // Ticket with number 1 has won
            return;
        }
        // Check that random value is not already drawn for round
        if (roundToWinningNumbers[_round].length > 0)
            revert RandomizerWrapper__RoundAlreadyHasWinners();
        roundToTicketsSold[_round] = _numberOfTicketsSold;
        uint256 requestId = _requestRandomness(abi.encode(_round));
        roundToRequestId[_round] = requestId;
    }

    function _fulfillRandomness(
        uint256 randomness,
        uint256 requestId,
        bytes memory data
    ) internal override {
        uint256 _round = abi.decode(data, (uint256));
        require(roundToRequestId[_round] == requestId, "Invalid requestId");
        randomizerCallback(_round, bytes32(randomness));
    }

    function randomizerCallback(uint256 _id, bytes32 _value) internal {
        // Get round from request ID
        uint256 round = _id;
        // Get number of tickets sold from round
        uint256 numberOfTicketsSold = roundToTicketsSold[round];
        // Get number of random values needed in the play
        uint256 numberOfRandomValues = _getNumberOfRandomValues(
            numberOfTicketsSold
        );
        uint256 winningTicket;
        if (numberOfRandomValues == 1) {
            // Get winning ticket
            winningTicket = _getTicketNumberFromRandomValue(
                uint256(_value),
                numberOfTicketsSold
            );
            roundToWinningNumbers[round].push(winningTicket);
        } else {
            // Get pseudo random numbers for number of random values
            for (uint256 i = 0; i < numberOfRandomValues; ) {
                bool doubleValue = true;
                // Derive a starting pseudo random value as variant for derived numbers
                uint256 value = _getTicketNumberFromRandomValue(
                    _derivedRandomNumbers(uint256(_value), i),
                    numberOfTicketsSold
                );
                // While doubles are found
                while (doubleValue) {
                    // Get winning ticket
                    winningTicket = _getTicketNumberFromRandomValue(
                        _derivedRandomNumbers(uint256(_value), value),
                        numberOfTicketsSold
                    );
                    // Check for doublicate value
                    doubleValue = _checkDoubleValue(
                        winningTicket,
                        round,
                        roundToWinningNumbers[round].length
                    );
                    // Change variant to create different winning ticket
                    value = (value + 1) % numberOfTicketsSold; // Wrap around if necessary
                }
                // Store winning ticket in mapping for round => tickets
                roundToWinningNumbers[round].push(winningTicket);
                i++;
            }
        }
        // Emit winning tickets
        emit RandomizerWrapper__RoundWinners(
            round,
            numberOfTicketsSold,
            roundToWinningNumbers[round]
        );
    }

    function estimateRandomizerFee() external pure returns (uint256) {
        return 0;
    }

    /**
     * @dev Checks if a winning ticket number is already present in the list of winners for a play round.
     *
     * @param _winningTicket The ticket number to check.
     * @param _round The play round to check within.
     * @param _arrayLength The current length of the array of winning numbers for the play round.
     * @return `true` if the ticket number is already present in the list of winners, `false` otherwise.
     */
    function _checkDoubleValue(
        uint _winningTicket,
        uint _round,
        uint _arrayLength
    ) internal view returns (bool) {
        for (uint256 j = 0; j < _arrayLength; ++j) {
            if (roundToWinningNumbers[_round][j] == _winningTicket) {
                return true;
            }
        }
        return false;
    }

    function setBeneficiary(address _beneficiary) external onlyOwner {
        _setBeneficiary(_beneficiary);
    }

  

    function setSuperchainRaffle(address _superchainRaffle) external onlyOwner {
        _setSuperchainRaffle(_superchainRaffle);
    }


    // --------------------------
    // Internal
    // --------------------------

    /**
     * @dev Will return a non-zero ticket number
     *
     */
    function _getTicketNumberFromRandomValue(
        uint _randomValue,
        uint _modulo
    ) internal pure returns (uint ticketNumber) {
        uint extraVariation = 0;
        while (ticketNumber == 0) {
            unchecked {
                ticketNumber = (_randomValue + extraVariation) % _modulo;
                extraVariation += uint(
                    keccak256(abi.encodePacked(_randomValue + extraVariation))
                );
            }
        }
    }

    /**
     * @dev Derive random numbers from the number gottan from the VRF
     */
    function _derivedRandomNumbers(
        uint256 _randomValue,
        uint256 _number
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_randomValue, _number)));
    }

    /**
     * @dev Number of random values needed in the SuperchainRaffle based on number of tickets sold
     * <= 10 = 1 winner
     * <= 100 = 5 winners
     * > 100 = 10 winners
     */
    function _getNumberOfRandomValues(
        uint256 _numberOfTicketsSold
    ) internal pure returns (uint256) {
        if (_numberOfTicketsSold <= 10) return 1;
        else return 10;
    }

    function _setBeneficiary(address _beneficiary) internal {
        beneficiary = _beneficiary;
    }

    function _setSuperchainRaffle(address _superchainRaffle) internal {
        superchainRaffle = _superchainRaffle;
    }

    function withdraw() external onlyOwner {
        if (address(this).balance > 0) {
            (bool sent, ) = beneficiary.call{value: address(this).balance}("");
            if (!sent) revert RandomizerWrapper__FailedToSentEther();
        }
    }

    function _operator() internal view override returns (address) {
        return _operatorAddr;
    }

    receive() external payable {}
}
