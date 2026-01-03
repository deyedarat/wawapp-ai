const fs = require('fs');
const path = require('path');

/**
 * Config Loader for WawApp Backend
 * Reads app configuration from file system with safe defaults
 */
class ConfigLoader {
  constructor(configPath = '/etc/wawapp/config.json') {
    this.configPath = configPath;
    this.safeDefaults = {
      minClientVersion: '1.0.0',
      maintenance: false,
      forceUpdate: false,
      supportWhatsApp: null,
      message: null
    };
    this.cachedConfig = null;
    this.lastLoadTime = null;
    this.CACHE_TTL_MS = 60000; // 1 minute cache
  }

  /**
   * Load config from file or return safe defaults
   * @returns {Object} Configuration object
   */
  loadConfig() {
    const now = Date.now();
    
    // Return cached config if still valid
    if (this.cachedConfig && this.lastLoadTime && (now - this.lastLoadTime < this.CACHE_TTL_MS)) {
      console.log('[ConfigLoader] Returning cached config');
      return this.cachedConfig;
    }

    try {
      // Check if config file exists
      if (!fs.existsSync(this.configPath)) {
        console.warn(`[ConfigLoader] Config file not found at ${this.configPath}, using safe defaults`);
        this.cachedConfig = { ...this.safeDefaults };
        this.lastLoadTime = now;
        return this.cachedConfig;
      }

      // Read and parse config file
      const fileContent = fs.readFileSync(this.configPath, 'utf8');
      const parsedConfig = JSON.parse(fileContent);
      
      // Merge with defaults to ensure all required fields exist
      this.cachedConfig = {
        ...this.safeDefaults,
        ...parsedConfig
      };
      
      this.lastLoadTime = now;
      console.log('[ConfigLoader] Config loaded successfully from file');
      return this.cachedConfig;

    } catch (error) {
      console.error('[ConfigLoader] Error loading config:', error.message);
      
      // Return safe defaults on any error
      this.cachedConfig = { ...this.safeDefaults };
      this.lastLoadTime = now;
      return this.cachedConfig;
    }
  }

  /**
   * Get config with serverTime added
   * @returns {Object} Configuration object with serverTime
   */
  getConfigWithServerTime() {
    const config = this.loadConfig();
    return {
      ...config,
      serverTime: new Date().toISOString()
    };
  }

  /**
   * Clear cache (useful for testing or forced reload)
   */
  clearCache() {
    this.cachedConfig = null;
    this.lastLoadTime = null;
    console.log('[ConfigLoader] Cache cleared');
  }
}

module.exports = ConfigLoader;
