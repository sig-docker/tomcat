#! /bin/bash

#
# This script checks the list of available upstream Tomcat tags and triggers,
# and triggers builds for any that haven't yet been build for the current
# commit.
#

HUB_BASE='https://registry.hub.docker.com'

die () {
	>&2 echo "ERROR: $*"
	exit 1
}

current_git_hash () {
	git rev-parse --short HEAD || die "git error"
}

fetch_tags () {
	url="${HUB_BASE}/v1/repositories/${1}/tags"
	>&2 echo "Fetching tags for ${1} from registry."
	curl -s -q "$url" || die "Error fetching tags for '$1' from $url"
}

list_all_tags () {
	fetch_tags $1 | sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | tr '}' '\n'  | awk -F: '{print $3}'
}

get_tomcat_tags () {
	# This can all probably be done in awk
	list_all_tags tomcat |grep -E '^[^7][0-9]*\.[0-9]*\.[0-9]*-jdk(8|11)-openjdk$'|tr - ' ' |awk '{print $3,$2,$1}' |sort -rV -k 2,3 |tr . ' ' |awk '{print $5,$1,$2,$3,$4}' |uniq -f 1 |awk '{print $4 "." $5 "." $1 "-" $3 "-" $2}'
}

sig_tomcat_already_pushed () {
	sig_tag="$1"
	if [ -z "$ALL_SIG_TAGS" ]; then
		ALL_SIG_TAGS="$(list_all_tags sigcorp/tomcat)"
	fi
	echo "$ALL_SIG_TAGS" | grep -q $sig_tag
	return $?
}

list_base_tags_to_build () {
	git_hash=$(current_git_hash)
	for base_tag in $(get_tomcat_tags); do	
		hashed_tag="${base_tag}-${git_hash}"	
		if ! sig_tomcat_already_pushed $hashed_tag; then
			echo "${base_tag}"
		fi
	done	
}

to_build="$(list_base_tags_to_build)"
echo -n "[ "
is_first=y
for base_tag in $to_build; do	
	[ -z "$is_first" ] && echo -n ", "
	echo -n "\"${base_tag}\""
	unset is_first
done
echo " ]"
