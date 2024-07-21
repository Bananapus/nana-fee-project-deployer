// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@bananapus/core/script/helpers/CoreDeploymentLib.sol";
import "@bananapus/721-hook/script/helpers/Hook721DeploymentLib.sol";
import "@bananapus/suckers/script/helpers/SuckerDeploymentLib.sol";
import "@rev-net/core/script/helpers/RevnetCoreDeploymentLib.sol";
import "@bananapus/buyback-hook/script/helpers/BuybackDeploymentLib.sol";
import "@bananapus/swap-terminal/script/helpers/SwapTerminalDeploymentLib.sol";

import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";
import {JBPermissionsData} from "@bananapus/core/src/structs/JBPermissionsData.sol";
import {JBConstants} from "@bananapus/core/src/libraries/JBConstants.sol";
import {JBAccountingContext} from "@bananapus/core/src/structs/JBAccountingContext.sol";
import {JBTerminalConfig} from "@bananapus/core/src/structs/JBTerminalConfig.sol";
import {REVStageConfig, REVMintConfig} from "@rev-net/core/src/structs/REVStageConfig.sol";
import {REVConfig} from "@rev-net/core/src/structs/REVConfig.sol";
import {REVBuybackPoolConfig} from "@rev-net/core/src/structs/REVBuybackPoolConfig.sol";
import {REVBuybackHookConfig} from "@rev-net/core/src/structs/REVBuybackHookConfig.sol";
import {JB721TierConfig} from "@bananapus/721-hook/src/structs/JB721TierConfig.sol";
import {JBTokenMapping} from "@bananapus/suckers/src/structs/JBTokenMapping.sol";
import {JBSuckerDeployerConfig} from "@bananapus/suckers/src/structs/JBSuckerDeployerConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core/src/structs/REVSuckerDeploymentConfig.sol";
import {JBPayHookSpecification} from "@bananapus/core/src/structs/JBPayHookSpecification.sol";
import {JB721InitTiersConfig} from "@bananapus/721-hook/src/structs/JB721InitTiersConfig.sol";
import {JB721TiersHookFlags} from "@bananapus/721-hook/src/structs/JB721TiersHookFlags.sol";
import {REVDescription} from "@rev-net/core/src/structs/REVDescription.sol";
import {IJBPrices} from "@bananapus/core/src/interfaces/IJBPrices.sol";
import {REVDeploy721TiersHookConfig} from "@rev-net/core/src/structs/REVDeploy721TiersHookConfig.sol";
import {JBDeploy721TiersHookConfig} from "@bananapus/721-hook/src/structs/JBDeploy721TiersHookConfig.sol";
import {IJB721TokenUriResolver} from "@bananapus/721-hook/src/interfaces/IJB721TokenUriResolver.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

struct FeeProjectConfig {
    REVConfig configuration;
    JBTerminalConfig[] terminalConfigurations;
    REVBuybackHookConfig buybackHookConfiguration;
    REVSuckerDeploymentConfig suckerDeploymentConfiguration;
}

