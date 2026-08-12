#!/usr/bin/env nu

# Notes:
# twpayne/chezmoi fails because it is not compressed

use std/log

export-env {
	# Use this to set the log level.
	$env.NU_LOG_LEVEL = "DEBUG"
}

# packages.json ships beside this script and is installed to a fixed path by the feature.
# Both locations are overridable so the script stays runnable by hand inside the container.
const DEFAULT_PACKAGES_JSON = "/usr/local/share/dev-shell/packages.json"
const DEFAULT_BIN_DIR = "/usr/local/bin"

let packages_json_location = ($env.DEV_SHELL_PACKAGES_JSON? | default $DEFAULT_PACKAGES_JSON | path expand)
if not ($packages_json_location | path exists) {
	log error $"packages.json not found at '($packages_json_location)'. Set $env.DEV_SHELL_PACKAGES_JSON to its location."
	exit 1
}

# Binaries go to a system directory because the feature installs as root at image build time,
# when the remote user's home directory is not the installing user's home.
let bin_dir = ($env.DEV_SHELL_BIN_DIR? | default $DEFAULT_BIN_DIR | path expand)
if not ($bin_dir | path exists) {
	mkdir $bin_dir
}


# install binaries will install the files into bin_dir
def "install binaries" []: list<string> -> record<any> {
	let input = $in
	if ($bin_dir | is-empty) or ($bin_dir | str length) == 0 {
		log error $"bin_dir is not defined: '($bin_dir)'"
		return null
	}

	$input | each {|it|
		let filename: string = ($it | path basename)
		log info $"Installing '($it)' to '($bin_dir)'"
		cp $it $bin_dir
		if $nu.os-info.name != "windows" {
			let file = ([$bin_dir, $filename] | path join)
			log info $"Fixing permissions on '($file)'"
			^chmod a+rx,go-w $file
		}
	} | flatten
}


# Search for packages to install
export def search []: string -> record<any> {
	let input = $in
	log info $"Searching packages for '($input)'"
	$packages_json_location
		| open
		| where {|it| ($it.repo =~ $"\(?i:($input)\)") or ($it.description =~ $"\(?i:($input)\)")}
}


# Install a package
export def install []: record<any> -> record<any> {
	let input = $in

	$input | each {|it|
		let url = $"https://github.com/($it.repo)/releases/download/($in.version)/($it.filename)"
		let tmp_dir = (mktemp --directory)
		if ("bin" in $it) {
			# Uncompressed
			let tmp_file = ($tmp_dir | path join ($it.bin))
			http get $url | save $tmp_file
			log debug $"tmp_file: '($tmp_file)'"
			log debug $"tmp_dir: '($tmp_dir)'"
			$tmp_file | install binaries
		} else if ("glob" in $it) {
			# Compressed
			let tmp_file = ($tmp_dir | path join ($it.filename))
			http get $url | save $tmp_file
			ouch --yes --quiet --accessible decompress --dir $tmp_dir $tmp_file
			log debug $"tmp_file: '($tmp_file)'"
			log debug $"tmp_dir: '($tmp_dir)'"
			glob --no-dir ($tmp_dir | path join "**" $it.glob) | install binaries
		} else {
			log error $"Package does not have bin \(uncompressed\) or glob \(compressed\) defined: '($it)'"
		}

	}
}


# Package module
export def main [
	action: string			# Action to take: search, download, install
	repo?: string			# GitHub repo name in owner/repo format
	--name (-n): string		# Binary name to install. Default: "repo" in "owner/repo"
	--filter (-f): string	# Filter the results if a single release can't be determined
]: nothing -> nothing {
	use std/log

	if $action == "search" {
		# Search for a package.
		log info $"Searching for package: '($repo)'"
		$repo | search

	} else if $action == "download" {
		# Download the package into the current directory.
		log info $"Downloading ($repo)"
		github download --name $name --filter $filter $repo

	} else if $action == "install" {
		# Install a package into the into the bin directory for the user or system.
		log info $"Installing package: '($repo)'"

		$repo | search | install

	} else if $action == "install-all" {
		# Install all packages into the into the bin directory.
		log info $"Installing package: '($repo)'"
		$packages_json_location
			| open
			| install

	}

}
