#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../vendor/std/src/crypto/sha256/sum.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vendor/std/src/log/error.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vendor/std/src/log/info.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../vendor/std/src/http/download.sh"
source "$(dirname "${BASH_SOURCE[0]}")/git/fetch.sh"
source "$(dirname "${BASH_SOURCE[0]}")/git/sum.sh"
source "$(dirname "${BASH_SOURCE[0]}")/git/latest_tag.sh"

function require::file() {
    local file="${1}"
    local url="${2}"
    local checksum="${3:-}"
    http::download "${file}" "${url}"
    if [[ "${checksum}" == "" ]]; then
        checksum=$(crypto::sha256::sum "${file}")
        if [[ "${checksum}" == "" ]]; then
            log::error "Fail get sha256 of ${file}"
            return 1
        fi

        sed "s| ${file} ${url}$| ${file} ${url} ${checksum}|" "${modfile}" > "${modfile}.tmp"
        mv "${modfile}.tmp" "${modfile}"
    fi

    if [[ "${checksum}" != "$(crypto::sha256::sum "${file}")" ]]; then
        log::error "File ${file} downloaded but its checksum is incorrect (expected ${checksum}, got $(crypto::sha256::sum "${file}"))"
        return 1
    fi
}

function require::git() {
    local dir="${1}"
    local url="${2}"
    local tag="${3:-}"
    local checksum="${4:-}"

    git::fetch "${dir}" "${url}" "${tag}"

    if [[ "${tag}" == "" ]]; then
        tag=$(git::latest_tag "${dir}")
        if [[ "${tag}" == "" ]]; then
            log::error "Fail get tag of ${dir}"
            return 1
        fi
        git::fetch "${dir}" "${url}" "${tag}"
        sed "s| ${dir} ${url}$| ${dir} ${url} ${tag}|" "${modfile}" > "${modfile}.tmp"
        mv "${modfile}.tmp" "${modfile}"
    fi

    if [[ "${checksum}" == "" ]]; then
        checksum=$(git::sum "${dir}")
        if [[ "${checksum}" == "" ]]; then
            log::error "Fail get hash of ${dir}"
            return 1
        fi
        sed "s| ${dir} ${url} ${tag}$| ${dir} ${url} ${tag} ${checksum}|" "${modfile}" > "${modfile}.tmp"
        mv "${modfile}.tmp" "${modfile}"
    fi

    if [[ "${checksum}" != "$(git::sum "${dir}")" ]]; then
        log::error "Git repo ${dir} downloaded but its checksum is incorrect (expected ${checksum}, got $(git::sum "${dir}"))"
        return 1
    fi
}

function require() {
    local modfile="${1}"
    local dir
    modfile="$(realpath "${modfile}")"
    dir="$(dirname "${modfile}")"
    cd "${dir}"
    IFS=$'\n'
    for line in $(cat "${modfile}"); do
        unset IFS
        read -r -a line <<< "${line}"
        IFS=$'\n'
        if [[ "${line[0]}" == "require::file" ]]; then
            require::file "${line[1]}" "${line[2]}" "${line[3]}"
        elif [[ "${line[0]}" == "require::git" ]]; then
            require::git "${line[1]}" "${line[2]}" "${line[3]}" "${line[4]}"
        elif [[ "${line[0]}" =~ ^# ]]; then
            : # comment ignore
        else
            log::error "Unknown require type ${line[0]}"
        fi
    done
    unset IFS
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    modfile="${1}"
    require "${modfile}"
fi
