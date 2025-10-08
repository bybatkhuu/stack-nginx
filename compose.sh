#!/bin/bash
set -euo pipefail


## --- Base --- ##
# Getting path of this script file:
_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "${_PROJECT_DIR}" || exit 2


# Loading .env file (if exists):
if [ -f ".env" ]; then
	# shellcheck disable=SC1091
	source .env
fi


# Checking docker and docker-compose installed:
if [ -z "$(which docker)" ]; then
	echo "[ERROR]: 'docker' not found or not installed!"
	exit 1
fi

if ! docker info > /dev/null 2>&1; then
	echo "[ERROR]: Unable to communicate with the docker daemon. Check docker is running or check your account added to docker group!"
	exit 1
fi

if ! docker compose > /dev/null 2>&1; then
	echo "[ERROR]: 'docker compose' not found or not installed!"
	exit 1
fi
## --- Base --- ##


## --- Variables --- ##
_DEFAULT_SERVICE="nginx"
## --- Variables --- ##


## --- Functions --- ##
_build()
{
	# shellcheck disable=SC2068
	docker compose build ${@:-} || exit 2
}

_validate()
{
	docker compose config || exit 2
}

_start()
{
	if [ "${1:-}" == "-l" ]; then
		shift
		# shellcheck disable=SC2068
		docker compose up -d --remove-orphans --force-recreate ${@:-} || exit 2
		_logs "${@:-}"
	else
		# shellcheck disable=SC2068
		docker compose up -d --remove-orphans --force-recreate ${@:-} || exit 2
	fi
}

_stop()
{
	if [ -z "${1:-}" ]; then
		docker compose down --remove-orphans || exit 2
	else
		# shellcheck disable=SC2068
		docker compose rm -sfv ${@:-} || exit 2
	fi
}

_restart()
{
	if [ "${1:-}" == "-l" ]; then
		shift
		_stop "${@:-}" || exit 2
		_start -l "${@:-}" || exit 2
	else
		_stop "${@:-}" || exit 2
		_start "${@:-}" || exit 2
	fi
	# docker compose restart ${@:-} || exit 2
}

_logs()
{
	# shellcheck disable=SC2068
	docker compose logs -f --tail 100 ${@} || exit 2
}

_list()
{
	docker compose ps || exit 2
}

_ps()
{
	# shellcheck disable=SC2068
	docker compose top ${@:-} || exit 2
}

_stats()
{
	# shellcheck disable=SC2068
	docker compose stats ${@:-} || exit 2
}

_exec()
{
	if [ -z "${1:-}" ]; then
		echo "[ERROR]: No arguments provided for exec command!"
		exit 1
	fi

	echo "[INFO]: Executing command inside '${_DEFAULT_SERVICE}' container..."
	# shellcheck disable=SC2068
	docker compose exec "${_DEFAULT_SERVICE}" ${@} || exit 2
}

_certs()
{
	docker compose exec certbot certbot certificates || exit 2
}

_reload()
{
	docker compose exec "${_DEFAULT_SERVICE}" /bin/bash -c "nginx -t && nginx -s reload" || exit 2
}

_enter()
{
	local _service="${_DEFAULT_SERVICE}"
	if [ -n "${1:-}" ]; then
		_service=${1}
	fi

	echo "[INFO]: Entering inside '${_service}' container..."
	docker compose exec "${_service}" /bin/bash || exit 2
}

_images()
{
	# shellcheck disable=SC2068
	docker compose images ${@:-} || exit 2
}

_clean()
{
	# shellcheck disable=SC2068
	docker compose down -v --remove-orphans ${@:-} || exit 2
}

_update()
{
	if docker compose ps | grep 'Up' > /dev/null 2>&1; then
		_stop "${@:-}" || exit 2
	fi

	# shellcheck disable=SC2068
	docker compose pull --policy always ${@:-} || exit 2
	# shellcheck disable=SC2046
	docker rmi -f $(docker images --filter "dangling=true" -q --no-trunc) > /dev/null 2>&1 || true

	# _start "${@:-}" || exit 2
}
## --- Functions --- ##


## --- Menu arguments --- ##
_error_params()
{
	echo "[INFO]: USAGE: ${0}  build | validate | start | stop | restart | logs | list | ps | stats | exec | certs | reload | enter | images | clean | update"
	exit 1
}

main()
{
	if [ -z "${1:-}" ]; then
		echo "[ERROR]: Not found any input!"
		_error_params
	fi

	case ${1} in
		build)
			shift
			_build "${@:-}";;
		validate | valid | config)
			shift
			_validate;;
		start | run | up)
			shift
			_start "${@:-}";;
		stop | down | remove | rm | delete | del)
			shift
			_stop "${@:-}";;
		restart)
			shift
			_restart "${@:-}";;
		logs)
			shift
			_logs "${@:-}";;
		list | ls)
			_list;;
		ps | top)
			shift
			_ps "${@:-}";;
		stats | resource | limit)
			shift
			_stats "${@:-}";;
		exec)
			shift
			_exec "${@:-}";;
		certs | certificates)
			shift
			_certs;;
		reload)
			shift
			_reload;;
		enter)
			shift
			_enter "${@:-}";;
		images | image)
			shift
			_images "${@:-}";;
		clean | clear)
			shift
			_clean "${@:-}";;
		update | pull)
			shift
			_update "${@:-}";;
		*)
			echo "[ERROR]: Failed to parse input: ${*}!"
			_error_params;;
	esac

	exit
}

main "${@:-}"
## --- Menu arguments --- ##
