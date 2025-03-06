rockspec_format = "3.0"
package = "samples"
version = "scm-1"
source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
   homepage = "*** please enter a project homepage ***",
   license = "*** please specify a license ***"
}
dependencies = {
   "lua >= 5.1, < 5.5",
   "inspect >= 3.1.3",
}
test_dependencies = {
   "busted >= 2.2.0",
   "luafilesystem >= 1.8.0",
   "luassert >= 1.9.0",
}
build = {
   type = "builtin",
   modules = {}
}
