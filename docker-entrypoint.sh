#!/usr/bin/env bash
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
    export "$primary_var"
}

apply_template_substitution() {
    local token="$1"
    local value="$2"
    local escaped_value

    escaped_value="$(printf '%s' "$value" | sed -e 's/[\/&\\]/\\&/g')"
    sed -i -e "s/${token}/${escaped_value}/g" "$CONFIG_OUTPUT_PATH"
}

resolve_env_var FRONTEND_BIND_IP "" "127.0.0.1"
resolve_env_var FRONTEND_PORT "" "4306"
resolve_env_var FRONTEND_PUBLIC_ADDRESS "" "127.0.0.1"

resolve_env_var WEBFRONTEND_ADDRESS AUTH_ADDRESS "localhost"
resolve_env_var WEBFRONTEND_PORT AUTH_PORT "8080"
resolve_env_var WEBFRONTEND_ENABLE_LOGIN_RATE_LIMIT WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT "false"
WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT="$WEBFRONTEND_ENABLE_LOGIN_RATE_LIMIT"
export WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT

resolve_env_var PLAYERMANAGER_USE_JSON_DB_MANAGER USE_JSON_DB_MANAGER "false"
resolve_env_var PLAYERMANAGER_NEWS_URL NEWS_URL "http://localhost/news"

resolve_env_var DBMANAGER_MAX_BACKUP_NUMBER MAX_BACKUP_NUMBER "5"
resolve_env_var DBMANAGER_BACKUP_INTERVAL_MINUTES BACKUP_INTERVAL_MINUTES "15"
resolve_env_var MAX_BACKUP_NUMBER DBMANAGER_MAX_BACKUP_NUMBER "$DBMANAGER_MAX_BACKUP_NUMBER"
resolve_env_var BACKUP_INTERVAL_MINUTES DBMANAGER_BACKUP_INTERVAL_MINUTES "$DBMANAGER_BACKUP_INTERVAL_MINUTES"

resolve_env_var GAMEDATA_LOAD_ALL_PROTOTYPES LOAD_ALL_PROTOTYPES "false"
resolve_env_var GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE USE_EQUIPMENT_SLOT_TABLE_CACHE "false"

resolve_env_var CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS AUTO_UNLOCK_AVATARS "true"
resolve_env_var CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS AUTO_UNLOCK_TEAMUPS "true"
resolve_env_var CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS ALLOW_SAME_GROUP_TALENTS "false"
resolve_env_var CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT DISABLE_INSTANCED_LOOT "false"
resolve_env_var CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING DISABLE_ACCOUNT_BINDING "false"
resolve_env_var CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING DISABLE_CHARACTER_BINDING "true"
resolve_env_var CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE USE_PRESTIGE_LOOT_TABLE "false"
resolve_env_var CUSTOMGAMEOPTIONS_APPLY_HIDDEN_PVP_DAMAGE_MODIFIERS "" "false"

resolve_env_var MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS "10000"
resolve_env_var MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO ES_TO_GAZILLIONITE_CONVERSION_RATIO "2.25"
resolve_env_var MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_STEP "" "4"
resolve_env_var MTXSTORE_GIFTING_OMEGA_LEVEL_REQUIRED "" "0"
resolve_env_var MTXSTORE_GIFTING_INFINITY_LEVEL_REQUIRED "" "0"
resolve_env_var MTXSTORE_HOME_PAGE_URL STORE_HOME_PAGE_URL "http://localhost/store"
resolve_env_var MTXSTORE_HOME_BANNER_PAGE_URL STORE_HOME_BANNER_PAGE_URL "http://localhost/store/images/banner.png"
resolve_env_var MTXSTORE_HEROES_BANNER_PAGE_URL STORE_HEROES_BANNER_PAGE_URL "http://localhost/store/images/banner.png"
resolve_env_var MTXSTORE_COSTUMES_BANNER_PAGE_URL STORE_COSTUMES_BANNER_PAGE_URL "http://localhost/store/images/banner.png"
resolve_env_var MTXSTORE_BOOSTS_BANNER_PAGE_URL STORE_BOOSTS_BANNER_PAGE_URL "http://localhost/store/images/banner.png"
resolve_env_var MTXSTORE_CHESTS_BANNER_PAGE_URL STORE_CHESTS_BANNER_PAGE_URL "http://localhost/store/images/banner.png"
resolve_env_var MTXSTORE_SPECIALS_BANNER_PAGE_URL STORE_SPECIALS_BANNER_PAGE_URL "http://localhost/store/images/banner.png"
resolve_env_var MTXSTORE_REAL_MONEY_URL STORE_REAL_MONEY_URL "https://localhost/MTXStore/AddG"
resolve_env_var MTXSTORE_REWRITE_ORIGINAL_BUNDLE_URLS "" "true"
resolve_env_var MTXSTORE_BUNDLE_INFO_URL "" "http://localhost/bundles/"
resolve_env_var MTXSTORE_BUNDLE_IMAGE_URL "" "http://localhost/bundles/images/"

