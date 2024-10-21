//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {ISuperchainRaffle} from "./interfaces/ISuperchainRaffle.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperchainModule} from "./interfaces/ISuperchainModule.sol";
import {IRandomizerWrapper} from "./interfaces/IRandomizerWrapper.sol";

contract SuperchainRaffle is
    Initializable,
    ISuperchainRaffle,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    struct RaffleRound {
        uint256 ticketsSold;
        RoundPrize roundPrizes;
        mapping(address => uint256) ticketsPerWallet;
        mapping(address => bool) winningClaimed;
        mapping(uint256 => address) ticketOwners;
        uint256[] winningNumbers;
    }
    struct SuperChainRaffleStorage {
        address beneficiary;
        IERC20 opToken;
        string uri;
        uint256 startTime;
        address superchainModule;
        address randomizerWrapper;
        bool mainnetRandomizedWrapper;
        uint256 protocolFee;
        uint256 maxAmountTickets;
        RandomValueThreshold[] randomValueThresholds; // Nueva variable de estado
        mapping(uint256 => WinningLogic) winningLogic;
        mapping(uint256 => RaffleRound) raffleRounds;
        uint256[] freeTicketsPerLevel;
        uint256[] winningLogicKeys;
    }
    uint256 public constant BPS = 10_000;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.superchain_raffle")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SUPERCHAIN_RAFFLE_STORAGE_LOCATION =
        0xe6e73cc6ab709186c31bbc8e40a3f00c92050f83301f9ffd3a431a89d588f300;

    function superChainRaffleStorage()
        private
        pure
        returns (SuperChainRaffleStorage storage $)
    {
        assembly {
            $.slot := SUPERCHAIN_RAFFLE_STORAGE_LOCATION
        }
    }

    function initialize(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _payoutPercentage,
        address _beneficiary,
        address _opToken,
        address _superchainModule,
        address _randomizerWrapper,
        address owner
    ) public initializer {
        __Ownable_init(owner);
        __UUPSUpgradeable_init();
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        _setWinningLogic(_numberOfWinners, _payoutPercentage);
        _setBeneficiary(_beneficiary);
        s.opToken = IERC20(_opToken);
        s.maxAmountTickets = 250;
        _setProtocolFee(0);
        _setSuperchainModule(_superchainModule);
        s.randomizerWrapper = _randomizerWrapper;
    }

    modifier onlySuperChainAccount(address user) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        if (
            ISuperchainModule(s.superchainModule)
                .getSuperChainAccount(msg.sender)
                .smartAccount == address(0)
        ) {
            revert SuperchainRaffle__SenderIsNotSCSA();
        }
        _;
    }

    modifier onlyRandomizerWrapper() {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        if (msg.sender != s.randomizerWrapper) {
            revert SuperchainRaffle__OnlyRandomizerWrapper();
        }
        _;
    }

    function roundsSinceStart() public view returns (uint256) {
        return _roundsSinceStart();
    }

    function enterRaffle(
        uint256 _numberOfTickets
    ) external whenNotPaused onlySuperChainAccount(msg.sender) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 round = _roundsSinceStart();
        RaffleRound storage currentRound = s.raffleRounds[round];
        uint256 ticketsRemaining = freeTicketsRemaining(msg.sender);

        if (_numberOfTickets > ticketsRemaining) {
            revert SuperchainRaffle__NotEnoughFreeTickets();
        }

        if (currentRound.ticketsSold + _numberOfTickets > s.maxAmountTickets)
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 round = _roundsSinceStart();
        RaffleRound storage currentRound = s.raffleRounds[round];
        uint16 userLevel = ISuperchainModule(s.superchainModule)
            .getSuperChainAccount(user)
            .level;
        if (userLevel == 0) return 0;
        uint256 freeTicketsForLevel;
        if (userLevel > s.freeTicketsPerLevel.length) {
            freeTicketsForLevel = s.freeTicketsPerLevel[
                s.freeTicketsPerLevel.length - 1
            ];
        } else {
            freeTicketsForLevel = s.freeTicketsPerLevel[userLevel - 1];
        }
        uint256 ticketsBought = currentRound.ticketsPerWallet[user];
        return
            ticketsBought >= freeTicketsForLevel
                ? 0
                : freeTicketsForLevel - ticketsBought;
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 currentRound = _roundsSinceStart() - 1;
        uint256 lastUnclaimedRound = 0;

        for (uint256 round = 0; round <= currentRound; round++) {
            if (s.raffleRounds[round].winningNumbers.length == 0) {
                lastUnclaimedRound = round;
                break;
            }
        }

        for (
            uint256 round = lastUnclaimedRound;
            round <= currentRound;
            round++
        ) {
            RaffleRound storage currentRaffleRound = s.raffleRounds[round];
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
                    RaffleRound storage nextRaffleRound = s.raffleRounds[
                        nextRound
                    ];
                    nextRaffleRound.roundPrizes.EthAmount += ethPrize;
                    nextRaffleRound.roundPrizes.OpAmount += opPrize;
                    currentRaffleRound.roundPrizes.EthAmount = 0;
                    currentRaffleRound.roundPrizes.OpAmount = 0;
                    emit RaffleFundMoved(round, nextRound);
                }
                continue;
            }

            if (ticketsSold == 1) {
                currentRaffleRound.winningNumbers.push(0);
                Winner[] memory winners = new Winner[](1);
                winners[0] = Winner(
                    0,
                    currentRaffleRound.ticketOwners[0],
                    opPrize,
                    ethPrize
                );

                emit RoundWinners(round, ticketsSold, winners);
            } else {
                IRandomizerWrapper(s.randomizerWrapper).requestRandomNumber(
                    address(this),
                    round
                );
            }
        }
    }

    function canRaffle() external view returns (bool isRaffleable) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 round = _roundsSinceStart() - 1;
        for (round; round > 0; round--) {
            if (s.raffleRounds[round].winningNumbers.length == 0) {
                isRaffleable = true;
                return isRaffleable;
            }
        }
    }

    function fundRaffle(
        uint256 rounds,
        uint256 OpAmount
    ) external payable whenNotPaused {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 EthAmount = msg.value;
        _transferOP(address(this), OpAmount);
        uint256 _currentRound = _roundsSinceStart();
        for (uint256 i = _currentRound; i < _currentRound + rounds; i++) {
            RaffleRound storage currentRound = s.raffleRounds[i];
            currentRound.roundPrizes.EthAmount += (EthAmount / rounds);
            currentRound.roundPrizes.OpAmount += (OpAmount / rounds);
            emit RaffleFunded(i, EthAmount / rounds, OpAmount / rounds);
        }
    }
    function getTicketOwner(
        uint256 ticketId,
        uint256 round
    ) public view returns (address) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.raffleRounds[round].ticketOwners[ticketId];
    }

    function setMaxAmountTicketsPerRound(
        uint256 _amountTickets
    ) external onlyOwner {
        _setMaxAmountTicketsPerRound(_amountTickets);
    }

    function setURI(string memory _uri) external onlyOwner {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        s.uri = _uri;
        emit URIChanged(_uri);
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        s.startTime = _timeStamp;
        emit RaffleStarted(_timeStamp);
    }

    function setProtocolFee(uint256 _fee) external onlyOwner {
        _setProtocolFee(_fee);
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        if (_amountEth > address(this).balance)
            revert SuperchainRaffle__NotEnoughEtherInContract();
        (bool sent, ) = payable(s.beneficiary).call{value: _amountEth}("");
        if (!sent) revert SuperchainRaffle__FailedToSentEther();
        if (_amountOp > s.opToken.balanceOf(address(this)))
            revert SuperchainRaffle__NotEnoughOpInContract();
        bool opSent = IERC20(s.opToken).transfer(s.beneficiary, _amountOp);
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.raffleRounds[round].ticketsPerWallet[user];
    }

    function getTicketsSoldPerRound(
        uint256 round
    ) external view whenNotPaused returns (uint256) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.raffleRounds[round].ticketsSold;
    }

    function getWinningNumbers(
        uint256 round
    ) external view returns (uint256[] memory) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.raffleRounds[round].winningNumbers;
    }

    function getWinningLogic()
        external
        view
        returns (uint256[] memory, uint256[][] memory)
    {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 length = s.winningLogicKeys.length;
        uint256[] memory numberOfWinners = new uint256[](length);
        uint256[][] memory payoutPercentages = new uint256[][](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 key = s.winningLogicKeys[i];
            numberOfWinners[i] = key;
            payoutPercentages[i] = s.winningLogic[key].payoutPercentage;
        }

        return (numberOfWinners, payoutPercentages);
    }

    function getFreeTicketsPerLevel() external view returns (uint256[] memory) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.freeTicketsPerLevel;
    }

    function getRoundPrizes(
        uint256 _round
    ) external view returns (uint256 EthAmount, uint256 OpAmount) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        RaffleRound storage currentRound = s.raffleRounds[_round];
        EthAmount = currentRound.roundPrizes.EthAmount;
        OpAmount = currentRound.roundPrizes.OpAmount;
    }

    function totalRoundsPlayed(
        address _user,
        uint256 _startRound,
        uint256 _endRound
    ) external view returns (uint256 roundsPlayed) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        if (_endRound > roundsSinceStart() - 1)
            revert SuperchainRaffle__InvalidEndRound();
        for (_startRound; _startRound <= _endRound; _startRound++) {
            if (s.raffleRounds[_startRound].ticketsPerWallet[_user] != 0)
                roundsPlayed++;
        }
    }
    function setRandomValueThresholds(
        RandomValueThreshold[] memory _randomValueThresholds
    ) external onlyOwner {
        _setRandomValueThresholds(_randomValueThresholds); // Nueva función para actualizar los umbrales
    }

    function setWinningLogic(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _payoutPercentage
    ) external onlyOwner {
        _setWinningLogic(_numberOfWinners, _payoutPercentage);
    }

    function setFreeTicketsPerLevel(
        uint256[] memory _freeTicketsPerLevel
    ) external onlyOwner {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        s.freeTicketsPerLevel = _freeTicketsPerLevel;
        emit FreeTicketsPerLevelChanged(_freeTicketsPerLevel);
    }

    function _setRandomValueThresholds(
        RandomValueThreshold[] memory _randomValueThresholds
    ) internal {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        delete s.randomValueThresholds; // Limpiar los umbrales existentes
        for (uint256 i = 0; i < _randomValueThresholds.length; i++) {
            s.randomValueThresholds.push(_randomValueThresholds[i]);
        }
    }

    // .

    function _claimableAmounts(
        address user
    ) internal returns (uint256 amountETH, uint256 amountOP) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 round = (_roundsSinceStart() - 1);
        for (round; round > 0; round--) {
            RaffleRound storage currentRound = s.raffleRounds[round];
            if (currentRound.winningClaimed[user]) break;
            if (currentRound.winningNumbers.length != 0) {
                uint256[] memory winningTickets = currentRound.winningNumbers;
                uint256 nOfWinningTickets = winningTickets.length;
                WinningLogic memory logic = s.winningLogic[nOfWinningTickets];
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 round = (_roundsSinceStart() - 1);
        for (round; round > 0; round--) {
            if (s.raffleRounds[round].winningClaimed[user]) break;
            if (s.raffleRounds[round].winningNumbers.length != 0) {
                uint256[] memory winningTickets = s
                    .raffleRounds[round]
                    .winningNumbers;
                uint256 nOfWinningTickets = winningTickets.length;
                WinningLogic memory logic = s.winningLogic[nOfWinningTickets];
                for (uint256 i; i < nOfWinningTickets; ++i) {
                    if (
                        _getTicketBuyerAddress(winningTickets[i], round) == user
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        if (_to == address(this)) {
            require(
                s.opToken.transferFrom(msg.sender, _to, _amountOP),
                "OP transfer failed"
            );
        } else {
            require(s.opToken.transfer(_to, _amountOP), "OP transfer failed");
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
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        RaffleRound storage currentRound = s.raffleRounds[_round];
        uint256 totalEthCollected = currentRound.roundPrizes.EthAmount;
        if (totalEthCollected == 0) return 0;
        uint256 protocolFeeAmount = s.protocolFee == 0
            ? 0
            : (totalEthCollected * s.protocolFee) / BPS;
        uint256 totalWinnableETHPrizeForRound = totalEthCollected -
            protocolFeeAmount;
        return ((totalWinnableETHPrizeForRound * _percentage) / BPS);
    }

    function _getOPAmount(
        uint256 _percentage,
        uint256 _round
    ) internal view returns (uint256) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        RaffleRound storage currentRound = s.raffleRounds[_round];
        uint256 totalOPCollected = currentRound.roundPrizes.OpAmount;
        if (totalOPCollected == 0) return 0;
        return ((totalOPCollected * _percentage) / BPS);
    }

    function _getTicketBuyerAddress(
        uint256 _ticketId,
        uint256 _round
    ) internal view returns (address) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.raffleRounds[_round].ticketOwners[_ticketId];
    }

    function _roundsSinceStart() internal view returns (uint256) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        if (block.timestamp < s.startTime)
            revert SuperchainRaffle__SuperchainRaffleNotStartedYet();
        return ((block.timestamp - s.startTime) / 1 weeks) + 1;
    }

    function _setBeneficiary(address _beneficiary) internal {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        s.beneficiary = _beneficiary;
    }

    function _setSuperchainModule(address _newSuperchainModule) internal {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        s.superchainModule = _newSuperchainModule;
    }

    function _setMaxAmountTicketsPerRound(uint256 _maxAmount) internal {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        s.maxAmountTickets = _maxAmount;
    }

    function _setProtocolFee(uint256 _fee) internal {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        s.protocolFee = _fee;
    }

    function _setWinningLogic(
        uint256[] memory _numberOfWinners,
        uint256[][] memory _payoutPercentage
    ) internal {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        delete s.winningLogicKeys; // Clear the existing keys
        uint256 arrayLength = _numberOfWinners.length;
        for (uint256 i; i < arrayLength; ++i) {
            uint256 key = _numberOfWinners[i];
            WinningLogic storage logic = s.winningLogic[key];
            if (logic.payoutPercentage.length != 0) {
                delete logic.payoutPercentage;
            }
            uint256 innerArrayLength = _payoutPercentage[i].length;
            for (uint256 j; j < innerArrayLength; ++j) {
                logic.payoutPercentage.push(_payoutPercentage[i][j]);
            }
            s.winningLogicKeys.push(key); // Add the key to the keys array
        }
    }

    function randomizerCallback(
        uint256 _round,
        uint256 randomness
    ) external onlyRandomizerWrapper {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        uint256 numberOfTicketsSold = s.raffleRounds[_round].ticketsSold;
        uint256 numberOfRandomValues = _getNumberOfRandomValues(
            numberOfTicketsSold
        );
        Winner[] memory winners = new Winner[](numberOfRandomValues);
        uint256 totalEthPrize = s.raffleRounds[_round].roundPrizes.EthAmount;
        uint256 totalOpPrize = s.raffleRounds[_round].roundPrizes.OpAmount;
        if (numberOfRandomValues == 1) {
            uint256 winningTicket = _getTicketNumberFromRandomValue(
                randomness,
                numberOfTicketsSold
            );
            s.raffleRounds[_round].winningNumbers.push(winningTicket);
            address ticketOwner = getTicketOwner(winningTicket, _round);
            winners[0] = Winner(
                winningTicket,
                ticketOwner,
                totalOpPrize,
                totalEthPrize
            );
        } else {
            for (uint256 i = 0; i < numberOfRandomValues; ) {
                bool doubleValue = true;
                uint256 value = _getTicketNumberFromRandomValue(
                    _derivedRandomNumbers(randomness, i),
                    numberOfTicketsSold
                );
                uint256 winningTicket;
                while (doubleValue) {
                    winningTicket = _getTicketNumberFromRandomValue(
                        _derivedRandomNumbers(randomness, value),
                        numberOfTicketsSold
                    );
                    doubleValue = _checkDoubleValue(
                        winningTicket,
                        _round,
                        s.raffleRounds[_round].winningNumbers.length
                    );
                    value = (value + 1) % numberOfTicketsSold;
                }
                s.raffleRounds[_round].winningNumbers.push(winningTicket);

                uint256 ethPrize = (totalEthPrize *
                    s.winningLogic[numberOfRandomValues].payoutPercentage[i]) /
                    BPS;
                uint256 opPrize = (totalOpPrize *
                    s.winningLogic[numberOfRandomValues].payoutPercentage[i]) /
                    BPS;
                address ticketOwner = getTicketOwner(winningTicket, _round);

                winners[i] = (
                    Winner(winningTicket, ticketOwner, opPrize, ethPrize)
                );

                i++;
            }
        }
        emit RoundWinners(_round, numberOfTicketsSold, winners);
    }

    function _checkDoubleValue(
        uint _winningTicket,
        uint _round,
        uint _arrayLength
    ) internal view returns (bool) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        for (uint256 j = 0; j < _arrayLength; ++j) {
            if (s.raffleRounds[_round].winningNumbers[j] == _winningTicket) {
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
    ) internal view returns (uint256) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        for (uint256 i = 0; i < s.randomValueThresholds.length; i++) {
            if (
                _numberOfTicketsSold <=
                s.randomValueThresholds[i].ticketThreshold
            ) {
                return s.randomValueThresholds[i].randomValues;
            }
        }
        return
            s
                .randomValueThresholds[s.randomValueThresholds.length - 1]
                .randomValues; // Valor por defecto si no se cumple ningún umbral
    }

    function beneficiary() external view returns (address) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.beneficiary;
    }

    function opToken() external view returns (IERC20) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.opToken;
    }

    // Getter para `uri`
    function uri() external view returns (string memory) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.uri;
    }

    // Getter para `startTime`
    function startTime() external view returns (uint256) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.startTime;
    }

    // Getter para `superchainModule`
    function superchainModule() external view returns (address) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.superchainModule;
    }

    // Getter para `randomizerWrapper`
    function randomizerWrapper() external view returns (address) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.randomizerWrapper;
    }

    // Getter para `mainnetRandomizedWrapper`
    function mainnetRandomizedWrapper() external view returns (bool) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.mainnetRandomizedWrapper;
    }

    // Getter para `protocolFee`
    function protocolFee() external view returns (uint256) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.protocolFee;
    }

    // Getter para `maxAmountTickets`
    function maxAmountTickets() external view returns (uint256) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.maxAmountTickets;
    }

    // Getter para `randomValueThresholds`
    function randomValueThresholds()
        external
        view
        returns (RandomValueThreshold[] memory)
    {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.randomValueThresholds;
    }

    // Getter para `freeTicketsPerLevel`
    function freeTicketsPerLevel() external view returns (uint256[] memory) {
        SuperChainRaffleStorage storage s = superChainRaffleStorage();
        return s.freeTicketsPerLevel;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
