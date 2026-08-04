#!/usr/bin/env bash
set -euo pipefail


## --- Base --- ##
_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-"$0"}")" >/dev/null 2>&1 && pwd -P)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2


# shellcheck disable=SC1091
[ -f .env ] && . .env


if ! command -v git >/dev/null 2>&1; then
	echo "[ERROR]: Not found 'git' command, please install it first!" >&2
	exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
	echo "[ERROR]: Not found 'gh' command, please install it first!" >&2
	exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
	echo "[ERROR]: You need to login: 'gh auth login'!" >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	echo "[ERROR]: Not found 'jq' command, please install it first!" >&2
	exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
	echo "[ERROR]: Not found 'yq' command, please install it first!" >&2
	exit 1
fi
## --- Base --- ##


## --- Variables --- ##
# Load from environment variables:
COMPOSE_FILE_PATH="${COMPOSE_FILE_PATH:-compose.yml}"
REPO_OWNER="${REPO_OWNER:-bybatkhuu}"
REGISTRY_NAME="${REGISTRY_NAME:-${REPO_OWNER}}"
SUBMODULE_LIST="
[
	{
		\"submodule_repo\": \"${REPO_OWNER}/sidecar-certbot\",
		\"image_name\": \"${REGISTRY_NAME}/certbot\",
		\"service_name\": \"certbot\"
	},
	{
		\"submodule_repo\": \"${REPO_OWNER}/server-nginx-template\",
		\"image_name\": \"${REGISTRY_NAME}/nginx\",
		\"service_name\": \"nginx\"
	}
]"

# Flags:
_CREATE_BRANCH=false
_IS_COMMIT=false
_IS_PUSH=false
_CREATE_PR=false
## --- Variables --- ##


## --- Menu arguments --- ##
_usage_help() {
	cat <<EOF
USAGE: ${0} [options]

OPTIONS:
    -b, --branch          Enable create new branch step. Default: false
    -c, --commit          Enable commit step. Default: false
    -p, --push            Enable push step. Default: false
    -r, --pull-request    Enable create pull request step. Default: false
    -h, --help            Show this help message.

EXAMPLES:
    ${0} -b -c -p -r
    ${0} --branch --commit
EOF
}

while [ $# -gt 0 ]; do
	case "${1}" in
		-b | --branch)
			_CREATE_BRANCH=true
			shift;;
		-c | --commit)
			_IS_COMMIT=true
			shift;;
		-p | --push)
			_IS_PUSH=true
			shift;;
		-r | --pull-request)
			_CREATE_PR=true
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
	echo "[INFO]: Checking and syncing for new versions of dependencies/submodules..."
	local _has_new_versions=false
	while read -r _submodule; do
		local _submodule_repo _image_name _service_name
		_submodule_repo=$(echo "${_submodule}" | jq -r '.submodule_repo')
		_image_name=$(echo "${_submodule}" | jq -r '.image_name')
		_service_name=$(echo "${_submodule}" | jq -r '.service_name')

		local _submodule_version
		_submodule_version="$(gh release view --json tagName --repo "${_submodule_repo}" | jq -r ".tagName" | tr -d 'v')" || exit 2
		if [ -z "${_submodule_version}" ] || [ "${_submodule_version}" == "null" ]; then
			echo "[ERROR]: Not found any release version from submodule: '${_submodule_repo}'!" >&2
			exit 1
		fi

		local _has_new_version=false
		local _latest_image="${_image_name}:${_submodule_version}"
		local _current_image
		_current_image=$(yq ".services.${_service_name}.image" "${COMPOSE_FILE_PATH}")

		if [ "${_current_image}" == "${_latest_image}" ]; then
			echo "[INFO]: The service '${_service_name}' with image '${_latest_image}' is already up-to-date."
			continue
		else
			echo "[INFO]: Found new version for service '${_service_name}': '${_latest_image}'."
			_has_new_version=true
			_has_new_versions=true
		fi

		if [ "${_has_new_version}" == true ]; then
			echo "[INFO]: Syncing '${_service_name}' service image version to: '${_latest_image}'..."
			yq -i ".services.${_service_name}.image = \"${_latest_image}\"" "${COMPOSE_FILE_PATH}"
			echo "[OK]: Done."
		fi
	done < <(echo "${SUBMODULE_LIST}" | jq -c '.[]')

	if [ "${_has_new_versions}" == false ]; then
		echo "[OK]: No new versions found, nothing to update."
		exit 0
	fi

	local _new_branch_name
	if [ "${_CREATE_BRANCH}" == true ]; then
		_new_branch_name="deps/update-$(date -u '+%y%m%d-%H%M%S')"
		git checkout -b "${_new_branch_name}" || exit 2
	fi

	if [ "${_IS_COMMIT}" == true ]; then
		echo "[INFO]: Committing changes..."
		git add "${COMPOSE_FILE_PATH}" || exit 2
		git commit -m "deps: update docker compose.yml dependency/image versions." || exit 2
		echo "[OK]: Done."

		if [ "${_IS_PUSH}" == true ]; then
			if [ "${_CREATE_BRANCH}" = true ]; then
				echo "[INFO]: Pushing changes to new branch '${_new_branch_name}'..."
				git push -u origin "${_new_branch_name}" || exit 2
				echo "[OK]: Done."
			else
				echo "[INFO]: Pushing changes to the current branch..."
				git push || exit 2
				echo "[OK]: Done."
			fi

			if [ "${_CREATE_PR}" == true ]; then
				if [ "${_CREATE_BRANCH}" == true ]; then
					echo "[INFO]: Creating pull request..."
					gh pr create \
						-t "Update docker compose.yml dependency/image versions" \
						-b "This PR updates the versions of images in the docker compose.yml file." \
						-l "dependencies" \
						-r "${REPO_OWNER}" \
						-B dev || exit 2
					echo "[OK]: Done."
				else
					echo "[WARN]: You cannot create a pull request without a new branch!" >&2
					exit 1
				fi
			fi
		fi
	fi

	echo "[OK]: All done."
}

main
## --- Main --- ##
