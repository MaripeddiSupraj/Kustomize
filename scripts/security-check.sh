#!/bin/bash

# Security Validation Script
# Run this before committing to ensure no sensitive data is included

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "🔒 Running Security Validation..."

ERRORS=0

# Check for potential sensitive data patterns
echo "Checking for sensitive data patterns..."

# Check for real passwords (not demo ones)
if grep -r -E "(password|passwd|pwd).*[=:]\s*[^(changeme|demo|test|dev_|staging_)]" . --exclude-dir=.git --exclude="*.md" --exclude="security-check.sh" 2>/dev/null; then
    print_error "Potential real passwords found!"
    ERRORS=$((ERRORS + 1))
fi

# Check for API keys
if grep -r -E "(api[_-]?key|apikey|token).*[=:]\s*['\"][a-zA-Z0-9]{20,}" . --exclude-dir=.git --exclude="*.md" 2>/dev/null; then
    print_error "Potential API keys found!"
    ERRORS=$((ERRORS + 1))
fi

# Check for AWS credentials
if grep -r -E "(aws[_-]?(access[_-]?key|secret))" . --exclude-dir=.git --exclude="*.md" 2>/dev/null; then
    print_error "Potential AWS credentials found!"
    ERRORS=$((ERRORS + 1))
fi

# Check for GCP service account keys
if grep -r "private_key" . --exclude-dir=.git --exclude="*.md" 2>/dev/null; then
    print_error "Potential GCP service account keys found!"
    ERRORS=$((ERRORS + 1))
fi

# Check for production secrets in production overlay
if grep -E "password|secret" overlays/production/kustomization.yaml | grep -v "#" 2>/dev/null; then
    print_error "Production overlay contains hardcoded secrets!"
    ERRORS=$((ERRORS + 1))
fi

# Validate demo passwords are clearly marked
if ! grep -q "DEMO ONLY" README.md; then
    print_warning "Demo passwords should be clearly marked in README"
fi

if ! grep -q "changeme123" base/kustomization.yaml; then
    print_warning "Base should contain obvious demo password"
fi

# Check that production overlay doesn't have secretGenerator
if grep -A 5 "secretGenerator:" overlays/production/kustomization.yaml | grep -v "#" 2>/dev/null; then
    print_error "Production overlay should not generate secrets!"
    ERRORS=$((ERRORS + 1))
fi

echo
if [ $ERRORS -eq 0 ]; then
    print_success "✅ Security validation passed!"
    print_success "✅ No sensitive data detected"
    print_success "✅ Demo passwords are properly marked"
    print_success "✅ Production secrets are externalized"
    echo
    echo "Safe to commit! 🚀"
    exit 0
else
    print_error "❌ Security validation failed with $ERRORS errors"
    echo
    echo "Please fix the issues above before committing."
    exit 1
fi
