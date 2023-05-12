// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract LiteRideVoteToken is ERC20, Ownable, ERC20Permit, ERC20Votes {
    constructor()
        ERC20("LiteRideVoteToken", "LTRV")
        ERC20Permit("LiteRideVoteToken")
    {
        _mint(msg.sender, 100 * 10 ** decimals()); // 100 tokens
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount); // owner can mint tokens to create more votes to distribute
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
