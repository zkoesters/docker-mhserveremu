#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: build-sqlinterop.sh [--help]

Build SQLite.Interop.dll from pinned System.Data.SQLite source.

Required environment variables:
  SQLITE_INTEROP_VERSION            Version, e.g. 1.0.118.0
  SQLITE_SOURCE_ARCHIVE_SHA256      SHA256 for source archive

Optional environment variables:
  SQLITE_SOURCE_BASE_URL            Default: https://system.data.sqlite.org/blobs
  SQLITE_SOURCE_ARCHIVE_NAME        Default: sqlite-netFx-source-${SQLITE_INTEROP_VERSION}.zip
  WORK_DIR                          Default: /tmp/sqlinterop-build
  ALLOW_NON_TMP_WORKDIR             Set to 1 to allow WORK_DIR outside /tmp
  OUTPUT_DIR                        Default: /out
  KEEP_WORKDIR                      Set to 1 to preserve work dir on exit
  VERBOSE                           Set to 1 for verbose logs
  STRIP_OUTPUT                      Set to 0 to skip strip attempt
EOF
}

log() {
    printf '%s\n' "$*"
}

debug() {
    if [ "${VERBOSE:-0}" = "1" ]; then
        log "[debug] $*"
    fi
}

die() {
    log "[error] $*" >&2
    exit 1
}

validate_sha256_input() {
    local value="$1"

    if [[ ! "$value" =~ ^[A-Fa-f0-9]{64}$ ]]; then
        die "SQLITE_SOURCE_ARCHIVE_SHA256 must be a 64-character hex string"
    fi
}

