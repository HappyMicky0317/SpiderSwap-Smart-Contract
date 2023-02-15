// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import './libraries/SpiderSwapV2Library.sol';
import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';
import './interfaces/ISpiderSwapV2Router02.sol';
import './interfaces/ISpiderSwapV2Factory.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './interfaces/IBank.sol';

contract SpiderSwapV2Router02 is ISpiderSwapV2Router02 {
    using SafeMathSpiderSwap for uint;

    address public immutable override factory;
    address public immutable override WETH;

    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'SpiderSwapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (ISpiderSwapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            ISpiderSwapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = SpiderSwapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = SpiderSwapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'SpiderSwapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = SpiderSwapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'SpiderSwapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = SpiderSwapV2Library.pairFor(factory, tokenA, tokenB);
        (amountA, amountB) = takeAddLiquidityFee(tokenA, tokenB, amountA, amountB, false);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ISpiderSwapV2Pair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = SpiderSwapV2Library.pairFor(factory, token, WETH);
        IWETH(WETH).deposit{value: amountETH}();
        
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        
        (amountToken, amountETH) = takeAddLiquidityFee(token, WETH, amountToken, amountETH, true);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
       
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = ISpiderSwapV2Pair(pair).mint(to);      
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = SpiderSwapV2Library.pairFor(factory, tokenA, tokenB);
        ISpiderSwapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = ISpiderSwapV2Pair(pair).burn(to);
        (address token0,) = SpiderSwapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'SpiderSwapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'SpiderSwapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = SpiderSwapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        ISpiderSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = SpiderSwapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        ISpiderSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = SpiderSwapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        ISpiderSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SpiderSwapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? SpiderSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            ISpiderSwapV2Pair(SpiderSwapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = SpiderSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SpiderSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        amounts[0] = takeSwapFee( path[0], amounts[0], false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = SpiderSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'SpiderSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        amounts[0] = takeSwapFee( path[0], amounts[0], false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SpiderSwapV2Router: INVALID_PATH');
        amounts = SpiderSwapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SpiderSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        amounts[0] = takeSwapFee(path[0], amounts[0], true);
        assert(IWETH(WETH).transfer(SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SpiderSwapV2Router: INVALID_PATH');
        amounts = SpiderSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'SpiderSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        amounts[0] = takeSwapFee( path[0], amounts[0], false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SpiderSwapV2Router: INVALID_PATH');
        amounts = SpiderSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SpiderSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        amounts[0] = takeSwapFee( path[0], amounts[0], false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SpiderSwapV2Router: INVALID_PATH');
        amounts = SpiderSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'SpiderSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        amounts[0] = takeSwapFee( path[0], amounts[0], true);
        assert(IWETH(WETH).transfer(SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SpiderSwapV2Library.sortTokens(input, output);
            ISpiderSwapV2Pair pair = ISpiderSwapV2Pair(SpiderSwapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = SpiderSwapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? SpiderSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        amountIn = takeSwapFee( path[0], amountIn, false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'SpiderSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'SpiderSwapV2Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        amountIn = takeSwapFee( path[0], amountIn, true);
        assert(IWETH(WETH).transfer(SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'SpiderSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'SpiderSwapV2Router: INVALID_PATH');
        amountIn = takeSwapFee( path[0], amountIn, false);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SpiderSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'SpiderSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return SpiderSwapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return SpiderSwapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return SpiderSwapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return SpiderSwapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return SpiderSwapV2Library.getAmountsIn(factory, amountOut, path);
    }


    function takeAddLiquidityFee(address _token0, address _token1, uint256 _amount0, uint256 _amount1, bool isEth) internal returns(uint256, uint256){
        uint256 PERCENT = ISpiderSwapV2Factory(factory).PERCENT100(); 
        
        address[5] memory bankFarm = [ISpiderSwapV2Factory(factory).kyth(),ISpiderSwapV2Factory(factory).usdtx(), 
        ISpiderSwapV2Factory(factory).goldx(), ISpiderSwapV2Factory(factory).btcx(), ISpiderSwapV2Factory(factory).ethx()];
        
        uint256[4] memory bankFee0;
        bankFee0[0] = _amount0.mul(ISpiderSwapV2Factory(factory).bankFee()).div(PERCENT); 
        bankFee0[1]  = _amount0.mul(ISpiderSwapV2Factory(factory).lockFee()).div(PERCENT); //lfee0
        bankFee0[2]  = _amount0.mul(ISpiderSwapV2Factory(factory).globalFee()).div(PERCENT); //globalFee0
        bankFee0[3]  = _amount0.mul(ISpiderSwapV2Factory(factory).rouletteFee()).div(PERCENT); //rouletteFee0
        uint256 _totalFees0 = (bankFee0[0].mul(5)) + bankFee0[1] + bankFee0[2] + bankFee0[3];

       
        uint256[4] memory bankFee1;
        bankFee1[0] = _amount0.mul(ISpiderSwapV2Factory(factory).bankFee()).div(PERCENT); 
        bankFee1[1]  = _amount0.mul(ISpiderSwapV2Factory(factory).lockFee()).div(PERCENT); //lfee1
        bankFee1[2]  = _amount0.mul(ISpiderSwapV2Factory(factory).globalFee()).div(PERCENT); //globalFee1
        bankFee1[3]  = _amount0.mul(ISpiderSwapV2Factory(factory).rouletteFee()).div(PERCENT); //rouletteFee1
        uint256 _totalFees1 = (bankFee1[0].mul(5)) + bankFee1[1] + bankFee1[2] + bankFee1[3];

        TransferHelper.safeTransferFrom(_token0, msg.sender,address(this), _totalFees0);
        if(!isEth){
            TransferHelper.safeTransferFrom(_token1, msg.sender,address(this), _totalFees1);
        }

        TransferHelper.safeTransfer(_token0, ISpiderSwapV2Factory(factory).DEADADDRESS(), bankFee0[1]);
        TransferHelper.safeTransfer(_token1, ISpiderSwapV2Factory(factory).DEADADDRESS(), bankFee1[1]);

        TransferHelper.safeTransfer(_token0, ISpiderSwapV2Factory(factory).global(), bankFee0[2]);
        TransferHelper.safeTransfer(_token1, ISpiderSwapV2Factory(factory).global(), bankFee1[2]);

        TransferHelper.safeTransfer(_token0, ISpiderSwapV2Factory(factory).roulette(), bankFee0[3]);
        TransferHelper.safeTransfer(_token1, ISpiderSwapV2Factory(factory).roulette(), bankFee1[3]);

        _approvetoken(_token0, bankFarm[0], _amount0);
        _approvetoken(_token0, bankFarm[1], _amount0);
        _approvetoken(_token0, bankFarm[2], _amount0);
        _approvetoken(_token0, bankFarm[3], _amount0);
        _approvetoken(_token0, bankFarm[4], _amount0);

        _approvetoken(_token1, bankFarm[0], _amount1);
        _approvetoken(_token1, bankFarm[1], _amount1);
        _approvetoken(_token1, bankFarm[2], _amount1);
        _approvetoken(_token1, bankFarm[3], _amount1);
        _approvetoken(_token1, bankFarm[4], _amount1);

        IBank(bankFarm[0]).addReward(_token0, _token1, bankFee0[0], bankFee1[0]);
        IBank(bankFarm[1]).addReward(_token0, _token1, bankFee0[0], bankFee1[0]);
        IBank(bankFarm[2]).addReward(_token0, _token1, bankFee0[0], bankFee1[0]);
        IBank(bankFarm[3]).addReward(_token0, _token1, bankFee0[0], bankFee1[0]);
        IBank(bankFarm[4]).addReward(_token0, _token1, bankFee0[0], bankFee1[0]);

        _amount0 = _amount0.sub(_totalFees0);
        _amount1 = _amount1.sub(_totalFees1);
        return(_amount0, _amount1);
    }

    function _approvetoken(address token, address _receiver, uint256 amount) private {
        if(IERC20(token).allowance(address(this), _receiver) < amount){
            IERC20(token).approve(_receiver, amount);
        }
    }

   function takeSwapFee(address token, uint256 amount, bool isEth) internal returns(uint256){
        uint256 PERCENT100 = ISpiderSwapV2Factory(factory).PERCENT100();

        uint256 sFarmFee = amount.mul(ISpiderSwapV2Factory(factory).sFarmFee()).div(PERCENT100);
        uint256 sUSDTxFee = amount.mul(ISpiderSwapV2Factory(factory).sUSDTxFee()).div(PERCENT100);
        uint256 sGlobalFee = amount.mul(ISpiderSwapV2Factory(factory).sGlobalFee()).div(PERCENT100);
        uint256 sLockFee = amount.mul(ISpiderSwapV2Factory(factory).sLockFee()).div(PERCENT100);
        uint256 sRouletteFee = amount.mul(ISpiderSwapV2Factory(factory).sRouletteFee()).div(PERCENT100);

        if(isEth){
            TransferHelper.safeTransfer(token, ISpiderSwapV2Factory(factory).farm(), sFarmFee);
            TransferHelper.safeTransfer(token, ISpiderSwapV2Factory(factory).global(), sGlobalFee);
            TransferHelper.safeTransfer(token, ISpiderSwapV2Factory(factory).DEADADDRESS(), sLockFee);
            TransferHelper.safeTransfer(token, ISpiderSwapV2Factory(factory).roulette(), sRouletteFee);
        }else {
            TransferHelper.safeTransferFrom(token, msg.sender, address(this), sUSDTxFee);

            TransferHelper.safeTransferFrom(token, msg.sender, ISpiderSwapV2Factory(factory).farm(), sFarmFee);
            TransferHelper.safeTransferFrom(token, msg.sender, ISpiderSwapV2Factory(factory).global(), sGlobalFee);
            TransferHelper.safeTransferFrom(token, msg.sender, ISpiderSwapV2Factory(factory).DEADADDRESS(), sLockFee);
            TransferHelper.safeTransferFrom(token, msg.sender, ISpiderSwapV2Factory(factory).roulette(), sRouletteFee);
        }

        _approvetoken(token, ISpiderSwapV2Factory(factory).usdtx(), amount);
        IBank(ISpiderSwapV2Factory(factory).usdtx()).addReward(token, address(0x00), sUSDTxFee, 0);

        amount = amount.sub((sFarmFee + sUSDTxFee + sGlobalFee + sLockFee + sRouletteFee));
        return amount;
    }

}
