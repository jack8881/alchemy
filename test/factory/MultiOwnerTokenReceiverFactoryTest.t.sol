// This file is part of Modular Account.
//
// Copyright 2024 Alchemy Insights, Inc.
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
// Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
// implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with this program.  If not, see
// <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";

import {ERC721PresetMinterPauserAutoId} from
    "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import {EntryPoint} from "@eth-infinitism/account-abstraction/core/EntryPoint.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {UpgradeableModularAccount} from "../../src/account/UpgradeableModularAccount.sol";
import {MultiOwnerTokenReceiverMSCAFactory} from "../../src/factory/MultiOwnerTokenReceiverMSCAFactory.sol";
import {IEntryPoint} from "../../src/interfaces/erc4337/IEntryPoint.sol";
import {MultiOwnerPlugin} from "../../src/plugins/owner/MultiOwnerPlugin.sol";
import {TokenReceiverPlugin} from "../../src/plugins/TokenReceiverPlugin.sol";
import {MockERC1155} from "../mocks/tokens/MockERC1155.sol";
import {MockERC777} from "../mocks/tokens/MockERC777.sol";

contract MultiOwnerTokenReceiverMSCAFactoryTest is Test {
    using ECDSA for bytes32;

    EntryPoint public entryPoint;
    MultiOwnerTokenReceiverMSCAFactory public factory;
    MultiOwnerPlugin public multiOwnerPlugin;
    TokenReceiverPlugin public tokenReceiverPlugin;
    address public impl;
    ERC721PresetMinterPauserAutoId public t0;
    MockERC777 public t1;
    MockERC1155 public t2;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public nftHolder = address(3);

    address[] public owners;
    address[] public largeOwners;
    uint256[] public tokenIds;
    uint256[] public tokenAmts;
    uint256[] public zeroTokenAmts;

    uint256 internal constant _TOKEN_AMOUNT = 1 ether;
    uint256 internal constant _TOKEN_ID = 0;
    uint256 internal constant _BATCH_TOKEN_IDS = 5;
    uint256 internal constant _MAX_OWNERS_ON_CREATION = 100;

    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() public {
        owners.push(owner1);
        owners.push(owner2);
        entryPoint = new EntryPoint();
        impl = address(new UpgradeableModularAccount(IEntryPoint(address(entryPoint))));
        multiOwnerPlugin = new MultiOwnerPlugin();
        tokenReceiverPlugin = new TokenReceiverPlugin();
        bytes32 ownerManifestHash = keccak256(abi.encode(multiOwnerPlugin.pluginManifest()));
        bytes32 tokenReceiverManifestHash = keccak256(abi.encode(tokenReceiverPlugin.pluginManifest()));
        factory = new MultiOwnerTokenReceiverMSCAFactory(
            address(this),
            address(multiOwnerPlugin),
            address(tokenReceiverPlugin),
            impl,
            ownerManifestHash,
            tokenReceiverManifestHash,
            IEntryPoint(address(entryPoint))
        );
        vm.deal(nftHolder, 100 ether);

        t0 = new ERC721PresetMinterPauserAutoId("t0", "t0", "");
        t0.mint(nftHolder);

        t1 = new MockERC777();
        t1.mint(nftHolder, _TOKEN_AMOUNT);

        t2 = new MockERC1155();
        t2.mint(nftHolder, _TOKEN_ID, _TOKEN_AMOUNT);
        for (uint256 i = 1; i < _BATCH_TOKEN_IDS; i++) {
            t2.mint(nftHolder, i, _TOKEN_AMOUNT);
            tokenIds.push(i);
            tokenAmts.push(_TOKEN_AMOUNT);
            zeroTokenAmts.push(0);
        }

        for (uint160 i = 0; i < _MAX_OWNERS_ON_CREATION; i++) {
            largeOwners.push(address(i + 1));
        }
    }

    function test_addressMatch() public {
        address predicted = factory.getAddress(0, owners);
        address deployed = factory.createAccount(0, owners);
        assertEq(predicted, deployed);
    }

    function test_deploy() public {
        address deployed = factory.createAccount(0, owners);

        // test that the deployed account is initialized
        assertEq(address(UpgradeableModularAccount(payable(deployed)).entryPoint()), address(entryPoint));

        // test that the deployed account installed owner plugin correctly
        address[] memory actualOwners = multiOwnerPlugin.ownersOf(deployed);
        assertEq(actualOwners.length, 2);
        assertEq(actualOwners[0], owner2);
        assertEq(actualOwners[1], owner1);
    }

    function test_receiveTokens() public {
        address acct = factory.createAccount(0, owners);

        vm.startPrank(nftHolder);

        // test that it can receive tokens
        assertEq(t0.ownerOf(_TOKEN_ID), nftHolder);
        t0.safeTransferFrom(nftHolder, acct, _TOKEN_ID);
        assertEq(t0.ownerOf(_TOKEN_ID), acct);

        assertEq(t1.balanceOf(nftHolder), _TOKEN_AMOUNT);
        assertEq(t1.balanceOf(acct), 0);
        t1.transfer(acct, _TOKEN_AMOUNT);
        assertEq(t1.balanceOf(nftHolder), 0);
        assertEq(t1.balanceOf(acct), _TOKEN_AMOUNT);

        assertEq(t2.balanceOf(nftHolder, _TOKEN_ID), _TOKEN_AMOUNT);
        assertEq(t2.balanceOf(acct, _TOKEN_ID), 0);
        t2.safeTransferFrom(nftHolder, acct, _TOKEN_ID, _TOKEN_AMOUNT, "");
        assertEq(t2.balanceOf(nftHolder, _TOKEN_ID), 0);
        assertEq(t2.balanceOf(acct, _TOKEN_ID), _TOKEN_AMOUNT);

        for (uint256 i = 1; i < _BATCH_TOKEN_IDS; i++) {
            assertEq(t2.balanceOf(nftHolder, i), _TOKEN_AMOUNT);
            assertEq(t2.balanceOf(acct, i), 0);
        }
        t2.safeBatchTransferFrom(nftHolder, acct, tokenIds, tokenAmts, "");
        for (uint256 i = 1; i < _BATCH_TOKEN_IDS; i++) {
            assertEq(t2.balanceOf(nftHolder, i), 0);
            assertEq(t2.balanceOf(acct, i), _TOKEN_AMOUNT);
        }
    }

    function test_deployCollision() public {
        address deployed = factory.createAccount(0, owners);

        uint256 gasStart = gasleft();

        // deploy 2nd time which should short circuit
        // test for short circuit -> call should cost less than a CREATE2, or 32000 gas
        address secondDeploy = factory.createAccount(0, owners);

        assertApproxEqAbs(gasleft(), gasStart, 31999);
        assertEq(deployed, secondDeploy);
    }

    function test_deployedAccountHasCorrectPlugins() public {
        address deployed = factory.createAccount(0, owners);

        // check installed plugins on account
        address[] memory plugins = UpgradeableModularAccount(payable(deployed)).getInstalledPlugins();
        assertEq(plugins.length, 2);
        assertEq(plugins[0], address(tokenReceiverPlugin));
        assertEq(plugins[1], address(multiOwnerPlugin));
    }

    function test_addStake() public {
        assertEq(entryPoint.balanceOf(address(factory)), 0);
        vm.deal(address(this), 100 ether);
        factory.addStake{value: 10 ether}(10 hours, 10 ether);
        assertEq(entryPoint.getDepositInfo(address(factory)).stake, 10 ether);
    }

    function test_unlockStake() public {
        test_addStake();
        factory.unlockStake();
        assertEq(entryPoint.getDepositInfo(address(factory)).withdrawTime, block.timestamp + 10 hours);
    }

    function test_withdrawStake() public {
        test_unlockStake();
        vm.warp(10 hours);
        vm.expectRevert("Stake withdrawal is not due");
        factory.withdrawStake(payable(address(this)));
        assertEq(address(this).balance, 90 ether);
        vm.warp(10 hours + 1);
        factory.withdrawStake(payable(address(this)));
        assertEq(address(this).balance, 100 ether);
    }

    function test_withdraw() public {
        factory.addStake{value: 10 ether}(10 hours, 1 ether);
        assertEq(address(factory).balance, 9 ether);
        factory.withdraw(payable(address(this)), address(0), 0); // amount = balance if native currency
        assertEq(address(factory).balance, 0);
    }

    function test_2StepOwnershipTransfer() public {
        assertEq(factory.owner(), address(this));
        factory.transferOwnership(owner1);
        assertEq(factory.owner(), address(this));
        vm.prank(owner1);
        factory.acceptOwnership();
        assertEq(factory.owner(), owner1);
    }

    function test_getAddressWithMaxOwnersAndDeploy() public {
        address addr = factory.getAddress(0, largeOwners);
        assertEq(addr, factory.createAccount(0, largeOwners));
    }

    function test_getAddressWithTooManyOwners() public {
        largeOwners.push(address(101));
        vm.expectRevert(MultiOwnerTokenReceiverMSCAFactory.OwnersLimitExceeded.selector);
        factory.getAddress(0, largeOwners);
    }

    function test_getAddressWithUnsortedOwners() public {
        address[] memory tempOwners = new address[](2);
        tempOwners[0] = address(2);
        tempOwners[1] = address(1);
        vm.expectRevert(MultiOwnerTokenReceiverMSCAFactory.InvalidOwner.selector);
        factory.getAddress(0, tempOwners);
    }

    function test_deployWithDuplicateOwners() public {
        address[] memory tempOwners = new address[](2);
        tempOwners[0] = address(1);
        tempOwners[1] = address(1);
        vm.expectRevert(MultiOwnerTokenReceiverMSCAFactory.InvalidOwner.selector);
        factory.createAccount(0, tempOwners);
    }

    function test_deployWithUnsortedOwners() public {
        address[] memory tempOwners = new address[](2);
        tempOwners[0] = address(2);
        tempOwners[1] = address(1);
        vm.expectRevert(MultiOwnerTokenReceiverMSCAFactory.InvalidOwner.selector);
        factory.createAccount(0, tempOwners);
    }

    // to receive funds from withdraw
    receive() external payable {}
}
