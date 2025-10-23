#!/bin/bash

#################################################################################
# File: scripts/zap_ephemeral_test.sh
# Description: Ephemeral OWASP ZAP DAST Testing Script
# Author: Haitam Bidiouane (@sch0penheimer)
# Last Modified: 21/10/2025
#
# This script performs an ephemeral DAST scan using OWASP ZAP against a specified
# web application. It installs ZAP if not already present, starts it in daemon mode,
# performs a spider and active scan, and generates a report of findings.
#################################################################################

set -e

APPLICATION_URL="${1:-https://http.codes}"
ZAP_PORT=8080
ZAP_HOME="/opt/zap"
ZAP_LOG="/tmp/zap.log"

echo "=========================================="
echo "OWASP ZAP DAST Testing Script"
echo "=========================================="
echo "Target URL: $APPLICATION_URL"
echo "ZAP Port: $ZAP_PORT"
echo "=========================================="

##-- cleanup function on exit --##
cleanup() {
    echo ""
    echo "[Cleanup] Shutting down ZAP..."
    curl -s "http://localhost:$ZAP_PORT/JSON/core/action/shutdown/" || true
    sleep 2
    pkill -f zap.sh || true
    pkill -f java.*zap || true
    echo "[Cleanup] Done"
}
trap cleanup EXIT

#==============================================================================#
# PHASE 1: Installation
#==============================================================================#
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== INSTALLATION PHASE ====="

if [ ! -d "$ZAP_HOME" ]; then
    echo "Installing OWASP ZAP..."
    
    echo "Updating package lists..."
    sudo apt-get update -qq
    
    echo "Installing dependencies (jq, curl, wget)..."
    sudo apt-get install -y jq curl wget default-jre
    
    echo "Downloading OWASP ZAP..."
    cd /tmp
    wget -q https://github.com/zaproxy/zaproxy/releases/download/v2.16.1/ZAP_2.16.1_Linux.tar.gz
    
    echo "Extracting ZAP..."
    tar -xzf ZAP_2.16.1_Linux.tar.gz
    
    echo "Installing ZAP to $ZAP_HOME..."
    sudo mv ZAP_2.16.1 $ZAP_HOME
    sudo chmod +x $ZAP_HOME/zap.sh
    
    echo "Creating ZAP directories..."
    sudo mkdir -p /home/zap/.ZAP
    sudo chown -R $(whoami) $ZAP_HOME
    sudo chown -R $(whoami) /home/zap 2>/dev/null || true
    
    echo "ZAP installation completed."
else
    echo "ZAP already installed at $ZAP_HOME"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installation phase completed."

#==============================================================================#
# PHASE 2: Pre-Scan - Start ZAP and Verify Target
#==============================================================================#
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== PRE-SCAN PHASE ====="

echo "Testing target application accessibility..."
if curl -f --connect-timeout 10 "$APPLICATION_URL" > /dev/null 2>&1; then
    echo "Target application is accessible"
else
    echo "WARNING: Target application may not be accessible"
    echo "Continuing anyway..."
fi

echo ""
echo "Starting OWASP ZAP daemon..."
$ZAP_HOME/zap.sh -daemon -host 0.0.0.0 -port $ZAP_PORT \
    -config api.disablekey=true \
    -config api.addrs.addr.name=.* \
    -config api.addrs.addr.regex=true > $ZAP_LOG 2>&1 &

ZAP_PID=$!
echo "ZAP PID: $ZAP_PID"

echo "Waiting for ZAP to start (this may take 30-60 seconds)..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    
    if curl -s http://localhost:$ZAP_PORT/JSON/core/view/version/ > /dev/null 2>&1; then
        echo " ZAP is ready!"
        break
    fi
    
    echo "  Attempt $attempt/$max_attempts - Waiting for ZAP..."
    sleep 5
    
    # Check if process is still running
    if ! kill -0 $ZAP_PID 2>/dev/null; then
        echo " ERROR: ZAP process died during startup"
        echo ""
        echo "=== ZAP Log Contents ==="
        cat $ZAP_LOG
        echo "=== End ZAP Logs ==="
        exit 1
    fi
done

if [ $attempt -ge $max_attempts ]; then
    echo " ERROR: ZAP failed to start within timeout"
    echo ""
    echo "=== ZAP Log Contents ==="
    cat $ZAP_LOG
    echo "=== End ZAP Logs ==="
    exit 1
fi

echo ""
echo "ZAP Version:"
curl -s "http://localhost:$ZAP_PORT/JSON/core/view/version/" | jq .

echo ""
echo "ZAP Process Info:"
ps aux | grep "[z]ap" || echo "No ZAP process found in ps output"

echo ""
echo "Port $ZAP_PORT Status:"
netstat -tlnp 2>/dev/null | grep $ZAP_PORT || ss -tlnp | grep $ZAP_PORT || echo "Could not check port status"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pre-scan phase completed."

