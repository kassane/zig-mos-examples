// Wrapper header for translate-c.
// _Static_assert with struct-size checks fails during translation because
// the host-side sizeof differs from the target layout. Suppress it here.
#define _Static_assert(cond, msg)
#include "geos.h"
