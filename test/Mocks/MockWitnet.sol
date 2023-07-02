// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IWitnetRandomness} from "witnet-solidity-bridge/interfaces/IWitnetRandomness.sol";

contract MockWitnet is IWitnetRandomness {

    function estimateRandomizeFee(uint256 _gasPrice) external pure returns (uint256) {
        return _gasPrice * 100;
    }

    function getRandomizeData(uint256 _block) external view returns (
            address _from,
            uint256 _id,
            uint256 _prevBlock,
            uint256 _nextBlock) 
    {
        return (msg.sender, 0, _block - 1, _block + 1);
    }

    function getRandomnessAfter(uint256 /*_block*/) external pure returns (bytes32) {
        return bytes32(abi.encodePacked(uint256(1000)));
    }

    function getRandomnessNextBlock(uint256 /*_block*/) external pure returns (uint256) {
        return 1000;
    }

    function getRandomnessPrevBlock(uint256 /*_block*/) external pure returns (uint256) {
        return 1000;
    }

    function isRandomized(uint256 /*_block*/) external pure returns (bool) {
        return true;
    }

    function latestRandomizeBlock() external view returns (uint256) {
        return block.number;
    }

    function random(uint32 _range, uint256 /*_nonce*/, bytes32 /*_seed*/) external pure returns (uint32) {
        return 1000 % _range;
    }

    function random(uint32 _range, uint256 /*_nonce*/, uint256 /*_block*/) external pure returns (uint32) {
        return 1000 % _range;
    }

    function randomize() external payable returns (uint256 _usedFunds) {
        return 9 * msg.value / 10;
    }

    function upgradeRandomizeFee(uint256 /*_block*/) external payable returns (uint256 _usedFunds) {
        return 9 * msg.value / 10;
    }
}