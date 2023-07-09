// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVault.sol";
import "./LpToken.sol";
import "./PriceConsumerV3.sol";
import "./interfaces/MyERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

interface IUniswapV2Router {
    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        //amount of tokens we are sending in
        uint256 amountIn,
        //the minimum amount of tokens we want out of the trade
        uint256 amountOutMin,
        //list of token addresses we are going to trade in.  this is necessary to calculate amounts
        address[] calldata path,
        //this is the address we are going to send the output tokens to
        address to,
        //the last time that the trade is valid for
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract Vault is IVault, Ownable {
    MyERC20 private wethToken;
    MyERC20 private usdcToken;
    // address private wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
    address private wethAddress = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    // address private usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // mainnet
    address private usdcAddress = 0xB72Bb8CD764006641de1687b3e3C89957106F460;

    address private controlAddress = 0x42d0b8efF2fFF1a70B57C8E96bE77C2e49A774c3; // AI bot address

    uint256 slippage;

    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    IUniswapV2Factory private constant factory =
        IUniswapV2Factory(UNISWAP_V2_FACTORY);

    uint256 private priceDecimal = 8;

    string private curCoin;
    bool private bSwap;

    mapping(address => Vault) vaults;
    LpToken public lpToken;
    PriceConsumerV3 private oracle;
    // using SafeMath for uint256;

    uint256 public totalVaultEth;
    uint256 public totalVaultUSDC;

    constructor(address _lpTokenAddress, address _oracle) {
        wethToken = MyERC20(wethAddress);
        usdcToken = MyERC20(usdcAddress);

        lpToken = LpToken(_lpTokenAddress);
        curCoin = "usdc";

        totalVaultUSDC = 0;
        totalVaultEth = 0;

        bSwap = false;
        oracle = PriceConsumerV3(_oracle);

        slippage = 30; // 0.3 %
    }

    /**
    @notice Allows a user to deposit USDC collateral in exchange for some amount of stablecoin
    @param amountToDeposit  The amount of usdc the user sent in the transaction
     */
    function deposit(
        address depositTokenAddress,
        uint256 amountToDeposit
    ) external override {
        require(amountToDeposit > 0, "incorrect token amount");
        require(depositTokenAddress == usdcAddress, "incorrect token");
        require(bSwap == false, "swapping");

        uint256 timestamp = block.timestamp;

        require(
            usdcToken.balanceOf(msg.sender) >
                (amountToDeposit * (10 ** usdcToken.decimals())),
            "insufficient balance"
        );

        uint256 usdcPrice = getUSDCUSDPrice();
        uint256 ethPrice = getEthUSDPrice();

        uint256 amountToMint = (amountToDeposit * usdcPrice) /
            (10 ** priceDecimal);

        uint256 estimatedLpTokens = 0;

        uint256 totalAmountUsd = (totalVaultUSDC *
            usdcPrice *
            (10 ** (wethToken.decimals() - usdcToken.decimals())) +
            totalVaultEth *
            ethPrice) / (10 ** priceDecimal);
        estimatedLpTokens =
            (amountToMint *
                (10 ** lpToken.decimals()) *
                lpToken.totalSupply()) /
            totalAmountUsd;
        totalVaultUSDC =
            totalVaultUSDC +
            amountToDeposit *
            (10 ** usdcToken.decimals());

        usdcToken.transferFrom(
            msg.sender,
            address(this),
            amountToDeposit * (10 ** usdcToken.decimals())
        );

        lpToken.mint(msg.sender, estimatedLpTokens);
        // vaults[msg.sender].collateralAmount +=
        //     amountToDeposit *
        //     (10 ** usdcToken.decimals());
        // vaults[msg.sender].debtAmount +=
        //     amountToMint *
        //     (10 ** usdcToken.decimals());
        emit Deposit(
            "Deposit",
            msg.sender,
            amountToDeposit,
            timestamp
        );
    }

    function initializeVault(
        uint256 usdcAmount,
        uint256 lpTokenAmount
    ) external override onlyOwner {
        require(usdcAmount > 0, "incorrect usdc token amount");
        require(lpTokenAmount > 0, "incorrect lp token amount");
        require(
            totalVaultUSDC == 0 && usdcToken.balanceOf(address(this)) == 0,
            "total usdc amount is not zero. banned initializing"
        );
        require(
            totalVaultEth == 0 && wethToken.balanceOf(address(this)) == 0,
            "total eth amount is not zero. banned initializing"
        );

        usdcAmount = usdcAmount * (10 ** usdcToken.decimals());
        lpTokenAmount = lpTokenAmount * (10 ** lpToken.decimals());

        require(
            usdcToken.balanceOf(msg.sender) > usdcAmount,
            "insufficient balance in initializing vault"
        );

        uint256 usdcPrice = getUSDCUSDPrice();
        uint256 amountToMint = (usdcAmount * usdcPrice) / (10 ** priceDecimal);

        curCoin = "usdc";
        usdcToken.transferFrom(msg.sender, address(this), usdcAmount);

        uint256 totalAmountUsd = (totalVaultUSDC * usdcPrice) /
            (10 ** priceDecimal);
        totalVaultUSDC = usdcAmount;
        lpToken.mint(msg.sender, lpTokenAmount);
        // vaults[msg.sender].collateralAmount += usdcAmount;
        // vaults[msg.sender].debtAmount += amountToMint;
    }

    /**
    @notice Allows a user to withdraw up to 100% of the collateral they have on deposit
    @dev This cannot allow a user to withdraw more than they put in
    @param lptokenAmount  the amount of stablecoin that a user is repaying to redeem their collateral for.
     */
    function withdraw(uint256 lptokenAmount) external override {
        lptokenAmount = lptokenAmount * (10 ** lpToken.decimals());

        require(lptokenAmount > 0, "insufficient lp tokens");

        require(
            lptokenAmount < lpToken.balanceOf(msg.sender),
            "insufficient lp tokens"
        );

        require(bSwap == false, "swapping");

        uint256 usdcPrice = getUSDCUSDPrice();
        uint256 ethPrice = getEthUSDPrice();

        uint256 usdcTokens = (lptokenAmount *
            (totalVaultUSDC +
                (totalVaultEth * (ethPrice / usdcPrice)) /
                (10 ** (wethToken.decimals() - usdcToken.decimals())))) /
            lpToken.totalSupply();
        // require(
        //     usdcTokens <= vaults[msg.sender].collateralAmount,
        //     "withdraw limit exceeded"
        // );

        uint256 withdrawUSD = (usdcTokens * usdcPrice) / (10 ** priceDecimal);
        if (compareStrings(curCoin, "usdc")) {
            require(
                usdcToken.balanceOf(address(this)) >= usdcTokens,
                "insufficient balance"
            );
            require(
                usdcToken.transfer(msg.sender, usdcTokens),
                "transfer failed in withdraw"
            );
            // vaults[msg.sender].collateralAmount -= usdcTokens;
            // vaults[msg.sender].debtAmount -= withdrawUSD;
            totalVaultUSDC -= usdcTokens;
        } else if (compareStrings(curCoin, "eth")) {
            uint256 withdrawUSDForETH = (withdrawUSD /
                (10 ** usdcToken.decimals())) * (10 ** wethToken.decimals());
            uint256 ethTokens = (withdrawUSDForETH * (10 ** priceDecimal)) /
                ethPrice;

            require(ethTokens < totalVaultEth, "insufficient eth value");

            require(
                MyERC20(wethAddress).approve(UNISWAP_V2_ROUTER, ethTokens),
                "approve failed usdc address"
            );
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = usdcAddress;
            IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
                ethTokens,
                0,
                path,
                msg.sender,
                block.timestamp
            );

            totalVaultEth = wethToken.balanceOf(address(this));

            // vaults[msg.sender].collateralAmount -= usdcTokens;
            // vaults[msg.sender].debtAmount -=
            //     (withdrawUSDForETH / (10 ** wethToken.decimals())) *
            //     (10 ** usdcToken.decimals());
            totalVaultUSDC -= usdcTokens;
        }
        lpToken.burn(msg.sender, lptokenAmount);

        emit Withdraw(
            "Withdraw",
            msg.sender,
            lptokenAmount,
            block.timestamp
        );
    }

