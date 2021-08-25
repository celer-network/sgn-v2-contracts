PROTOC_VER=""
GEN_SOL_VER=""


prepare_tools() {
  setup_git
}

gen_sol() {}
add_to_pr() {}

setup_git() {
  git config --global user.email "build@celer.network"
  git config --global user.name "Build Bot"
  git config --global push.default "current"
}