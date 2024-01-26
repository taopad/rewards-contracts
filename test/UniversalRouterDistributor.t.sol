// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@solmate/src/test/utils/mocks/MockERC20.sol";
import "src/UniversalRewardsDistributor.sol";

import {Merkle} from "@murky/src/Merkle.sol";

import "@forge-std/Test.sol";

contract UniversalRouterDistributor is Test {
    uint256 internal constant MAX_RECEIVERS = 20;

    UniversalRewardsDistributor internal distributor;
    Merkle merkle = new Merkle();
    MockERC20 internal token1;
    MockERC20 internal token2;

    event RootUpdated(address indexed token, uint256 amount, bytes32 newRoot);
    event RewardsClaimed(address indexed account, address indexed token, uint256 amount);

    function setUp() public {
        distributor = new UniversalRewardsDistributor();
        token1 = new MockERC20("Token1", "TKN1", 18);
        token2 = new MockERC20("Token2", "TKN2", 18);
    }

    function testUpdateRoot(uint256 amount, bytes32 root) public {
        amount = bound(amount, 1 ether, type(uint256).max);

        deal(address(token1), address(this), amount);

        token1.approve(address(distributor), amount);

        vm.expectEmit(true, true, true, true, address(distributor));
        emit RootUpdated(address(token1), amount, root);
        distributor.updateRoot(address(token1), amount, root);

        assertEq(token1.balanceOf(address(this)), 0);
        assertEq(token1.balanceOf(address(distributor)), amount);
        assertEq(distributor.roots(address(token1)), root);
    }

    function testUpdateRootShouldReversWhenNotOwner(address token, uint256 amount, bytes32 root, address caller)
        public
    {
        vm.assume(caller != distributor.owner());

        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        distributor.updateRoot(token, amount, root);
    }

    function testSkim(uint256 amount) public {
        deal(address(token1), address(distributor), amount);

        distributor.skim(address(token1));

        assertEq(ERC20(address(token1)).balanceOf(address(distributor)), 0);
        assertEq(ERC20(address(token1)).balanceOf(address(this)), amount);
    }

    function testSkimShouldReversWhenNotOwner(address caller) public {
        vm.assume(caller != distributor.owner());

        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        distributor.skim(address(token1));
    }

    function testRewards(uint256 claimable, uint8 size) public {
        claimable = bound(claimable, 1 ether, type(uint256).max);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        bytes32[] memory data1 = _setupRewards(address(token1), claimable, boundedSize);
        bytes32[] memory data2 = _setupRewards(address(token2), claimable, boundedSize);
        _claimAndVerifyRewards(address(token1), data1, claimable);
        _claimAndVerifyRewards(address(token2), data2, claimable);
    }

    function testRewardsWithUpdate(uint256 claimable1, uint256 claimable2, uint8 size) public {
        claimable1 = bound(claimable1, 1 ether, type(uint128).max);
        claimable2 = bound(claimable2, claimable1 * 2, type(uint256).max);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        bytes32[] memory data1 = _setupRewards(address(token1), claimable1, boundedSize);
        _claimAndVerifyRewards(address(token1), data1, claimable1);

        bytes32[] memory data2 = _setupRewards(address(token1), claimable2, boundedSize);
        _claimAndVerifyRewards(address(token1), data2, claimable2);
    }

    function testRewardsShouldRevertWhenAlreadyClaimed(uint256 claimable, uint8 size) public {
        claimable = bound(claimable, 1 ether, type(uint256).max);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        bytes32[] memory data = _setupRewards(address(token1), claimable, boundedSize);

        bytes32[] memory proof = merkle.getProof(data, 0);
        distributor.claim(vm.addr(1), address(token1), claimable / 2, proof); // first user has claimable / 2

        vm.expectRevert(IUniversalRewardsDistributor.AlreadyClaimed.selector);
        distributor.claim(vm.addr(1), address(token1), claimable / 2, proof); // first user has claimable / 2
    }

    function testRewardsShouldRevertWhenInvalidProofAndCorrectInputs(
        bytes32[] memory proof,
        uint256 claimable,
        uint8 size
    ) public {
        claimable = bound(claimable, 1 ether, type(uint256).max);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        _setupRewards(address(token1), claimable, boundedSize);

        vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
        distributor.claim(vm.addr(1), address(token1), claimable / 2, proof); // first user has claimable / 2
    }

    function testRewardsShouldRevertWhenValidProofButIncorrectInputs(
        address account,
        address token,
        uint256 amount,
        uint256 claimable,
        uint8 size
    ) public {
        claimable = bound(claimable, 1 ether, type(uint256).max);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        bytes32[] memory data = _setupRewards(address(token1), claimable, boundedSize);

        bytes32[] memory proof = merkle.getProof(data, 0);
        vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
        distributor.claim(account, token, amount, proof);
    }

    /// @dev In the implementation, claimed rewards are stored as a mapping.
    ///      The test function use vm.store to emulate assignations.
    ///      | Name    | Type                                            | Slot | Offset | Bytes |
    ///      |---------|-------------------------------------------------|------|--------|-------|
    ///      | _owner  | address                                         | 0    | 0      | 20    |
    ///      | root    | bytes32                                         | 1    | 0      | 32    |
    ///      | claimed | mapping(address => mapping(address => uint256)) | 2    | 0      | 32    |
    function testClaimedGetter(address token, address account, uint256 amount) public {
        vm.store(
            address(distributor),
            keccak256(abi.encode(address(token), keccak256(abi.encode(account, uint256(2))))),
            bytes32(amount)
        );
        assertEq(distributor.claimed(account, token), amount);
    }

    function _setupRewards(address token, uint256 claimable, uint256 size) internal returns (bytes32[] memory data) {
        data = new bytes32[](size);

        uint256 i;
        uint256 total;
        uint256 remaining = claimable;
        while (i < size) {
            uint256 index = i + 1;

            uint256 claimableInput = remaining / 2;

            data[i] = keccak256(bytes.concat(keccak256(abi.encode(vm.addr(index), claimableInput))));

            i += 1;
            total += claimableInput;
            remaining -= claimableInput;
        }

        deal(token, address(this), total);

        ERC20(token).approve(address(distributor), total);

        bytes32 root = merkle.getRoot(data);
        distributor.updateRoot(token, total, root);
    }

    function _claimAndVerifyRewards(address token, bytes32[] memory data, uint256 claimable) internal {
        uint256 i;
        uint256 remaining = claimable;
        while (i < data.length) {
            bytes32[] memory proof = merkle.getProof(data, i);

            uint256 index = i + 1;
            uint256 claimableInput = remaining / 2;
            uint256 claimableAdjusted = claimableInput - distributor.claimed(vm.addr(index), token);

            uint256 balanceBeforeUser = ERC20(token).balanceOf(vm.addr(index));
            uint256 balanceBeforeDistributor = ERC20(token).balanceOf(address(distributor));

            // Claim token
            vm.expectEmit(true, true, true, true, address(distributor));
            emit RewardsClaimed(vm.addr(index), token, claimableAdjusted);
            distributor.claim(vm.addr(index), token, claimableInput, proof);

            // stack too deep.
            // uint256 balanceAfterUser = balanceBeforeUser + claimableAdjusted;
            // uint256 balanceAfterDistributor = balanceBeforeDistributor - claimableAdjusted;

            assertEq(ERC20(token).balanceOf(vm.addr(index)), balanceBeforeUser + claimableAdjusted);
            assertEq(ERC20(token).balanceOf(address(distributor)), balanceBeforeDistributor - claimableAdjusted);

            // Assert claimed getter
            assertEq(distributor.claimed(vm.addr(index), token), balanceBeforeUser + claimableAdjusted);

            i += 1;
            remaining -= claimableInput;
        }
    }
}