    function swapAll() external override {
        // not external
        require(msg.sender == controlAddress, "incorrect AI bot account");
        bSwap = true;

        if (
            controlAddress.balance <
            (10 ** (wethToken.decimals() - 1))
        ) {
            wethToken.withdraw(10 ** (wethToken.decimals() - 1));
            payable(msg.sender).transfer(address(this).balance);
        }
        
        address pairAddress = factory.getPair(wethAddress, usdcAddress);
        (uint256 resA, uint256 resB, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        if (wethAddress < usdcAddress) {
            uint tmp = resA;
            resA = resB;
            resB = tmp;
        }

        if (compareStrings(curCoin, "usdc")) {
            curCoin = "eth";

            if (
                !MyERC20(usdcAddress).approve(UNISWAP_V2_ROUTER, totalVaultUSDC)
            ) {
                bSwap = false;
            } else {
                uint256 expectedAmountOutMin = IUniswapV2Router(UNISWAP_V2_ROUTER)
                    .getAmountOut(totalVaultUSDC, resB, resA);
                expectedAmountOutMin = expectedAmountOutMin * (10000 - slippage) / 10000;

                address[] memory path = new address[](2);
                path[0] = usdcAddress;
                path[1] = wethAddress;
                IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
                    totalVaultUSDC,
                    expectedAmountOutMin,
                    path,
                    address(this),
                    block.timestamp
                );

                totalVaultUSDC = 0;
                totalVaultEth = wethToken.balanceOf(address(this));
                bSwap = false;

                emit SwapAll(
                    "SwapAll",
                    "usdc",
                    totalVaultUSDC,
                    block.timestamp
                );
            }
        } else if (compareStrings(curCoin, "eth")) {
            curCoin = "usdc";

            if (
                !MyERC20(wethAddress).approve(UNISWAP_V2_ROUTER, totalVaultEth)
            ) {
                bSwap = false;
            } else {
                uint256 expectedAmountOutMin = IUniswapV2Router(UNISWAP_V2_ROUTER)
                    .getAmountOut(totalVaultEth, resA, resB);
                expectedAmountOutMin = expectedAmountOutMin * (10000 - slippage) / 10000;

                address[] memory pathW = new address[](2);
                pathW[0] = wethAddress;
                pathW[1] = usdcAddress;

                IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
                    totalVaultEth,
                    expectedAmountOutMin,
                    pathW,
                    address(this),
                    block.timestamp
                );

                totalVaultEth = 0;
                totalVaultUSDC = usdcToken.balanceOf(address(this));
                bSwap = true;
                emit SwapAll("SwapAll", "eth", totalVaultEth, block.timestamp);
            }
        }
        bSwap = false;
    }

    function setSlippage(uint256 _slippage) public onlyOwner {
        slippage = _slippage;
    }

    function getCurrentCoin() public view returns (string memory) {
        return curCoin;
    }

    /**
    @notice Returns the details of a vault
    @param userAddress  the address of the vault owner
    @return vault  the vault details
     */
    function getVault(
        address userAddress
    ) external view override returns (Vault memory vault) {
        return vaults[userAddress];
    }

    /**
    @notice Returns an estimate of how much collateral could be withdrawn for a given amount of stablecoin
    @param lptokenAmount  the amount of stable coin that would be repaid
    @return collateralAmount the estimated amount of a vault's collateral that would be returned 
     */
    function estimateCollateralAmount(
        uint256 lptokenAmount
    ) external view override returns (uint256 collateralAmount) {
        lptokenAmount = lptokenAmount * (10 ** lpToken.decimals());

        require(lptokenAmount > 0, "insufficient lp tokens");

        require(
            lptokenAmount < lpToken.totalSupply(),
            "insufficient lp tokens"
        );

        uint256 usdcPrice = getUSDCUSDPrice();
        uint256 ethPrice = getEthUSDPrice();

        collateralAmount =
            (lptokenAmount / lpToken.totalSupply()) *
            (totalVaultUSDC +
                (totalVaultEth * ethPrice) /
                (usdcPrice *
                    10 ** (wethToken.decimals() - usdcToken.decimals())));
    }

    /**
    @notice Returns an estimate on how much stable coin could be minted at the current rate
    @param depositAmount the amount of ETH that would be deposited
    @return tokenAmount  the estimated amount of stablecoin that would be minted
     */
    function estimateTokenAmount(
        uint256 depositAmount
    ) external view returns (uint256 tokenAmount) {
        return depositAmount * getEthUSDPrice();
    }

    function getEthUSDPrice() public view returns (uint256) {
        uint price8 = uint(oracle.getETHLatestPrice());
        return price8;
    }

    function getSwapFlag() public view returns (bool) {
        return bSwap;
    }

    function getSlippage() public view returns (uint256) {
        return slippage;
    }

    function getUSDCUSDPrice() public view returns (uint256) {
        uint price8 = uint(oracle.getUSDCLatestPrice());
        return price8;
    }

    function getOracle() public view returns (address) {
        return address(oracle);
    }

    function getLpToken() public view returns (address) {
        return address(lpToken);
    }

    function compareStrings(
        string memory a,
        string memory b
    ) public view returns (bool) {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
