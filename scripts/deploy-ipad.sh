#!/usr/bin/env bash

# Build, install, and launch Hozon on one connected physical iPad.
# This script is safe to run from an SSH session on the Mac that has Xcode and
# the paired iPad available.
set -euo pipefail

readonly SCHEME="Hozon"

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: ./scripts/deploy-ipad.sh [--device <identifier-or-name>] [--no-launch]

Builds the Hozon Debug scheme for a connected physical iPad, installs the
result, and launches its configured bundle identifier. Run it from the repository or over SSH
on the Mac paired with the iPad.

Options:
  --device <identifier-or-name>  Select one exact physical iPad by its
                                 devicectl identifier, UDID, or name.
  --no-launch                    Install the app but do not launch it.
  -h, --help                     Show this help.

Without --device, the script continues only when exactly one paired, booted,
physical iPad is available. It never selects a simulator or Mac.
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

signing_help() {
    cat >&2 <<'EOF'

Signing/provisioning prerequisite:
  1. Sign in to Xcode with the Apple Developer account for this project.
  2. In Certificates, Identifiers & Profiles, enable the App Group
     group.benekuehn.Hozon for both benekuehn.Hozon and
     benekuehn.Hozon.ActionExtension.
  3. Let Xcode's automatic signing create or refresh the development profiles,
     then rerun this script.
EOF
}

device_selector=""
should_launch=true

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --device)
            [ "$#" -ge 2 ] || die "--device requires an identifier or name."
            device_selector="$2"
            shift 2
            ;;
        --no-launch)
            should_launch=false
            shift
            ;;
        --)
            shift
            [ "$#" -eq 0 ] || die "Unexpected positional arguments: $*"
            ;;
        *)
            if [ -z "$device_selector" ]; then
                device_selector="$1"
                shift
            else
                die "Unexpected argument: $1"
            fi
            ;;
    esac
done

command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild is unavailable. Install or select Xcode first."
command -v xcrun >/dev/null 2>&1 || die "xcrun is unavailable. Install or select Xcode first."
command -v plutil >/dev/null 2>&1 || die "plutil is unavailable. It is required for device discovery."
xcrun devicectl list devices --help >/dev/null 2>&1 || die "This Xcode does not provide xcrun devicectl."

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hozon-device-deploy.XXXXXX")" || die "Could not create temporary build directory."
cleanup() {
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"
}
trap cleanup EXIT HUP INT TERM

device_info_json="$temp_dir/device-info.json"
build_log="$temp_dir/build.log"
derived_data="$temp_dir/DerivedData"

# Restrict discovery to paired, booted, physical iPads. `devicectl` reports
# these attributes for connected devices; this deliberately excludes Macs and
# all simulator destinations.
readonly IPAD_FILTER="properties.hardware.deviceType = 'iPad' AND properties.hardware.reality = 'physical' AND properties.connection.pairingState = 'paired' AND properties.state.bootState = 'booted'"

list_candidate_identifiers() {
    xcrun devicectl list devices \
        --filter "$IPAD_FILTER" \
        --columns Identifier \
        --hide-default-columns \
        --hide-headers
}

read_device_details() {
    local selector="$1"

    xcrun devicectl device info details \
        --device "$selector" \
        --json-output "$device_info_json" \
        >/dev/null

    device_name="$(plutil -extract result.properties.state.name raw "$device_info_json")"
    device_udid="$(plutil -extract result.properties.hardware.udid raw "$device_info_json")"
    device_type="$(plutil -extract result.properties.hardware.deviceType raw "$device_info_json")"
    device_reality="$(plutil -extract result.properties.hardware.reality raw "$device_info_json")"
}

candidate_identifiers="$(list_candidate_identifiers)" || die "Could not discover connected devices with devicectl."

if [ -n "$device_selector" ]; then
    # --search may return partial matches, so verify every candidate below with
    # exact equality against its name and identifiers before choosing one.
    candidate_identifiers="$(xcrun devicectl list devices \
        --filter "$IPAD_FILTER" \
        --search "$device_selector" \
        --columns Identifier \
        --hide-default-columns \
        --hide-headers)" || die "Could not look up device '$device_selector'."

    matching_identifiers=""
    for candidate in $candidate_identifiers; do
        read_device_details "$candidate" || continue
        if [ "$device_selector" = "$candidate" ] || \
           [ "$device_selector" = "$device_udid" ] || \
           [ "$device_selector" = "$device_name" ]; then
            matching_identifiers="${matching_identifiers:+$matching_identifiers }$candidate"
        fi
    done

    match_count=0
    for candidate in $matching_identifiers; do
        match_count=$((match_count + 1))
    done

    case "$match_count" in
        1) device_identifier="$matching_identifiers" ;;
        0) die "No paired, booted physical iPad exactly matches '$device_selector'." ;;
        *) die "More than one physical iPad exactly matches '$device_selector'; use its identifier or UDID." ;;
    esac
else
    candidate_count=0
    for candidate in $candidate_identifiers; do
        candidate_count=$((candidate_count + 1))
    done

    case "$candidate_count" in
        1) device_identifier="$candidate_identifiers" ;;
        0) die "No paired, booted physical iPad is available. Connect and unlock one, then try again." ;;
        *)
            printf 'Available physical iPads:\n' >&2
            xcrun devicectl list devices --filter "$IPAD_FILTER" >&2
            die "More than one physical iPad is available; rerun with --device <identifier-or-name>."
            ;;
    esac
fi

read_device_details "$device_identifier" || die "Could not read the selected iPad's details."
[ "$device_type" = "iPad" ] && [ "$device_reality" = "physical" ] || die "The selected device is not a physical iPad."

printf 'Deploying to %s…\n' "$device_name"

if ! xcodebuild \
    -project "$repo_root/Hozon.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS,id=$device_udid" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    -derivedDataPath "$derived_data" \
    build 2>&1 | tee "$build_log"; then
    if grep -Eqi 'No Accounts|Provisioning profile|No profiles for|application-groups|App Groups|code signing' "$build_log"; then
        signing_help
    fi
    die "Build failed. See the Xcode output above."
fi

app_path="$(find "$derived_data/Build/Products" -type d -name 'Hozon.app' -path '*Debug-iphoneos*' -print | head -n 1)"
[ -n "$app_path" ] && [ -d "$app_path" ] || die "Build succeeded but Hozon.app was not found in DerivedData."
bundle_identifier="$(plutil -extract CFBundleIdentifier raw "$app_path/Info.plist")" || die "Could not read the built app's bundle identifier."

printf 'Installing Hozon…\n'
xcrun devicectl device install app --device "$device_udid" "$app_path"

if [ "$should_launch" = true ]; then
    printf 'Launching Hozon…\n'
    xcrun devicectl device process launch \
        --device "$device_udid" \
        --terminate-existing \
        "$bundle_identifier"
fi

printf 'Deployment complete for %s.\n' "$device_name"
