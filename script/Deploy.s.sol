// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, stdJson} from "lib/forge-std/src/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {JBConstants} from "@bananapus/core/src/libraries/JBConstants.sol";
import {JBTerminalConfig} from "@bananapus/core/src/structs/JBTerminalConfig.sol";
import {JBPayHookSpecification} from "@bananapus/core/src/structs/JBPayHookSpecification.sol";
import {IJBTerminal} from "@bananapus/core/src/interfaces/terminal/IJBTerminal.sol";
import {IJBRulesets} from "@bananapus/core/src/interfaces/IJBRulesets.sol";
import {IJBPrices} from "@bananapus/core/src/interfaces/IJBPrices.sol";
import {IJBBuybackHook} from "@bananapus/buyback-hook/src/interfaces/IJBBuybackHook.sol";
import {IJB721TiersHook} from "@bananapus/721-hook/src/interfaces/IJB721TiersHook.sol";
import {IJB721TiersHookDeployer} from "@bananapus/721-hook/src/interfaces/IJB721TiersHookDeployer.sol";
import {IJB721TiersHookStore} from "@bananapus/721-hook/src/interfaces/IJB721TiersHookStore.sol";
import {IJB721TokenUriResolver} from "@bananapus/721-hook/src/interfaces/IJB721TokenUriResolver.sol";
import {JB721TierConfig} from "@bananapus/721-hook/src/structs/JB721TierConfig.sol";
import {JB721TiersHookFlags} from "@bananapus/721-hook/src/structs/JB721TiersHookFlags.sol";
import {JBDeploy721TiersHookConfig} from "@bananapus/721-hook/src/structs/JBDeploy721TiersHookConfig.sol";
import {JB721InitTiersConfig} from "@bananapus/721-hook/src/structs/JB721InitTiersConfig.sol";
import {JBDeploy721TiersHookConfig} from "@bananapus/721-hook/src/structs/JBDeploy721TiersHookConfig.sol";
import {BPTokenMapping} from "@bananapus/suckers/src/structs/BPTokenMapping.sol";
import {BPSuckerDeployerConfig} from "@bananapus/suckers/src/structs/BPSuckerDeployerConfig.sol";
import {IBPSuckerDeployer} from "@bananapus/suckers/src/interfaces/IBPSuckerDeployer.sol";
import {REVStageConfig} from "@rev-net/core/src/structs/REVStageConfig.sol";
import {REVBuybackHookConfig} from "@rev-net/core/src/structs/REVBuybackHookConfig.sol";
import {REVDeploy721TiersHookConfig} from "@rev-net/core/src/structs/REVDeploy721TiersHookConfig.sol";
import {REVBuybackPoolConfig} from "@rev-net/core/src/structs/REVBuybackPoolConfig.sol";
import {REVDescription} from "@rev-net/core/src/structs/REVDescription.sol";
import {REVConfig} from "@rev-net/core/src/structs/REVConfig.sol";
import {REVCroptopAllowedPost} from "@rev-net/core/src/structs/REVCroptopAllowedPost.sol";
import {REVCroptopDeployer} from "@rev-net/core/src/REVCroptopDeployer.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core/src/structs/REVSuckerDeploymentConfig.sol";
import {CTAllowedPost} from "@croptop/core/src/structs/CTAllowedPost.sol";

import {Banny721TokenUriResolver} from "./../src/Banny721TokenUriResolver.sol";

