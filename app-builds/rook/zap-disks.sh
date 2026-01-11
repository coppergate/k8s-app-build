# this will wipe out all of the identifying info on the the listed devices
# these are the 'Rook' raw devices that are used in CEPH
# mounted on the 'host' 'host'
DISKA=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")

for disk in "${DISKA[@]}";
do

	# Check if the disk is in use
	if ! lsblk "$disk" >/dev/null 2>&1; then
		echo "Disk ${disk} not found, skipping"
		continue
	fi

	MOUNTED=$(lsblk -nlo MOUNTPOINT "$disk" | grep -v '^$')
	HOLDERS=$(lsblk -nlo TYPE "$disk" | grep -v -E '^(disk|part)$')

	if [ -n "$MOUNTED" ] || [ -n "$HOLDERS" ]; then
		echo "Skipping disk ${disk} - it appears to be in use:"
		[ -n "$MOUNTED" ] && echo "  Mounted at: ${MOUNTED}"
		[ -n "$HOLDERS" ] && echo "  Has active holders of type: ${HOLDERS}"
		continue
	fi

	echo "zapping disk - ${disk}"
	# Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
	sgdisk --zap-all $disk

	# Wipe a large portion of the beginning of the disk to remove more LVM metadata that may be present
	dd if=/dev/zero of="$disk" bs=1M count=1000 oflag=direct,dsync

	# SSDs may be better cleaned with blkdiscard instead of dd
	blkdiscard $disk

	# Inform the OS of partition table changes
	partprobe $disk

done
