#!/bin/sh

RED='\033[0;31m'
YELLOW='\033[0;33m'
CLEAR='\033[0m'

die() {
    printf "%b\n" "${RED}FATAL:${CLEAR} $1"
    printf "\n%b\n" "${RED}YOUR INSTALLATION MAY BE DIRTY.${CLEAR}"
    printf "%b\n" "please run ./iw4x-updoot -c to clean up the directory by removing all iw4x and iw4x-updoot files."
    printf "%b\n" "you may then run ./iw4x-updoot to install iw4x again."
    exit 1
}

info() {
    printf "%b\n" "${YELLOW}INFO:${CLEAR} $1"
    return 0
}

# dependency check
info "evaluating dependencies..."
for i in jq grep sed unzip sha256sum curl ; do
    command -v "$i" > /dev/null ||
        { info "script dependencies not met: ${i}" ; exit 1 ; }
done

metadata_file="${PWD}/iw4x-updoot/versions"
rawlist_file="${PWD}/iw4x-updoot/rawlist"
dlclist_file="${PWD}/iw4x-updoot/dlclist"

# TODO: this should probably have better verification but it's fine
[ ! -f "${PWD}/iw4mp.exe" ] &&
    { die "you find yourself in a strange land; are we sure this is the correct directory?" ; }

cleanup() {
    info "cleaning up..."
    if [ -f "${PWD}/iw4x.dll" ] ; then
        info "removing iw4x-client: ${PWD}/iw4x.dll..."
        rm "${PWD}/iw4x.dll" ||
            die "failed to remove iw4x-client."
    else
        info "iw4x-client: ${PWD}/iw4x.dll does not appear to exist."
    fi

    if [ -e "$PWD/release.zip" ] ; then
        info "removing iw4x-rawfiles archive: ${PWD}/release.zip..."
        rm "${PWD}/release.zip" ||
            die "failed to remove iw4x-rawfiles archive."
    else
        info "iw4x-rawfiles archive does not appear to exist."
    fi

    info "removing rawfiles..."
    if [ -f "$rawlist_file" ] ; then
        while read -r line; do
            # this shouldn't remove this entire directory, skip this entry
            [ "$line" = 'zone/' ] &&
                continue

            rm -Rf "$line" ||
                die "failed to remove rawfiles with rawfile: ${line}"
        done < "$rawlist_file"
    else
        info "rawlist_file: ${rawlist_file} does not exist, cannot clean up rawfiles."
    fi

    info "removing DLCs..."
    if [ -f "$dlclist_file" ] ; then
        while read -r line; do
            rm "$line" ||
                die "failed to remove DLCs with DLC: ${line}"
        done < "$dlclist_file"

        if [ -f "${PWD}/iw4x-updoot/dlcs.json" ]; then
            rm "${PWD}/iw4x-updoot/dlcs.json" ||
                die "failed to remove DLCs with DLC list file: ${PWD}/iw4x-updoot/dlcs.json"
        fi
    else
        info "dlclist_file: ${dlclist_file} does not exist, cannot clean up DLCs."
    fi

    if [ -d "${PWD}/iw4x-updoot" ] ; then
        info "removing iw4x-updoot directory: ${PWD}/iw4x-updoot..."
        rm -Rf "${PWD}/iw4x-updoot" ||
            die "removing iw4x-updoot directory: ${PWD}/iw4x-updoot has failed."
    else
        info "iw4x-updoot directory: ${PWD}/iw4x-updoot does not exist, cannot remove."
    fi

    exit 0
}

while getopts "cd" opts; do
    case "${opts}" in
        c) cleanup ;;
        d) install_dlc="true" ;;
        *) printf "%s\n" "unrecognized flag: ${OPTARG}" && exit 1 ;;
    esac
done

[ "$install_dlc" = 'true' ] && {
    if ! command -v b3sum > /dev/null ; then
        die "script dependencies not met: b3sum, cannot download DLCs"
    fi
}

[ -d "${PWD}/iw4x-updoot/temp" ] ||
    { mkdir -p "${PWD}/iw4x-updoot/temp" || die "failed to create iw4x-updoot directory" ; }

[ -f "$metadata_file" ] ||
    { touch "$metadata_file" || die "failed to create metadata file" ; }

[ -f "$dlclist_file" ] ||
    { touch "$dlclist_file" || die "failed to create dlclist file" ; }

# https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases-for-a-repository
gh() {
    curl --silent -L \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" "$1"
}