contract DeployScript is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;
    /// @notice tracks the deployment of the sucker contracts for the chain we are deploying to.
    SuckerDeployment suckers;
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the 721 hook contracts for the chain we are deploying to.
    Hook721Deployment hook;
    /// @notice tracks the deployment of the buyback hook.
    BuybackDeployment buybackHook;
    /// @notice tracks the deployment of the swap terminal.
    SwapTerminalDeployment swapTerminal;

    FeeProjectConfig feeProjectConfig;
    bytes32 SUCKER_SALT = "NANA_SUCKER";
    bytes32 ERC20_SALT = "NANA_TOKEN";
    address OPERATOR = 0x961d4191965C49537c88F764D88318872CE405bE;
    address TRUSTED_FORWARDER = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    uint256 TIME_UNTIL_START = 1 days;

    function configureSphinx() public override {
        // TODO: Update to contain revnet devs.
        sphinxConfig.projectName = "nana-fee-project";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core/deployments/"))
        );
        // Get the deployment addresses for the suckers contracts for this chain.
        suckers = SuckerDeploymentLib.getDeployment(
            vm.envOr("NANA_SUCKERS_DEPLOYMENT_PATH", string("node_modules/@bananapus/suckers/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        revnet = RevnetCoreDeploymentLib.getDeployment(
            vm.envOr("REVNET_CORE_DEPLOYMENT_PATH", string("node_modules/@rev-net/core/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        hook = Hook721DeploymentLib.getDeployment(
            vm.envOr("NANA_721_DEPLOYMENT_PATH", string("node_modules/@bananapus/721-hook/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        buybackHook = BuybackDeploymentLib.getDeployment(
            vm.envOr("NANA_BUYBACK_HOOK_DEPLOYMENT_PATH", string("node_modules/@bananapus/buyback-hook/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        swapTerminal = SwapTerminalDeploymentLib.getDeployment(
            vm.envOr("NANA_SWAP_TERMINAL_DEPLOYMENT_PATH", string("node_modules/@bananapus/swap-terminal/deployments/"))
        );

        feeProjectConfig = getNANARevnetConfig();

        // Since Juicebox has logic dependent on the timestamp we warp time to create a scenario closer to production.
        // We force simulations to make the assumption that the `START_TIME` has not occured,
        // and is not the current time.
        // Because of the cross-chain allowing components of nana-core, all chains require the same start_time,
        // for this reason we can't rely on the simulations block.time and we need a shared timestamp across all
        // simulations.
        uint256 _realTimestamp = vm.envUint("START_TIME");
        if (_realTimestamp <= block.timestamp - 1 days) {
            revert("Something went wrong while setting the 'START_TIME' environment variable.");
        }

        vm.warp(_realTimestamp);

        // Perform the deployment transactions.
        deploy();
    }

    function getNANARevnetConfig() internal view returns (FeeProjectConfig memory) {
        // Define constants
        string memory name = "Bananapus";
        string memory symbol = "$NANA";
        string memory projectUri = "ipfs://QmareAjTrXVLNyUhipU2iYpWCHYqzeHYvZ1TaK9HtswvcW";
        uint8 decimals = 18;
        uint256 decimalMultiplier = 10 ** decimals;

        // The tokens that the project accepts and stores.
        JBAccountingContext[] memory accountingContextsToAccept = new JBAccountingContext[](1);

        // Accept the chain's native currency through the multi terminal.
        accountingContextsToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        // The terminals that the project will accept funds through.
        JBTerminalConfig[] memory terminalConfigurations = new JBTerminalConfig[](2);
        terminalConfigurations[0] =
            JBTerminalConfig({terminal: core.terminal, accountingContextsToAccept: accountingContextsToAccept});
        terminalConfigurations[1] = JBTerminalConfig({
            terminal: swapTerminal.swap_terminal,
            accountingContextsToAccept: new JBAccountingContext[](0)
        });

        REVMintConfig[] memory mintConfs = new REVMintConfig[](1);
        mintConfs[0] = REVMintConfig({
            chainId: uint32(11_155_111),
            count: uint104(37_000_000 * decimalMultiplier),
            beneficiary: OPERATOR
        });

        // The project's revnet stage configurations.
        REVStageConfig[] memory stageConfigurations = new REVStageConfig[](1);
        stageConfigurations[0] = REVStageConfig({
            mintConfigs: mintConfs,
            startsAtOrAfter: uint40(block.timestamp + TIME_UNTIL_START),
            splitPercent: uint16(JBConstants.MAX_RESERVED_PERCENT / 5), // 20%
            initialIssuance: uint112(1000 * decimalMultiplier),
            issuanceDecayFrequency: 30 days,
            issuanceDecayPercent: 25_000_000, // 2.5%
            cashOutTaxRate: 3000 // 0.3
        });

        // The project's revnet configuration
        REVConfig memory revnetConfiguration = REVConfig({
            description: REVDescription(name, symbol, projectUri, ERC20_SALT),
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            splitOperator: OPERATOR,
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
        REVBuybackHookConfig memory buybackHookConfiguration =
            REVBuybackHookConfig({hook: buybackHook.hook, poolConfigurations: buybackPoolConfigurations});

        // Organize the instructions for how this project will connect to other chains.
        JBTokenMapping[] memory tokenMappings = new JBTokenMapping[](1);
        tokenMappings[0] = JBTokenMapping({
            localToken: JBConstants.NATIVE_TOKEN,
            remoteToken: JBConstants.NATIVE_TOKEN,
            minGas: 200_000,
            minBridgeAmount: 0.01 ether
        });

        JBSuckerDeployerConfig[] memory suckerDeployerConfigurations;
        if (block.chainid == 1 || block.chainid == 11_155_111) {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](3);
            // OP
            suckerDeployerConfigurations[0] =
                JBSuckerDeployerConfig({deployer: suckers.optimismDeployer, mappings: tokenMappings});

            suckerDeployerConfigurations[1] =
                JBSuckerDeployerConfig({deployer: suckers.baseDeployer, mappings: tokenMappings});

            suckerDeployerConfigurations[2] =
                JBSuckerDeployerConfig({deployer: suckers.arbitrumDeployer, mappings: tokenMappings});
        } else {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](1);
            // L2 -> Mainnet
            suckerDeployerConfigurations[0] = JBSuckerDeployerConfig({
                deployer: address(suckers.optimismDeployer) != address(0)
                    ? suckers.optimismDeployer
                    : address(suckers.baseDeployer) != address(0) ? suckers.baseDeployer : suckers.arbitrumDeployer,
                mappings: tokenMappings
            });

            if (address(suckerDeployerConfigurations[0].deployer) == address(0)) {
                revert("L2 > L1 Sucker is not configured");
            }
        }

        // Specify all sucker deployments.
        REVSuckerDeploymentConfig memory suckerDeploymentConfiguration =
            REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: SUCKER_SALT});

        return FeeProjectConfig({
            configuration: revnetConfiguration,
            terminalConfigurations: terminalConfigurations,
            buybackHookConfiguration: buybackHookConfiguration,
            suckerDeploymentConfiguration: suckerDeploymentConfiguration
        });
    }

    function deploy() public sphinx {

        // TODO replace this permission stuff with setting the revnet deployer as the 721 operator.

        // The permissions required to configure a revnet.
        uint256[] memory _permissions = new uint256[](7);
        _permissions[0] = JBPermissionIds.QUEUE_RULESETS;
        _permissions[1] = JBPermissionIds.SET_TERMINALS;
        _permissions[2] = JBPermissionIds.DEPLOY_ERC20;
        _permissions[3] = JBPermissionIds.SET_BUYBACK_POOL;
        _permissions[4] = JBPermissionIds.SET_SPLIT_GROUPS;
        _permissions[5] = JBPermissionIds.DEPLOY_SUCKERS;
        _permissions[6] = JBPermissionIds.MINT_TOKENS;

        // Give the permissions to the sucker registry.
        uint8[] memory _registryPermissions = new uint8[](1);
        _registryPermissions[0] = JBPermissionIds.MAP_SUCKER_TOKEN;
        core.permissions.setPermissionsFor(
            safeAddress(),
            JBPermissionsData({operator: address(suckers.registry), projectId: 1, permissionIds: _registryPermissions})
        );

        // Deploy the NANA fee project.
        revnet.basic_deployer.deployFor({
            revnetId: 1,
            configuration: feeProjectConfig.configuration,
            terminalConfigurations: feeProjectConfig.terminalConfigurations,
            buybackHookConfiguration: feeProjectConfig.buybackHookConfiguration,
            suckerDeploymentConfiguration: feeProjectConfig.suckerDeploymentConfiguration
        });

        // Tranfer ownership.
        core.projects.transferFrom(safeAddress(), address(revnet.basic_deployer), 1);
    }
}
