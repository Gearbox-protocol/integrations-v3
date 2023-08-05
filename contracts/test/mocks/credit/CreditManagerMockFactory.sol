// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";

import {
    CreditConfiguratorV3,
    CreditManagerOpts
} from "@gearbox-protocol/core-v3/contracts/credit/CreditConfiguratorV3.sol";
import {CreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditFacadeV3.sol";
import {PoolService} from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";

// import {CreditManagerLiveMock} from "./CreditManagerLiveMock.sol";

/// @title CreditManagerV3Mock factory
/// @notice Same as `CreditManagerV3Factory` but configures mock credit manager
contract CreditManagerV3MockFactory {
// CreditManagerLiveMock public CreditManagerV3;
// CreditFacadeV3 public creditFacade;
// CreditConfiguratorV3 public CreditConfiguratorV3;
// PoolService public immutable pool;

// address[] public adapters;

// constructor(address _pool, CreditManagerOpts memory opts, uint256 salt)
//     ContractUpgrader(address(PoolService(_pool).addressProvider()))
// {
//     pool = PoolService(_pool);

//     CreditManagerV3 = new CreditManagerLiveMock(_pool);
//     creditFacade = new CreditFacadeV3(
//         address(creditManager),
//         opts.degenNFT,
//         opts.blacklistHelper,
//         opts.expirable
//     );

//     bytes memory configuratorByteCode =
//         abi.encodePacked(type(CreditConfiguratorV3).creationCode, abi.encode(CreditManagerV3, creditFacade, opts));

//     address CreditConfiguratorV3Addr = getAddress(configuratorByteCode, salt);

//     creditManager.setConfigurator(CreditConfiguratorV3Addr);

//     deploy(configuratorByteCode, salt);

//     CreditConfiguratorV3 = CreditConfiguratorV3(CreditConfiguratorV3Addr);

//     require(address(creditConfigurator.CreditManagerV3()) == address(creditManager), "Incorrect CM");
// }

// function getAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
//     bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));

//     // NOTE: cast last 20 bytes of hash to address
//     return address(uint160(uint256(hash)));
// }

// function deploy(bytes memory bytecode, uint256 _salt) public payable {
//     address addr;

//     /*
//     NOTE: How to call create2

//     create2(v, p, n, s)
//     create new contract with code at memory p to p + n
//     and send v wei
//     and return the new address
//     where new address = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)))
//           s = big-endian 256-bit value
//     */
//     assembly {
//         addr :=
//             create2(
//                 callvalue(), // wei sent with current call
//                 // Actual code starts after skipping the first 32 bytes
//                 add(bytecode, 0x20),
//                 mload(bytecode), // Load the size of code contained in the first 32 bytes
//                 _salt // Salt from function arguments
//             )

//         if iszero(extcodesize(addr)) { revert(0, 0) }
//     }
// }

// /// @dev adds adapters to public array to provide ability for DAO to
// /// check the list before running configure command
// function addAdapters(Adapter[] memory _adapters) external onlyOwner {
//     uint256 len = _adapters.length;
//     for (uint256 i = 0; i < len;) {
//         adapters.push(_adapters[i]);
//         unchecked {
//             ++i;
//         }
//     }
// }

// function _configure() internal override {
//     ContractsRegister cr = ContractsRegister(addressProvider.getContractsRegister());

//     uint256 len = adapters.length;
//     for (uint256 i = 0; i < len;) {
//         creditConfigurator.allowAdapter(adapters[i].targetContract, adapters[i].adapter);
//         unchecked {
//             ++i;
//         }
//     }

//     cr.addCreditManagerV3(address(creditManager));

//     pool.connectCreditManagerV3(address(creditManager));

//     _postInstall();
// }

// function _postInstall() internal virtual {}
}
