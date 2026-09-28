# Only an explicit 404 means absent. Network, authentication and service errors
# must stop release mutations rather than masquerade as an unpublished version.
release_url_exists() {
  local status
  status="$(curl --silent --show-error --location --output /dev/null \
    --write-out '%{http_code}' --connect-timeout 10 --max-time 30 --retry 2 "$@")" || return 1
  case "$status" in
    200) echo true ;;
    404) echo false ;;
    *) echo "Release lookup failed (HTTP $status)." >&2; return 1 ;;
  esac
}
