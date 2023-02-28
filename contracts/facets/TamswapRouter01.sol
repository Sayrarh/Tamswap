// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import  "../interfaces/ITamswapRouter01.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {ITamswapFactory} from "../interfaces/ITamswapFactory.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import "../libraries/TamswapLibrary.sol";
import {LibTamRouter1} from "../libraries/LibTamStorage.sol";


contract TamswapRouter01 is ITamswapRouter01 {
   
    LibTamRouter1.TamswapRouter1Storage internal r1s =  LibTamRouter1.myRouter1Storage(); 

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'TamswapRouter: EXPIRED');
        _;
    }

    function factory() external view returns(address){
       return LibTamRouter1.getFactoryAddress();
    }

     function WETH() external view returns(address){
        return LibTamRouter1.getFactoryAddress();
    }


    // // **** ADD LIQUIDITY ****
    function _addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin) private returns (uint amountA, uint amountB){
        // create the pair if it doesn't exist yet
         if(ITamswapFactory(r1s.factory).getPair(tokenA, tokenB) == address(0)){
            ITamswapFactory(r1s.factory).createPair(tokenA, tokenB);
         }

         (uint256 reserveA, uint256 reserveB) = TamswapLibrary.getReserves(r1s.factory, tokenA, tokenB);
         if(reserveA == 0 && reserveB == 0){
            (amountA, amountB) = (amountADesired, amountBDesired);
         }else{
            uint amountBOptimal = TamswapLibrary.quote(amountADesired, reserveA, reserveB);
             if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'TamswapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
             } else {
                uint amountAOptimal = TamswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'TamswapRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
             }
         }
        
    }
   
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
      
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        address pair = TamswapLibrary.pairFor(r1s.factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = ITamswapPair(pair).mint(to);
    }


    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external override payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {

        (amountToken, amountETH) = _addLiquidity(
            token,
            r1s.WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = TamswapLibrary.pairFor(r1s.factory, token, r1s.WETH);

        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);

        IWETH(r1s.WETH).deposit{value: amountETH}();
        assert(IWETH(r1s.WETH).transfer(pair, amountETH));
        liquidity = ITamswapPair(pair).mint(to);

        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH); // refund dust eth, if any
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
       
        address pair = TamswapLibrary.pairFor(r1s.factory, tokenA, tokenB);

        ITamswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = ITamswapPair(pair).burn(to);
        (address token0,) = TamswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= amountAMin, 'TamswapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'TamswapRouter: INSUFFICIENT_B_AMOUNT');
    }


    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
      
        (amountToken, amountETH) = removeLiquidity(
            token,
            r1s.WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(r1s.WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }


    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint256 amountA, uint256 amountB) {

        address pair = TamswapLibrary.pairFor(r1s.factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ITamswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);

        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }


    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint256 amountToken, uint256 amountETH) {
        address pair = TamswapLibrary.pairFor(r1s.factory, token, r1s.WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ITamswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) private {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = TamswapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? TamswapLibrary.pairFor(r1s.factory, output, path[i + 2]) : _to;
            ITamswapPair(TamswapLibrary.pairFor(r1s.factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }


    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = TamswapLibrary.getAmountsOut(r1s.factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'TamswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, TamswapLibrary.pairFor(r1s.factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }


    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = TamswapLibrary.getAmountsIn(r1s.factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'TamswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, TamswapLibrary.pairFor(r1s.factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == r1s.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsOut(r1s.factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'TamswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(r1s.WETH).deposit{value: amounts[0]}();
        assert(IWETH(r1s.WETH).transfer(TamswapLibrary.pairFor(r1s.factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
     }


    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
        external
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == r1s.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsIn(r1s.factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'TamswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, TamswapLibrary.pairFor(r1s.factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWETH(r1s.WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }


    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint deadline)
        external
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == r1s.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsOut(r1s.factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'TamswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, TamswapLibrary.pairFor(r1s.factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));

        IWETH(r1s.WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == r1s.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsIn(r1s.factory, amountOut, path);
        require(amounts[0] <= msg.value, 'TamswapRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(r1s.WETH).deposit{value: amounts[0]}();

        assert(IWETH(r1s.WETH).transfer(TamswapLibrary.pairFor(r1s.factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]); // refund dust eth, if any
     }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure override returns (uint256 amountB) {
        return TamswapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure override returns (uint256 amountOut) {
        return TamswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public pure override returns (uint256 amountIn) {
        return TamswapLibrary.getAmountOut(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view override returns (uint256[] memory amounts) {
        return TamswapLibrary.getAmountsOut(r1s.factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path) public view override returns (uint256[] memory amounts) {
        return TamswapLibrary.getAmountsIn(r1s.factory, amountOut, path);
    }
}
