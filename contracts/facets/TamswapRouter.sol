// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;

import {ITamswapRouter} from "../interfaces/ITamswapRouter.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {ITamswapFactory} from "../interfaces/ITamswapFactory.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import "../libraries/TamswapLibrary.sol";
import {LibTamswapRouter} from "../libraries/LibTamStorage.sol";

contract TamswapRouter is ITamswapRouter{
    using SafeMath for uint;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'TamswapRouter: EXPIRED');
        _;
    }

    function WETH() external override view returns(address){
        return LibTamswapRouter.getWETHAddress();
    }

        // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (ITamswapFactory(address(this)).getPair(tokenA, tokenB) == address(0)) {
            ITamswapFactory(address(this)).createPair(tokenA, tokenB);
        }

        (uint reserveA, uint reserveB) = TamswapLibrary.getReserves(address(this), tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = TamswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'TamswapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = TamswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'TamswapV2Router: INSUFFICIENT_A_AMOUNT');
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
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = TamswapLibrary.pairFor(address(this), tokenA, tokenB);
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
    ) external virtual override payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 
        (amountToken, amountETH) = _addLiquidity(
            token,
            rs.WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        address pair = TamswapLibrary.pairFor(address(this), token, rs.WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(rs.WETH).deposit{value: amountETH}();
        assert(IWETH(rs.WETH).transfer(pair, amountETH));
        liquidity = ITamswapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {

        address pair = TamswapLibrary.pairFor(address(this), tokenA, tokenB);
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
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {

         LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        (amountToken, amountETH) = removeLiquidity(
            token,
            rs.WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );

        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(rs.WETH).withdraw(amountETH);
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
    ) external virtual override returns (uint256 amountA, uint256 amountB) {

        address pair = TamswapLibrary.pairFor(address(this), tokenA, tokenB);
        uint value = approveMax ? type(uint256).max : liquidity;
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
    ) external virtual override returns (uint amountToken, uint amountETH) {
        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        address pair = TamswapLibrary.pairFor(address(this), token, rs.WETH);
        uint value = approveMax ? type(uint256).max : liquidity;
        ITamswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {

        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        (, amountETH) = removeLiquidity(
            token,
            rs.WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );

        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(rs.WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint256 amountETH) {

        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        address pair = TamswapLibrary.pairFor(address(this), token, rs.WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ITamswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual { 
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = TamswapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? TamswapLibrary.pairFor(address(this), output, path[i + 2]) : _to;

            ITamswapPair(TamswapLibrary.pairFor(address(this), input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {

        amounts = TamswapLibrary.getAmountsOut(address(this), amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'TamswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TamswapLibrary.pairFor(address(this), path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {

        amounts = TamswapLibrary.getAmountsIn(address(this), amountOut, path);
        require(amounts[0] <= amountInMax, 'TamswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TamswapLibrary.pairFor(address(this), path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        require(path[0] == rs.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsOut(address(this), msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'TamswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(rs.WETH).deposit{value: amounts[0]}();
        assert(IWETH(rs.WETH).transfer(TamswapLibrary.pairFor(address(this), path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        require(path[path.length - 1] == rs.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsIn(address(0), amountOut, path);
        require(amounts[0] <= amountInMax, 'TamswapRouter: EXCESSIVE_INPUT_AMOUNT');

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TamswapLibrary.pairFor(address(this), path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, address(this));
        IWETH(rs.WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        require(path[path.length - 1] == rs.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsOut(address(this), amountIn, path);

        require(amounts[amounts.length - 1] >= amountOutMin, 'TamswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TamswapLibrary.pairFor(address(this), path[0], path[1]), amounts[0]
        );

        _swap(amounts, path, address(this));
        IWETH(rs.WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
         LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        require(path[0] == rs.WETH, 'TamswapRouter: INVALID_PATH');
        amounts = TamswapLibrary.getAmountsIn(address(this), amountOut, path);
        require(amounts[0] <= msg.value, 'TamswapRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(rs.WETH).deposit{value: amounts[0]}();
        assert(IWETH(rs.WETH).transfer(TamswapLibrary.pairFor(address(this), path[0], path[1]), amounts[0]));

        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        

        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = TamswapLibrary.sortTokens(input, output);
            ITamswapPair pair = ITamswapPair(TamswapLibrary.pairFor(address(this), input, output));
            uint amountInput;
            uint amountOutput;

            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = TamswapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }

            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? TamswapLibrary.pairFor(address(this), output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TamswapLibrary.pairFor(address(this), path[0], path[1]), amountIn
        );
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'Tamswap: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
         LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        require(path[0] == rs.WETH, 'TamswapRouter: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(rs.WETH).deposit{value: amountIn}();
        assert(IWETH(rs.WETH).transfer(TamswapLibrary.pairFor(address(this), path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'TamswapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        LibTamswapRouter.TamswapRouterStorage storage rs =  LibTamswapRouter.myRouterStorage(); 

        require(path[path.length - 1] == rs.WETH, 'TamswapRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TamswapLibrary.pairFor(address(this), path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(rs.WETH).balanceOf(address(this));

        require(amountOut >= amountOutMin, 'TamswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(rs.WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure virtual override returns (uint256 amountB) {
        return TamswapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return TamswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return TamswapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return TamswapLibrary.getAmountsOut(address(this), amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return TamswapLibrary.getAmountsIn(address(this), amountOut, path);
    }
}