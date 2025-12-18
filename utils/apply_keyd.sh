#!/usr/bin/env sh

if ! systemctl list-unit-files | grep -q '^keyd\.service'; then
    echo "Could not find keyd systemd service. This usually means you don't have keyd installed yet."

    if command -v apt >/dev/null 2>&1; then
		INSTALL_COMMAND='sudo apt-get install keyd'

		while true; do
			printf "Would you like to install keyd now? (will run \`%s\`) [Y/n]: " "$INSTALL_COMMAND"
			read -r REPLY
			REPLY=${REPLY:-Y}

			case "$REPLY" in
				[Yy]* )
					$INSTALL_COMMAND
					break
					;;
				[Nn]* )
					break
					;;
				* )
					echo Invalid response.
					;;
			esac
		done
	else
		echo Could not find apt. If this is not a Debian-based distro, you can try installing keyd yourself.
    fi
fi

DEFAULT_CONF='/etc/keyd/default.conf'
printf "Where do you want your config file to be saved? [%s]: " "$DEFAULT_CONF"
read -r REPLY
CONF_PATH="${REPLY:-$DEFAULT_CONF}"

while true; do
	SCRIPT_DIR=$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)
	CONF_SOURCE_PATH="$SCRIPT_DIR/../keyd/default.conf"

	if [ -f "$CONF_PATH" ]; then
		echo "There is already a file in $CONF_PATH. How would you want to handle this?"
		echo "    [Y]: Overwrite $CONF_PATH"
		echo '    [N]: Abort'
		echo '    <path to destination>: Use another path instead'
		printf 'Choose an option [y/n/<path>]: '

		read -r CHOICE

		case "$CHOICE" in
			[Yy]* )
				;;
			[Nn]* )
				echo Aborting.
				exit 1
				;;
			* )
				CONF_PATH="$CHOICE"
				continue
				;;
		esac
	fi

	CONF_DIR="$(dirname "$CONF_PATH")"

	if [ -w "$CONF_DIR" ]; then
		cp "$CONF_SOURCE_PATH" "$CONF_PATH"
	else
		echo "Current user does not have write permissions to $CONF_DIR. Superuser permission is needed to copy files."
		sudo cp "$CONF_SOURCE_PATH" "$CONF_PATH"
	fi

	break
done

if systemctl list-unit-files | grep -q '^keyd\.service'; then
	RESTART_COMMAND='sudo systemctl enable --now keyd && sudo systemctl restart --now keyd'
	while true; do
		printf "Would you like to restart the keyd service now? (will run \`%s\`) [Y/n]: " "$RESTART_COMMAND"
		read -r REPLY

		case "$REPLY" in
			[Yy]* )
				$RESTART_COMMAND
				break
				;;
			[Nn]* )
				break
				;;
			* )
				;;
		esac
	done
fi