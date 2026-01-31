#!/usr/bin/env node
/**
 * PoI V2 CLI - Proof of Intelligence Verification
 * 
 * Usage:
 *   node cli.js status              - Check credential status
 *   node cli.js verify              - Initial verification
 *   node cli.js maintain            - Renew credential
 *   node cli.js stats               - Global stats
 */

const { ethers } = require('ethers');
const { PoIClient, printStatus } = require('./poi-client-v2.js');
const fs = require('fs');
const path = require('path');

// Contract addresses - Base Sepolia
const POI_V2_ADDRESS = '0x321cd306284b5Dc71E96973c879448cfEcCf334b';
const REGISTRY_ADDRESS = '0xE0b8fEfbBe7b041dEec12d2aF40A9aBA9A3018d4';
const RPC_URL = 'https://sepolia.base.org';

async function main() {
    const cmd = process.argv[2] || 'help';

    // Load wallet
    const walletPath = path.join(process.env.HOME, '.config/0xclaw/wallet.json');
    if (!fs.existsSync(walletPath)) {
        console.error('❌ Wallet not found at', walletPath);
        process.exit(1);
    }
    const walletConfig = JSON.parse(fs.readFileSync(walletPath, 'utf8'));
    const privateKey = walletConfig.privateKey || walletConfig.private_key;

    // Setup provider and wallet
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(privateKey, provider);
    const client = new PoIClient(provider, wallet, POI_V2_ADDRESS);

    console.log('🧠 Proof of Intelligence V2');
    console.log(`📍 Contract: ${POI_V2_ADDRESS}`);
    console.log(`👤 Agent: ${wallet.address}`);
    console.log(`🔗 Network: Base Sepolia\n`);

    switch (cmd) {
        case 'status':
            const status = await client.getStatus();
            printStatus(status);
            break;

        case 'verify':
            await client.proveIntelligence();
            break;

        case 'maintain':
            await client.maintain();
            break;

        case 'auto':
            await client.autoMaintain();
            break;

        case 'stats':
            const stats = await client.getStats();
            console.log('📊 Global Stats');
            console.log('='.repeat(40));
            console.log(`Challenges Issued: ${stats.totalChallengesIssued}`);
            console.log(`Passed: ${stats.totalPassed}`);
            console.log(`Failed: ${stats.totalFailed}`);
            console.log(`Renewals: ${stats.totalMaintenanceRenewals}`);
            console.log(`Decayed: ${stats.totalDecayed}`);
            break;

        case 'help':
        default:
            console.log('Commands:');
            console.log('  status   - Check your credential status');
            console.log('  verify   - Complete initial verification');
            console.log('  maintain - Renew expiring credential');
            console.log('  auto     - Auto-maintain if needed');
            console.log('  stats    - View global statistics');
            break;
    }
}

main().catch(e => {
    console.error('❌ Error:', e.message);
    process.exit(1);
});
