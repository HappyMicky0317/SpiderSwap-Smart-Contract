pragma solidity 0.6.12;
import "./IERC20.sol";


interface IBank{
    function addReward(address token0, address token1, uint256 amount0, uint256 amount1) external;
}

