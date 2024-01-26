// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title IUniversalRewardsDistributor
/// @author MerlinEgalite
/// @notice UniversalRewardsDistributor's interface.
interface IUniversalRewardsDistributor {
    /* EVENTS */

    /// @notice Emitted when the merkle tree's root is updated.
    /// @param token The address of the reward token.
    /// @param amount The amount of reward token matching the new merkle tree's root.
    /// @param newRoot The new merkle tree's root.
    event RootUpdated(address indexed token, uint256 amount, bytes32 newRoot);

    /// @notice Emitted when rewards are claimed.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param token The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event RewardsClaimed(address indexed account, address indexed token, uint256 amount);

    /* ERRORS */

    /// @notice Thrown when the merkle proof is invalid or expired.
    error ProofInvalidOrExpired();

    /// @notice Thrown when the rewards have already been claimed.
    error AlreadyClaimed();

    /* EXTERNAL */

    function updateRoot(address token, uint256 amount, bytes32 newRoot) external;

    function skim(address token) external;

    function claim(address account, address token, uint256 claimable, bytes32[] calldata proof) external;
}