#==============================================================================#
# PHASE 3: Spider Scan
#==============================================================================#
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== SPIDER SCAN PHASE ====="

echo "Starting OWASP ZAP Spider Scan..."
echo "Target URL: $APPLICATION_URL"

spider_response=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/action/scan/?url=$APPLICATION_URL&recurse=true")
echo "Spider API Response: $spider_response"

spider_scanid=$(echo "$spider_response" | jq -r '.scan')
echo "Spider Scan ID: $spider_scanid"

if [ "$spider_scanid" = "null" ] || [ -z "$spider_scanid" ]; then
    echo " ERROR: Failed to start spider scan"
    echo "Full response: $spider_response"
    exit 1
fi

echo "Waiting for spider scan to complete..."
stat=0
timeout=600
counter=0

while [ "$stat" != "100" ] && [ $counter -lt $timeout ]; do
    stat=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/view/status/?scanId=$spider_scanid" | jq -r '.status')
    echo "  [$(date '+%Y-%m-%d %H:%M:%S')] Spider scan progress: $stat%"
    
    if [ "$stat" = "100" ]; then
        echo " Spider scan completed successfully."
        break
    fi
    
    sleep 10
    counter=$((counter + 10))
done

if [ $counter -ge $timeout ]; then
    echo " Spider scan timed out"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Spider scan completed."

#==============================================================================#
# PHASE 4: Active Scan
#==============================================================================#
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== ACTIVE SCAN PHASE ====="

echo "Starting OWASP ZAP Active Scan..."
active_response=$(curl -s "http://localhost:$ZAP_PORT/JSON/ascan/action/scan/?url=$APPLICATION_URL&recurse=true&inScopeOnly=false")
echo "Active Scan API Response: $active_response"

active_scanid=$(echo "$active_response" | jq -r '.scan')
echo "Active Scan ID: $active_scanid"

if [ "$active_scanid" = "null" ] || [ -z "$active_scanid" ]; then
    echo " ERROR: Failed to start active scan"
    echo "Full response: $active_response"
    exit 1
fi

echo "Waiting for active scan to complete..."
stat=0
timeout=900
counter=0

while [ "$stat" != "100" ] && [ $counter -lt $timeout ]; do
    stat=$(curl -s "http://localhost:$ZAP_PORT/JSON/ascan/view/status/?scanId=$active_scanid" | jq -r '.status')
    echo "  [$(date '+%Y-%m-%d %H:%M:%S')] Active scan progress: $stat%"
    
    if [ "$stat" = "100" ]; then
        echo " Active scan completed successfully."
        break
    fi
    
    sleep 15
    counter=$((counter + 15))
done

if [ $counter -ge $timeout ]; then
    echo "Active scan timed out - proceeding with partial results"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Active scan completed."

#==============================================================================#
# PHASE 5: Results Analysis
#==============================================================================#
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== RESULTS ANALYSIS ====="

echo "Generating scan report..."
curl -s "http://localhost:$ZAP_PORT/OTHER/core/other/jsonreport/" | jq . > zap-scan-results.json
echo " Report saved to: zap-scan-results.json"

echo ""
echo "Analyzing scan results..."
alerts_summary=$(curl -s "http://localhost:$ZAP_PORT/JSON/alert/view/alertsSummary/?baseurl=$APPLICATION_URL")
echo "Alerts Summary: $alerts_summary"

high_alerts=$(echo "$alerts_summary" | jq -r '.alertsSummary.High // 0')
medium_alerts=$(echo "$alerts_summary" | jq -r '.alertsSummary.Medium // 0')
low_alerts=$(echo "$alerts_summary" | jq -r '.alertsSummary.Low // 0')
info_alerts=$(echo "$alerts_summary" | jq -r '.alertsSummary.Informational // 0')

echo ""
echo "=========================================="
echo "OWASP ZAP DAST Scan Results Summary"
echo "=========================================="
echo "High severity alerts:          $high_alerts"
echo "Medium severity alerts:        $medium_alerts"
echo "Low severity alerts:           $low_alerts"
echo "Informational alerts:          $info_alerts"
echo "=========================================="

echo ""
if [ "$high_alerts" != "0" ] && [ "$high_alerts" != "null" ]; then
    echo "HIGH severity vulnerabilities detected!"
    exit 1
elif [ "$medium_alerts" != "0" ] && [ "$medium_alerts" != "null" ]; then
    echo "MEDIUM severity vulnerabilities detected (within threshold)"
elif [ "$low_alerts" != "0" ] && [ "$low_alerts" != "null" ]; then
    echo " Only LOW severity vulnerabilities detected"
else
    echo " No significant vulnerabilities found"
fi

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DAST scan completed successfully."
echo ""
echo "Results saved to: $(pwd)/zap-scan-results.json"