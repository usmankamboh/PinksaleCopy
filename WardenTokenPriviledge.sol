//SPDX-License-Identifier: MIT
pragma solidity^ 0.8.0;
import "./Partnership.sol";

contract WardenTokenPriviledge is Partnership {
    uint256 public eligibleAmount = 10 ether; // 10 WAD
    IBEP20 public wardenToken;
    event UpdateWardenToken(IBEP20 indexed token);
    event UpdateEligibleAmount(uint256 amount);
    function updateWardenToken(IBEP20 token)public onlyOwner{wardenToken = token;
        emit UpdateWardenToken(token);
    }
    function updateEligibleAmount(uint256 amount)public onlyOwner{
        eligibleAmount = amount;
        emit UpdateEligibleAmount(amount);
    }
    function isEligibleForFreeTrade(address user)public view returns (bool){
        if (address(wardenToken) == 0x0000000000000000000000000000000000000000) {
            return false;
        }
        return wardenToken.balanceOf(user) >= eligibleAmount;
    }
}