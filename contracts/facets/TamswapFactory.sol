// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/TamswapPair.sol";
import {ITamswapFactory} from "../interfaces/ITamswapFactory.sol";
import {LibTamFactory} from "../libraries/LibTamStorage.sol";

contract TamswapFactory{
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    //////ERROR//////
    error NotFeeToSetter();
    error IdenticalAddresses();
    error AddressZero();


    //The createPair() creates a new TamswapPair contract for a given pair of tokens tokenX and tokenY.
    function createPair(address tokenX, address tokenY) external returns(address pairContractAddress){
        LibTamFactory.FactoryStorage storage factorystate = LibTamFactory.myFactoryStorage();
        if(tokenX == tokenY){
            revert IdenticalAddresses();
        }
        (address _tokenX, address _tokenY) = tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
        if(tokenX == address(0) && tokenY == address(0)){
            revert AddressZero();
        }

        require(factorystate.getPair[tokenX][tokenY] == address(0), "Pair already exists");
        bytes memory bytecode = type(TamswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_tokenX, _tokenY));
        assembly {
            pairContractAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        ITamswapPair(pairContractAddress).initialize(_tokenX, _tokenY);
        factorystate.getPair[_tokenX][_tokenY] = pairContractAddress;
        factorystate.getPair[_tokenY][_tokenX] = pairContractAddress; //populate mapping in the reverse direction
        factorystate.allPairs.push(pairContractAddress);

        emit PairCreated(_tokenX, _tokenY, pairContractAddress, factorystate.allPairs.length);
    }

    

    // This function returns the number of all existing pair contract
    function allPairsLength() external view returns(uint256){
        LibTamFactory.FactoryStorage storage factorystate = LibTamFactory.myFactoryStorage();
        return factorystate.allPairs.length;
    }

    // /* @notice: This function sets the address where the protocol fee is sent to
    //    only feeToSetter can set the _feeTo address */
    function seeFeeTo(address _feeTo) external{
        LibTamFactory.FactoryStorage storage factorystate = LibTamFactory.myFactoryStorage();
        if(msg.sender != factorystate.feeToSetter){
            revert NotFeeToSetter();
        }
        require(_feeTo != address(0) && _feeTo != factorystate.feeTo, "Sanity");
        factorystate.feeTo = _feeTo;
    }
    

    // /* @notice: This function changes the feeToSetter 
    //    only feeToSetter can change the feeToSetter*/
    function changeFeeToSetter(address _newFeeToSetter) external{
        LibTamFactory.FactoryStorage storage factorystate = LibTamFactory.myFactoryStorage();
        if(msg.sender != factorystate.feeToSetter){
            revert NotFeeToSetter();
        }
        require(_newFeeToSetter != address(0) && _newFeeToSetter != factorystate.feeToSetter, "Sanity");
        factorystate.feeToSetter = _newFeeToSetter;
    }

}
