// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyTokenOne is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("MyTokenOne", "MTK1") {
        _mint(msg.sender, 100000 * 10 * decimals());
    }

    function mint( uint256 amount) public  {
        require(amount < 10000e18, "Amount should not exceed 10000");
        _mint(msg.sender, amount);
    }

    function burn (address addr, uint amount) public {
        require(balanceOf(addr) >= amount, "User does not own the tokens");
        _burn(addr, amount);
    }

     function decimals() public view virtual override returns (uint8) {
        return 6; // Change this value to set the number of decimal places
    }
}