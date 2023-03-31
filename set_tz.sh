die () {
    echo "ERROR: $*"
    exit 1
}

if [ -z "$TIMEZONE" ]; then
    echo "TIMEZONE environment variable not set. Using default (UTC)."
    exit 0
fi

ZONE_FILE="/usr/share/zoneinfo/$TIMEZONE"
[ -f "$ZONE_FILE" ] || die "Timezone file not found: $ZONE_FILE"

echo "Setting timezone to: $TIMEZONE"

echo "$TIMEZONE" > /etc/timezone || die "Error updating /etc/timezone"
cp -f "$ZONE_FILE" /etc/localtime || die "Error updating /etc/localtime"
echo "current_timezone: $TIMEZONE" >/ansible/group_vars/all/timezone.yml || die "Error updating Ansible timezone"
