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
# Flags:
_IS_LOGS=false
_IS_DATA=false
_IS_BACKUPS=false
_IS_ALL=false
_IS_FORCE=false
## --- Variables --- ##


## --- Main --- ##
main()
{
	## --- Menu arguments --- ##
	if [ -n "${1:-}" ]; then
		local _input
		for _input in "${@:-}"; do
			case ${_input} in
				-l | --logs)
					_IS_LOGS=true
					shift;;
				-d | --data)
					_IS_DATA=true
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
				*)
					echo "[ERROR]: Failed to parse input -> ${_input}!"
					echo "[INFO]: USAGE: ${0}  -l, --logs | -d, --data | -b, --backups | -a, --all | -f, --force"
					exit 1;;
			esac
		done
	fi
	## --- Menu arguments --- ##


	echo "[INFO]: Cleaning..."

	find . -type f -name ".DS_Store" -print -delete || exit 2
	find . -type f -name "Thumbs.db" -print -delete || exit 2

	rm -rfv ./tmp || exit 2

	local _is_docker_running=false
	if [ -n "$(which docker)" ] && docker info > /dev/null 2>&1; then
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
		# find . -type d -name ".git" -prune -o -type d -name "logs" -exec rm -rfv {} + || exit 2
		find ./volumes/storage -type f -name "*.log" -exec rm -v {} + || exit 2
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

			rm -rfv ./volumes/storage/nginx/ssl/* || {
				sudo rm -rfv ./volumes/storage/nginx/ssl/* || exit 2
			}
			echo "[OK]: Removed data."
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
			rm -rfv ./volumes/backups || {
				sudo rm -rfv ./volumes/backups || exit 2
			}
			echo "[OK]: Removed backups."
		fi
	fi

	echo "[OK]: Done."
}

main "${@:-}"
## --- Main --- ##
