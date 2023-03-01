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

library LibTamRouter1 {
    bytes32 constant ROUTER1_STORAGE_POSITION = keccak256("diamond.standard.tamswap.router1.storage");

    struct TamswapRouter1Storage {
        address WETH;
    }

    function myRouter1Storage() internal pure returns (TamswapRouter1Storage storage r1s) {
        bytes32 position = ROUTER1_STORAGE_POSITION;
        assembly {
            r1s.slot := position
        }
    }

    function setWETHAddress(address _WETH) internal {
        TamswapRouter1Storage storage r1s = myRouter1Storage();
        r1s.WETH = _WETH;
    }

    function getWETHAddress() internal view returns (address WETH) {
        WETH = myRouter1Storage().WETH;
    }
}

library LibTamRouter2 {
    bytes32 constant ROUTER2_STORAGE_POSITION = keccak256("diamond.standard.tamswap.router2.storage");

    struct TamswapRouter2Storage {
        address WETH;
    }

    function myRouter2Storage() internal pure returns (TamswapRouter2Storage storage r2s) {
        bytes32 position = ROUTER2_STORAGE_POSITION;
        assembly {
            r2s.slot := position
        }
    }

    function setWETHAddress(address _WETH) internal {
        TamswapRouter2Storage storage r1s = myRouter2Storage();
        r1s.WETH = _WETH;
    }

    function getWETHAddress() internal view returns (address WETH) {
        WETH = myRouter2Storage().WETH;
    }
}
