// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {MidasDegenNFT} from "../../../../integrations/midas/MidasDegenNFT.sol";
import {STANDARD_GREENLISTED_ROLE} from "../../../../integrations/midas/interfaces/external/IMidasAccessControl.sol";

contract MidasAccessControlMock {
    mapping(bytes32 => mapping(address => bool)) internal _roles;

    function grantRole(bytes32 role, address account) external {
        _roles[role][account] = true;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
    }
}

/// @title MidasDegenNFT unit test
/// @notice U:[MID-DNFT]: Unit tests for MidasDegenNFT
contract MidasDegenNFTUnitTest is Test {
    MidasDegenNFT degenNFT;
    MidasAccessControlMock accessControl;

    address greenlistedUser;
    address nonGreenlistedUser;

    function setUp() public {
        accessControl = new MidasAccessControlMock();
        greenlistedUser = makeAddr("GREENLISTED_USER");
        nonGreenlistedUser = makeAddr("NON_GREENLISTED_USER");

        // Deploy as this test contract so gateway == address(this)
        degenNFT = new MidasDegenNFT(address(accessControl), STANDARD_GREENLISTED_ROLE);

        accessControl.grantRole(STANDARD_GREENLISTED_ROLE, greenlistedUser);
    }

    /// @notice U:[MID-DNFT-1]: Constructor sets parameters correctly
    function test_U_MID_DNFT_01_constructor_works() public view {
        assertEq(degenNFT.contractType(), "DEGEN_NFT::MIDAS", "Incorrect contract type");
        assertEq(degenNFT.version(), 3_11, "Incorrect version");
        assertEq(degenNFT.gateway(), address(this), "Incorrect gateway");
        assertEq(degenNFT.accessControl(), address(accessControl), "Incorrect access control");
        assertEq(degenNFT.greenlistedRole(), STANDARD_GREENLISTED_ROLE, "Incorrect greenlisted role");
    }

    /// @notice U:[MID-DNFT-2]: `burn` succeeds when `from` is greenlisted
    function test_U_MID_DNFT_02_burn_succeeds_when_greenlisted() public view {
        degenNFT.burn(greenlistedUser, 1);
    }

    /// @notice U:[MID-DNFT-3]: `burn` reverts when `from` is not greenlisted
    function test_U_MID_DNFT_03_burn_reverts_when_not_greenlisted() public {
        vm.expectRevert(MidasDegenNFT.NotGreenlistedException.selector);
        degenNFT.burn(nonGreenlistedUser, 1);
    }

    /// @notice U:[MID-DNFT-4]: `serialize` works as expected
    function test_U_MID_DNFT_04_serialize_works() public view {
        bytes memory serializedData = degenNFT.serialize();
        (address gw, address ac, bytes32 role) = abi.decode(serializedData, (address, address, bytes32));

        assertEq(gw, address(this), "Incorrect gateway in serialized data");
        assertEq(ac, address(accessControl), "Incorrect access control in serialized data");
        assertEq(role, STANDARD_GREENLISTED_ROLE, "Incorrect greenlisted role in serialized data");
    }
}
