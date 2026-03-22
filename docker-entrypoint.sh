#!/usr/bin/env bash
# docker-entrypoint.sh — Generate Config.ini from template and environment variables.
#
# This script resolves environment variables (with optional legacy alias fallback),
# substitutes %%PLACEHOLDER%% tokens in Config.ini.template, validates that no
# unresolved placeholders remain, and then exec's the CMD.

set -Eeo pipefail

CONFIG_TEMPLATE_PATH="/usr/share/mhserveremu/Config.ini.template"
CONFIG_OUTPUT_PATH="/usr/share/mhserveremu/Config.ini"

resolve_env_var() {
    local primary_var="$1"
    local legacy_var="$2"
    local default_value="$3"
    local resolved_value="${!primary_var:-}"

    if [ -z "$resolved_value" ] && [ -n "$legacy_var" ]; then
        resolved_value="${!legacy_var:-}"
    fi
    if [ -z "$resolved_value" ]; then
        resolved_value="$default_value"
    fi

    printf -v "$primary_var" "%s" "$resolved_value"
    # shellcheck disable=SC2163  # Intentional: exports the variable named by $primary_var
    export "$primary_var"
}

apply_template_substitution() {
    local token="$1"
    local value="$2"
    local escaped_value

    # In awk gsub() replacement text, '&' expands to the matched text and
    # backslashes are escape characters. Escape both so values are substituted
    # literally.
    escaped_value="${value//\\/\\\\}"
    escaped_value="${escaped_value//&/\\&}"

    awk -v tok="$token" -v val="$escaped_value" '{ gsub(tok, val); print }' \
        "$CONFIG_OUTPUT_PATH" > "${CONFIG_OUTPUT_PATH}.tmp" \
        && mv "${CONFIG_OUTPUT_PATH}.tmp" "$CONFIG_OUTPUT_PATH"
}

# ── Variable definition table ──────────────────────────────────────────────
# Format: PRIMARY_VAR|LEGACY_VAR|DEFAULT_VALUE
#
# To add a new environment variable, add a single line to this table.
# The variable will be automatically resolved and substituted into
# %%PRIMARY_VAR%% in the Config.ini template.

ENV_VARS="
FRONTEND_BIND_IP||127.0.0.1
FRONTEND_PORT||4306
FRONTEND_PUBLIC_ADDRESS||127.0.0.1
WEBFRONTEND_ADDRESS|AUTH_ADDRESS|localhost
WEBFRONTEND_PORT|AUTH_PORT|8080
WEBFRONTEND_ENABLE_LOGIN_RATE_LIMIT|WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT|false
PLAYERMANAGER_USE_JSON_DB_MANAGER|USE_JSON_DB_MANAGER|false
PLAYERMANAGER_NEWS_URL|NEWS_URL|http://localhost/news
DBMANAGER_MAX_BACKUP_NUMBER|MAX_BACKUP_NUMBER|5
DBMANAGER_BACKUP_INTERVAL_MINUTES|BACKUP_INTERVAL_MINUTES|15
GAMEDATA_LOAD_ALL_PROTOTYPES|LOAD_ALL_PROTOTYPES|false
GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE|USE_EQUIPMENT_SLOT_TABLE_CACHE|false
CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS|AUTO_UNLOCK_AVATARS|true
CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS|AUTO_UNLOCK_TEAMUPS|true
CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS|ALLOW_SAME_GROUP_TALENTS|false
CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT|DISABLE_INSTANCED_LOOT|false
CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING|DISABLE_ACCOUNT_BINDING|false
CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING|DISABLE_CHARACTER_BINDING|true
CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE|USE_PRESTIGE_LOOT_TABLE|false
CUSTOMGAMEOPTIONS_APPLY_HIDDEN_PVP_DAMAGE_MODIFIERS||false
MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS|GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS|10000
MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO|ES_TO_GAZILLIONITE_CONVERSION_RATIO|2.25
MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_STEP||4
MTXSTORE_GIFTING_OMEGA_LEVEL_REQUIRED||0
MTXSTORE_GIFTING_INFINITY_LEVEL_REQUIRED||0
MTXSTORE_HOME_PAGE_URL|STORE_HOME_PAGE_URL|http://localhost/store
MTXSTORE_HOME_BANNER_PAGE_URL|STORE_HOME_BANNER_PAGE_URL|http://localhost/store/images/banner.png
MTXSTORE_HEROES_BANNER_PAGE_URL|STORE_HEROES_BANNER_PAGE_URL|http://localhost/store/images/banner.png
MTXSTORE_COSTUMES_BANNER_PAGE_URL|STORE_COSTUMES_BANNER_PAGE_URL|http://localhost/store/images/banner.png
MTXSTORE_BOOSTS_BANNER_PAGE_URL|STORE_BOOSTS_BANNER_PAGE_URL|http://localhost/store/images/banner.png
MTXSTORE_CHESTS_BANNER_PAGE_URL|STORE_CHESTS_BANNER_PAGE_URL|http://localhost/store/images/banner.png
MTXSTORE_SPECIALS_BANNER_PAGE_URL|STORE_SPECIALS_BANNER_PAGE_URL|http://localhost/store/images/banner.png
MTXSTORE_REAL_MONEY_URL|STORE_REAL_MONEY_URL|https://localhost/MTXStore/AddG
MTXSTORE_REWRITE_ORIGINAL_BUNDLE_URLS||true
MTXSTORE_BUNDLE_INFO_URL||http://localhost/bundles/
MTXSTORE_BUNDLE_IMAGE_URL||http://localhost/bundles/images/
"