populate_template() {
    apply_template_substitution "%%FRONTEND_BIND_IP%%" "$FRONTEND_BIND_IP"
    apply_template_substitution "%%FRONTEND_PORT%%" "$FRONTEND_PORT"
    apply_template_substitution "%%FRONTEND_PUBLIC_ADDRESS%%" "$FRONTEND_PUBLIC_ADDRESS"
    apply_template_substitution "%%WEBFRONTEND_ADDRESS%%" "$WEBFRONTEND_ADDRESS"
    apply_template_substitution "%%WEBFRONTEND_PORT%%" "$WEBFRONTEND_PORT"
    apply_template_substitution "%%WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT%%" "$WEBFRONTEND_ENABLE_LOGING_RATE_LIMIT"
    apply_template_substitution "%%PLAYERMANAGER_USE_JSON_DB_MANAGER%%" "$PLAYERMANAGER_USE_JSON_DB_MANAGER"
    apply_template_substitution "%%PLAYERMANAGER_NEWS_URL%%" "$PLAYERMANAGER_NEWS_URL"
    apply_template_substitution "%%DBMANAGER_MAX_BACKUP_NUMBER%%" "$DBMANAGER_MAX_BACKUP_NUMBER"
    apply_template_substitution "%%DBMANAGER_BACKUP_INTERVAL_MINUTES%%" "$DBMANAGER_BACKUP_INTERVAL_MINUTES"
    apply_template_substitution "%%MAX_BACKUP_NUMBER%%" "$MAX_BACKUP_NUMBER"
    apply_template_substitution "%%BACKUP_INTERVAL_MINUTES%%" "$BACKUP_INTERVAL_MINUTES"
    apply_template_substitution "%%GAMEDATA_LOAD_ALL_PROTOTYPES%%" "$GAMEDATA_LOAD_ALL_PROTOTYPES"
    apply_template_substitution "%%GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE%%" "$GAMEDATA_USE_EQUIPMENT_SLOT_TABLE_CACHE"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS%%" "$CUSTOMGAMEOPTIONS_AUTO_UNLOCK_AVATARS"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS%%" "$CUSTOMGAMEOPTIONS_AUTO_UNLOCK_TEAMUPS"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS%%" "$CUSTOMGAMEOPTIONS_ALLOW_SAME_GROUP_TALENTS"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT%%" "$CUSTOMGAMEOPTIONS_DISABLE_INSTANCED_LOOT"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING%%" "$CUSTOMGAMEOPTIONS_DISABLE_ACCOUNT_BINDING"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING%%" "$CUSTOMGAMEOPTIONS_DISABLE_CHARACTER_BINDING"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE%%" "$CUSTOMGAMEOPTIONS_USE_PRESTIGE_LOOT_TABLE"
    apply_template_substitution "%%CUSTOMGAMEOPTIONS_APPLY_HIDDEN_PVP_DAMAGE_MODIFIERS%%" "$CUSTOMGAMEOPTIONS_APPLY_HIDDEN_PVP_DAMAGE_MODIFIERS"
    apply_template_substitution "%%MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS%%" "$MTXSTORE_GAZILLIONITE_BALANCE_FOR_NEW_ACCOUNTS"
    apply_template_substitution "%%MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO%%" "$MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_RATIO"
    apply_template_substitution "%%MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_STEP%%" "$MTXSTORE_ES_TO_GAZILLIONITE_CONVERSION_STEP"
    apply_template_substitution "%%MTXSTORE_GIFTING_OMEGA_LEVEL_REQUIRED%%" "$MTXSTORE_GIFTING_OMEGA_LEVEL_REQUIRED"
    apply_template_substitution "%%MTXSTORE_GIFTING_INFINITY_LEVEL_REQUIRED%%" "$MTXSTORE_GIFTING_INFINITY_LEVEL_REQUIRED"
    apply_template_substitution "%%MTXSTORE_HOME_PAGE_URL%%" "$MTXSTORE_HOME_PAGE_URL"
    apply_template_substitution "%%MTXSTORE_HOME_BANNER_PAGE_URL%%" "$MTXSTORE_HOME_BANNER_PAGE_URL"
    apply_template_substitution "%%MTXSTORE_HEROES_BANNER_PAGE_URL%%" "$MTXSTORE_HEROES_BANNER_PAGE_URL"
    apply_template_substitution "%%MTXSTORE_COSTUMES_BANNER_PAGE_URL%%" "$MTXSTORE_COSTUMES_BANNER_PAGE_URL"
    apply_template_substitution "%%MTXSTORE_BOOSTS_BANNER_PAGE_URL%%" "$MTXSTORE_BOOSTS_BANNER_PAGE_URL"
    apply_template_substitution "%%MTXSTORE_CHESTS_BANNER_PAGE_URL%%" "$MTXSTORE_CHESTS_BANNER_PAGE_URL"
    apply_template_substitution "%%MTXSTORE_SPECIALS_BANNER_PAGE_URL%%" "$MTXSTORE_SPECIALS_BANNER_PAGE_URL"
    apply_template_substitution "%%MTXSTORE_REAL_MONEY_URL%%" "$MTXSTORE_REAL_MONEY_URL"
    apply_template_substitution "%%MTXSTORE_REWRITE_ORIGINAL_BUNDLE_URLS%%" "$MTXSTORE_REWRITE_ORIGINAL_BUNDLE_URLS"
    apply_template_substitution "%%MTXSTORE_BUNDLE_INFO_URL%%" "$MTXSTORE_BUNDLE_INFO_URL"
    apply_template_substitution "%%MTXSTORE_BUNDLE_IMAGE_URL%%" "$MTXSTORE_BUNDLE_IMAGE_URL"
}

cp "$CONFIG_TEMPLATE_PATH" "$CONFIG_OUTPUT_PATH"
populate_template

if grep -qE "%%[A-Z0-9_]+%%" "$CONFIG_OUTPUT_PATH"; then
    echo "Error: unresolved Config.ini template placeholders detected" >&2
    exit 1
fi

exec "$@"
