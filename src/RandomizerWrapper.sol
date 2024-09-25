//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {GelatoVRFConsumerBase} from "vrf-contracts/GelatoVRFConsumerBase.sol";
import {ISuperchainRaffle} from "./interfaces/ISuperchainRaffle.sol";
import {IRandomizerWrapper} from "./interfaces/IRandomizerWrapper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RandomizerWrapper is IRandomizerWrapper, Ownable, GelatoVRFConsumerBase {
    mapping(uint256 => address) public requestIdToRaffleAddress;
    mapping(address => bool) public raffleWhitelisted;
    address private _operatorAddr;
    address public beneficiary;

    modifier onlyWhitelistedRaffle() {
        if (raffleWhitelisted[msg.sender] == false) revert OnlySuperchainRaffle();
        _;
    }

    constructor(address _beneficiary, address operator, address owner) Ownable(owner) {
        _setBeneficiary(_beneficiary);
        _operatorAddr = operator;
    }

    function requestRandomNumber(address _raffle, uint256 _round) external  onlyWhitelistedRaffle {
        uint256 requestId = _requestRandomness(abi.encode(_round));
        requestIdToRaffleAddress[requestId] = _raffle;
    }

    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory data) internal override {
        uint256 _round = abi.decode(data, (uint256));
        address raffleAddress = requestIdToRaffleAddress[requestId];
        require(raffleAddress != address(0), "Invalid requestId");
        ISuperchainRaffle(raffleAddress).randomizerCallback(_round, randomness);
    }

    function setBeneficiary(address _beneficiary) external onlyOwner {
        _setBeneficiary(_beneficiary);
    }

    function setOperator(address operator) external onlyOwner {
        _operatorAddr = operator;
    }

    function _operator() internal view override returns (address) {
        return _operatorAddr;
    }

    function _setBeneficiary(address _beneficiary) internal {
        beneficiary = _beneficiary;
    }

    function setWhitelistedRaffle(address _raffle, bool _whitelisted) external onlyOwner {
        raffleWhitelisted[_raffle] = _whitelisted;
    }

    receive() external payable {}
}