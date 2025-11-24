#!/bin/bash

# Sancta Via Liturgical Calendar - Data Generation Script
# This script generates liturgical calendar data using RomCal integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_info "Generating liturgical calendar data for Sancta Via Liturgical Calendar..."

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    log_error "Node.js not found. Please install Node.js to generate liturgical data."
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "tools/romcal_integration" ]; then
    log_error "RomCal integration tools not found. Please run this script from the package root."
    exit 1
fi

# Change to romcal integration directory
cd tools/romcal_integration

log_info "Installing Node.js dependencies..."
npm install

log_info "Generating liturgical calendar data (2024-2035)..."
npm run generate

log_success "Liturgical calendar data generation complete!"
log_info "Data has been generated and embedded in the package."

cd ../..

log_success "Build complete! The package is ready to use."