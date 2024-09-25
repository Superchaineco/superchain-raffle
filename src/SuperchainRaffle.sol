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
    uint256 public startTime;
    address public superchainModule;
    address public randomizerWrapper;
    bool public mainnetRandomizedWrapper;
    uint256 public protocolFee;
    uint256 public immutable BPS = 10_000;
    uint256 public maxAmountTickets = 250;
    mapping(uint256 => WinningLogic) private winningLogic;
    mapping(uint256 => RaffleRound) public raffleRounds;
    struct RaffleRound {
        uint256 ticketsSold;
        RoundPrize roundPrizes;
        mapping(address => uint256) ticketsPerWallet;
        mapping(address => bool) winningClaimed;
        mapping(uint256 => address) ticketOwners;
        uint256[] winningNumbers;
    }

    constructor(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _payoutPercentage,
        address _beneficiary,
        address _opToken,
        address _superchainModule,
        address _randomizerWrapper
    ) Ownable(msg.sender) {
        _setWinningLogic(_numberOfWinners, _payoutPercentage);
        _setBeneficiary(_beneficiary);
        opToken = IERC20(_opToken);
        _setProtocolFee(0);
        _setSuperchainModule(_superchainModule);
        randomizerWrapper = _randomizerWrapper;
    }

    function roundsSinceStart() public view returns (uint256) {
        return _roundsSinceStart();
    }

    function enterRaffle(uint256 _numberOfTickets) external whenNotPaused {
        if (
            ISuperchainModule(superchainModule)
                .getSuperChainAccount(msg.sender)
                .smartAccount == address(0)
        ) {
            revert SuperchainRaffle__SenderIsNotSCSA();
        }

        uint256 round = _roundsSinceStart();
        RaffleRound storage currentRound = raffleRounds[round];
        uint256 ticketsRemaining = freeTicketsRemaining(msg.sender);

        if (_numberOfTickets > ticketsRemaining) {
            revert SuperchainRaffle__NotEnoughFreeTickets();
        }

        if (currentRound.ticketsSold + _numberOfTickets > maxAmountTickets)
            revert SuperchainRaffle__MaxNumberOfTicketsReached();

        currentRound.ticketsPerWallet[msg.sender] += _numberOfTickets;
        for (uint256 i = 0; i < _numberOfTickets; i++) {
            currentRound.ticketOwners[currentRound.ticketsSold + i] = msg
                .sender;
        }
        currentRound.ticketsSold += _numberOfTickets;

        emit TicketsPurchased(
            msg.sender,
            currentRound.ticketsSold,
            _numberOfTickets,
            round
        );
    }

    function freeTicketsRemaining(address user) public view returns (uint256) {
        uint256 round = _roundsSinceStart();
        RaffleRound storage currentRound = raffleRounds[round];
        uint16 userLevel = ISuperchainModule(superchainModule)
            .getSuperChainAccount(user)
            .level;
        uint256 ticketsBought = currentRound.ticketsPerWallet[user];
        return
            ticketsBought >= uint256(userLevel) ? 0 : userLevel - ticketsBought;
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

    function raffle() external whenNotPaused {
        uint256 currentRound = _roundsSinceStart() - 1;
        uint256 lastUnclaimedRound = 0;

        for (uint256 round = 0; round <= currentRound; round++) {
            if (raffleRounds[round].winningNumbers.length == 0) {
                lastUnclaimedRound = round;
                break;
            }
        }

        for (uint256 round = lastUnclaimedRound; round <= currentRound; round++) {
            RaffleRound storage currentRaffleRound = raffleRounds[round];
            if (currentRaffleRound.winningNumbers.length != 0) continue;

            uint256 ticketsSold = currentRaffleRound.ticketsSold;
            uint256 ethPrize = currentRaffleRound.roundPrizes.EthAmount;
            uint256 opPrize = currentRaffleRound.roundPrizes.OpAmount;

            if (ethPrize == 0 && opPrize == 0) {
                continue;
            }

            if (ticketsSold == 0) {
                uint256 nextRound = round + 1;
                if (nextRound <= currentRound + 1) {
                    RaffleRound storage nextRaffleRound = raffleRounds[nextRound];
                    nextRaffleRound.roundPrizes.EthAmount += ethPrize;
                    nextRaffleRound.roundPrizes.OpAmount += opPrize;
                    currentRaffleRound.roundPrizes.EthAmount = 0;
                    currentRaffleRound.roundPrizes.OpAmount = 0;
                }
                continue;
            }

            if (ticketsSold == 1) {
                currentRaffleRound.winningNumbers.push(0);
            } else {
                IRandomizerWrapper(randomizerWrapper).requestRandomNumber(
                    address(this),
                    round
                );
            }
        }
    }

    function canRaffle() external view returns (bool isRaffleable) {
        uint256 round = _roundsSinceStart() - 1;
        for (round; round > 0; round--) {
            if (raffleRounds[round].winningNumbers.length == 0) {
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
        uint256 _currentRound = _roundsSinceStart();
        for (uint256 i = _currentRound; i < _currentRound + rounds; i++) {
            RaffleRound storage currentRound = raffleRounds[i];
            currentRound.roundPrizes.EthAmount += (EthAmount / rounds);
            currentRound.roundPrizes.OpAmount += (OpAmount / rounds);
            emit RaffleFunded(i, EthAmount / rounds, OpAmount / rounds);
        }
    }
    function getTicketOwner(
        uint256 ticketId,
        uint256 round
    ) external view returns (address) {
        return raffleRounds[round].ticketOwners[ticketId];
    }

    function setMaxAmountTicketsPerRound(
        uint256 _amountTickets
    ) external onlyOwner {
        _setMaxAmountTicketsPerRound(_amountTickets);
    }

    function setURI(string memory _uri) external onlyOwner {
        uri = _uri;
    }

    function setBeneficiary(address _beneficiary) external onlyOwner {
        _setBeneficiary(_beneficiary);
    }

    function setSuperchainModule(
        address _newSuperchainModule
    ) external onlyOwner {
        _setSuperchainModule(_newSuperchainModule);
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
        if (_amountOp > opToken.balanceOf(address(this)))
            revert SuperchainRaffle__NotEnoughOpInContract();
        bool opSent = IERC20(opToken).transfer(beneficiary, _amountOp);
        if (!opSent) revert SuperchainRaffle__FailedToSentOp();
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
        return raffleRounds[round].ticketsPerWallet[user];
    }

    function getTotalTicketsPerRound(
        uint256 round
    ) external view whenNotPaused returns (uint256) {
        return raffleRounds[round].ticketsSold;
    }

    function getWinningNumbers(
        uint256 round
    ) external view returns (uint256[] memory) {
        return raffleRounds[round].winningNumbers;
    }
    function getRoundPrizes(
        uint256 _round
    ) external view returns (uint256 EthAmount, uint256 OpAmount) {
        RaffleRound storage currentRound = raffleRounds[_round];
        EthAmount = currentRound.roundPrizes.EthAmount;
        OpAmount = currentRound.roundPrizes.OpAmount;
    }

    function totalRoundsPlayed(
        address _user,
        uint256 _startRound,
        uint256 _endRound
    ) external view returns (uint256 roundsPlayed) {
        if (_endRound > roundsSinceStart() - 1)
            revert SuperchainRaffle__InvalidEndRound();
        for (_startRound; _startRound <= _endRound; _startRound++) {
            if (raffleRounds[_startRound].ticketsPerWallet[_user] != 0)
                roundsPlayed++;
        }
    }

    function _claimableAmounts(
        address user
    ) internal returns (uint256 amountETH, uint256 amountOP) {
        uint256 round = (_roundsSinceStart() - 1);
        for (round; round > 0; round--) {
            RaffleRound storage currentRound = raffleRounds[round];
            if (currentRound.winningClaimed[user]) break;
            if (currentRound.winningNumbers.length != 0) {
                uint256[] memory winningTickets = currentRound.winningNumbers;
                uint256 nOfWinningTickets = winningTickets.length;
                WinningLogic memory logic = winningLogic[nOfWinningTickets];
                for (uint256 i; i < nOfWinningTickets; ++i) {
                    if (currentRound.ticketOwners[winningTickets[i]] == user) {
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
                if (amountETH != 0 || amountOP != 0) {
                    currentRound.winningClaimed[user] = true;
                }
            }
        }
    }

    function _getClaimableAmounts(
        address user
    ) internal view returns (uint256 amountETH, uint256 amountOP) {
        uint256 round = (_roundsSinceStart() - 1);
        for (round; round > 0; round--) {
            if (raffleRounds[round].winningClaimed[user]) break;
            if (raffleRounds[round].winningNumbers.length != 0) {
                uint256[] memory winningTickets = raffleRounds[round]
                    .winningNumbers;
                uint256 nOfWinningTickets = winningTickets.length;
                WinningLogic memory logic = winningLogic[nOfWinningTickets];
                for (uint256 i; i < nOfWinningTickets; ++i) {
                    if (
                        _getTicketBuyerAddress(
                            winningTickets[i],
                            raffleRounds[round].ticketsSold,
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
        if (!sent) revert EthTransferFailed();
    }

    function _getETHAmount(
        uint256 _percentage,
        uint256 _round
    ) internal view returns (uint256) {
        RaffleRound storage currentRound = raffleRounds[_round];
        uint256 totalEthCollected = currentRound.roundPrizes.EthAmount;
        if (totalEthCollected == 0) return 0;
        uint256 protocolFeeAmount = protocolFee == 0
            ? 0
            : (totalEthCollected * protocolFee) / BPS;
        uint256 totalWinnableETHPrizeForRound = totalEthCollected -
            protocolFeeAmount;
        return ((totalWinnableETHPrizeForRound * _percentage) / BPS);
    }

    function _getOPAmount(
        uint256 _percentage,
        uint256 _round
    ) internal view returns (uint256) {
        RaffleRound storage currentRound = raffleRounds[_round];
        uint256 totalOPCollected = currentRound.roundPrizes.OpAmount;
        if (totalOPCollected == 0) return 0;
        return ((totalOPCollected * _percentage) / BPS);
    }

    function _getTicketBuyerAddress(
        uint256 _winningTicket,
        uint256 _ticketSold,
        uint256 _round
    ) internal view returns (address winner) {
        for (uint256 i = _winningTicket; i <= _ticketSold; ++i) {
            RaffleRound storage currentRound = raffleRounds[_round];
            address temp = currentRound.ticketOwners[i];
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

    function randomizerCallback(uint256 _round, uint256 randomness) external {
        require(
            msg.sender == randomizerWrapper,
            "Only RandomizerWrapper can call this function"
        );
        uint256 numberOfTicketsSold = raffleRounds[_round].ticketsSold;
        uint256 numberOfRandomValues = _getNumberOfRandomValues(
            numberOfTicketsSold
        );
        uint256 winningTicket;
        uint256[] memory winningTickets = new uint256[](numberOfRandomValues);
        if (numberOfRandomValues == 1) {
            winningTicket = _getTicketNumberFromRandomValue(
                randomness,
                numberOfTicketsSold
            );
            raffleRounds[_round].winningNumbers.push(winningTicket);
            winningTickets[0] = winningTicket;
        } else {
            for (uint256 i = 0; i < numberOfRandomValues; ) {
                bool doubleValue = true;
                uint256 value = _getTicketNumberFromRandomValue(
                    _derivedRandomNumbers(randomness, i),
                    numberOfTicketsSold
                );
                while (doubleValue) {
                    winningTicket = _getTicketNumberFromRandomValue(
                        _derivedRandomNumbers(randomness, value),
                        numberOfTicketsSold
                    );
                    doubleValue = _checkDoubleValue(
                        winningTicket,
                        _round,
                        raffleRounds[_round].winningNumbers.length
                    );
                    value = (value + 1) % numberOfTicketsSold;
                }
                raffleRounds[_round].winningNumbers.push(winningTicket);
                winningTickets[i] = winningTicket;
                i++;
            }
        }
        emit RoundWinners(_round, numberOfTicketsSold, winningTickets);
    }

    function _checkDoubleValue(
        uint _winningTicket,
        uint _round,
        uint _arrayLength
    ) internal view returns (bool) {
        for (uint256 j = 0; j < _arrayLength; ++j) {
            if (raffleRounds[_round].winningNumbers[j] == _winningTicket) {
                return true;
            }
        }
        return false;
    }

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

    function _derivedRandomNumbers(
        uint256 _randomValue,
        uint256 _number
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_randomValue, _number)));
    }

    function _getNumberOfRandomValues(
        uint256 _numberOfTicketsSold
    ) internal pure returns (uint256) {
        if (_numberOfTicketsSold <= 10) return 1;
        else return 10;
    }
}
