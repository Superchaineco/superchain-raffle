// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/access/Ownable.sol";
import {ISuperchainModule} from "./interfaces/ISuperchainModule.sol";
import {SuperchainRaffle } from "./SuperchainRaffle.sol";

contract SuperchainRaffleFactory is Ownable  {
    event SuperchainRaffleCreated(address superchainRaffle, string uri);
    
    address private _superchainModule;
    SuperchainRaffle[] public raffles;
    address private _opToken;

    constructor(address superchainModule, address opToken) Ownable(msg.sender) {
        _superchainModule = superchainModule;
        _opToken = opToken;
    }

    /**
     * @dev Create a new SuperchainRaffle contract
     */
    function createSuperchainRaffle(
        uint[] memory _numberOfWinners,
        uint[][] memory _payoutPercentage,
        address _beneficiary,
        uint _fee,
        string memory _uri
    ) external onlyOwner {
        SuperchainRaffle raffle = new SuperchainRaffle(
            _numberOfWinners,
            _payoutPercentage,
            _beneficiary,
            _opToken,
            _superchainModule,
            _fee
        );
        raffle.setURI(_uri);
        raffle.transferOwnership(msg.sender);
        raffles.push(raffle);

        emit SuperchainRaffleCreated(address(raffle), _uri);
    }

    function setSuperchainModule(address superchainModule) external onlyOwner {
        _superchainModule = superchainModule;
    }

    /**
     * @dev Get a SuperchainRaffle contract by index
     */
    function getRaffle(uint index) external view returns (address) {
        require(index < raffles.length, "Invalid index");
        return address(raffles[index]);
    }
}
