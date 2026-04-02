const fs = require('fs');
const path = require('path');
const configPath = path.join(process.env.HOME, '.config/opencode/opencode.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

if (config.mcp && config.mcp.cloudwatch && config.mcp.cloudwatch.environment) {
    delete config.mcp.cloudwatch.environment.AWS_PROFILE;
    delete config.mcp.cloudwatch.environment.AWS_REGION;
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    console.log('Fixed opencode.json');
} else {
    console.log('No fix needed or structure changed');
}
