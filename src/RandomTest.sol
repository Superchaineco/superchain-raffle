// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {GelatoVRFConsumerBase} from "vrf-contracts/GelatoVRFConsumerBase.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RandomTest is GelatoVRFConsumerBase, Ownable {
    address private _operatorAddr;
    uint256 public randomResult;
    constructor(address operator) Ownable(msg.sender) {
        _operatorAddr = operator;
    }
    function requestRandomness(
        bytes memory data
    ) external onlyOwner returns (uint256) {
        uint256 requestId = _requestRandomness(data);
        return requestId;
    }

    function _fulfillRandomness(
        uint256 randomness,
        uint256 requestId,
        bytes memory data
    ) internal override {
        randomResult = randomness;
    }

    function _operator() internal view override returns (address) {
        return _operatorAddr;
    }
}
