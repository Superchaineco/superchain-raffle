//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ISuperchainRafflePoints} from "./interfaces/ISuperchainRafflePoints.sol";

contract SuperchainRafflePoints is ISuperchainRafflePoints, ERC20, Ownable {
    // Addresses of the SuperchainRaffle contract
    mapping(address => bool) public superchainRaffles;
    uint private constant ONE_ETHER = 1 ether;
    address public beneficiary;

    // --------------------------
    // Modifiers
    // --------------------------

    modifier onlySuperchainRaffle() {
        if (superchainRaffles[msg.sender] != true)
            revert OnlySuperchainRaffle();
        _;
    }

    constructor(
        address _superchainRaffle,
        address _beneficiary
    ) ERC20("superchainRaffle Points", "zkPTS") {
        _setSuperchainRaffle(_superchainRaffle);
        _setBeneficiary(_beneficiary);
    }

    // --------------------------
    // Restricted Functions
    // --------------------------

    /**
     *
     * @dev Mint points to the winners address
     */
    function mintSuperchainRafflePoints(
        address _raffleWinner,
        uint256 _amount
    ) external onlySuperchainRaffle returns (bool) {
        if (_raffleWinner == address(0)) revert InvalidAddressInput();
        if (_amount < ONE_ETHER) revert InvalidWinnerPoints();
        _mint(_raffleWinner, _amount);
        emit SuperchainRafflePointsGiven(
            _raffleWinner,
            _amount,
            block.timestamp
        );
        return true;
    }

    /**
     * @dev Set address of the SuperchainRaffle contract
     */
    function setSuperchainRaffle(
        address _newSuperchainRaffle
    ) external onlyOwner {
        _setSuperchainRaffle(_newSuperchainRaffle);
    }

    function withdraw() external onlyOwner {
        if (address(this).balance > 0) {
            (bool sent, ) = beneficiary.call{value: address(this).balance}("");
            if (!sent) revert SuperchainRafflePoints__FailedToSentEther();
        }
    }

    function mintForReferral(
        address _receiver,
        uint _amount
    ) external onlyOwner {
        _mint(_receiver, _amount);
    }

    function setBeneficiary(address _beneficiary) external onlyOwner {
        _setBeneficiary(_beneficiary);
    }

    // --------------------------
    // Internal
    // --------------------------

    function _setSuperchainRaffle(address _newSuperchainRaffle) internal {
        if (_newSuperchainRaffle == address(0)) revert InvalidAddressInput();
        superchainRaffles[_newSuperchainRaffle] = true;
    }

    function _setBeneficiary(address _beneficiary) internal {
        beneficiary = _beneficiary;
    }

    /**
     * @notice Internal function to update token balances
     * @param from The address transferring the tokens
     * @param to The address receiving the tokens
     * @param value The list of token amounts
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20) {
        // Ensure that the transfer is either minting, burning
        require(
            from == address(0) || to == address(0),
            "TRANSFER_NOT_SUPPORTED"
        );

        super._update(from, to, value);
    }

    receive() external payable {}
}
