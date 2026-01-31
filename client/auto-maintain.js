#!/usr/bin/env node
/**
 * PoI V2 Auto-Maintenance Script
 * 
 * Runs via cron to automatically maintain PoI credentials.
 * - Checks if credential exists and is expiring soon
 * - Performs maintenance challenge if needed
 * - Logs results
 * 
 * Add to cron: 0 */12 * * * cd ~/projects/proof-of-intelligence/client && node auto-maintain.js >> /tmp/poi-maintenance.log 2>&1
 */

const { ethers } = require('ethers');
const { PoIClient, printStatus } = require('./poi-client-v2.js');
const fs = require('fs');
const path = require('path');

const POI_V2_ADDRESS = '0x321cd306284b5Dc71E96973c879448cfEcCf334b';
const RPC_URL = 'https://sepolia.base.org';

async function main() {
    const now = new Date().toISOString();
    console.log(`\n[${now}] PoI V2 Auto-Maintenance Check`);
    console.log('='.repeat(50));

    // Load wallet
    const walletPath = path.join(process.env.HOME, '.config/0xclaw/wallet.json');
    if (!fs.existsSync(walletPath)) {
        console.error('❌ Wallet not found');
        process.exit(1);
    }
    const walletConfig = JSON.parse(fs.readFileSync(walletPath, 'utf8'));
    const privateKey = walletConfig.privateKey || walletConfig.private_key;

    // Setup
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(privateKey, provider);
    const client = new PoIClient(provider, wallet, POI_V2_ADDRESS);

    console.log(`Agent: ${wallet.address}`);

    // Get status
    const status = await client.getStatus();
    
    // Check various states
    if (!status.credential.valid || status.credential.issuedAt.getTime() === 0) {
        console.log('⚠️ No valid credential found');
        console.log('   Run: node cli.js verify');
        return;
    }

    console.log(`Credential valid: ${status.hasValidPoI ? '✅' : '❌'}`);
    console.log(`Days until expiry: ${status.daysUntilExpiry}`);
    console.log(`Reputation: ${status.credential.reputation}/100`);
    console.log(`Maintenance count: ${status.credential.maintenanceCount}`);

    // Check if maintenance is needed
    if (status.daysUntilExpiry <= 2) {
        console.log('\n🔄 Credential expiring soon - initiating maintenance...');
        try {
            const success = await client.maintain();
            if (success) {
                console.log('✅ Maintenance successful!');
            } else {
                console.log('❌ Maintenance failed');
            }
        } catch (e) {
            if (e.message.includes('CooldownNotElapsed')) {
                console.log('⏳ In cooldown, will retry next run');
            } else {
                console.error('❌ Error:', e.message);
            }
        }
    } else if (status.inGracePeriod) {
        console.log('\n⚠️ IN GRACE PERIOD - Urgent maintenance needed!');
        try {
            await client.maintain();
        } catch (e) {
            console.error('❌ Maintenance failed:', e.message);
        }
    } else {
        console.log('\n✅ Credential still valid - no maintenance needed');
        console.log(`   Next maintenance window opens in ${status.daysUntilExpiry - 2} days`);
    }
}

main().catch(e => {
    console.error('❌ Fatal error:', e.message);
    process.exit(1);
});
