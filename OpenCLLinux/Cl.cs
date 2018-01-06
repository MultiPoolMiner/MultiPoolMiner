namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;

    [Flags]
    public enum FpConfig : ulong
    {
        FpDenorm                     = (1 << 0),
        FpInfNan                     = (1 << 1),
        FpRoundToNearest             = (1 << 2),
        FpRoundToZero                = (1 << 3),
        FpRoundToInf                 = (1 << 4),
        FpFma                        = (1 << 5),
        FpSoftFloat                  = (1 << 6),
        FpCorrectlyRoundedDivideSqrt = (1 << 7),
    }

	public enum ProfilingInfo: int
	{
		Queued = 0x1280,
		Submit = 0x1281,
		Start  = 0x1282,
		End    = 0x1283,
	};

	public enum SamplerInfo : uint
	{
		ReferenceCount = 0x1150,
		Context = 0x1151,
		NormalizedCoords = 0x1152,
		AddressingMode = 0x1153,
		FilterMode = 0x1154,
	};

	public enum FilterMode : uint
	{
		Nearest = 0x1140,
		Linear = 0x1141,
	};

	public enum AddressingMode : uint
	{
		None = 0x1130,
		ClampToEdge = 0x1131,
		Clamp = 0x1132,
		Repeat = 0x1133,
	};

	public enum EventInfo: int
	{
		CommandQueue = 0x11D0,
		CommandType = 0x11D1,
		ReferenceCount = 0x11D2,
		CommandExecutionStatus = 0x11D3,
	};

	[Flags]
	public enum MapFlags: int
	{
		Read  = (1 << 0),
		Write = (1 << 1),
	}

	public enum KernelWorkGroupInfo : int // cl_int
	{
		WorkGroupSize = 0x11B0,
		CompileWorkGroupSize = 0x11B1,
		LocalMemSize = 0x11B2
	};

	public enum KernelInfo : int // cl_int
	{
		FunctionName = 0x1190,
		NumArgs = 0x1191,
		ReferenceCount = 0x1192,
		Context = 0x1193,
		Program = 0x1194
	}

	public enum CommandQueueInfo : int // cl_int
	{
		Context = 0x1090,
		Device = 0x1091,
		ReferenceCount = 0x1092,
		Properties = 0x1093
	}

	public enum ImageInfo : uint // cl_uint
	{
		Format = 0x1110,
		ElementSize = 0x1111,
		RowPitch = 0x1112,
		SlicePitch = 0x1113,
		Width = 0x1114,
		Height = 0x1115,
		Depth = 0x1116,
	};

	public enum MemInfo : uint // cl_uint
	{
		Type = 0x1100,
		Flags = 0x1101,
		Size = 0x1102,
		HostPtr = 0x1103,
		MapCount = 0x1104,
		ReferenceCount = 0x1105,
		Context = 0x1106,
	};

	public enum ContextInfo : uint // cl_uint
	{
		ReferenceCount = 0x1080,
		Devices = 0x1081,
		Properties = 0x1082,
	};

	public enum ChannelType : uint
	{
		SnormInt8      = 0x10D0,
		SnormInt16     = 0x10D1,
		UnormInt8      = 0x10D2,
		UnormInt16     = 0x10D3,
		UnormShort565  = 0x10D4,
		UnormShort555  = 0x10D5,
		UnormInt101010 = 0x10D6,
		SignedInt8     = 0x10D7,
		SignedInt16    = 0x10D8,
		SignedInt32    = 0x10D9,
		UnsignedInt8   = 0x10DA,
		UnsignedInt16  = 0x10DB,
		UnsignedInt32  = 0x10DC,
		HalfFloat      = 0x10DD,
		Float          = 0x10DE,
	};

	public enum ChannelOrder : uint
	{
		R         = 0x10B0,
		A         = 0x10B1,
		RG        = 0x10B2,
		RA        = 0x10B3,
		RGB       = 0x10B4,
		RGBA      = 0x10B5,
		BGRA      = 0x10B6,
		ARGB      = 0x10B7,
		Intensity = 0x10B8,
		Luminance = 0x10B9,
	};

    [Flags]
    public enum DeviceExecCapabilities : ulong
    {
        ExecKernel       = (1 << 0),
        ExecNativeKernel = (1 << 1),
    }

    [Flags]
    public enum DeviceType : ulong
    {
        Default     = (1 << 0),
        Cpu         = (1 << 1),
        Gpu         = (1 << 2),
        Accelerator = (1 << 3),
        All         = 0xFFFFFFFF,
    }

    public enum DeviceMemCacheType : uint
    {
        None           = 0x0,
        ReadOnlyCache  = 0x1,
        ReadWriteCache = 0x2,
    }

    public enum DeviceLocalMemType : uint
    {
        Local  = 0x1,
        Global = 0x2,
    }

	public enum ErrorCode : int
	{
		Success = 0,

		DeviceNotFound = -1,
		DeviceNotAvailable = -2,
		CompilerNotAvailable = -3,
		MemObjectAllocationFailure = -4,
		OutOfResources = -5,
		OutOfHostMemory = -6,
		ProfilingInfoNotAvailable = -7,
		MemCopyOverlap = -8,
		ImageFormatMismatch = -9,
		ImageFormatNotSupported = -10,
		BuildProgramFailure = -11,
		MapFailure = -12,

		InvalidValue = -30,
		InvalidDeviceType = -31,
		InvalidPlatform = -32,
		InvalidDevice = -33,
		InvalidContext = -34,
		InvalidQueueProperties = -35,
		InvalidCommandQueue = -36,
		InvalidHostPtr = -37,
		InvalidMemObject = -38,
		InvalidImageFormatDescriptor = -39,
		InvalidImageSize = -40,
		InvalidSampler = -41,
		InvalidBinary = -42,
		InvalidBuildOptions = -43,
		InvalidProgram = -44,
		InvalidProgramExecutable = -45,
		InvalidKernelName = -46,
		InvalidKernelDefinition = -47,
		InvalidKernel = -48,
		InvalidArgIndex = -49,
		InvalidArgValue = -50,
		InvalidArgSize = -51,
		InvalidKernelArgs = -52,
		InvalidWorkDimension = -53,
		InvalidWorkGroupSize = -54,
		InvalidWorkItemSize = -55,
		InvalidGlobalOffset = -56,
		InvalidEventWaitList = -57,
		InvalidEvent = -58,
		InvalidOperation = -59,
		InvalidGlObject = -60,
		InvalidBufferSize = -61,
		InvalidMipLevel = -62,
	};

    internal delegate ErrorCode GetInfoDelegate(IntPtr handle, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

    internal delegate ErrorCode GetBuildInfoDelegate(IntPtr program, IntPtr device, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

    internal static class Cl
    {

        internal static T GetInfo<T>(GetInfoDelegate method, IntPtr handle, uint name) where T: struct
        {
            IntPtr size;
            object result = default(T);
            var h = GCHandle.Alloc(result, GCHandleType.Pinned);
            try {
                ErrorCode error = method(handle, name, (IntPtr)Marshal.SizeOf<T>(), h.AddrOfPinnedObject(), out size);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                h.Free();
            }
            return (T)result;
        }

        internal static string GetInfoString(GetInfoDelegate method, IntPtr handle, uint name)
        {
            IntPtr size;
            ErrorCode error = method(handle, name, IntPtr.Zero, IntPtr.Zero, out size);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            string result = null;
            IntPtr buf = Marshal.AllocHGlobal(size);
            try {
                error = method(handle, name, size, buf, out size);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
                result = Marshal.PtrToStringAnsi(buf);
            }
            finally {
                Marshal.FreeHGlobal(buf);
            }
            return result;
        }

        internal static T GetInfoEnum<T>(GetInfoDelegate method, IntPtr handle, uint name) where T: struct
        {
            var type = Enum.GetUnderlyingType(typeof(T));
            var result = Activator.CreateInstance(type);
            var size = (IntPtr)Marshal.SizeOf(type);
            var h = GCHandle.Alloc(result, GCHandleType.Pinned);
            try {
                ErrorCode error = method(handle, name, size, h.AddrOfPinnedObject(), out size);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                h.Free();
            }
            return (T)result;
        }

        internal static T[] GetInfoArray<T>(GetInfoDelegate method, IntPtr handle, uint name) where T: struct
        {
            IntPtr size;
            ErrorCode error = method(handle, name, IntPtr.Zero, IntPtr.Zero, out size);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            int count = (int)size/Marshal.SizeOf<T>();
            if (count*Marshal.SizeOf<T>() < (int)size) {
                count++;
            }
            T[] result = new T[count];
            GCHandle gch = GCHandle.Alloc(result, GCHandleType.Pinned);
            try {
                error = method(handle, name, (IntPtr)(count*Marshal.SizeOf<T>()), gch.AddrOfPinnedObject(), out size);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                gch.Free();
            }
            return result;
        }

        internal static T GetBuildInfo<T>(GetBuildInfoDelegate method, IntPtr program, IntPtr device, uint name) where T : struct
        {
            IntPtr size;
            T result = default(T);
            var h = GCHandle.Alloc(result, GCHandleType.Pinned);
            try {
                ErrorCode error = method(program, device, name, (IntPtr)Marshal.SizeOf<T>(), h.AddrOfPinnedObject(), out size);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                h.Free();
            }
            return result;
        }

        internal static string GetBuildInfoString(GetBuildInfoDelegate method, IntPtr program, IntPtr device, uint name)
        {
            IntPtr size;
            ErrorCode error = method(program, device, name, IntPtr.Zero, IntPtr.Zero, out size);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            string result = null;
            IntPtr buf = Marshal.AllocHGlobal(size);
            try {
                error = method(program, device, name, size, buf, out size);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
                result = Marshal.PtrToStringAnsi(buf);
            }
            finally {
                Marshal.FreeHGlobal(buf);
            }
            return result;
        }

        internal static T GetBuildInfoEnum<T>(GetBuildInfoDelegate method, IntPtr program, IntPtr device, uint name) where T : struct
        {
            var type = Enum.GetUnderlyingType(typeof(T));
            var result = Activator.CreateInstance(type);
            var size = (IntPtr)Marshal.SizeOf(type);
            var h = GCHandle.Alloc(result, GCHandleType.Pinned);
            try {
                ErrorCode error = method(program, device, name, size, h.AddrOfPinnedObject(), out size);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                h.Free();
            }
            return (T)result;
        }
    }
}
