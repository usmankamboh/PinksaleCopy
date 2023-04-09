//SPDX-License-Identifier: MIT
pragma solidity^ 0.8.0;
import "Ownable.sol";
import "./IWardenTradingRoute.sol";
contract RoutingManagement is Ownable {
    struct Route {
      string name;
      bool enable;
      IWardenTradingRoute route;
    }
    event AddedTradingRoute(address indexed addedBy,string name,IWardenTradingRoute indexed routingAddress,uint256 indexed index);
    event EnabledTradingRoute(address indexed enabledBy,string name,IWardenTradingRoute indexed routingAddress,uint256 indexed index);
    event DisabledTradingRoute(address indexed disabledBy,string name,IWardenTradingRoute indexed routingAddress,uint256 indexed index);
    Route[] public tradingRoutes; // list of trading routes
    modifier onlyTradingRouteEnabled(uint _index) {
        require(tradingRoutes[_index].enable, "This trading route is disabled");
        _;
    }
    modifier onlyTradingRouteDisabled(uint _index) {
        require(tradingRoutes[_index].enable, "This trading route is enabled");
        _;
    }
    function addTradingRoute(string calldata _name,IWardenTradingRoute _routingAddress)external onlyOwner{
        tradingRoutes.push(Route({name: _name,enable: true,route: _routingAddress}));
        emit AddedTradingRoute(msg.sender, _name, _routingAddress, tradingRoutes.length - 1);
    }
    function disableTradingRoute(uint256 _index)public onlyOwner onlyTradingRouteEnabled(_index){
        tradingRoutes[_index].enable = false;
        emit DisabledTradingRoute(msg.sender, tradingRoutes[_index].name, tradingRoutes[_index].route, _index);
    }
    function enableTradingRoute(uint256 _index)public onlyOwner onlyTradingRouteDisabled(_index){
        tradingRoutes[_index].enable = true;
        emit EnabledTradingRoute(msg.sender, tradingRoutes[_index].name, tradingRoutes[_index].route, _index);
    }
    function allRoutesLength() public view returns (uint256) {
        return tradingRoutes.length;
    }
    function isTradingRouteEnabled(uint256 _index) public view returns (bool) {
        return tradingRoutes[_index].enable;
    }
}