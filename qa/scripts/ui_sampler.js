const { execSync } = require('child_process');
const fs = require('fs');

const device = "R83Y20PC4EN";
console.log("[SAMPLER] Starting high-frequency UI sampler for 10 seconds...");

const startTime = Date.now();
let counter = 0;
let found = false;

while (Date.now() - startTime < 15000) {
    try {
        // Fast dump to memory stream if possible, but android uiautomator always dumps to file
        execSync(`adb -s ${device} shell uiautomator dump /sdcard/trap_${counter}.xml > /dev/null 2>&1`);
        const xml = execSync(`adb -s ${device} shell cat /sdcard/trap_${counter}.xml`).toString();
        
        if (xml.includes("0.5")) {
            console.log(`[SAMPLER] 🚨 FOUND IT IN SAMPLE #${counter} at time +${((Date.now() - startTime)/1000).toFixed(1)}s`);
            fs.writeFileSync(`qa_forensics/caught_sample_${counter}.xml`, xml);
            found = true;
            break;
        }
        counter++;
    } catch(e) {
        // ignore errors
    }
}

if (!found) {
    console.log("[SAMPLER] 🏁 Finished 15s window. Cache replay NOT caught in sampling.");
    process.exit(1);
} else {
    process.exit(0);
}
