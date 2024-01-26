// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniversalRewardsDistributor} from "./interfaces/IUniversalRewardsDistributor.sol";

import {ERC20, SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title UniversalRewardsDistributor
/// @author MerlinEgalite
/// @notice This contract allows to distribute different rewards tokens to multiple accounts using a Merkle tree.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor is IUniversalRewardsDistributor, Ownable {
    using SafeTransferLib for ERC20;

    /* STORAGE */

    /// @notice The merkle tree's root of the current rewards distribution of each token.
    mapping (address => bytes32) public roots;

    /// @notice The `amount` of `reward` token already claimed by `account`.
    mapping(address account => mapping(address reward => uint256 amount)) public claimed;

    /* EXTERNAL */

    /// @notice Updates the current merkle tree's root.
    /// @param token The address of the reward token.
    /// @param amount The amount of reward token matching the new merkle tree's root.
    /// @param newRoot The new merkle tree's root.
    function updateRoot(address token, uint256 amount, bytes32 newRoot) external onlyOwner {
        roots[token] = newRoot;
        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit RootUpdated(token, amount, newRoot);
    }

    /// @notice Transfers the `token` balance from this contract to the owner.
    function skim(address token) external onlyOwner {
        ERC20(token).safeTransfer(msg.sender, ERC20(token).balanceOf(address(this)));
    }

    /// @notice Claims rewards.
    /// @param account The address to claim rewards for.
    /// @param token The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(address account, address token, uint256 claimable, bytes32[] calldata proof) external {
        if (
            !MerkleProof.verifyCalldata(
                proof, roots[token], keccak256(bytes.concat(keccak256(abi.encode(account, claimable))))
            )
        ) {
            revert ProofInvalidOrExpired();
        }

        uint256 amount = claimable - claimed[account][token];
        if (amount == 0) revert AlreadyClaimed();

        claimed[account][token] = claimable;

        ERC20(token).safeTransfer(account, amount);
        emit RewardsClaimed(account, token, amount);
    }
}
