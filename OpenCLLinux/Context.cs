namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;

    public delegate void ContextNotify(string errInfo, object userData);

    internal delegate void ContextNotifyInternal(IntPtr errInfo, IntPtr privateData, IntPtr cb, IntPtr userData);

    internal class ContextNotifyData : IDisposable
    {
        private ContextNotify callback;
        private object data;

        private GCHandle handle;

        public ContextNotifyData(ContextNotify callback, object data)
        {
            this.callback = callback;
            this.data = data;
            this.handle = GCHandle.Alloc(this, GCHandleType.Normal);
        }

        ~ContextNotifyData()
        {
            Dispose(false);
        }

        public static void Callback(IntPtr errInfo, IntPtr privateData, IntPtr cb, IntPtr userData)
        {
            var h = GCHandle.FromIntPtr(userData);
            var d = h.Target as ContextNotifyData;
            d.callback(Marshal.PtrToStringAnsi(errInfo), d.data);
        }

        public IntPtr Handle
        {
            get { return GCHandle.ToIntPtr(this.handle); }
        }

        // IDisposable

        private bool disposed = false;

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!disposed) {
                this.handle.Free();
                disposed = true;
            }
        }
    }

    public enum ContextProperties : uint
    {
        Platform = 0x1084,
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ContextProperty
    {
        public static readonly ContextProperty Zero = new ContextProperty(0);

        private readonly uint name;
        private readonly IntPtr value;

        public ContextProperty(ContextProperties property, IntPtr value)
        {
            this.name = (uint)property;
            this.value = value;
        }

        public ContextProperty(ContextProperties property)
        {
            this.name = (uint)property;
            this.value = IntPtr.Zero;
        }

        public ContextProperties Name
        {
            get { return (ContextProperties)this.name; }
        }

        public IntPtr Value
        {
            get { return this.value; }
        }
    }

    public sealed class Context : RefCountedObject
    {
//        public static readonly Context Zero = new Context(IntPtr.Zero, default(GCHandle));

        private const uint CL_CONTEXT_REFERENCE_COUNT = 0x1080;
        private const uint CL_CONTEXT_DEVICES         = 0x1081;
        private const uint CL_CONTEXT_PROPERTIES      = 0x1082;
        private const uint CL_CONTEXT_NUM_DEVICES     = 0x1083;

        private ContextNotifyData callback;

        internal Context(IntPtr handle) : this(handle, null) { }

        internal Context(IntPtr handle, ContextNotifyData cb) : base(handle)
        { 
            this.callback = cb;
        }

        // Context attributes

        public uint ReferenceCount
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetContextInfo, this.handle, CL_CONTEXT_REFERENCE_COUNT); }
        }

        public Device[] Devices
        {
            get { return Device.FromIntPtr(Cl.GetInfoArray<IntPtr>(NativeMethods.clGetContextInfo, this.handle, CL_CONTEXT_REFERENCE_COUNT)); }
        }

        public ContextProperty[] Properties
        {
            get { return Cl.GetInfoArray<ContextProperty>(NativeMethods.clGetContextInfo, this.handle, CL_CONTEXT_PROPERTIES); }
        }

        // RefCountedHandle

        protected override void Retain()
        {
            NativeMethods.clRetainContext(this.handle);
        }

        protected override void Release()
        {
            NativeMethods.clReleaseContext(this.handle);
        }

        // IDisposable

        private bool disposed = false;

        protected override void Dispose(bool disposing)
        {
            if (!disposed) {
                if (disposing && this.callback != null) {
                    this.callback.Dispose();
                }
                this.callback = null;
                this.disposed = true;
            }
            base.Dispose(disposing);
        }

        // static factory methods

        public static Context CreateContext(Platform platform, Device[] devices, ContextNotify callback, object userData)
        {
            var pty = new ContextProperty[] { new ContextProperty(ContextProperties.Platform, platform.handle), ContextProperty.Zero };
            var num = devices.Length;
            var dev = new IntPtr[num];
            for (var i=0; i<num; i++) {
                dev[i] = devices[i].handle;
            }
            var pfn = (ContextNotifyData)null;
            var pcb = (ContextNotifyInternal)null;
            var ptr = IntPtr.Zero;
            if (callback != null) {
                pfn = new ContextNotifyData(callback, userData);
                pcb = ContextNotifyData.Callback;
                ptr = pfn.Handle;
            }
            var err = ErrorCode.Success;
            var ctx = NativeMethods.clCreateContext(pty, (uint)num, dev, pcb, ptr, out err);
            if (err != ErrorCode.Success) {
                throw new OpenClException(err);
            }
            return new Context(ctx, pfn);
        }

        public static Context CreateContextFromType(Platform platform, DeviceType type, ContextNotify callback, object userData)
        {
            var pty = new ContextProperty[] { new ContextProperty(ContextProperties.Platform, platform.handle), ContextProperty.Zero };
            var pfn = (ContextNotifyData)null;
            var pcb = (ContextNotifyInternal)null;
            var ptr = IntPtr.Zero;
            if (callback != null) {
                pfn = new ContextNotifyData(callback, userData);
                pcb = ContextNotifyData.Callback;
                ptr = pfn.Handle;
            }
            var err = ErrorCode.Success;
            var ctx = NativeMethods.clCreateContextFromType(pty, type, pcb, ptr, out err);
            if (err != ErrorCode.Success) {
                throw new OpenClException(err);
            }
            return new Context(ctx, pfn);
        }
    }

}
