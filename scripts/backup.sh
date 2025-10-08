#!/bin/bash
set -euo pipefail


## --- Base --- ##
# Getting path of this script file:
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2


# Loading .env file:
if [ -f ".env" ]; then
	# shellcheck disable=SC1091
	source .env
fi
## --- Base --- ##


## --- Variables --- ##
# Load from envrionment variables:
PROJECT_SLUG="${PROJECT_SLUG:-stack-nginx}"
BACKUPS_DIR="${BACKUPS_DIR:-./volumes/backups}"
## --- Variables --- ##


## --- Main --- ##
main()
{
	if [ ! -d "${BACKUPS_DIR}" ]; then
		mkdir -pv "${BACKUPS_DIR}" || exit 2
	fi

	echo "[INFO]: Checking current version..."
	local _current_version
	_current_version="$(./scripts/get-version.sh)"
	echo "[OK]: Current version: '${_current_version}'"

	local _backup_file_path
	_backup_file_path="${BACKUPS_DIR}/${PROJECT_SLUG}.v${_current_version}.$(date -u '+%y%m%d_%H%M%S').tar.gz"
	echo "[INFO]: Creating backup file: '${_backup_file_path}'..."
	tar -czpvf "${_backup_file_path}" -C ./volumes ./storage || {
		sudo tar -czpvf "${_backup_file_path}" -C ./volumes ./storage || exit 2
	}
	echo "[OK]: Done."
}

main "${@:-}"
## --- Main --- ##
