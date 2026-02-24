#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
    echo "Usage: $0 <image-tag>"
    exit 2
fi

IMAGE_TAG="$1"

run_expect_success() {
    local name="$1"
    shift
    local out
    out="$(mktemp)"

    echo "==> PASS expected: ${name}"
    if "$@" >"$out" 2>&1; then
        cat "$out"
        rm -f "$out"
        return 0
    fi

    cat "$out"
    rm -f "$out"
    echo "FAILED: ${name} (expected success)"
    exit 1
}

run_expect_failure() {
    local name="$1"
    local pattern="$2"
    shift 2
    local out
    out="$(mktemp)"

    echo "==> FAIL expected: ${name}"
    if "$@" >"$out" 2>&1; then
        cat "$out"
        rm -f "$out"
        echo "FAILED: ${name} (expected failure)"
        exit 1
    fi

    if ! grep -Fq "$pattern" "$out"; then
        cat "$out"
        rm -f "$out"
        echo "FAILED: ${name} (missing expected output: $pattern)"
        exit 1
    fi

    cat "$out"
    rm -f "$out"
}

assert_output_contains() {
    local pattern="$1"
    shift
    local out
    out="$(mktemp)"

    if "$@" >"$out" 2>&1; then
        if grep -Fq "$pattern" "$out"; then
            cat "$out"
            rm -f "$out"
            return 0
        fi
    fi

    cat "$out"
    rm -f "$out"
    echo "FAILED: expected output to contain: $pattern"
    exit 1
}

# 1) No PHP_DISABLE_FUNCTIONS should not cause early exit.
assert_output_contains "Starting configuration..." \
    docker run --rm "$IMAGE_TAG" sh -lc 'echo startup-ok'

# 2) Valid Laravel docroot should succeed.
run_expect_success "valid docroot /var/www/html/public" \
    docker run --rm \
    -e NGINX_DOCROOT=/var/www/html/public \
    "$IMAGE_TAG" sh -lc 'echo valid-docroot-ok'

# 3) Invalid docroot with semicolon should fail.
run_expect_failure "invalid docroot semicolon" "ERROR: NGINX_DOCROOT contains invalid characters" \
    docker run --rm \
    -e "NGINX_DOCROOT=/var/www/html/public;evil" \
    "$IMAGE_TAG" sh -lc 'echo should-not-run'

# 4) Invalid index with newline should fail.
bad_index=$'index.php\nindex.html'
run_expect_failure "invalid index newline" "ERROR: NGINX_INDEX_FILES contains invalid characters" \
    docker run --rm \
    -e "NGINX_INDEX_FILES=${bad_index}" \
    "$IMAGE_TAG" sh -lc 'echo should-not-run'

# 5) Invalid front controller with newline should fail.
bad_front=$'/index.php?$query_string\nx'
run_expect_failure "invalid front controller newline" "ERROR: NGINX_FRONT_CONTROLLER contains invalid characters" \
    docker run --rm \
    -e "NGINX_FRONT_CONTROLLER=${bad_front}" \
    "$IMAGE_TAG" sh -lc 'echo should-not-run'

echo "All startup regression checks passed for ${IMAGE_TAG}"
