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

list_all_tags () {
	build/hub_tags.py $* || die "Error fetching tags from hub: $*"
}

get_tomcat_tags () {
	# This can all probably be done in awk
	list_all_tags library tomcat |grep -E '^[^7][0-9]*\.[0-9]*\.[0-9]*-jdk(8|11)-openjdk$'|tr - ' ' |awk '{print $3,$2,$1}' |sort -rV -k 2,3 |tr . ' ' |awk '{print $5,$1,$2,$3,$4}' |uniq -f 1 |awk '{print $4 "." $5 "." $1 "-" $3 "-" $2}'
}

sig_tomcat_already_pushed () {
	sig_tag="$1"
	if [ -z "$ALL_SIG_TAGS" ]; then
		ALL_SIG_TAGS="$(list_all_tags sigcorp tomcat)"
	fi
	echo "$ALL_SIG_TAGS" | grep -q $sig_tag
	return $?
}

skip_tag () {
	if grep -q "^$1" skip_tags; then
		>&2 echo -n "SKIPPING: "
		>&2 grep "^$1" skip_tags
		return 0
	fi
	return 1
}

list_base_tags_to_build () {
	git_hash=$(current_git_hash)
	for base_tag in $(get_tomcat_tags); do
		>&2 echo "Base Tag: ${base_tag}"
		skip_tag $base_tag && continue
		hashed_tag="${base_tag}-${git_hash}"	
		# sig_tomcat_already_pushed $hashed_tag && continue
		echo "${base_tag}"
	done	
}

cmd_base () {
	to_build="$(list_base_tags_to_build)"

	>&2 echo "---- To Build ----
$to_build
------------------"

	echo -n "[ "
	is_first=y
	for base_tag in $to_build; do
		[ -z "$is_first" ] && echo -n ", "
		echo -n "\"${base_tag}\""
		unset is_first
	done
	echo " ]"
}

cmd_exclude () {
	hash=$(current_git_hash)
	sig_tags="$(list_all_tags sigcorp tomcat |grep -- "-${hash}$")"
	echo -n "[ "
	is_first=y
	for t in $sig_tags; do
		a=($(echo $t |tr '-' ' '))
		unset a[-1]
		target=${a[-1]}
		unset a[-1]
		baseTag=$(echo ${a[*]} | tr ' ' '-')

		[ -z "$is_first" ] && echo -n ", "
		unset is_first
		echo -n "{ \"baseTag\":\"${baseTag}\", \"target\":\"${target}\" }"
		>&2 echo "EXCLUDE: { \"baseTag\":\"${baseTag}\", \"target\":\"${target}\" }"
	done
	echo " ]"
}

cmd_buildcount () {
	hash=$(current_git_hash)
	sig_tags="$(list_all_tags sigcorp tomcat |grep -- "-${hash}$")"
	targets=$(cat .github/workflows/publish.yml |yq -r '.jobs.build.strategy.matrix.target[]')
	c=0
	for baseTag in $(list_base_tags_to_build); do
		for target in $targets; do
			if echo "$sig_tags" |grep $baseTag |grep -q $target; then
				>&2 echo "$baseTag $target found"
			else
				>&2 echo "$baseTag $target not found"
				c=$((c+1))
			fi
		done
	done
	>&2 echo "Build Count: $c"
	echo $c
}

if [ -z "$1" ]; then
	echo "usage: $0 <base|exclude|buildcount>"
	exit 1
fi

CMD="$1"; shift
cmd_${CMD} $*
