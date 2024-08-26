// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/access/Ownable.sol";
import {ISuperchainModule} from "./interfaces/ISuperchainModule.sol";
import {SuperchainRaffle } from "./SuperchainRaffle.sol";

contract SuperchainRaffleFactory is Ownable  {
    event SuperchainRaffleCreated(address superchainRaffle);
    ISuperchainModule private _superchainModule;
    SuperchainRaffle[] public raffles;

    constructor(address superchainModule) Ownable(msg.sender) {
        _superchainModule = ISuperchainModule(superchainModule);
    }

    /**
     * @dev Create a new SuperchainRaffle contract
     */
    function createSuperchainRaffle(
        uint[] memory _numberOfWinners,
        uint[][] memory _payoutPercentage,
        address _beneficiary,
        uint256 _superchainRafflePointsPerTicket,
        uint _fee
    ) external onlyOwner {
        SuperchainRaffle raffle = new SuperchainRaffle(
            _numberOfWinners,
            _payoutPercentage,
            _beneficiary,
            _superchainRafflePointsPerTicket,
            _superchainModule,
            _fee
        );

        raffle.transferOwnership(msg.sender);

        raffles.push(raffle);

        emit SuperchainRaffleCreated(address(raffle));
    }

    function setSuperchainModule(address superchainModule) external onlyOwner {
        _superchainModule = ISuperchainModule(superchainModule);
    }

    /**
     * @dev Get a SuperchainRaffle contract by index
     */
    function getRaffle(uint index) external view returns (address) {
        require(index < raffles.length, "Invalid index");
        return address(raffles[index]);
    }
}
