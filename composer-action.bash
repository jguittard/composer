#!/bin/bash
set -e
command_string="composer:${ACTION_COMPOSER_VERSION}"
mkdir -p ~/.ssh
touch ~/.gitconfig

if [ -n "$ACTION_SSH_KEY" ]
then
	echo "Storing private key file for root"
	ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
	ssh-keyscan -t rsa gitlab.com >> ~/.ssh/known_hosts
	ssh-keyscan -t rsa bitbucket.org >> ~/.ssh/known_hosts

	if [ -n "$ACTION_SSH_DOMAIN" ]
	then
		ssh-keyscan -t rsa "$ACTION_SSH_DOMAIN" >> ~/.ssh/known_hosts
	fi

	echo "$ACTION_SSH_KEY" > ~/.ssh/action_rsa
	echo "$ACTION_SSH_KEY_PUB" > ~/.ssh/action_rsa.pub
	chmod 600 ~/.ssh/action_rsa

	echo "PRIVATE KEY:"
	md5sum ~/.ssh/action_rsa
	echo "PUBLIC KEY:"
	md5sum ~/.ssh/action_rsa.pub

	echo "[core]" >> ~/.gitconfig
	echo "sshCommand = \"ssh -F ~/.ssh/action_rsa\"" >> ~/.gitconfig
else
	echo "No private keys supplied"
fi

if [ -n "$ACTION_COMMAND" ]
then
	command_string="$command_string $ACTION_COMMAND"
fi

if [ -n "$ACTION_WORKING_DIR" ]
then
	command_string="$command_string --working-dir=$ACTION_WORKING_DIR"
fi

# TODO: Use -z instead of ! -n
if [ ! -n "$ACTION_ONLY_ARGS" ]
then
	if [ "$ACTION_COMMAND" = "install" ]
	then
		case "$ACTION_SUGGEST" in
        		yes)
        			# Default behaviour
        		;;
        		no)
        			command_string="$command_string --no-suggest"
        		;;
        		*)
        			echo "Invalid input for action argument: suggest (must be yes or no)"
        			exit 1
        		;;
        	esac

        	case "$ACTION_DEV" in
        		yes)
        			# Default behaviour
        		;;
        		no)
        			command_string="$command_string --no-dev"
        		;;
        		*)
        			echo "Invalid input for action argument: dev (must be yes or no)"
        			exit 1
        		;;
        	esac

        	case "$ACTION_PROGRESS" in
        		yes)
        			# Default behaviour
        		;;
        		no)
        			command_string="$command_string --no-progress"
        		;;
        		*)
        			echo "Invalid input for action argument: progress (must be yes or no)"
        			exit 1
        		;;
        	esac
	fi

	case "$ACTION_INTERACTION" in
		yes)
			# Default behaviour
		;;
		no)
			command_string="$command_string --no-interaction"
		;;
		*)
			echo "Invalid input for action argument: interaction  (must be yes or no)"
			exit 1
		;;
	esac

	case "$ACTION_QUIET" in
		yes)
			command_string="$command_string --quiet"
		;;
		no)
			# Default behaviour
		;;
		*)
			echo "Invalid input for action argument: quiet (must be yes or no)"
			exit 1
		;;
	esac

	if [ -n "$ACTION_ARGS" ]
	then
		command_string="$command_string $ACTION_ARGS"
	fi
else
	command_string="$command_string $ACTION_ONLY_ARGS"
fi

docker pull -q composer:"${ACTION_COMPOSER_VERSION}"
detected_version=$(docker run --rm composer:"${ACTION_COMPOSER_VERSION}" --version | perl -pe '($_)=/\b(\d+.\d+\.\d+)\b/;')
detected_major_version=$(docker run --rm composer:"${ACTION_COMPOSER_VERSION}" --version | perl -pe '($_)=/\b(\d)\d*\.\d+\.\d+/;')
echo "::set-output name=composer_cache_dir::${RUNNER_WORKSPACE}/composer/cache"
echo "::set-output name=composer_major_version::${detected_major_version}"
echo "::set-output name=composer_version::${detected_version}"
echo "::set-output name=full_command::${command_string}"

echo "Running composer v${detected_version}"
echo "Command: $command_string"
docker run --rm \
	--volume ~/.gitconfig:/root/.gitconfig \
	--volume ~/.ssh:/root/.ssh \
	--volume "${RUNNER_WORKSPACE}"/composer:/tmp \
	--volume "${GITHUB_WORKSPACE}":/app \
	--workdir /app \
	${command_string}
