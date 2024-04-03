// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@bananapus/core/script/helpers/CoreDeploymentLib.sol";
import "@bananapus/721-hook/script/helpers/Hook721DeploymentLib.sol";
import "@bananapus/suckers/script/helpers/SuckerDeploymentLib.sol";
import "@croptop/core/script/helpers/CroptopDeploymentLib.sol";
import "@rev-net/core/script/helpers/RevnetCoreDeploymentLib.sol";
import "@bananapus/buyback-hook/script/helpers/BuybackDeploymentLib.sol";

import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";
import {JBPermissionsData} from "@bananapus/core/src/structs/JBPermissionsData.sol";
import {JBConstants} from "@bananapus/core/src/libraries/JBConstants.sol";
import {JBTerminalConfig} from "@bananapus/core/src/structs/JBTerminalConfig.sol";
import {REVStageConfig} from "@rev-net/core/src/structs/REVStageConfig.sol";
import {REVConfig} from "@rev-net/core/src/structs/REVConfig.sol";
import {REVCroptopAllowedPost} from "@rev-net/core/src/structs/REVCroptopAllowedPost.sol";
import {REVBuybackPoolConfig} from "@rev-net/core/src/structs/REVBuybackPoolConfig.sol";
import {REVBuybackHookConfig} from "@rev-net/core/src/structs/REVBuybackHookConfig.sol";
import {JB721TierConfig} from "@bananapus/721-hook/src/structs/JB721TierConfig.sol";
import {BPTokenMapping} from "@bananapus/suckers/src/structs/BPTokenMapping.sol";
import {BPSuckerDeployerConfig} from "@bananapus/suckers/src/structs/BPSuckerDeployerConfig.sol";
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
    REVDeploy721TiersHookConfig hookConfiguration;
    JBPayHookSpecification[] otherPayHooksSpecifications;
    uint16 extraHookMetadata;
    REVCroptopAllowedPost[] allowedPosts;
}