contract Deploy is Script {
    function run() public {
        // We need some pseudo-random bytes32.
        bytes32 suckerSalt = keccak256(abi.encode(block.number, block.timestamp));

        // More pseudo-random bytes32.
        bytes32 tokenSalt = keccak256(abi.encode(block.timestamp, block.number));

        // Deploy to sepolia
        _deployTo({rpc: "https://rpc.ankr.com/eth_sepolia", suckerSalt: suckerSalt, tokenSalt: tokenSalt});

        // Deploy to OP sepolia
        // _deployTo({rpc: "https://rpc.ankr.com/optimism_sepolia", suckerSalt: suckerSalt, tokenSalt: tokenSalt});
    }

    function _deployTo(string memory rpc, bytes32 tokenSalt, bytes32 suckerSalt) private {
        // vm.createSelectFork(rpc);
        uint256 chainId = block.chainid;
        address operator = 0x961d4191965C49537c88F764D88318872CE405bE;
        address trustedForwarder;
        string memory chain;
        // Ethereun Mainnet
        if (chainId == 1) {
            trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
            chain = "1";
            // Ethereum Sepolia
        } else if (chainId == 11_155_111) {
            trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
            chain = "11155111";
            // Optimism Mainnet
        } else if (chainId == 420) {
            trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
            chain = "420";
            // Optimism Sepolia
        } else if (chainId == 11_155_420) {
            trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
            chain = "11155420";
            // Polygon Mainnet
        } else if (chainId == 137) {
            trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
            chain = "137";
            // Polygon Mumbai
        } else if (chainId == 80_001) {
            trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
            chain = "80001";
        } else {
            revert("Invalid RPC / no juice contracts deployed on this network");
        }

        address multiTerminalAddress = _getDeploymentAddress(
            string.concat("node_modules/@bananapus/core/broadcast/Deploy.s.sol/", chain, "/run-latest.json"),
            "JBMultiTerminal"
        );

        address rulesetsAddress = _getDeploymentAddress(
            string.concat("node_modules/@bananapus/core/broadcast/Deploy.s.sol/", chain, "/run-latest.json"),
            "JBRulesets"
        );

        address buybackHookAddress = _getDeploymentAddress(
            string.concat("node_modules/@bananapus/buyback-hook/broadcast/Deploy.s.sol/", chain, "/run-latest.json"),
            "JBBuybackHook"
        );

        address hookStoreAddress = _getDeploymentAddress(
            string.concat("node_modules/@bananapus/721-hook/broadcast/Deploy.s.sol/", chain, "/run-latest.json"),
            "JB721TiersHookStore"
        );

        address optimismSuckerDeployerAddress = 0xDBA108aE1738F456A0685f4C0aE30532385C4c24;

        address revCroptopDeployerAddress = _getDeploymentAddress(
            string.concat("node_modules/@rev-net/core/broadcast/Deploy.s.sol/", chain, "/run-latest.json"),
            "REVCroptopDeployer"
        );

        // Define constants
        string memory name = "Bananapus";
        string memory symbol = "$NANA";
        string memory projectUri = "";
        string memory baseUri = "ipfs://";
        string memory contractUri = "";
        uint32 nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));
        uint8 decimals = 18;
        uint256 decimalMultiplier = 10 ** decimals;
        uint40 oneDay = 86_400;
        uint40 start = uint40(block.timestamp);

        // The tokens that the project accepts.
        address[] memory tokensToAccept = new address[](1);

        // Accept the chain's native currency through the multi terminal.
        tokensToAccept[0] = JBConstants.NATIVE_TOKEN;

        // The terminals that the project will accept funds through.
        JBTerminalConfig[] memory terminalConfigurations = new JBTerminalConfig[](1);
        terminalConfigurations[0] =
            JBTerminalConfig({terminal: IJBTerminal(multiTerminalAddress), tokensToAccept: tokensToAccept});

        // The project's revnet stage configurations.
        REVStageConfig[] memory stageConfigurations = new REVStageConfig[](1);
        stageConfigurations[0] = REVStageConfig({
            startsAtOrAfter: start,
            operatorSplitRate: uint16(JBConstants.MAX_RESERVED_RATE / 5),
            initialIssuanceRate: uint112(1_000 * decimalMultiplier),
            priceCeilingIncreaseFrequency: 7 * oneDay,
            priceCeilingIncreasePercentage: uint32(JBConstants.MAX_DECAY_RATE / 100), // 1%
            priceFloorTaxIntensity: uint16(JBConstants.MAX_REDEMPTION_RATE / 3) // 0.3
        });

        // The project's revnet configuration
        REVConfig memory revnetConfiguration = REVConfig({
            baseCurrency: nativeCurrency,
            premintTokenAmount: 37_000_000 * decimalMultiplier,
            initialOperator: operator,
            stageConfigurations: stageConfigurations
        });

        // The project's buyback hook configuration.
        REVBuybackPoolConfig[] memory buybackPoolConfigurations = new REVBuybackPoolConfig[](1);
        buybackPoolConfigurations[0] = REVBuybackPoolConfig({
            token: JBConstants.NATIVE_TOKEN,
            fee: 10_000,
            twapWindow: 2 days,
            twapSlippageTolerance: 9000
        });
        REVBuybackHookConfig memory buybackHookConfiguration = REVBuybackHookConfig({
            hook: IJBBuybackHook(buybackHookAddress),
            poolConfigurations: buybackPoolConfigurations
        });

        // The project's allowed croptop posts.
        REVCroptopAllowedPost[] memory allowedPosts = new REVCroptopAllowedPost[](4);
        allowedPosts[0] = REVCroptopAllowedPost({
            category: 0,
            minimumPrice: 10 ** (decimals - 3),
            minimumTotalSupply: 10_000,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[1] = REVCroptopAllowedPost({
            category: 1,
            minimumPrice: 10 ** (decimals - 1),
            minimumTotalSupply: 100,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[2] = REVCroptopAllowedPost({
            category: 2,
            minimumPrice: 10 ** decimals,
            minimumTotalSupply: 10,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[3] = REVCroptopAllowedPost({
            category: 3,
            minimumPrice: 10 ** (decimals + 2),
            minimumTotalSupply: 10,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });

        // Organize the instructions for how this project will connect to other chains.
        BPTokenMapping[] memory tokenMappings = new BPTokenMapping[](1);
        tokenMappings[0] = BPTokenMapping({
            localToken: JBConstants.NATIVE_TOKEN,
            remoteToken: JBConstants.NATIVE_TOKEN,
            minGas: 200_000,
            minBridgeAmount: 0.01 ether
        });

        // Specify the optimism sucker.
        BPSuckerDeployerConfig[] memory suckerDeployerConfigurations = new BPSuckerDeployerConfig[](1);
        suckerDeployerConfigurations[0] = BPSuckerDeployerConfig({
            deployer: IBPSuckerDeployer(optimismSuckerDeployerAddress),
            mappings: tokenMappings
        });

        // Specify all sucker deployments.
        REVSuckerDeploymentConfig memory suckerDeploymentConfiguration =
            REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: suckerSalt});

        // Deploy it all.
        vm.startBroadcast();

        // Deploy the $NANA Revnet.
        REVCroptopDeployer(revCroptopDeployerAddress).deployCroptopRevnetWith({
            description: REVDescription(name, symbol, projectUri, tokenSalt),
            configuration: revnetConfiguration,
            terminalConfigurations: terminalConfigurations,
            buybackHookConfiguration: buybackHookConfiguration,
            suckerDeploymentConfiguration: suckerDeploymentConfiguration,
            hookConfiguration: REVDeploy721TiersHookConfig({
                baseline721HookConfiguration: JBDeploy721TiersHookConfig({
                    name: name,
                    symbol: symbol,
                    rulesets: IJBRulesets(rulesetsAddress),
                    baseUri: baseUri,
                    tokenUriResolver: IJB721TokenUriResolver(address(0)),
                    contractUri: contractUri,
                    tiersConfig: JB721InitTiersConfig({
                        tiers: new JB721TierConfig[](0),
                        currency: nativeCurrency,
                        decimals: decimals,
                        prices: IJBPrices(address(0))
                    }),
                    reserveBeneficiary: address(0),
                    store: IJB721TiersHookStore(hookStoreAddress),
                    flags: JB721TiersHookFlags({
                        noNewTiersWithReserves: false,
                        noNewTiersWithVotes: false,
                        noNewTiersWithOwnerMinting: false,
                        preventOverspending: false
                    })
                }),
                operatorCanAdjustTiers: true,
                operatorCanUpdateMetadata: true,
                operatorCanMint: true
            }),
            otherPayHooksSpecifications: new JBPayHookSpecification[](0),
            extraHookMetadata: 0,
            allowedPosts: allowedPosts
        });

        vm.stopBroadcast();
    }

    /// @notice Get the address of a contract that was deployed by the Deploy script.
    /// @dev Reverts if the contract was not found.
    /// @param path The path to the deployment file.
    /// @param contractName The name of the contract to get the address of.
    /// @return The address of the contract.
    function _getDeploymentAddress(string memory path, string memory contractName) internal view returns (address) {
        string memory deploymentJson = vm.readFile(path);
        uint256 nOfTransactions = stdJson.readStringArray(deploymentJson, ".transactions").length;

        for (uint256 i = 0; i < nOfTransactions; i++) {
            string memory currentKey = string.concat(".transactions", "[", Strings.toString(i), "]");
            string memory currentContractName =
                stdJson.readString(deploymentJson, string.concat(currentKey, ".contractName"));

            if (keccak256(abi.encodePacked(currentContractName)) == keccak256(abi.encodePacked(contractName))) {
                return stdJson.readAddress(deploymentJson, string.concat(currentKey, ".contractAddress"));
            }
        }

        revert(string.concat("Could not find contract with name '", contractName, "' in deployment file '", path, "'"));
    }
}
