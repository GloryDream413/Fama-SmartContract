// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
@title The interface for the vault contract
*/
interface IVault {
    // #### Struct definitions
    struct Vault {
        uint256 collateralAmount; // The amount of collateral held by the vault contract
        uint256 debtAmount; // The amount of stable coin that was minted against the collateral
    }

    // #### Event definitions
    event Deposit(string strTopic, address userAddress, uint256 amountToDeposit, uint256 timestampDeposit);
    event Withdraw(string strTopic, address userAddress, uint256 lptokenAmount, uint256 timestampWithdraw);
    event SwapAll(string strTopic, string strType, uint256 amount, uint256 timestampSwap);

    // #### Function definitions

    /**
    @notice Allows a user to deposit ETH collateral in exchange for some amount of stablecoin
    @param amountToDeposit  The amount of ether the user sent in the transaction
     */
    function deposit(address depositTokenAddress, uint256 amountToDeposit) external;

    function initializeVault(
        uint256 usdcAmount,
        uint256 lpTokenAmount
    ) external;

    /**
    @notice Allows a user to withdraw up to 100% of the collateral they have on deposit
    @dev This cannot allow a user to withdraw more than they put in
    @param repaymentAmount  the amount of stablecoin that a user is repaying to redeem their collateral for.
     */
    function withdraw(uint256 repaymentAmount) external;

    /**
    @notice Returns the details of a vault
    @param userAddress  the address of the vault owner
    @return vault  the vault details
     */
    function getVault(
        address userAddress
    ) external view returns (Vault memory vault);

    function swapAll() external;

    /**
    @notice Returns an estimate of how much collateral could be withdrawn for a given amount of stablecoin
    @param lptokenAmount  the amount of stable coin that would be repaid
    @return collateralAmount the estimated amount of a vault's collateral that would be returned 
     */
    function estimateCollateralAmount(
        uint256 lptokenAmount
    ) external view returns (uint256 collateralAmount);
}