client_json=$(gh https://api.github.com/repos/iw4x/iw4x-client/releases/latest)
rawfiles_json=$(gh https://api.github.com/repos/iw4x/iw4x-rawfiles/releases/latest)

client_version=$(printf '%s' "$client_json" | jq -r '.name')
rawfiles_version=$(printf '%s' "$rawfiles_json" | jq -r '.name')

rawfiles_download() {
    rawfiles_url=$(printf '%s' "$rawfiles_json" | jq -r --compact-output '.assets[].browser_download_url | select(test("release.zip"))')
    if ! curl -# -L -o release.zip "$rawfiles_url" ; then
        die "failed to download iw4x-rawfiles: $rawfiles_url"
    else
        printf "\033[1A\033[2K"
    fi

    info "comparing iw4x-rawfiles checksums..."
    checksum=$(printf '%s' "$rawfiles_json" | jq -r '.assets[] | select(.browser_download_url | test ("release.zip")) .digest')
    checksum="${checksum#sha256:}" # removes sha256: from the beginning of the string
    local_checksum=$(sha256sum "${PWD}/release.zip")
    local_checksum="${local_checksum%% *}" # removes release.zip from the end of the string

    [ "$local_checksum" != "$checksum" ] &&
        die "iw4x-rawfiles checksum mismatch."

    unset checksum local_checksum rawfiles_url
}

client_download() {
    client_url=$(printf '%s' "$client_json" | jq -r --compact-output '.assets[].browser_download_url | select(test("iw4x.dll"))')
    if ! curl -# -L -o iw4x.dll "$client_url" ; then
        die "failed to download iw4x-client: $client_url"
    else
        printf "\033[1A\033[2K"
    fi

    info "comparing iw4x-client checksums..."
    checksum=$(printf '%s' "$client_json" | jq -r '.assets[] | select(.browser_download_url | test ("iw4x.dll")) .digest')
    checksum="${checksum#sha256:}"
    local_checksum=$(sha256sum "${PWD}/iw4x.dll")
    local_checksum="${local_checksum%% *}"

    [ "$local_checksum" != "$checksum" ] &&
        die "iw4x-client checksum mismatch."

    unset checksum local_checksum client_url
}

dlc_download() {
    for i in $(jq -r '.files[].path | select(test("\\.(iwd|ff)$"))' "${PWD}/iw4x-updoot/dlcs.json") ; do
        current_dlc_name="${i##*/}" # removes everything up until and including the last / in path to get individual file name

        case "$current_dlc_name" in
            *.iwd) dest="main/${current_dlc_name}" ;;
            *.ff) dest="zone/dlc/${current_dlc_name}" ;;
        esac

        info "downloading DLC: ${current_dlc_name}"
        if ! curl -# -L -o "${PWD}/${dest}" "https://cdn.iw4x.io/${i}" ; then
            die "downloading DLC archive: ${i} has failed"
        else
            printf "\033[2A\033[2K" # move up one line and remove it (gets rid of progress bar once it hits 100%)
        fi

        dlc_checksum=$(jq -r '.files[] | select(.asset_name == "'"$current_dlc_name"'") | .blake3' "${PWD}/iw4x-updoot/dlcs.json")
        local_dlc_checksum=$(b3sum "${PWD}/${dest}")
        local_dlc_checksum="${local_dlc_checksum%% *}" # remove space and filename from end of checksum output

        [ "$dlc_checksum" != "$local_dlc_checksum" ] &&
            die "${current_dlc_name} checksum mismatch."

        printf "%s\n" "$dest" >> "$dlclist_file"
    done

    unset current_dlc_name dlc_checksum local_dlc_checksum dest i
}

if ! grep "client_version:" "$metadata_file" > /dev/null ; then
    # if the client_version wasn't added to the metadata previously,
    # the client has probably never been installed; pull it:
    info "this appears to be a new installation, downloading client..."
    client_download
    info "client downloaded."

    info "writing client_version: ${client_version} to metadata file: ${metadata_file}..."
    printf "%s\n" "client_version: ${client_version}" >> "$metadata_file" ||
        die "failed to add client_version: ${client_version} to metadata file: ${metadata_file}."
else
    # check if client is outdated
    if grep "client_version: ${client_version}" "$metadata_file" > /dev/null ; then
        info "client_version: ${client_version}; iw4x-client is up to date."
    else
        # if client is outdated, update
        info "iw4x-client is outdated, updating..."

        # delete old client
        info "removing old client..."
        rm "${PWD}/iw4x.dll" ||
            die "failed to remove old client: ${PWD}/iw4x.dll"

        # pull new client
        client_download
        info "client updated."

        # remove old client version from metadata
        info "updating metadata file..."
        temp=$(sed '/client_version:/d' "$metadata_file") # i really wish posix sed had -i
        printf "%s\n" "$temp" > "$metadata_file" ||
            die "failed to remove old client_version from metadata file: ${metadata_file}"

        unset temp

        # add new client version to metadata
        printf "%s\n" "client_version: ${client_version}" >> "$metadata_file" ||
            die "failed to add new client_version: ${client_version} to metadata file: ${metadata_file}"
    fi
