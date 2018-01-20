namespace OpenCl
{
    using System;

    public abstract class HandleObject
    {
        internal readonly IntPtr handle;

        internal HandleObject(IntPtr handle)
        {
            this.handle = handle;
        }
    }
}
