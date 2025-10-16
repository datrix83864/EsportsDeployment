#!/bin/bash
#
# iPXE Boot Server Testing Script
# Tests DHCP, TFTP, and HTTP functionality
#
# Usage:
#   ./test_pxe.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_fail() { echo -e "${RED}[✗]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "=========================================="
echo "iPXE Boot Server Test Suite"
echo "=========================================="
echo ""

# Test 1: Check if services are running
log_info "Testing services status..."

if systemctl is-active --quiet dnsmasq; then
    log_success "dnsmasq (DHCP) is running"
else
    log_fail "dnsmasq is not running"
fi

if systemctl is-active --quiet tftpd-hpa; then
    log_success "tftpd-hpa (TFTP) is running"
else
    log_fail "tftpd-hpa is not running"
fi

if systemctl is-active --quiet nginx; then
    log_success "nginx (HTTP) is running"
else
    log_fail "nginx is not running"
fi

echo ""

# Test 2: Check if ports are listening
log_info "Testing network ports..."

if ss -ulnp | grep -q ":67 "; then
    log_success "Port 67 (DHCP) is listening"
else
    log_fail "Port 67 (DHCP) is not listening"
fi

if ss -ulnp | grep -q ":69 "; then
    log_success "Port 69 (TFTP) is listening"
else
    log_fail "Port 69 (TFTP) is not listening"
fi

if ss -tlnp | grep -q ":80 "; then
    log_success "Port 80 (HTTP) is listening"
else
    log_fail "Port 80 (HTTP) is not listening"
fi

if ss -tlnp | grep -q ":8080 "; then
    log_success "Port 8080 (HTTP Images) is listening"
else
    log_fail "Port 8080 (HTTP Images) is not listening"
fi

echo ""

# Test 3: Check if boot files exist
log_info "Testing boot files..."

if [[ -f /srv/tftp/ipxe.efi ]]; then
    log_success "ipxe.efi exists"
else
    log_fail "ipxe.efi not found"
fi

if [[ -f /srv/tftp/undionly.kpxe ]]; then
    log_success "undionly.kpxe exists"
else
    log_fail "undionly.kpxe not found"
fi

if [[ -f /srv/tftp/boot.ipxe ]]; then
    log_success "boot.ipxe exists"
else
    log_fail "boot.ipxe not found"
fi

if [[ -f /srv/tftp/wimboot ]]; then
    log_success "wimboot exists"
else
    log_fail "wimboot not found"
fi

echo ""

# Test 4: Test TFTP access
log_info "Testing TFTP server access..."

TFTP_TEST=$(mktemp)
if echo "get test.ipxe $TFTP_TEST" | tftp localhost 2>&1 | grep -q "Received"; then
    log_success "TFTP server is accessible"
    rm -f "$TFTP_TEST"
else
    log_fail "Cannot access TFTP server"
fi

echo ""

# Test 5: Test HTTP access
log_info "Testing HTTP server access..."

if curl -s -f http://localhost/health > /dev/null; then
    log_success "HTTP server health check passed"
else
    log_fail "HTTP server health check failed"
fi

if curl -s -f http://localhost/boot.ipxe > /dev/null; then
    log_success "boot.ipxe is accessible via HTTP"
else
    log_fail "boot.ipxe is not accessible via HTTP"
fi

if curl -s -f http://localhost:8080/health > /dev/null; then
    log_success "Image server health check passed"
else
    log_fail "Image server health check failed"
fi

echo ""

# Test 6: Check DHCP configuration
log_info "Testing DHCP configuration..."

if grep -q "dhcp-range" /etc/dnsmasq.conf; then
    log_success "DHCP range is configured"
else
    log_fail "DHCP range not found in configuration"
fi

if grep -q "enable-tftp" /etc/dnsmasq.conf; then
    log_success "TFTP is enabled in dnsmasq"
else
    log_fail "TFTP not enabled in dnsmasq"
fi

echo ""

# Test 7: Check directory permissions
log_info "Testing directory permissions..."

if [[ -d /srv/tftp ]] && [[ -r /srv/tftp ]]; then
    log_success "/srv/tftp is readable"
else
    log_fail "/srv/tftp is not readable"
fi

if [[ -d /srv/images ]] && [[ -r /srv/images ]]; then
    log_success "/srv/images is readable"
else
    log_fail "/srv/images is not readable"
fi

echo ""

# Test 8: Check logs for errors
log_info "Checking recent logs for errors..."

DHCP_ERRORS=$(journalctl -u dnsmasq --since "5 minutes ago" | grep -i error | wc -l)
if [[ $DHCP_ERRORS -eq 0 ]]; then
    log_success "No recent DHCP errors"
else
    log_warning "Found $DHCP_ERRORS DHCP errors in last 5 minutes"
fi

TFTP_ERRORS=$(journalctl -u tftpd-hpa --since "5 minutes ago" | grep -i error | wc -l)
if [[ $TFTP_ERRORS -eq 0 ]]; then
    log_success "No recent TFTP errors"
else
    log_warning "Found $TFTP_ERRORS TFTP errors in last 5 minutes"
fi

NGINX_ERRORS=$(grep -i error /var/log/nginx/error.log 2>/dev/null | tail -5 | wc -l)
if [[ $NGINX_ERRORS -eq 0 ]]; then
    log_success "No recent nginx errors"
else
    log_warning "Found $NGINX_ERRORS nginx errors in recent logs"
fi

echo ""

# Test 9: Check disk space
log_info "Checking disk space..."

TFTP_USAGE=$(df /srv/tftp | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $TFTP_USAGE -lt 80 ]]; then
    log_success "/srv/tftp has sufficient space (${TFTP_USAGE}% used)"
else
    log_warning "/srv/tftp is ${TFTP_USAGE}% full"
fi

IMAGES_USAGE=$(df /srv/images | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $IMAGES_USAGE -lt 80 ]]; then
    log_success "/srv/images has sufficient space (${IMAGES_USAGE}% used)"
else
    log_warning "/srv/images is ${IMAGES_USAGE}% full"
fi

echo ""

# Test 10: Check DHCP leases (if any)
log_info "Checking DHCP leases..."

if [[ -f /var/lib/misc/dnsmasq.leases ]]; then
    LEASE_COUNT=$(wc -l < /var/lib/misc/dnsmasq.leases)
    log_info "Active DHCP leases: $LEASE_COUNT"
    if [[ $LEASE_COUNT -gt 0 ]]; then
        echo ""
        echo "Recent leases:"
        tail -5 /var/lib/misc/dnsmasq.leases | while read -r line; do
            echo "  $line"
        done
    fi
else
    log_info "No DHCP leases file yet (this is normal if no clients have booted)"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Your iPXE boot server is ready to use!"
    echo ""
    echo "Next steps:"
    echo "  1. Copy Windows image files to /srv/images/windows11/"
    echo "  2. Boot a test client via PXE"
    echo "  3. Monitor logs: journalctl -u dnsmasq -f"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check service status: systemctl status dnsmasq tftpd-hpa nginx"
    echo "  - View logs: journalctl -u dnsmasq -u tftpd-hpa"
    echo "  - Verify configuration: cat /etc/dnsmasq.conf"
    echo "  - Check firewall: ufw status"
    echo ""
    exit 1
fi