contract DeployScript is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;
    /// @notice tracks the deployment of the sucker contracts for the chain we are deploying to.
    SuckerDeployment suckers;
    /// @notice tracks the deployment of the croptop contracts for the chain we are deploying to.
    CroptopDeployment croptop;
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the 721 hook contracts for the chain we are deploying to.
    Hook721Deployment hook;
    /// @notice tracks the deployment of the buyback hook.
    BuybackDeployment buybackHook;

    FeeProjectConfig feeProjectConfig;
    bytes32 SUCKER_SALT = "NANA_SUCKER";
    bytes32 ERC20_SALT = "NANA_TOKEN";
    address OPERATOR = 0x961d4191965C49537c88F764D88318872CE405bE;
    address TRUSTED_FORWARDER = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    function configureSphinx() public override {
        // TODO: Update to contain revnet devs.
        sphinxConfig.owners = [0x26416423d530b1931A2a7a6b7D435Fac65eED27d];
        sphinxConfig.orgId = "cltepuu9u0003j58rjtbd0hvu";
        sphinxConfig.projectName = "nana-fee-project";
        sphinxConfig.threshold = 1;
        sphinxConfig.mainnets = ["ethereum", "optimism"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia"];
        sphinxConfig.saltNonce = 10;
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
        croptop = CroptopDeploymentLib.getDeployment(
            vm.envOr("CROPTOP_CORE_DEPLOYMENT_PATH", string("node_modules/@croptop/core/deployments/"))
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

        feeProjectConfig = getNANARevnetConfig();

        // Perform the deployment transactions.
        deploy();
    }
    
    function getNANARevnetConfig() internal view returns (FeeProjectConfig memory){
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
        uint40 start = uint40(1710875417);

        // The tokens that the project accepts and stores.
        address[] memory tokensToAccept = new address[](1);

        // Accept the chain's native currency through the multi terminal.
        tokensToAccept[0] = JBConstants.NATIVE_TOKEN;

        // The terminals that the project will accept funds through.
        JBTerminalConfig[] memory terminalConfigurations = new JBTerminalConfig[](1);
        terminalConfigurations[0] =
            JBTerminalConfig({terminal: core.terminal, tokensToAccept: tokensToAccept});

        // The project's revnet stage configurations.
        REVStageConfig[] memory stageConfigurations = new REVStageConfig[](1);
        stageConfigurations[0] = REVStageConfig({
            startsAtOrAfter: start,
            splitRate: uint16(JBConstants.MAX_RESERVED_RATE / 5), // 20%
            initialIssuanceRate: uint112(1000 * decimalMultiplier),
            priceCeilingIncreaseFrequency: 7 * oneDay,
            priceCeilingIncreasePercentage: uint32(JBConstants.MAX_DECAY_RATE / 100), // 1%
            priceFloorTaxIntensity: uint16(JBConstants.MAX_REDEMPTION_RATE / 3) // 0.3
        });

        // The project's revnet configuration
        REVConfig memory revnetConfiguration = REVConfig({
            description: REVDescription(name, symbol, projectUri, ERC20_SALT),
            baseCurrency: nativeCurrency,
            premintTokenAmount: 37_000_000 * decimalMultiplier,
            premintChainId: 11155111,
            initialSplitOperator: OPERATOR,
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
            hook: buybackHook.hook,
            poolConfigurations: buybackPoolConfigurations
        });

        // The project's allowed croptop posts.
        REVCroptopAllowedPost[] memory allowedPosts = new REVCroptopAllowedPost[](6);
        allowedPosts[0] = REVCroptopAllowedPost({
            category: 0,
            minimumPrice: 10 ** (decimals - 5),
            minimumTotalSupply: 100_000,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[1] = REVCroptopAllowedPost({
            category: 1,
            minimumPrice: 10 ** (decimals - 4),
            minimumTotalSupply: 100_000,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[2] = REVCroptopAllowedPost({
            category: 2,
            minimumPrice: 10 ** (decimals - 3),
            minimumTotalSupply: 10_000,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[3] = REVCroptopAllowedPost({
            category: 3,
            minimumPrice: 10 ** (decimals - 1),
            minimumTotalSupply: 100,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[4] = REVCroptopAllowedPost({
            category: 4,
            minimumPrice: 10 ** decimals,
            minimumTotalSupply: 10,
            maximumTotalSupply: 999_999_999,
            allowedAddresses: new address[](0)
        });
        allowedPosts[5] = REVCroptopAllowedPost({
            category: 5,
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
        if(address(suckers.optimismDeployer) == address(0))
            revert("Optimism sucker deployer is not configured on this network.");

        BPSuckerDeployerConfig[] memory suckerDeployerConfigurations = new BPSuckerDeployerConfig[](1);
        suckerDeployerConfigurations[0] = BPSuckerDeployerConfig({
            deployer: suckers.optimismDeployer,
            mappings: tokenMappings
        });

        // Specify all sucker deployments.
        REVSuckerDeploymentConfig memory suckerDeploymentConfiguration =
            REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: SUCKER_SALT});

        return FeeProjectConfig({
            configuration: revnetConfiguration,
            terminalConfigurations: terminalConfigurations,
            buybackHookConfiguration: buybackHookConfiguration,
            suckerDeploymentConfiguration: suckerDeploymentConfiguration,
            hookConfiguration: REVDeploy721TiersHookConfig({
                baseline721HookConfiguration: JBDeploy721TiersHookConfig({
                    name: name,
                    symbol: symbol,
                    rulesets: core.rulesets,
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
    }

    function deploy() public sphinx {
        // The permissions required to configure a revnet.
        uint256[] memory _permissions = new uint256[](6);
        _permissions[0] = JBPermissionIds.QUEUE_RULESETS;
        _permissions[1] = JBPermissionIds.DEPLOY_ERC20;
        _permissions[2] = JBPermissionIds.SET_BUYBACK_POOL;
        _permissions[3] = JBPermissionIds.SET_SPLIT_GROUPS; 
        _permissions[4] = JBPermissionIds.MAP_SUCKER_TOKEN; 
        _permissions[5] = JBPermissionIds.DEPLOY_SUCKERS; 

        // Give the permissions to the croptop deployer.
        core.permissions.setPermissionsFor(safeAddress(), JBPermissionsData({
            operator: address(revnet.croptop_deployer),
            projectId: 1,
            permissionIds: _permissions
        }));

        // Give the permissions to the sucker registry.
        // TODO: Check if this is actually needed. And if it is, why is it needed?
        uint256[] memory _registryPermissions = new uint256[](1);
        _registryPermissions[0] = JBPermissionIds.MAP_SUCKER_TOKEN; 
        core.permissions.setPermissionsFor(safeAddress(), JBPermissionsData({
            operator: address(suckers.registry),
            projectId: 1,
            permissionIds: _registryPermissions
        }));

        // Deploy the NANA fee project.
        revnet.croptop_deployer.launchCroptopRevnetFor({
            revnetId: 1,
            configuration: feeProjectConfig.configuration,
            terminalConfigurations: feeProjectConfig.terminalConfigurations,
            buybackHookConfiguration: feeProjectConfig.buybackHookConfiguration,
            suckerDeploymentConfiguration: feeProjectConfig.suckerDeploymentConfiguration,
            hookConfiguration: feeProjectConfig.hookConfiguration,
            otherPayHooksSpecifications: feeProjectConfig.otherPayHooksSpecifications,
            extraHookMetadata: feeProjectConfig.extraHookMetadata,
            allowedPosts: feeProjectConfig.allowedPosts
        });

        // Tranfer ownership.
        core.projects.transferFrom(safeAddress(), address(revnet.croptop_deployer), 1);
    }
}
