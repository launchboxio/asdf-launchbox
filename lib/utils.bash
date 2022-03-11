#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/launchboxio/launchbox"
TOOL_NAME="launchbox"
TOOL_TEST="launchbox --help"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  list_github_tags
}

download_release() {
  local version filename url platform arch
  version="$1"
  filename="$2"
  platform=$(get_platform)
  arch=$(get_arch)

  url="$GH_REPO/releases/download/v${version}/launchbox-v${version}-${platform}-${arch}.tar.gz"
  echo "$url"
  echo "* Downloading $TOOL_NAME release $version..."
  echo "$filename"
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
  stat "${filename}"
}

get_platform() {
  local -r kernel="$(uname -s)"
  if [[ $OSTYPE == "msys" || $kernel == "CYGWIN"* || $kernel == "MINGW"* ]]; then
    echo windows
  else
    uname | tr '[:upper:]' '[:lower:]'
  fi
}

get_arch() {
  local -r machine="$(uname -m)"

  if [[ $machine == "arm64" ]] || [[ $machine == "aarch64" ]]; then
    echo "arm64"
  elif [[ $machine == *"arm"* ]] || [[ $machine == *"aarch"* ]]; then
    echo "arm"
  elif [[ $machine == *"386"* ]]; then
    echo "386"
  else
    echo "amd64"
  fi
}

install_version() {
  local platform=$(get_platform)
  local arch=$(get_arch)
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    local -r bin_install_path="${install_path}/bin"
    echo "Checking download path"
    ls -al $ASDF_DOWNLOAD_PATH
    echo "Checking install path"
    ls -al "${install_path}"
    echo "Checking unzipped archive"
    ls -al "${install_path}/launchbox-v${version}-${platform}-${arch}"
    mv "${install_path}/launchbox-v${version}-${platform}-${arch}/launchbox/" "${bin_install_path}/launchbox"
    # TODO: Verify checksum
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    ls -al "$install_path"
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
