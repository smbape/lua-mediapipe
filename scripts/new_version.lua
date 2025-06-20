local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

-- Load cfg first so that the loader knows it is running inside LuaRocks
local cfg = require("luarocks.core.cfg")
local fs = require("luarocks.fs")

local loader = require("luarocks.loader")
local cmd = require("luarocks.cmd")

local description = "LuaRocks main command-line interface"

local commands = {
   new_version = "luarocks.cmd.new_version",
}

local util = require("luarocks.util")
local new_version = require(commands.new_version)
local new_version_command = new_version.command

function new_version.add_to_parser(parser)
   local cmd = parser:command("new_version", [[
This is a utility function that writes a new rockspec, updating data from a
previous one.

If a package name is given, it downloads the latest rockspec from the default
server. If a rockspec is given, it uses it instead. If no argument is given, it
looks for a rockspec same way 'luarocks make' does.

If the version number is not given and tag is passed using --tag, it is used as
the version, with 'v' removed from beginning.  Otherwise, it only increments the
revision number of the given (or downloaded) rockspec.

If a URL is given, it replaces the one from the old rockspec with the given URL.
If a URL is not given and a new version is given, it tries to guess the new URL
by replacing occurrences of the version number in the URL or tag; if the guessed
URL is invalid, the old URL is restored. It also tries to download the new URL
to determine the new MD5 checksum.

If a tag is given, it replaces the one from the old rockspec. If there is an old
tag but no new one passed, it is guessed in the same way URL is.

If a directory is not given, it defaults to the current directory.

WARNING: it writes the new rockspec to the given directory, overwriting the file
if it already exists.]], util.see_also())
       :summary("Auto-write a rockspec for a new version of a rock.")

   cmd:argument("rock", "Package name or rockspec.")
       :args("?")
   cmd:argument("new_version", "New version of the rock.")
       :args("?")
   cmd:argument("abi", "Lua ABI version of the rock.")
       :args("?")

   cmd:option("--dir", "Output directory for the new rockspec.")
   cmd:option("--tag", "New SCM tag.")
   cmd:option("--prefix", "Install prefix.")
   cmd:option("--platform", "OS platform.")

   cmd:flag("--repair", "Vendor in external shared library dependencies of the binary rock.")
   cmd:option("--plat", "Desired target platform.")
   cmd:flag("--strip", "Strip symbols in the resulting wheel.")
   cmd:option("--exclude", "Exclude SONAME from grafting into the resulting wheel Please make sure wheel metadata reflects your dependencies. " .. 
                           "See https://github.com/pypa/auditwheel/pull/411#issuecomment-1500826281 (can contain wildcards, for example libfoo.so.*)")
   cmd:flag("--only-plat", "Do not check for higher policy compatibility.")
   cmd:flag("--disable-isa-ext-check", "Do not check for extended ISA compatibility (e.g. x86_64_v2)")

   cmd:option("--opencv-name", "OpenCV rock name.")
   cmd:option("--opencv-version", "OpenCV rock version.")
end

local function dump_table_as_python_array(tbl)
   local str = "["
   for k, v in pairs(tbl) do
      if #str > 1 then
         str = str .. ", "
      end
      if type(v) == "string" then
         str = str .. "'" .. v .. "'"
      elseif type(v) == "number" then
         str = str .. v
      elseif type(v) == "boolean" then
         if v then
            str = str .. "True"
         else
            str = str .. "False"
         end
      elseif type(v) == nil then
         str = str .. "None"
      end
   end
   str = str .. "]"
   return str
end

