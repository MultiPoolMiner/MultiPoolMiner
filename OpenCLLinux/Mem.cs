namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;

    [Flags]
    public enum MemFlags : ulong
    {
        None         = 0,
        ReadWrite    = (1 << 0),
        WriteOnly    = (1 << 1),
        ReadOnly     = (1 << 2),
        UseHostPtr   = (1 << 3),
        AllocHostPtr = (1 << 4),
        CopyHostPtr  = (1 << 5),
    }

    public enum MemObjectType : uint
    {
        Buffer  = 0x10F0,
        Image2D = 0x10F1,
        Image3D = 0x10F2,
    }

//    [DebuggerTypeProxy(typeof(MemDebugView<>))]
	public sealed class Mem<T> : RefCountedObject, IEquatable<Mem<T>> where T: struct
    {
		internal Mem(IntPtr handle) : base(handle) { }

        private const uint CL_MEM_TYPE                 = 0x1100;
        private const uint CL_MEM_FLAGS                = 0x1101;
        private const uint CL_MEM_SIZE                 = 0x1102;
        private const uint CL_MEM_HOST_PTR             = 0x1103;
        private const uint CL_MEM_MAP_COUNT            = 0x1104;
        private const uint CL_MEM_REFERENCE_COUNT      = 0x1105;
        private const uint CL_MEM_CONTEXT              = 0x1106;
        private const uint CL_MEM_ASSOCIATED_MEMOBJECT = 0x1107;
        private const uint CL_MEM_OFFSET               = 0x1108;
        private const uint CL_MEM_USES_SVM_POINTER     = 0x1109;

        // Mem attributes

        public MemObjectType Type
        {
            get { return Cl.GetInfoEnum<MemObjectType>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_TYPE); }
        }

        public MemFlags Flags
        {
            get { return Cl.GetInfoEnum<MemFlags>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_FLAGS); }
        }
        
        public uint Size
        {
            get { return (uint)Cl.GetInfo<IntPtr>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_SIZE); }
        }

        public IntPtr HostPtr
        {
            get { return Cl.GetInfo<IntPtr>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_HOST_PTR); }
        }

        public uint MapCount
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_MAP_COUNT); }
        }

        public uint ReferenceCount
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_REFERENCE_COUNT); }
        }

        public Context Context
        {
            get {
                var ctx = Cl.GetInfo<IntPtr>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_CONTEXT);
                return new Context(ctx);
            }
        }

        public Mem<T> AssociatedMemObject
        {
            get {
                var mem = Cl.GetInfo<IntPtr>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_ASSOCIATED_MEMOBJECT);
                if (mem != IntPtr.Zero) {
                    return new Mem<T>(mem);
                }
                else {
                    return null;
                }
            }
        }

        public uint Offset
        {
            get { return (uint)Cl.GetInfo<IntPtr>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_OFFSET); }
        }

        public bool UsesSvmPointer
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetMemObjectInfo, this.handle, CL_MEM_USES_SVM_POINTER) != 0; }
        }

        // RefCountedObject

		protected override void Retain()
        {
			NativeMethods.clRetainMemObject(this.handle);
        }

		protected override void Release()
        {
			NativeMethods.clReleaseMemObject(this.handle);
        }

		// IEquatable

        public bool Equals(Mem<T> other)
        {
            return this.handle == other.handle;
        }

        // static factory methods

        public static Mem<T> CreateBuffer(Context context, T[] data)
        {
            return CreateBuffer(context, MemFlags.None, data);
        }

        public static Mem<T> CreateBuffer(Context context, MemFlags flags, T[] data)
        {
            var res = IntPtr.Zero;
            var gch = GCHandle.Alloc(data, GCHandleType.Pinned);
            try {
                var size = (IntPtr)(Marshal.SizeOf<T>()*data.Length);
                ErrorCode error;
                res = NativeMethods.clCreateBuffer(context.handle, flags, size, gch.AddrOfPinnedObject(), out error);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                gch.Free();
            }
            return new Mem<T>(res);
        }

        public static Mem<T> CreateBuffer(Context context, int size)
        {
            return CreateBuffer(context, MemFlags.None, size);
        }

        public static Mem<T> CreateBuffer(Context context, MemFlags flags, int size)
        {
            ErrorCode error;
            var res = NativeMethods.clCreateBuffer(context.handle, flags, (IntPtr)size, IntPtr.Zero, out error);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return new Mem<T>(res);
        }

        public static Mem<T> CreateBuffer(Context context, uint size)
        {
            return CreateBuffer(context, MemFlags.None, size);
        }

        public static Mem<T> CreateBuffer(Context context, MemFlags flags, uint size)
        {
            ErrorCode error;
            var res = NativeMethods.clCreateBuffer(context.handle, flags, (IntPtr)size, IntPtr.Zero, out error);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return new Mem<T>(res);
        }
    }

    internal sealed class MemDebugView<T> where T: struct
    {
        private readonly Mem<T> mem;

        public MemDebugView(Mem<T> mem)
        {
            this.mem = mem;
        }

        public T[] Values
        {
            get {
                //ErrorCode err;
                var size = this.mem.Size;

                var elemSize = Marshal.SizeOf<T>();
                var length = size/elemSize;
                if (length*elemSize < size) {
                    length++;
                }
                var result = new T[length];

//                var context = this.mem.Context;
//
//                var devices = context.Devices;
//                var commandQueue = CommandQueue.CreateCommandQueue(context, devices[0], CommandQueueProperties.None);
//
//                using(var ev = commandQueue.EnqueueReadBuffer(this.mem, true, result));

                return result;
            }
        }
    }
}
