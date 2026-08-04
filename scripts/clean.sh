#!/usr/bin/env bash
set -euo pipefail


## --- Base --- ##
_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-"$0"}")" >/dev/null 2>&1 && pwd -P)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2


# shellcheck disable=SC1091
[ -f .env ] && . .env
## --- Base --- ##


## --- Variables --- ##
# Flags:
_IS_LOGS=false
_IS_DATA=false
_IS_CERTS=false
_IS_BACKUPS=false
_IS_ALL=false
_IS_FORCE=false
_IS_VERBOSE=true
## --- Variables --- ##


## --- Menu arguments --- ##
_usage_help() {
	cat <<EOF
USAGE: ${0} [options]

OPTIONS:
    -l, --logs       Remove logs. Default: false
    -d, --data       Remove data. Default: false
    -c, --certs      Remove SSL certificates. Default: false
    -b, --backups    Remove backups. Default: false
    -a, --all        Enable all mode. Default: false
    -f, --force      Enable force mode. Default: false
    -s, --silent     Enable silent mode. Default: false
    -h, --help       Show this help message.

EXAMPLES:
    ${0} -a -s
    ${0} --all
EOF
}

while [ $# -gt 0 ]; do
	case "${1}" in
		-l | --logs)
			_IS_LOGS=true
			shift;;
		-d | --data)
			_IS_DATA=true
			shift;;
 		-c | --certs)
 			_IS_CERTS=true
 			shift;;
		-b | --backups)
			_IS_BACKUPS=true
			shift;;
		-a | --all)
			_IS_ALL=true
			shift;;
		-f | --force)
			_IS_FORCE=true
			shift;;
		-s | --silent)
			_IS_VERBOSE=false
			shift;;
		-h | --help)
			_usage_help
			exit 0;;
		*)
			echo "[ERROR]: Failed to parse argument -> ${1}!" >&2
			_usage_help
			exit 1;;
	esac
done
## --- Menu arguments --- ##


## --- Main --- ##
main()
{
	local _verbose_flag=""
	if [ "${_IS_VERBOSE}" == true ]; then
		_verbose_flag="-v"
	fi

	echo "[INFO]: Cleaning..."

	find . -path "./volumes/storage" -prune -o -type f -name ".DS_Store" -print -exec rm -f ${_verbose_flag} {} + || exit 2
	find . -path "./volumes/storage" -prune -o -type f -name ".Thumbs.db" -print -exec rm -f ${_verbose_flag} {} + || exit 2

	rm -rfv ./tmp || exit 2

	local _is_docker_running=false
	if command -v docker >/dev/null 2>&1 && docker info > /dev/null 2>&1; then
		_is_docker_running=true
	fi

	if [ "${_is_docker_running}" == true ]; then
		if docker compose ps | grep 'Up' > /dev/null 2>&1; then
			echo "[WARNING]: Docker services are running, please stop it before cleaning!"
			exit 1
		fi
	fi

	if [ "${_IS_ALL}" == true ]; then
		rm -rf ./volumes/.vscode-server/* || {
			sudo rm -rf ./volumes/.vscode-server/* || exit 2
		}
	fi

	if [ "${_IS_LOGS}" == true ] || [ "${_IS_ALL}" == true ]; then
		echo "[INFO]: Removing logs..."
		find ./volumes/storage -type d -name "logs" -exec rm -rf ${_verbose_flag} {} + || {
			sudo find ./volumes/storage -type d -name "logs" -exec rm -rf ${_verbose_flag} {} + || exit 2
		}
		echo "[OK]: Removed logs."
	fi

	local _confirm_input
	if [ "${_IS_DATA}" == true ] || [ "${_IS_ALL}" == true ]; then
		_confirm_input="n"
		if [ "${_IS_FORCE}" == true ]; then
			_confirm_input="y"
		else
			echo "[WARNING]: This will remove all data! Are you sure? (y/n, default: n)"
			read -r -p "> " _confirm_input
		fi

		if [ "${_confirm_input}" == "y" ] || [ "${_confirm_input}" == "Y" ]; then
			echo "[INFO]: Removing data..."
			docker compose down -v --remove-orphans || exit 2

			find ./volumes/storage -type d -name "data" -exec rm -rf ${_verbose_flag} {} + || {
				sudo find ./volumes/storage -type d -name "data" -exec rm -rf ${_verbose_flag} {} + || exit 2
			}
			echo "[OK]: Removed data."
		fi
	fi

	if [ "${_IS_CERTS}" == true ] || [ "${_IS_ALL}" == true ]; then
		_confirm_input="n"
		if [ "${_IS_FORCE}" == true ]; then
			_confirm_input="y"
		else
			echo "[WARNING]: This will remove all SSL certificates! Are you sure? (y/n, default: n)"
			read -r -p "> " _confirm_input
		fi

		if [ "${_confirm_input}" == "y" ] || [ "${_confirm_input}" == "Y" ]; then
			echo "[INFO]: Removing SSL certificates..."
			rm -rf ${_verbose_flag} ./volumes/secrets/certbot/ssl/* || {
				sudo rm -rf ${_verbose_flag} ./volumes/secrets/certbot/ssl/* || exit 2
			}
			echo "[OK]: Removed SSL certificates."
		fi
	fi

	if [ "${_IS_BACKUPS}" == true ]; then
		_confirm_input="n"
		if [ "${_IS_FORCE}" == true ]; then
			_confirm_input="y"
		else
			echo "[WARNING]: This will remove all backups! Are you sure? (y/n, default: n)"
			read -r -p "> " _confirm_input
		fi

		if [ "${_confirm_input}" == "y" ] || [ "${_confirm_input}" == "Y" ]; then
			echo "[INFO]: Removing backups..."
			rm -rf ${_verbose_flag} ./volumes/backups || {
				sudo rm -rf ${_verbose_flag} ./volumes/backups || exit 2
			}
			echo "[OK]: Removed backups."
		fi
	fi

	echo "[OK]: Done."
}

main
## --- Main --- ##
