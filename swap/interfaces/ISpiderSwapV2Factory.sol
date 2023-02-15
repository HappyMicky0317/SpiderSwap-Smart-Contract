// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

interface ISpiderSwapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeToSetter(address) external;
    function PERCENT100() external view returns (uint256);
    function DEADADDRESS() external view returns (address);
 
    function global() external view returns (address);
    function kyth() external view returns (address);
    function usdtx() external view returns (address);
    function goldx() external view returns (address);
    function btcx() external view returns (address);
    function ethx() external view returns (address);
    function roulette() external view returns (address);
    function farm() external view returns (address);

    function bankFee() external view returns (uint256);
    function globalFee() external view returns (uint256);
    function lockFee() external view returns (uint256);
    function rouletteFee() external view returns (uint256);

    function sFarmFee() external view returns (uint256);
    function sUSDTxFee() external view returns (uint256);
    function sGlobalFee() external view returns (uint256);
    function sLockFee() external view returns (uint256);
    function sRouletteFee() external view returns (uint256);

}
