//SPDX-License-Identifier: MIT
pragma solidity^ 0.8.0;
import "./IBEP20.sol";
interface IWardenTradingRoute {
event Trade(IBEP20 indexed _src,uint256 _srcAmount,IBEP20 indexed _dest,uint256 _destAmount);
function trade(IBEP20 _src,IBEP20 _dest,uint256 _srcAmount)external payable returns(uint256 _destAmount);
function getDestinationReturnAmount(IBEP20 _src,IBEP20 _dest,uint256 _srcAmount)external view returns(uint256 _destAmount);
// function getSourceReturnAmount(IBEP20 _src,IBEP20 _dest,uint256 _destAmount)external view returns(uint256 _srcAmount);
}