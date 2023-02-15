// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import './interfaces/ISpiderSwapV2Factory.sol';
import './SpiderSwapV2Pair.sol';
import './interfaces/IBank.sol';
import './interfaces/IERC20.sol';


contract SpiderSwapV2Factory is ISpiderSwapV2Factory {
    uint256 public override constant PERCENT100 = 1000000; 
    address public override constant DEADADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public override feeTo;
    address public override feeToSetter;
    // Global recevier address
    address public override global; 
    address public override roulette;
    address public override farm;
    // Bank address 
    address public override kyth; 
    address public override usdtx; 
    address public override goldx; 
    address public override btcx; 
    address public override ethx;
    // Up to 4 decimal
    uint256 public override bankFee = 1000;
    uint256 public override globalFee = 7000;
    uint256 public override lockFee = 2500; 
    uint256 public override rouletteFee = 500;
    // Swap fee
    uint256 public override sFarmFee = 1000;
    uint256 public override sUSDTxFee = 500;
    uint256 public override sGlobalFee = 7000;
    uint256 public override sLockFee = 2500; // 
    uint256 public override sRouletteFee = 500;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter, address _global) public {
        feeToSetter = _feeToSetter;
        global = _global;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(SpiderSwapV2Pair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'SpiderSwapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SpiderSwapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'SpiderSwapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(SpiderSwapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        SpiderSwapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'SpiderSwapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

}