# ── Backward-compatible legacy aliases ─────────────────────────────────────
# These re-export resolved values under legacy names so that users who read
# the legacy variable in their own scripts still see the correct value.
# They also substitute %%LEGACY_NAME%% tokens that appear in older templates.

LEGACY_REEXPORTS="
WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT|WEBFRONTEND_ENABLE_LOGIN_RATE_LIMIT
MAX_BACKUP_NUMBER|DBMANAGER_MAX_BACKUP_NUMBER
BACKUP_INTERVAL_MINUTES|DBMANAGER_BACKUP_INTERVAL_MINUTES
"

# ── Resolve all variables ──────────────────────────────────────────────────

while IFS='|' read -r primary legacy default; do
    [ -z "$primary" ] && continue
    resolve_env_var "$primary" "$legacy" "$default"
done <<< "$ENV_VARS"

while IFS='|' read -r alias_name source_name; do
    [ -z "$alias_name" ] && continue
    printf -v "$alias_name" "%s" "${!source_name}"
    # shellcheck disable=SC2163  # Intentional: exports the variable named by $alias_name
    export "$alias_name"
done <<< "$LEGACY_REEXPORTS"

# ── Validate environment variables ─────────────────────────────────────────
# Format: VAR_NAME|TYPE
# Supported types: port, bool, int, number, url

validate_env_var() {
    local name="$1"
    local type="$2"
    local value="${!name}"

    # Skip validation if the variable is empty (using its default is fine)
    [ -z "$value" ] && return 0

    case "$type" in
        port)
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
                echo "Error: $name must be a port number (1-65535), got: '$value'" >&2
                return 1
            fi
            ;;
        bool)
            if [[ "$value" != "true" && "$value" != "false" ]]; then
                echo "Error: $name must be 'true' or 'false', got: '$value'" >&2
                return 1
            fi
            ;;
        int)
            if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
                echo "Error: $name must be an integer, got: '$value'" >&2
                return 1
            fi
            ;;
        number)
            if ! [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
                echo "Error: $name must be a number, got: '$value'" >&2
                return 1
            fi
            ;;
        url)
            if ! [[ "$value" =~ ^https?:// ]]; then
                echo "Warning: $name doesn't look like a URL: '$value'" >&2
            fi
            ;;
    esac
}

VALIDATIONS="
FRONTEND_PORT|port
WEBFRONTEND_PORT|port
WEBFRONTEND_ENABLE_LOGIN_RATE_LIMIT|bool
PLAYERMANAGER_USE_JSON_DB_MANAGER|bool
DBMANAGER_MAX_BACKUP_NUMBER|int
DBMANAGER_BACKUP_INTERVAL_MINUTES|int
GAMEDATA_LOAD_ALL_PROTOTYPES|bool
GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE|bool
CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS|bool
CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS|bool
CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS|bool
CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT|bool
CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING|bool
CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING|bool
CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE|bool
CUSTOMGAMEOPTIONS_APPLY_HIDDEN_PVP_DAMAGE_MODIFIERS|bool
MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS|int
MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO|number
MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_STEP|int
MTXSTORE_GIFTING_OMEGA_LEVEL_REQUIRED|int
MTXSTORE_GIFTING_INFINITY_LEVEL_REQUIRED|int
MTXSTORE_REWRITE_ORIGINAL_BUNDLE_URLS|bool
"

validation_failed=0
while IFS='|' read -r var_name var_type; do
    [ -z "$var_name" ] && continue
    if ! validate_env_var "$var_name" "$var_type"; then
        validation_failed=1
    fi
done <<< "$VALIDATIONS"

if [ "$validation_failed" -eq 1 ]; then
    echo "Error: environment variable validation failed. Fix the values above." >&2
    exit 1
fi

# ── Generate Config.ini ────────────────────────────────────────────────────

cp "$CONFIG_TEMPLATE_PATH" "$CONFIG_OUTPUT_PATH"

while IFS='|' read -r primary _ _; do
    [ -z "$primary" ] && continue
    apply_template_substitution "%%${primary}%%" "${!primary}"
done <<< "$ENV_VARS"

# Also substitute legacy-named placeholders that appear in older templates
while IFS='|' read -r alias_name _; do
    [ -z "$alias_name" ] && continue
    apply_template_substitution "%%${alias_name}%%" "${!alias_name}"
done <<< "$LEGACY_REEXPORTS"

# ── Validate ───────────────────────────────────────────────────────────────

if grep -qE '%%[A-Z0-9_]+%%' "$CONFIG_OUTPUT_PATH"; then
    echo "Error: unresolved Config.ini template placeholders detected:" >&2
    grep -nE '%%[A-Z0-9_]+%%' "$CONFIG_OUTPUT_PATH" >&2
    exit 1
fi

exec "$@"
