#!/bin/bash

export PATH=/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ $# -eq 0 ]] && \
{
	echo "USAGE: repair.sh <repository path> [repository path […]]" >&2
	exit 1
}

wd="$(realpath "$(dirname "$0")")"
init="$wd/init.sh"
[ -r "$init" ] || \
{
	echo "Couldn't open init file" >&2
	exit 2
}

. "$init"

target=$target/$instance

function getSource ()
{
	for i in ${!sources[*]}; do
		if [[ "${targets[$i]}" == "$1" ]]; then
			echo "${sources[$i]}"
			return 0
		elif [[ -z "${targets[$i]}" && "${sources[$i]}" == "$1" ]]; then
			echo "$1"
			return 0
		fi
	done
	
	return 1
}

for repo; do
	
	t=${repo/$target/}
	src=$(getSource "$t")
	
	[ -z "$src" ] && \
	{
		echo "Source for repository '$repo' not found" >&2
		continue
	}
	
	rdiff-backup --verify "$repo" 2>&1 | grep 'Computed SHA1 digest of' | sed s/'.*Computed SHA1 digest of '// | \
	while read file; do
		[[ "${src:${#src}-1:1}" != "/" ]] && src="$src/"
		file="$src$file"
		touch "$file"
	done
done
