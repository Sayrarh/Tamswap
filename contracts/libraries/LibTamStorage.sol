// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibTamFactory {
    bytes32 constant FACTORY_STORAGE_POSITION = keccak256("diamond.standard.tamswap.storage");

    struct FactoryStorage {
        /*address where the protocol fee is sent to if the fee is turned on, if not feeTo is set 
       to it's default state which is address(0)*/
        address feeTo;
        //admin setting the feeTo address
        address feeToSetter;
        //token0 => token1 => address of the pair contract
        //token1 => token0 => address of the pair contract
        mapping(address => mapping(address => address)) getPair;
        //stores all created pair contract addresses
        address[] allPairs;
    }

    function myFactoryStorage() internal pure returns (FactoryStorage storage factorystate) {
        bytes32 position = FACTORY_STORAGE_POSITION;
        assembly {
            factorystate.slot := position
        }
    }
}


library LibTamswapRouter{
    bytes32 constant ROUTER_STORAGE_POSITION = keccak256("diamond.standard.tamswap.router.storage");

    struct TamswapRouterStorage {
        address WETH;
    }

    function myRouterStorage() internal pure returns (TamswapRouterStorage storage rs) {
        bytes32 position = ROUTER_STORAGE_POSITION;
        assembly {
            rs.slot := position
        }
    }

    function setWETHAddress(address _WETH) internal {
        TamswapRouterStorage storage rs = myRouterStorage();
        rs.WETH = _WETH;
    }

    function getWETHAddress() internal view returns (address WETH) {
        WETH = myRouterStorage().WETH;
    }
}
