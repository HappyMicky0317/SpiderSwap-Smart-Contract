// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor( ) public ERC20("name", "symbol") {
      
    }

    function mint(address addr, uint256 supply) public {
        _mint(addr, supply);
    }
}