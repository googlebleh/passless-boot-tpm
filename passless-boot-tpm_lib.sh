perror ()
{
	echo >&2 "Error:" $@
}

dm_underlying_uuid ()
{
	while read -r line; do
		if [[ "$line" =~ device:[[:space:]]+(.+)$ ]]; then
			blkid -s UUID -o value "${BASH_REMATCH[1]}"
			return 0
		fi
	done < <(cryptsetup status "$dm_path")
	return 1
}

detect_dmcrypt_name ()
{
	dm_path="$1"
	if ! [[ "$dm_path" =~ ^/dev/mapper/([^/]+)$ ]]; then
		perror "rootfs doesn't appear to be a dm-crypt device."
		exit 23
	fi
	dm_name="${BASH_REMATCH[1]}"
}

cryptroot_device ()
{
	dm_path="$(findmnt --noheadings -o SOURCE /)"
	device="/dev/disk/by-uuid/$(dm_underlying_uuid "$dm_path")"

	if ! cryptsetup isLuks "$device"; then
		perror "detected encrypted root $device is unsupported (not LUKS-encrypted)."
		return 1
	fi
	echo "$device"
}

detect_in_crypttab ()
{
	while read -r entry; do
		if [[ "$entry" =~ ^$1[[:space:]]+([^[:space:]]+)[[:space:]] ]]; then
			device_uuid="${BASH_REMATCH[1]}"
			return 0
		fi
	done < /etc/crypttab.initramfs
	return 1
}

detect_encrypted_rootfs ()
{
	dm_name="$1"
	uuid_regex='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

	read -r cmdline < /proc/cmdline
	if [[ "$cmdline" =~ cryptdevice=UUID=device-($uuid_regex):$dm_name ]]; then
		mount_type="encrypt"
		device_uuid="${BASH_REMATCH[1]}"
		not_yet_implemented
	elif [[ "$cmdline" =~ rd\.luks\.name=($uuid_regex)=$dm_name ]]; then
		mount_type="sd-encrypt-cmdline"
		device_uuid="${BASH_REMATCH[1]}"
		not_yet_implemented
	elif detect_in_crypttab "$dm_name"; then
		mount_type="sd-encrypt-crypttab"
		# device_uuid set by detect_in_crypttab
	else
		perror "couldn't identify encrypted root partition."
	fi
	# TODO: handle systemd-gpt-auto-generator
}
