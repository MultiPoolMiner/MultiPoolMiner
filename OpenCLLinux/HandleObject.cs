namespace OpenCl
{
    using System;
    using System.Collections;
    using System.Diagnostics;
    using System.Linq;
    using System.Runtime.InteropServices;
    using System.Runtime.Serialization;
    using System.Collections.Generic;

    public abstract class HandleObject
    {
		internal readonly IntPtr handle;

		internal HandleObject(IntPtr handle)
		{
			this.handle = handle;
		}
    }
}
