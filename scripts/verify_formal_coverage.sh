#!/bin/bash
# Verify formal verification coverage for consensus rules

set -e

echo "=== Formal Verification Coverage Report ==="
echo ""

cd "$(dirname "$0")/../consensus-proof" || exit 1

echo "1. Kani Proofs:"
kani_count=$(grep -r "kani::proof" src/ 2>/dev/null | wc -l || echo "0")
echo "   Found: $kani_count proofs"

echo ""
echo "2. Property-Based Tests (proptest):"
proptest_count=$(grep -r "proptest!" tests/ 2>/dev/null | wc -l || echo "0")
echo "   Found: $proptest_count property tests"

echo ""
echo "3. Test Files:"
test_files=$(find tests -name "*.rs" 2>/dev/null | wc -l)
echo "   Found: $test_files test files"

echo ""
echo "4. TODOs in Source:"
todo_count=$(grep -ri "TODO\|FIXME" src/ 2>/dev/null | wc -l || echo "0")
echo "   Found: $todo_count TODOs (may indicate incomplete verification)"

echo ""
echo "=== Coverage Status ==="
echo "Kani Proofs: $kani_count (Target: 30+)"
echo "Property Tests: $proptest_count (Target: 100+)"
echo "Test Files: $test_files"
echo ""
echo "See docs/FORMAL_VERIFICATION_COVERAGE.md for detailed analysis"
