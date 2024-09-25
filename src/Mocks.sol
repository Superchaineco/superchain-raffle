// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {GelatoVRFConsumerBase} from "vrf-contracts/GelatoVRFConsumerBase.sol";
import {IRandomizerWrapper} from "./interfaces/IRandomizerWrapper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISuperchainModule.sol";
import {ISuperchainRaffle} from "./interfaces/ISuperchainRaffle.sol";
import "forge-std/console.sol";

contract MockRandomizerWrapper is
    IRandomizerWrapper,
    Ownable,
    GelatoVRFConsumerBase
{
    mapping(uint256 => address) public requestIdToRaffleAddress;
    mapping(address => bool) public raffleWhitelisted;
    address private _operatorAddr;
    address public beneficiary;

    modifier onlyWhitelistedRaffle() {
        if (raffleWhitelisted[msg.sender] == false)
            revert OnlySuperchainRaffle();
        _;
    }

    constructor(
        address _beneficiary,
        address operator,
        address owner
    ) Ownable(owner) {
        _setBeneficiary(_beneficiary);
        _operatorAddr = operator;
    }

    function requestRandomNumber(
        address _raffle,
        uint256 _round
    ) external onlyWhitelistedRaffle {
        uint256 requestId = uint256(keccak256(abi.encode(_round, block.timestamp)));
        requestIdToRaffleAddress[requestId] = _raffle;
        _fulfillRandomness(
            uint256(keccak256(abi.encode(block.timestamp, 100))),
            requestId,
            abi.encode(_round)
        );
    }

    function _fulfillRandomness(
        uint256 randomness,
        uint256 requestId,
        bytes memory data
    ) internal override {
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
    function setWhitelistedRaffle(
        address _raffle,
        bool _whitelisted
    ) external onlyOwner {
        raffleWhitelisted[_raffle] = _whitelisted;
    }

    receive() external payable {}
}

// Mock for ISuperchainModule
contract MockSuperchainModule {
    struct Account {
        address smartAccount;
        string superChainID;
        uint256 points;
        uint16 level;
        NounMetadata noun;
    }
    function superChainAccount(
        address account
    ) external view returns (Account memory) {
        
        return
            Account({
                smartAccount: account,
                superChainID: "",
                points: 200,
                level: 1,
                noun: NounMetadata({
                    background: 0,
                    body: 0,
                    accessory: 0,
                    head: 0,
                    glasses: 0
                })
            });
    }

    function getSuperChainAccount(
        address account
    ) external view returns (Account memory) {
        return
            Account({
                smartAccount: account,
                superChainID: "",
                points: 200,
                level: 1,
                noun: NounMetadata({
                    background: 0,
                    body: 0,
                    accessory: 0,
                    head: 0,
                    glasses: 0
                })
            });
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
