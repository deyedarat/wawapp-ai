# WawApp MCP Tools Documentation

**Last Updated**: 2025-11-30  
**MCP Server**: Configured in `.mcp/servers.json`

## Overview

WawApp provides custom MCP (Model Context Protocol) tools for AI agents
to inspect and manipulate order data, driver eligibility, and system state.

## Available Tools

### 1. wawapp_driver_eligibility

**Purpose**: Check if a driver is eligible to accept orders.

**Usage**:
```json
{
  "tool": "wawapp_driver_eligibility",
  "parameters": {
    "driver_id": "driver-uuid-here"
  }
}
```

**Returns**:
```json
{
  "eligible": true,
  "reasons": [
    "Driver has active status",
    "No active order in progress",
    "Driver location updated within 5 minutes"
  ],
  "warnings": []
}
```

**Common Use Cases**:
- Debugging why driver doesn't see nearby orders
- Verifying driver account status
- Troubleshooting order matching issues

**Example Agent Prompt**:
"Check eligibility for driver abc-123 and explain why they can't accept orders."

### 2. wawapp_order_trace

**Purpose**: Get full lifecycle trace of an order (creation → completion).

**Usage**:
```json
{
  "tool": "wawapp_order_trace",
  "parameters": {
    "order_id": "order-uuid-here",
    "include_events": true
  }
}
```

**Returns**:
```json
{
  "order_id": "order-uuid-here",
  "status": "completed",
  "timeline": [
    {
      "timestamp": "2025-11-30T10:15:00Z",
      "status": "matching",
      "event": "Order created by client-123"
    },
    {
      "timestamp": "2025-11-30T10:16:30Z",
      "status": "accepted",
      "event": "Driver driver-456 accepted order",
      "driver_id": "driver-456"
    },
    {
      "timestamp": "2025-11-30T10:18:00Z",
      "status": "onRoute",
      "event": "Driver en route to pickup"
    },
    {
      "timestamp": "2025-11-30T10:35:00Z",
      "status": "completed",
      "event": "Trip completed",
      "rating": 5
    }
  ],
  "duration_minutes": 20,
  "price": 500
}
```

**Common Use Cases**:
- Debugging order state transitions
- Investigating customer complaints
- Analyzing order matching performance
- Auditing driver behavior

**Example Agent Prompt**:
"Trace order xyz-789 and tell me why it expired without driver acceptance."

### 3. wawapp_driver_view_orders

**Purpose**: See what orders a specific driver currently sees in their "nearby orders" list.

**Usage**:
```json
{
  "tool": "wawapp_driver_view_orders",
  "parameters": {
    "driver_id": "driver-uuid-here",
    "include_distance": true
  }
}
```

**Returns**:
```json
{
  "driver_id": "driver-uuid-here",
  "driver_location": {
    "lat": 18.0735,
    "lng": -15.9582
  },
  "visible_orders": [
    {
      "order_id": "order-123",
      "pickup": {
        "lat": 18.0800,
        "lng": -15.9600
      },
      "distance_km": 1.2,
      "price": 450,
      "created_at": "2025-11-30T10:20:00Z"
    },
    {
      "order_id": "order-456",
      "pickup": {
        "lat": 18.0650,
        "lng": -15.9550
      },
      "distance_km": 0.8,
      "price": 350,
      "created_at": "2025-11-30T10:22:00Z"
    }
  ],
  "total_visible": 2,
  "radius_km": 8
}
```

**Common Use Cases**:
- Debugging why driver doesn't see specific order
- Verifying geospatial query correctness
- Testing order matching radius
- Investigating order visibility issues

**Example Agent Prompt**:
"Show me what orders driver abc-123 sees right now and why they don't see order xyz-789."

## Integration with AI Agents

### Claude Code

Claude can use these tools automatically when you ask questions like:
- "Why isn't driver X seeing any orders?"
- "Trace order Y and tell me what went wrong"
- "Check if driver Z is eligible"

### Amazon Q Developer

To use MCP tools with Amazon Q:
- Reference the tool explicitly: "Use wawapp_order_trace to analyze order ABC"
- Q will call the tool and use results in its response

### Custom Agents

Add to your `.claude/agents/*.md` files:

```markdown
When investigating order issues, ALWAYS use:
- wawapp_order_trace for order lifecycle analysis
- wawapp_driver_eligibility for driver status checks
- wawapp_driver_view_orders for visibility debugging
```

## Troubleshooting

### Tool Not Found

**Error**: "MCP tool 'wawapp_driver_eligibility' not available"

**Fix**:
- Check `.mcp/servers.json` exists and is valid JSON
- Restart your IDE/agent environment
- Verify MCP server is running

### Permission Denied

**Error**: "Firestore permission denied reading orders/{orderId}"

**Fix**:
- Ensure you're authenticated: `firebase login`
- Check Firestore security rules allow read access
- Verify service account has `firestore.viewer` role

### Stale Data

**Issue**: Tool returns outdated order status

**Fix**:
- MCP tools read real-time Firestore data
- If data seems stale, check Firestore directly
- Verify order_id is correct (UUIDs are case-sensitive)

## Development

### Adding New MCP Tools

1. Create tool implementation in `.mcp/tools/`
2. Register in `.mcp/servers.json`
3. Add documentation to this file
4. Test with: `mcp test wawapp_your_new_tool`

### Testing MCP Tools

```bash
# Test single tool
mcp test wawapp_order_trace --order-id="test-order-123"

# Test all WawApp tools
mcp test --filter="wawapp_*"
```

## Examples

### Example 1: Debugging Order Matching

**Scenario**: Client reports order not being matched with drivers.

**Agent Session**:
```
User: Why didn't order abc-123 get matched?

Agent: Let me investigate.
[Calls wawapp_order_trace with order_id="abc-123"]

Agent: The order expired after 10 minutes because:
1. Only 2 drivers were within 8km radius
2. Both drivers had active orders already
3. Order was created during peak hours (12:30 PM)

Recommendation: Increase matching radius to 12km during peak hours.
```

### Example 2: Driver Support

**Scenario**: Driver complains they don't see any orders.

**Agent Session**:
```
User: Driver xyz-456 says they don't see any nearby orders.

Agent: Checking driver eligibility.
[Calls wawapp_driver_eligibility with driver_id="xyz-456"]

Agent: Driver is NOT eligible because:
- Driver location last updated 25 minutes ago (threshold: 5 minutes)
- Driver status: "inactive"

Action: Ask driver to:
1. Enable GPS location services
2. Tap "Go Online" in driver app
```

## Security Notes

- MCP tools have READ-ONLY access to Firestore
- Tools respect Firestore security rules
- Driver/client PII is NOT exposed (only IDs)
- Tool usage is logged for audit trail

## Support

For issues with MCP tools:
1. Check this documentation first
2. Review `.mcp/servers.json` configuration
3. Contact: dev-team@wawapp.mr