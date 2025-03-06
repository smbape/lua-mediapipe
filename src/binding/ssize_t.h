#pragma once

#ifdef ssize_t
#define _stringify(s) #s
#define stringify(s) _stringify(s)
#error "ssize_t is a macro. Either undefined it or do not include this file"
#endif

#pragma push_macro("ssize_t")
#ifdef ssize_t
#undef ssize_t
#endif

// https://www.scivision.dev/ssize_t-platform-independent/
#include <cstddef>
namespace google::protobuf::lua {
	using ssize_t = std::ptrdiff_t;
}

#pragma pop_macro("ssize_t")
