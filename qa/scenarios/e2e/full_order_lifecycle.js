'use strict';
/**
 * SCENARIO: full_order_lifecycle (True E2E Dual-Device)
 *
 * Complete real-world flow:
 *   1. Rider opens client app → selects pickup/dropoff → confirms order
 *   2. System dispatches to driver via Cloud Functions + FCM
 *   3. Driver receives notification → accepts order
 *   4. Rider sees "driver found" screen
 *
 * FALLBACK: If rider UI automation fails (location permissions, etc.),
 * creates order via backend to still test the full dispatch→accept flow.
 */
const path = require('path');
const fs = require('fs');
const Device = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const B = require('../../backend/backend');
const { sleep } = require('../../orchestrator/utils');
const { driver: drvCfg, rider: rdrCfg, timing } = require('../../orchestrator/config');

const SCENARIO = 'full_order_lifecycle';

const TIMEOUTS = {
    appBoot: 20_000,
    uiTransition: 5_000,
    locationResolve: 8_000,
    orderDispatch: 90_000,
    postAccept: 12_000,
};

async function run(runId) {
    const tl = new Timeline(runId);
    const rep = new Reporter(runId, SCENARIO);

    const driverDev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');
    const riderDev = new Device(rdrCfg.deviceId, rdrCfg.packageName, 'rider');

    const artifactsDir = path.join('qa/artifacts', runId);
    fs.mkdirSync(artifactsDir, { recursive: true });

    console.log(`\n${'═'.repeat(70)}`);
    console.log(`  SCENARIO: ${SCENARIO} (TRUE E2E — DUAL DEVICE)`);
    console.log(`  Driver: ${drvCfg.deviceId}  |  Rider: ${rdrCfg.deviceId}`);
    console.log(`${'═'.repeat(70)}\n`);

    let orderId = null;
    let orderCreatedViaUI = false;

    try {
        tl.emit('SCENARIO_START', { scenario: SCENARIO });

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 0: Device Preparation
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 0] Preparing both devices...');
        await B.cleanupOrders();
        await B.injectDriverLocation();
        driverDev.prepareForScenario();
        riderDev.prepareForScenario();
        await sleep(2000);
        tl.emit('DEVICES_PREPARED', {});
        rep.recordPass('Both devices prepared and clean');

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 1: Launch Driver App (must be online BEFORE order)
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 1] Launching Driver app...');
        driverDev.launchDriverApp();
        await sleep(TIMEOUTS.appBoot);
        tl.emit('DRIVER_APP_LAUNCHED', { device: 'driver' });

        // Navigate to Nearby tab
        driverDev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
        await sleep(timing.listenerWait);
        tl.emit('DRIVER_LISTENER_ACTIVE', { device: 'driver' });
        rep.recordPass('Driver app launched and listener active');

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 2: Launch Rider App and Create Order
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 2] Launching Rider app...');
        riderDev.launchRiderApp();
        await sleep(TIMEOUTS.appBoot);
        tl.emit('RIDER_APP_LAUNCHED', { device: 'rider' });
        riderDev.screencap(path.join(artifactsDir, 'rider_home.png'));

        // Attempt to create order via rider UI
        orderId = await attemptRiderOrderCreation(riderDev, artifactsDir, tl);

        if (orderId) {
            orderCreatedViaUI = true;
            rep.recordPass('Order created via rider UI');
            console.log(`  [Rider] ✅ Order submitted via UI`);
        } else {
            // FALLBACK: Create order via backend
            console.log('  [Fallback] Rider UI flow incomplete — creating order via backend...');
            const { orderId: bid } = await B.createOrder({
                scenario: SCENARIO,
                lat: 18.0954303,
                lng: -15.9679639
            });
            orderId = bid;
            rep.recordFail('Rider UI order creation failed — used backend fallback', {
                classification: 'UI_NAVIGATION_FAILURE'
            });
            console.log(`  [Backend] Order created: ${orderId}`);
        }

        tl.emit('ORDER_CREATED', { orderId, viaUI: orderCreatedViaUI });

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 3: Wait for Dispatch to Reach Driver
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 3] Waiting for dispatch to reach driver...');
        tl.emit('WAITING_FOR_DISPATCH', { orderId });

        const dispatchStart = Date.now();
        let driverReceivedOffer = false;

        while (Date.now() - dispatchStart < TIMEOUTS.orderDispatch) {
            // Check fullscreen activity
            if (driverDev.isFullscreenActive()) {
                driverReceivedOffer = true;
                break;
            }
            // Check logcat for FCM
            const logs = driverDev.getLogcat({ limit: 150 });
            const hasFCM = logs.some(l =>
                l.includes('Native FCM received') ||
                l.includes('طلب جديد') ||
                l.includes('new_order') ||
                l.includes('dispatch_offer_source')
            );
            if (hasFCM) {
                driverReceivedOffer = true;
                break;
            }
            await sleep(3000);
            process.stdout.write('.');
        }
        console.log('');

        const dispatchLatency = Date.now() - dispatchStart;

        if (driverReceivedOffer) {
            rep.recordPass(`Driver received offer in ${dispatchLatency}ms`);
            console.log(`  [Driver] ✅ Offer received (${dispatchLatency}ms)`);
            tl.emit('OFFER_RECEIVED', { orderId, latencyMs: dispatchLatency });
        } else {
            driverDev.screencap(path.join(artifactsDir, 'driver_no_offer.png'));
            rep.recordFail(`Driver did not receive offer within ${TIMEOUTS.orderDispatch}ms`, {
                classification: 'DISPATCH_FAILURE'
            });
            throw new Error('Dispatch never reached driver');
        }

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 4: Driver Accepts Order
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 4] Driver accepting order...');
        await sleep(3000); // Let UI fully render

        driverDev.screencap(path.join(artifactsDir, 'driver_offer.png'));
        const offerUI = safeUIDump(driverDev, path.join(artifactsDir, 'driver_offer_ui.xml'));

        // Find Accept button
        let acceptTapped = false;
        if (offerUI) {
            const node = findUIElement(offerUI, ['قبول', 'قبول الطلب', 'accept']);
            if (node) {
                driverDev.tap(node.x, node.y);
                acceptTapped = true;
                console.log(`  [Driver] Tapped Accept at (${node.x}, ${node.y})`);
            }
        }
        if (!acceptTapped) {
            try {
                driverDev.tapByHint('قبول', artifactsDir);
                acceptTapped = true;
            } catch (_) {
                // Last resort: tap center-left area where accept usually is
                driverDev.tap(200, 1300);
                acceptTapped = true;
                console.log('  [Driver] Used fallback accept coordinates');
            }
        }

        tl.emit('DRIVER_ACCEPTED', { orderId });
        await sleep(TIMEOUTS.postAccept);

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 5: Verify Backend State
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 5] Verifying order status in backend...');

        const orderState = await B.inspectOrder(orderId);
        const status = orderState?.status;
        tl.emit('ORDER_STATUS', { orderId, status });

        if (status === 'accepted' || status === 'active_trip') {
            rep.recordPass(`Order accepted — status: ${status}`);
            console.log(`  [Backend] ✅ Order status: ${status}`);
        } else {
            rep.recordFail(`Order not accepted. Status: ${status}`, {
                classification: 'ACCEPT_FAILURE',
                actual: status
            });
            console.log(`  [Backend] ❌ Order status: ${status}`);
        }

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 6: Verify Rider Update
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 6] Checking rider app update...');
        await sleep(5000);

        riderDev.screencap(path.join(artifactsDir, 'rider_after_accept.png'));
        const riderPostUI = safeUIDump(riderDev, path.join(artifactsDir, 'rider_post_accept.xml'));

        if (riderPostUI) {
            const hasDriverInfo = riderPostUI.includes('السائق') ||
                riderPostUI.includes('driver') ||
                riderPostUI.includes('في الطريق') ||
                riderPostUI.includes('track');
            if (hasDriverInfo) {
                rep.recordPass('Rider sees driver assigned');
                console.log('  [Rider] ✅ Driver info visible');
            } else {
                console.log('  [Rider] ⚠️ Driver info not yet visible');
            }
        }

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 7: Evidence Collection
        // ══════════════════════════════════════════════════════════════════════════
        console.log('\n[Phase 7] Collecting evidence...');
        driverDev.screencap(path.join(artifactsDir, 'driver_final.png'));
        riderDev.screencap(path.join(artifactsDir, 'rider_final.png'));

        const driverLogs = driverDev.getLogcat({ limit: 500 });
        fs.writeFileSync(path.join(artifactsDir, 'driver_logcat.txt'), driverLogs.join('\n'));

        const riderLogs = riderDev.getLogcat({ limit: 500 });
        fs.writeFileSync(path.join(artifactsDir, 'rider_logcat.txt'), riderLogs.join('\n'));

        tl.emit('EVIDENCE_COLLECTED', { orderId });

        console.log(`\n${'═'.repeat(70)}`);
        console.log(`  ✅ SCENARIO COMPLETE: ${SCENARIO}`);
        console.log(`${'═'.repeat(70)}\n`);

    } catch (err) {
        console.error(`\n🔴 SCENARIO FAILED: ${err.message}\n`);
        try {
            driverDev.screencap(path.join(artifactsDir, 'driver_crash.png'));
            riderDev.screencap(path.join(artifactsDir, 'rider_crash.png'));
        } catch (_) { }
        if (!err.message.includes('FAIL')) {
            rep.recordFail(`Error: ${err.message}`, { classification: 'HARNESS_ERROR' });
        }
    } finally {
        console.log('[Cleanup] Resetting devices...');
        driverDev.killApp();
        riderDev.killApp();
        driverDev.clearNotifications();
        riderDev.clearNotifications();
        tl.emit('SCENARIO_END', { orderId });
        tl.close();
    }

    return rep.finalize(tl);
}

