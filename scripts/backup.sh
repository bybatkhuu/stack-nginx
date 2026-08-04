#!/usr/bin/env bash
set -euo pipefail


## --- Base --- ##
_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-"$0"}")" >/dev/null 2>&1 && pwd -P)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2


# shellcheck disable=SC1091
[ -f .env ] && . .env


if ! command -v tar >/dev/null 2>&1; then
	echo "[ERROR]: Not found 'tar' command, please install it first!" >&2
	exit 1
fi

if [ ! -f ./scripts/get-version.sh ]; then
	echo "[ERROR]: 'get-version.sh' script not found!" >&2
	exit 1
fi
## --- Base --- ##


## --- Variables --- ##
# Load from environment variables:
PROJECT_SLUG="${PROJECT_SLUG:-stack-nginx}"
BACKUPS_DIR="${BACKUPS_DIR:-./volumes/backups}"
## --- Variables --- ##


if [ ! -d "${BACKUPS_DIR}" ]; then
	mkdir -pv "${BACKUPS_DIR}" || exit 2
fi


## --- Main --- ##
main()
{
	echo "[INFO]: Checking current version..."
	local _current_version
	_current_version="$(./scripts/get-version.sh)"
	echo "[OK]: Current version: '${_current_version}'"

	local _backup_file_path
	_backup_file_path="${BACKUPS_DIR}/${PROJECT_SLUG}.v${_current_version}.$(date -u '+%y%m%d_%H%M%S').tar.gz"
	echo "[INFO]: Creating backup file: '${_backup_file_path}'..."
	tar -czpvf "${_backup_file_path}" -C ./volumes ./storage ./configs ./secrets || {
		sudo tar -czpvf "${_backup_file_path}" -C ./volumes ./storage ./configs ./secrets || exit 2
	}
	echo "[OK]: Done."
}

main
## --- Main --- ##
