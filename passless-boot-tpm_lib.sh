rootfs_name=root

detect_dmcrypt_path ()
{
	findmnt --noheadings -o SOURCE /
}

detect_dmcrypt_name ()
{
	dm_path="$1"
	if ! [[ "$dm_path" =~ ^/dev/mapper/([^/]+)$ ]]; then
		echo "Error: rootfs doesn't appear to be a dm-crypt device."
		exit 23
	fi
	dm_name="${BASH_REMATCH[1]}"
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
		echo "Error: couldn't identify encrypted root partition."
	fi
	# TODO: handle systemd-gpt-auto-generator
}
