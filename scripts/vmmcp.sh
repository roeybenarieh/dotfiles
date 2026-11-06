#!/usr/bin/env bash
# usage: ./scripts/vmmcp.sh <tool> '<json-args>'
U=http://localhost:8081/mcp
H='-H Content-Type:application/json -H Accept:application/json,text/event-stream'
SID=$(curl -s -i -m 20 $U $H -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"a","version":"1"}}}' | tr -d '\r' | awk -F': ' 'tolower($1)=="mcp-session-id"{print $2}')
curl -s -m 20 $U $H -H "mcp-session-id: $SID" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null
curl -s -m 60 $U $H -H "mcp-session-id: $SID" -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}"