validate_work_dir() {
    local dir="$1"
    local allow_non_tmp_workdir="${ALLOW_NON_TMP_WORKDIR:-0}"

    [ -n "$dir" ] || die "WORK_DIR must not be empty"
    [ "$dir" != "/" ] || die "Refusing to use WORK_DIR='/'"

    case "$dir" in
        /*) ;;
        *) die "WORK_DIR must be an absolute path" ;;
    esac

    if [ "$allow_non_tmp_workdir" != "1" ]; then
        case "$dir" in
            /tmp/*) ;;
            /tmp) die "Refusing to use WORK_DIR='/tmp'; use a dedicated subdirectory" ;;
            *) die "WORK_DIR must be under /tmp (set ALLOW_NON_TMP_WORKDIR=1 to override)" ;;
        esac
    fi
}

CLEANUP_WORK_DIR=""
CLEANUP_KEEP_WORKDIR="0"

cleanup() {
    if [ "${CLEANUP_KEEP_WORKDIR}" = "1" ]; then
        debug "Preserving work directory: ${CLEANUP_WORK_DIR}"
        return
    fi

    if [ -n "${CLEANUP_WORK_DIR}" ]; then
        rm -rf "${CLEANUP_WORK_DIR}"
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

verify_sha256() {
    local expected="$1"
    local file_path="$2"

    validate_sha256_input "$expected"

    if command -v sha256sum >/dev/null 2>&1; then
        if ! printf '%s  %s\n' "$expected" "$file_path" | sha256sum -c - >/dev/null 2>&1; then
            die "SHA256 mismatch for $file_path"
        fi
        return
    fi

    if command -v shasum >/dev/null 2>&1; then
        local actual
        actual="$(shasum -a 256 "$file_path" | cut -d ' ' -f 1)"
        [ "$actual" = "$expected" ] || die "SHA256 mismatch: expected $expected, got $actual"
        return
    fi

    die "No SHA256 tool available (sha256sum or shasum required)"
}

verify_output_architecture() {
    local target_arch="$1"
    local dll_path="$2"
    local expected_token=""
    local details=""

    [ -n "$target_arch" ] || return

    case "$target_arch" in
        amd64) expected_token="x86-64" ;;
        arm64) expected_token="aarch64" ;;
        *) die "Unsupported TARGETARCH for verification: $target_arch" ;;
    esac

    command -v objdump >/dev/null 2>&1 || die "objdump is required for architecture verification"

    details="$(objdump -f "$dll_path" 2>/dev/null || true)"
    printf '%s\n' "$details" | grep -qi "$expected_token" || {
        die "Unexpected SQLite.Interop.dll architecture for TARGETARCH=$target_arch"
    }
}

resolve_extracted_root() {
    local extract_root="$1"
    local compile_script_rel="Setup/compile-interop-assembly-release.sh"
    local first_dir=""
    local d=""
    local candidate=""

    if [ -f "${extract_root}/${compile_script_rel}" ]; then
        printf '%s\n' "$extract_root"
        return
    fi

    for d in "$extract_root"/*; do
        if [ -f "${d}/${compile_script_rel}" ]; then
            printf '%s\n' "$d"
            return
        fi
    done

    for d in "$extract_root"/*; do
        [ -d "$d" ] || continue
        for candidate in "$d"/*; do
            [ -d "$candidate" ] || continue
            if [ -f "${candidate}/${compile_script_rel}" ]; then
                printf '%s\n' "$candidate"
                return
            fi
        done
    done

    for d in "$extract_root"/*; do
        [ -d "$d" ] || continue
        first_dir="$d"
        break
    done

    [ -n "$first_dir" ] || die "Could not find extracted source directory under $extract_root"
    die "Could not locate ${compile_script_rel}; first extracted directory was ${first_dir}"
}

main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        usage
        return 0
    fi

    [ "$#" -eq 0 ] || die "Unknown argument: $1"

    : "${SQLITE_INTEROP_VERSION:?SQLITE_INTEROP_VERSION must be set}"
    : "${SQLITE_SOURCE_ARCHIVE_SHA256:?SQLITE_SOURCE_ARCHIVE_SHA256 must be set}"

    local base_url="${SQLITE_SOURCE_BASE_URL:-https://system.data.sqlite.org/blobs}"
    local archive_name="${SQLITE_SOURCE_ARCHIVE_NAME:-sqlite-netFx-source-${SQLITE_INTEROP_VERSION}.zip}"
    local work_dir="${WORK_DIR:-/tmp/sqlinterop-build}"
    local output_dir="${OUTPUT_DIR:-/out}"
    local keep_workdir="${KEEP_WORKDIR:-0}"
    local strip_output="${STRIP_OUTPUT:-1}"

    local archive_url="${base_url}/${SQLITE_INTEROP_VERSION}/${archive_name}"
    local archive_path="${work_dir}/${archive_name}"
    local extract_root="${work_dir}/src"
    local extracted_root
    local compile_script
    local dll_path=""

    require_command curl
    require_command unzip
    require_command chmod

    validate_work_dir "$work_dir"

    rm -rf "$work_dir"
    mkdir -p "$work_dir" "$output_dir" "$extract_root"

    CLEANUP_WORK_DIR="$work_dir"
    CLEANUP_KEEP_WORKDIR="$keep_workdir"
    trap cleanup EXIT

    log "Downloading source archive: $archive_url"
    curl \
        --fail \
        --location \
        --proto '=https' \
        --tlsv1.2 \
        --silent \
        --show-error \
        --output "$archive_path" \
        "$archive_url" || die "Failed to download source archive: $archive_url"

    log "Verifying archive checksum"
    verify_sha256 "$SQLITE_SOURCE_ARCHIVE_SHA256" "$archive_path"

    log "Extracting source archive"
    unzip -q "$archive_path" -d "$extract_root"

    extracted_root="$(resolve_extracted_root "$extract_root")"
    compile_script="${extracted_root}/Setup/compile-interop-assembly-release.sh"

    [ -f "$compile_script" ] || die "Compile script not found at $compile_script"
    chmod +x "$compile_script"

    log "Compiling SQLite.Interop.dll"
    (
        cd "${extracted_root}/Setup"
        ./compile-interop-assembly-release.sh
    )

    if [ -s "${extracted_root}/bin/2013/Release/bin/SQLite.Interop.dll" ]; then
        dll_path="${extracted_root}/bin/2013/Release/bin/SQLite.Interop.dll"
    else
        for candidate in "${extracted_root}"/bin/*/Release/bin/SQLite.Interop.dll; do
            [ -s "$candidate" ] || continue
            dll_path="$candidate"
            break
        done
    fi

    [ -n "$dll_path" ] || die "SQLite.Interop.dll was not produced"

    if [ "$strip_output" = "1" ] && command -v strip >/dev/null 2>&1; then
        debug "Attempting to strip output binary"
        strip "$dll_path" >/dev/null 2>&1 || true
    fi

    cp "$dll_path" "${output_dir}/SQLite.Interop.dll"
    [ -s "${output_dir}/SQLite.Interop.dll" ] || die "Output DLL is missing or empty"

    verify_output_architecture "${TARGETARCH:-}" "${output_dir}/SQLite.Interop.dll"

    log "Build successful"
    log "Output: ${output_dir}/SQLite.Interop.dll"
}

main "$@"