// ══════════════════════════════════════════════════════════════════════════════
// RIDER UI AUTOMATION
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Attempts to create an order through the rider app UI.
 * Returns orderId if successful, null if UI flow fails.
 */
async function attemptRiderOrderCreation(riderDev, artifactsDir, tl) {
    try {
        const homeUI = safeUIDump(riderDev, path.join(artifactsDir, 'rider_ui_home.xml'));
        if (!homeUI || !homeUI.includes('com.wawapp.client')) {
            console.log('  [Rider] App not on expected screen');
            return null;
        }

        // Check if we're on home screen (look for "بدء شحنة" or "الموقع الحالي")
        if (!homeUI.includes('الموقع الحالي') && !homeUI.includes('بدء شحنة')) {
            console.log('  [Rider] Not on home screen');
            return null;
        }

        // Step 1: Tap "الموقع الحالي" to set pickup to current GPS
        console.log('  [Rider] Step 1: Setting pickup to current location...');
        const pickupBtn = findUIElement(homeUI, ['الموقع الحالي']);
        if (pickupBtn) {
            riderDev.tap(pickupBtn.x, pickupBtn.y);
        } else {
            // Fallback coordinates from UI dump: bounds="[570,443][660,533]"
            riderDev.tap(615, 488);
        }
        await sleep(TIMEOUTS.locationResolve);

        // Step 2: Tap on dropoff field to open map picker
        console.log('  [Rider] Step 2: Opening dropoff location picker...');
        const afterPickupUI = safeUIDump(riderDev, path.join(artifactsDir, 'rider_after_pickup.xml'));

        // Tap the dropoff field area (second input field)
        // From UI dump: dropoff field bounds approximately [60,563][660,668]
        riderDev.tap(360, 615);
        await sleep(TIMEOUTS.uiTransition);

        // Check if map picker opened
        const mapUI = safeUIDump(riderDev, path.join(artifactsDir, 'rider_map_picker.xml'));
        if (mapUI && (mapUI.includes('تحديد موقع التسليم') || mapUI.includes('تأكيد') || mapUI.includes('موقعي'))) {
            console.log('  [Rider] Map picker opened, selecting dropoff...');

            // First tap "موقعي" to center on current GPS (enables the confirm button)
            const myLocBtn = findUIElement(mapUI, ['موقعي']);
            if (myLocBtn) {
                riderDev.tap(myLocBtn.x, myLocBtn.y);
                console.log('  [Rider] Tapped "موقعي" to center map');
                await sleep(4000); // Wait for GPS to resolve and map to move
            }

            // Now swipe map significantly to set a different dropoff point
            riderDev.swipe(360, 700, 360, 400, 1000);
            await sleep(3000);

            // Re-dump to get updated button state
            const mapUI2 = safeUIDump(riderDev, path.join(artifactsDir, 'rider_map2.xml'));
            if (mapUI2) {
                const confirmBtn = findUIElement(mapUI2, ['تأكيد الموقع', 'تأكيد']);
                if (confirmBtn) {
                    riderDev.tap(confirmBtn.x, confirmBtn.y);
                    console.log('  [Rider] Confirmed dropoff location');
                } else {
                    // Try one more swipe
                    riderDev.swipe(360, 600, 250, 350, 1200);
                    await sleep(3000);
                    const mapUI3 = safeUIDump(riderDev, path.join(artifactsDir, 'rider_map3.xml'));
                    const cb3 = findUIElement(mapUI3, ['تأكيد الموقع', 'تأكيد']);
                    if (cb3) riderDev.tap(cb3.x, cb3.y);
                    else return null;
                }
            } else {
                return null;
            }
            await sleep(TIMEOUTS.uiTransition);
        } else {
            console.log('  [Rider] Map picker did not open for dropoff');
            return null;
        }

        // Step 3: Tap "بدء شحنة"
        console.log('  [Rider] Step 3: Tapping "بدء شحنة"...');
        await sleep(2000);
        const preSubmitUI = safeUIDump(riderDev, path.join(artifactsDir, 'rider_pre_submit.xml'));
        riderDev.screencap(path.join(artifactsDir, 'rider_pre_submit.png'));

        if (!preSubmitUI) return null;

        // Check if button is enabled
        const btnMatch = preSubmitUI.match(/content-desc="بدء شحنة"[^/]*enabled="(true|false)"[^/]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
        if (btnMatch && btnMatch[1] === 'true') {
            const bx = Math.round((parseInt(btnMatch[2]) + parseInt(btnMatch[4])) / 2);
            const by = Math.round((parseInt(btnMatch[3]) + parseInt(btnMatch[5])) / 2);
            riderDev.tap(bx, by);
            console.log(`  [Rider] Tapped "بدء شحنة" at (${bx}, ${by})`);
        } else if (btnMatch && btnMatch[1] === 'false') {
            console.log('  [Rider] "بدء شحنة" is disabled — locations not properly set');
            return null;
        } else {
            // Try generic find
            const node = findUIElement(preSubmitUI, ['بدء شحنة']);
            if (node) riderDev.tap(node.x, node.y);
            else return null;
        }
        await sleep(TIMEOUTS.uiTransition);

        // Step 4: Quote screen → "اطلب الآن"
        console.log('  [Rider] Step 4: Tapping "اطلب الآن" on quote screen...');
        // Scroll down first — the button is below the fold
        riderDev.swipe(360, 1200, 360, 600, 500);
        await sleep(2000);

        const quoteUI = safeUIDump(riderDev, path.join(artifactsDir, 'rider_quote.xml'));
        riderDev.screencap(path.join(artifactsDir, 'rider_quote.png'));

        if (!quoteUI) return null;

        const requestBtn = findUIElement(quoteUI, ['اطلب الآن', 'request_now']);
        if (requestBtn) {
            riderDev.tap(requestBtn.x, requestBtn.y);
            console.log(`  [Rider] Tapped "اطلب الآن" at (${requestBtn.x}, ${requestBtn.y})`);
        } else {
            console.log('  [Rider] Could not find "اطلب الآن" button');
            return null;
        }

        tl.emit('ORDER_SUBMITTED_BY_RIDER', { device: 'rider' });
        await sleep(8000); // Wait for Firestore write

        // Step 5: Detect the order in Firestore
        const detectedOrderId = await waitForRiderOrder(30_000);
        return detectedOrderId;

    } catch (err) {
        console.log(`  [Rider] UI automation error: ${err.message}`);
        return null;
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

function safeUIDump(dev, filePath) {
    try {
        return dev.dumpUI(filePath);
    } catch (err) {
        console.log(`  [Warning] UI dump failed: ${err.message}`);
        return null;
    }
}

function findUIElement(xml, hints) {
    if (!xml) return null;
    for (const hint of hints) {
        const patterns = [
            new RegExp(`content-desc="[^"]*${escapeRegex(hint)}[^"]*"[^/]*bounds="\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]"`, 'i'),
            new RegExp(`text="[^"]*${escapeRegex(hint)}[^"]*"[^/]*bounds="\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]"`, 'i'),
            new RegExp(`resource-id="[^"]*${escapeRegex(hint)}[^"]*"[^/]*bounds="\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]"`, 'i'),
        ];
        for (const pat of patterns) {
            const match = xml.match(pat);
            if (match) {
                const x = Math.round((parseInt(match[1]) + parseInt(match[3])) / 2);
                const y = Math.round((parseInt(match[2]) + parseInt(match[4])) / 2);
                console.log(`  [UI] Found "${hint}" at (${x}, ${y})`);
                return { x, y, hint };
            }
        }
    }
    return null;
}

function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function waitForRiderOrder(timeoutMs) {
    const { db } = require('../../orchestrator/firebase');
    const start = Date.now();
    const cutoff = new Date(start - 120_000);

    while (Date.now() - start < timeoutMs) {
        const snapshot = await db.collection('orders')
            .where('status', 'in', ['matching', 'assigning', 'pending'])
            .orderBy('createdAt', 'desc')
            .limit(5)
            .get();

        for (const doc of snapshot.docs) {
            const data = doc.data();
            if (data.qa_test === true) continue;
            const createdAt = data.createdAt?.toDate?.() || new Date(0);
            if (createdAt > cutoff) return doc.id;
        }
        await sleep(3000);
    }
    return null;
}

module.exports = { run, SCENARIO };

if (require.main === module) {
    const { runId: makeId } = require('../../orchestrator/utils');
    run(makeId('e2e')).then(r => {
        console.log(`\nResult: ${r.passed ? 'PASSED ✅' : 'FAILED ❌'}`);
        if (r.failures && r.failures.length > 0) {
            console.log('Failures:');
            r.failures.forEach(f => console.log(`  - ${f.label}`));
        }
        process.exit(r.passed ? 0 : 1);
    });
}
