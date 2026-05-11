const fs = require('fs');
const path = require('path');

function checkDump(filename, mustContain, mustNotContain) {
    const filePath = path.join('qa_forensics', filename);
    if (!fs.existsSync(filePath)) {
        console.log(`[ANALYZER] ❌ File not found: ${filename}`);
        return;
    }
    const content = fs.readFileSync(filePath, 'utf8');
    const hasTarget = content.includes(mustContain);
    const hasExcluded = mustNotContain ? content.includes(mustNotContain) : false;

    console.log(`[ANALYZER] Analyzing ${filename}:`);
    console.log(`  - Found Target "${mustContain}": ${hasTarget ? "✅ YES" : "❌ NO"}`);
    if (mustNotContain) {
        console.log(`  - Found Excluded "${mustNotContain}": ${hasExcluded ? "⚠️ YES" : "✅ NO"}`);
    }
}

console.log("\n=== SCENARIO 2: TRANSIENT FAILURE (Expect Screen Alive) ===");
checkDump('s2_dump.xml', 'قبول الطلب'); // Should still contain the Accept button text in Arabic

console.log("\n=== SCENARIO 3: MAX RETRY EXCEEDED (Expect Dash Alive, Screen Dismissed) ===");
checkDump('s3_dump.xml', 'ملخص اليوم', 'قبول الطلب'); // Dash summary found, Accept Button GONE

console.log("\n=== SCENARIO 4: FATAL ALREADY TAKEN (Expect Dash Alive, Screen Dismissed) ===");
checkDump('s4_dump.xml', 'ملخص اليوم', 'قبول الطلب');

console.log("\n=== SCENARIO 5: BACKEND CANCEL (Expect Dash Alive, Screen Dismissed) ===");
checkDump('s5_dump.xml', 'ملخص اليوم', 'قبول الطلب');