function new_version.command(args)
   local prefix = args.prefix or ""
   local abi = args.abi

   if prefix ~= "" and prefix:sub(-1) ~= "/" then
      prefix = prefix .. "/"
   end

   local persist = require("luarocks.persist")
   local load_into_table = persist.load_into_table
   local first_pass = true

   function persist.load_into_table(filename, tbl)
      local out_rs, err, errcode = load_into_table(filename, tbl)
      if out_rs == nil then
         return out_rs, err, errcode
      end

      out_rs.source.url = ""
      out_rs.build.type = "none"
      out_rs.build.variables = nil

      local dependencies = out_rs.dependencies
      for k, dependency in pairs(dependencies) do
         if dependency:sub(1, 4) == "lua " then
            dependencies[k] = "lua == " .. abi
         end
      end

      local install_libdir = prefix .. "lib/lua/" .. abi
      local shared_library_suffix

      if args.platform == "win32" then
         shared_library_suffix = ".dll"
      else
         shared_library_suffix = ".so"
      end

      ---@type string[]
      local install_lib = {
         install_libdir .. "/mediapipe_lua" .. shared_library_suffix,
      }

      out_rs.build.install = {
         lib = install_lib
      }

      if args.platform ~= "win32" then
         local package_data = { "mediapipe_lua.so" }

         -- add repaired libs
         if args.repair then
            local install_libsdir = install_libdir .. "/mediapipe_lua/libs"

            if first_pass then
               first_pass = false
               local install_prefix = fs.current_dir()
               local cmake_args = {
                  "-DENABLE_REPAIR=ON",
                  "-DPACKAGE_DATA=" .. dump_table_as_python_array(package_data),
                  "-DCMAKE_INSTALL_PREFIX=" .. install_prefix,
                  "-DCMAKE_INSTALL_LIBDIR=" .. install_libdir,
                  "-DCMAKE_INSTALL_LIBSDIR=" .. install_libsdir,
               }

               for _, flag in ipairs({
                  "strip",
                  "only_plat",
                  "disable_isa_ext_check",
               }) do
                  if args[flag] then
                     cmake_args[#cmake_args + 1] = "-DAUDITWHEEL_" .. flag .. "=ON"
                  end
               end

               for _, option in ipairs({
                  "plat",
                  "exclude",
               }) do
                  if args[option] ~= nil then
                     cmake_args[#cmake_args + 1] = "-DAUDITWHEEL_" .. option .. "=" .. args[option]
                  end
               end

               cmake_args[#cmake_args + 1] = "-P"
               cmake_args[#cmake_args + 1] = "mediapipe_lua/auditwheel_repair.cmake"

               fs.change_dir(prefix .. "../..")
               local ok, err = fs.execute("cmake", unpack(cmake_args))
               fs.pop_dir()

               if not ok then
                  return nil, err
               end
            end

            local files = fs.list_dir(install_libsdir)
            for _, fname in ipairs(files) do
               local lib_src = install_libsdir .. "/" .. fname
               local module_path = lib_src:sub(#install_libdir + 2)
               local ext = module_path:match("(%-[^-]+)$")
               local module_name = module_path:sub(1, -#ext - 1):gsub("/", ".")

               install_lib[module_name] = lib_src
            end
         end
      end

      -- add install_libdir .. "/mediapipe_lua" directory
      ---@type string[]
      local includes = { install_libdir .. "/mediapipe_lua" }
      while #includes ~= 0 do
         ---@type string
         local include = table.remove(includes)
         if fs.is_dir(include) then
            ---@type string[]
            local files = fs.list_dir(include)
            for i = #files, 1, -1 do
               includes[#includes + 1] = include .. "/" .. files[i]
            end
         else
            local module_name = include:sub(#install_libdir + 2)

            local ext = module_name:match("(%..+)$")
            if ext ~= nil then
               module_name = module_name:sub(1, -#ext - 1):gsub("/", ".") .. ext:gsub("%.", "#")
            end

            install_lib[module_name] = include
         end
      end

      if args.opencv_version then
         local opencv_name = args.opencv_name or "opencv_lua"

         for k, dependency in pairs(dependencies) do
            if dependency:sub(1, 11) == "opencv_lua " or dependency:sub(1, #opencv_name + 1) == opencv_name .. " " then
               local opencv_version = args.opencv_version or dependency:sub(12, -1)
               dependencies[k] = opencv_name .. " == " .. opencv_version
            end
         end
      end

      return out_rs, err, errcode
   end

   return new_version_command(args)
end

cmd.run_command(description, commands, "luarocks.cmd.external", "new_version", ...)
