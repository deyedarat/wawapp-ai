const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();

async function run() {
  try {
    const config = await auth.projectConfigManager().getProjectConfig();
    console.log("Config fetched.");
    // Firebase Auth Admin API doesn't easily expose the *actual list* of test numbers via normal API, 
    // usually you configure them in the console. 
    // But let's see if they are inside the returned structure somewhere.
    console.log(JSON.stringify(config, null, 2));
  } catch (e) {
    console.error("Error:", e);
  }
}

run();