fi

if ! grep "rawfiles_version:" "$metadata_file" > /dev/null ; then
    info "this appears to be a new installation, downloading rawfiles..."
    rawfiles_download

    info "creating rawfiles list..."
    unzip -Z1 release.zip > "$rawlist_file" ||
        die "failed to write rawfiles list to rawlist_file: $rawlist_file"

    info "extracting rawfiles..."
    unzip -qq release.zip ||
        die "failed to extract rawfiles"

    info "writing rawfiles_version: ${rawfiles_version} to metadata file: ${metadata_file}..."
    printf "%s\n" "rawfiles_version: ${rawfiles_version}" >> "$metadata_file" ||
        die "failed to add rawfiles_version: ${rawfiles_version} to metadata file: ${metadata_file}"

    rm "${PWD}/release.zip"
else
    # check if rawfiles are outdated
    if grep "rawfiles_version: ${rawfiles_version}" "$metadata_file" > /dev/null ; then
        info "rawfiles_version: ${rawfiles_version}; iw4x-rawfiles are up to date."
    else
        info "iw4x-rawfiles are out of date, updating..."

        # the most simple and catch-all way to update this is to just wipe the old rawfiles and place the new ones
        # if rawfiles have been installed before, the contents should have been kept in
        # iw4x-updoot/rawlist, loop over the contents of that file and remove:
        info "removing old rawfiles..."
        while read -r line; do
            # this shouldn't remove this entire directory, skip this entry
            [ "$line" = 'zone/' ] &&
                continue

            rm -Rf "$line" ||
                die "failed to remove rawfiles with rawfile: ${line}"
        done < "$rawlist_file"

        info "removing old rawfiles archive..."
        rm "${PWD}/release.zip" ||
            die "failed to remove old rawfiles archive: ${PWD}/release.zip"

        info "downloading new rawfiles..."
        rawfiles_download

        info "updating rawfiles list..."
        unzip -Z1 release.zip > "$rawlist_file" ||
            die "failed to add new rawfiles list to rawlist_file: $rawlist_file"

        info "extracting rawfiles..."
        unzip -qq release.zip ||
            die "failed to extract rawfiles"

        info "updating metadata file..."
        # remove old ver from metadata
        temp=$(sed '/rawfiles_version:/d' "$metadata_file")
        printf "%s\n" "$temp" > "$metadata_file" ||
            die "failed to remove old rawfiles_version from metadata file: ${metadata_file}"

        unset temp

         # add new ver to metadata
        printf "%s\n" "rawfiles_version: ${rawfiles_version}" >> "$metadata_file" ||
            die "failed to add new rawfiles_version: ${rawfiles_version} to metadata file: ${metadata_file}"

        rm "${PWD}/release.zip"
    fi
fi

if ! grep 'dlc' "$metadata_file" > /dev/null && [ "$install_dlc" = "true" ] ; then
    # this json file has all of the dlc paths and checksums
    info "downloading DLC list from https://cdn.iw4x.io/update.json..."
    curl --silent -L -o "${PWD}/iw4x-updoot/dlcs.json" https://cdn.iw4x.io/update.json ||
        die "downloading dlcs.json has failed"

    info "downloading DLCs and comparing checksums..."
    dlc_download

    info "marking DLCs enabled in metadata file: ${metadata_file}"
    printf "%s\n" 'dlc' >> "$metadata_file" ||
        die "failed to write dlc to metadata file: ${metadata_file}"
elif [ "$install_dlc" = "true" ]; then
    curl --silent -L -o "${PWD}/iw4x-updoot/temp/dlcs.json" https://cdn.iw4x.io/update.json ||
        die "downloading dlcs.json has failed"

    current_dlclist_checksum=$(b3sum "${PWD}/iw4x-updoot/dlcs.json")
    current_dlclist_checksum="${current_dlclist_checksum%% *}"
    new_dlclist_checksum=$(b3sum "${PWD}/iw4x-updoot/temp/dlcs.json")
    new_dlclist_checksum="${new_dlclist_checksum%% *}"

    if [ "$current_dlclist_checksum" != "$new_dlclist_checksum" ] ; then
        info "iw4x DLCs outdated, updating..."
        while read -r line; do
            rm "$line" ||
                die "failed to remove DLCs with DLC: ${line}"
        done < "$dlclist_file"

        mv "${PWD}/iw4x-updoot/temp/dlcs.json" "${PWD}/iw4x-updoot/dlcs.json" ||
            die "failed to move new DLC list to iw4x-updoot"

        : > "$dlclist_file" # clear out file

        dlc_download
    else
        info "iw4x DLCs are up to date."
    fi
fi

info "done."
