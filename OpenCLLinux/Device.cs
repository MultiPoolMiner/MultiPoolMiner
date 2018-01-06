namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;

    public class Device : HandleObject
    {
        private const uint CL_DEVICE_TYPE =                                   0x1000;
        private const uint CL_DEVICE_VENDOR_ID =                              0x1001;
        private const uint CL_DEVICE_MAX_COMPUTE_UNITS =                      0x1002;
        private const uint CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS =               0x1003;
        private const uint CL_DEVICE_MAX_WORK_GROUP_SIZE =                    0x1004;
        private const uint CL_DEVICE_MAX_WORK_ITEM_SIZES =                    0x1005;
        private const uint CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR =            0x1006;
        private const uint CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT =           0x1007;
        private const uint CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT =             0x1008;
        private const uint CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG =            0x1009;
        private const uint CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT =           0x100A;
        private const uint CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE =          0x100B;
        private const uint CL_DEVICE_MAX_CLOCK_FREQUENCY =                    0x100C;
        private const uint CL_DEVICE_ADDRESS_BITS =                           0x100D;
        private const uint CL_DEVICE_MAX_READ_IMAGE_ARGS =                    0x100E;
        private const uint CL_DEVICE_MAX_WRITE_IMAGE_ARGS =                   0x100F;
        private const uint CL_DEVICE_MAX_MEM_ALLOC_SIZE =                     0x1010;
        private const uint CL_DEVICE_IMAGE2D_MAX_WIDTH =                      0x1011;
        private const uint CL_DEVICE_IMAGE2D_MAX_HEIGHT =                     0x1012;
        private const uint CL_DEVICE_IMAGE3D_MAX_WIDTH =                      0x1013;
        private const uint CL_DEVICE_IMAGE3D_MAX_HEIGHT =                     0x1014;
        private const uint CL_DEVICE_IMAGE3D_MAX_DEPTH =                      0x1015;
        private const uint CL_DEVICE_IMAGE_SUPPORT =                          0x1016;
        private const uint CL_DEVICE_MAX_PARAMETER_SIZE =                     0x1017;
        private const uint CL_DEVICE_MAX_SAMPLERS =                           0x1018;
        private const uint CL_DEVICE_MEM_BASE_ADDR_ALIGN =                    0x1019;
        private const uint CL_DEVICE_MIN_DATA_TYPE_ALIGN_SIZE =               0x101A;
        private const uint CL_DEVICE_SINGLE_FP_CONFIG =                       0x101B;
        private const uint CL_DEVICE_GLOBAL_MEM_CACHE_TYPE =                  0x101C;
        private const uint CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE =              0x101D;
        private const uint CL_DEVICE_GLOBAL_MEM_CACHE_SIZE =                  0x101E;
        private const uint CL_DEVICE_GLOBAL_MEM_SIZE =                        0x101F;
        private const uint CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE =               0x1020;
        private const uint CL_DEVICE_MAX_CONSTANT_ARGS =                      0x1021;
        private const uint CL_DEVICE_LOCAL_MEM_TYPE =                         0x1022;
        private const uint CL_DEVICE_LOCAL_MEM_SIZE =                         0x1023;
        private const uint CL_DEVICE_ERROR_CORRECTION_SUPPORT =               0x1024;
        private const uint CL_DEVICE_PROFILING_TIMER_RESOLUTION =             0x1025;
        private const uint CL_DEVICE_ENDIAN_LITTLE =                          0x1026;
        private const uint CL_DEVICE_AVAILABLE =                              0x1027;
        private const uint CL_DEVICE_COMPILER_AVAILABLE =                     0x1028;
        private const uint CL_DEVICE_EXECUTION_CAPABILITIES =                 0x1029;
        private const uint CL_DEVICE_QUEUE_PROPERTIES =                       0x102A;    /* deprecated */
        private const uint CL_DEVICE_QUEUE_ON_HOST_PROPERTIES =               0x102A;
        private const uint CL_DEVICE_NAME =                                   0x102B;
        private const uint CL_DEVICE_VENDOR =                                 0x102C;
        private const uint CL_DRIVER_VERSION =                                0x102D;
        private const uint CL_DEVICE_PROFILE =                                0x102E;
        private const uint CL_DEVICE_VERSION =                                0x102F;
        private const uint CL_DEVICE_EXTENSIONS =                             0x1030;
        private const uint CL_DEVICE_PLATFORM =                               0x1031;
        private const uint CL_DEVICE_DOUBLE_FP_CONFIG =                       0x1032;
        /* 0x1033 reserved for CL_DEVICE_HALF_FP_CONFIG */
        private const uint CL_DEVICE_PREFERRED_VECTOR_WIDTH_HALF =            0x1034;
        private const uint CL_DEVICE_HOST_UNIFIED_MEMORY =                    0x1035;   /* deprecated */
        private const uint CL_DEVICE_NATIVE_VECTOR_WIDTH_CHAR =               0x1036;
        private const uint CL_DEVICE_NATIVE_VECTOR_WIDTH_SHORT =              0x1037;
        private const uint CL_DEVICE_NATIVE_VECTOR_WIDTH_INT =                0x1038;
        private const uint CL_DEVICE_NATIVE_VECTOR_WIDTH_LONG =               0x1039;
        private const uint CL_DEVICE_NATIVE_VECTOR_WIDTH_FLOAT =              0x103A;
        private const uint CL_DEVICE_NATIVE_VECTOR_WIDTH_DOUBLE =             0x103B;
        private const uint CL_DEVICE_NATIVE_VECTOR_WIDTH_HALF =               0x103C;
        private const uint CL_DEVICE_OPENCL_C_VERSION =                       0x103D;
        private const uint CL_DEVICE_LINKER_AVAILABLE =                       0x103E;
        private const uint CL_DEVICE_BUILT_IN_KERNELS =                       0x103F;
        private const uint CL_DEVICE_IMAGE_MAX_BUFFER_SIZE =                  0x1040;
        private const uint CL_DEVICE_IMAGE_MAX_ARRAY_SIZE =                   0x1041;
        private const uint CL_DEVICE_PARENT_DEVICE =                          0x1042;
        private const uint CL_DEVICE_PARTITION_MAX_SUB_DEVICES =              0x1043;
        private const uint CL_DEVICE_PARTITION_PROPERTIES =                   0x1044;
        private const uint CL_DEVICE_PARTITION_AFFINITY_DOMAIN =              0x1045;
        private const uint CL_DEVICE_PARTITION_TYPE =                         0x1046;
        private const uint CL_DEVICE_REFERENCE_COUNT =                        0x1047;
        private const uint CL_DEVICE_PREFERRED_INTEROP_USER_SYNC =            0x1048;
        private const uint CL_DEVICE_PRINTF_BUFFER_SIZE =                     0x1049;
        private const uint CL_DEVICE_IMAGE_PITCH_ALIGNMENT =                  0x104A;
        private const uint CL_DEVICE_IMAGE_BASE_ADDRESS_ALIGNMENT =           0x104B;
        private const uint CL_DEVICE_MAX_READ_WRITE_IMAGE_ARGS =              0x104C;
        private const uint CL_DEVICE_MAX_GLOBAL_VARIABLE_SIZE =               0x104D;
        private const uint CL_DEVICE_QUEUE_ON_DEVICE_PROPERTIES =             0x104E;
        private const uint CL_DEVICE_QUEUE_ON_DEVICE_PREFERRED_SIZE =         0x104F;
        private const uint CL_DEVICE_QUEUE_ON_DEVICE_MAX_SIZE =               0x1050;
        private const uint CL_DEVICE_MAX_ON_DEVICE_QUEUES =                   0x1051;
        private const uint CL_DEVICE_MAX_ON_DEVICE_EVENTS =                   0x1052;
        private const uint CL_DEVICE_SVM_CAPABILITIES =                       0x1053;
        private const uint CL_DEVICE_GLOBAL_VARIABLE_PREFERRED_TOTAL_SIZE =   0x1054;
        private const uint CL_DEVICE_MAX_PIPE_ARGS =                          0x1055;
        private const uint CL_DEVICE_PIPE_MAX_ACTIVE_RESERVATIONS =           0x1056;
        private const uint CL_DEVICE_PIPE_MAX_PACKET_SIZE =                   0x1057;
        private const uint CL_DEVICE_PREFERRED_PLATFORM_ATOMIC_ALIGNMENT =    0x1058;
        private const uint CL_DEVICE_PREFERRED_GLOBAL_ATOMIC_ALIGNMENT =      0x1059;
        private const uint CL_DEVICE_PREFERRED_LOCAL_ATOMIC_ALIGNMENT =       0x105A;
        private const uint CL_DEVICE_IL_VERSION =                             0x105B;
        private const uint CL_DEVICE_MAX_NUM_SUB_GROUPS =                     0x105C;
        private const uint CL_DEVICE_SUB_GROUP_INDEPENDENT_FORWARD_PROGRESS = 0x105D;

        internal Device(IntPtr handle) : base(handle) { }

        // Device attributes

        public uint AddressBits
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_ADDRESS_BITS); }
        }

        public bool Available
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_AVAILABLE) != 0; }
        }

        public bool CompilerAvailable
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_COMPILER_AVAILABLE) != 0; }
        }

        public FpConfig DoubleFpConfig
        {
            get { return Cl.GetInfoEnum<FpConfig>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_DOUBLE_FP_CONFIG); }
        }

        public bool EndianLittle
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_ENDIAN_LITTLE) != 0; }
        }

        public bool ErrorCorrectionSupport
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_ERROR_CORRECTION_SUPPORT) != 0; }
        }

        public DeviceExecCapabilities ExecCapabilities
        {
            get { return Cl.GetInfoEnum<DeviceExecCapabilities>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_EXECUTION_CAPABILITIES); }
        }

        public string[] Extensions
        {
            get {
                var res = Cl.GetInfoString(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_EXTENSIONS);
                return res.Split(new char[] { ' ' });
            }
        }

        public ulong GlobalMemCacheSize
        {
            get { return Cl.GetInfo<ulong>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_GLOBAL_MEM_CACHE_SIZE); }
        }

        public DeviceMemCacheType GlobalMemCacheType
        {
            get { return Cl.GetInfoEnum<DeviceMemCacheType>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_GLOBAL_MEM_CACHE_TYPE); }
        }

        public uint GlobalMemCachelineSize
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE); }
        }

        public ulong GlobalMemSize
        {
            get { return Cl.GetInfo<ulong>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_GLOBAL_MEM_SIZE); }
        }

//        public FpConfig HalfFpConfig
//        {
//            get { return Cl.GetInfoEnum<FpConfig>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_HALF_FP_CONFIG); }
//        }

        public bool ImageSupport
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_IMAGE_SUPPORT) != 0; }
        }

//                    CL_DEVICE_IMAGE2D_MAX_HEIGHT    
//                    Return type: size_t
//
//                Max height of 2D image in pixels. The minimum value is 8192 if CL_DEVICE_IMAGE_SUPPORT is CL_TRUE.
//
//                    CL_DEVICE_IMAGE2D_MAX_WIDTH 
//                    Return type: size_t
//
//                Max width of 2D image in pixels. The minimum value is 8192 if CL_DEVICE_IMAGE_SUPPORT is CL_TRUE.
//
//                    CL_DEVICE_IMAGE3D_MAX_DEPTH 
//                    Return type: size_t
//
//                Max depth of 3D image in pixels. The minimum value is 2048 if CL_DEVICE_IMAGE_SUPPORT is CL_TRUE.
//
//                    CL_DEVICE_IMAGE3D_MAX_HEIGHT    
//                    Return type: size_t
//
//                Max height of 3D image in pixels. The minimum value is 2048 if CL_DEVICE_IMAGE_SUPPORT is CL_TRUE.
//
//                    CL_DEVICE_IMAGE3D_MAX_WIDTH 
//                    Return type: size_t
//
//                Max width of 3D image in pixels. The minimum value is 2048 if CL_DEVICE_IMAGE_SUPPORT is CL_TRUE.

        public ulong LocalMemSize
        {
            get { return Cl.GetInfo<ulong>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_LOCAL_MEM_SIZE); }
        }

        public DeviceLocalMemType LocalMemType
        {
            get { return Cl.GetInfoEnum<DeviceLocalMemType>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_LOCAL_MEM_TYPE); }
        }

        public uint MaxClockFrequency
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_CLOCK_FREQUENCY); }
        }

        public uint MaxComputeUnits
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_COMPUTE_UNITS); }
        }

        public uint MaxConstantArgs
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_CONSTANT_ARGS); }
        }

        public uint MaxConstantBufferSize
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE); }
        }

        public ulong MaxMemAllocSize
        {
            get { return Cl.GetInfo<ulong>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_MEM_ALLOC_SIZE); }
        }

        public uint MaxParameterSize
        {
            get { return (uint)Cl.GetInfo<UIntPtr>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_PARAMETER_SIZE); }
        }

        public uint MaxReadImageArgs
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_READ_IMAGE_ARGS); }
        }

        public uint MaxSamplers
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_SAMPLERS); }
        }

        public uint MaxWorkGroupSize
        {
            get { return (uint)Cl.GetInfo<UIntPtr>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_WORK_GROUP_SIZE); }
        }

        public uint MaxWorkItemDimensions
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS); }
        }

        public uint[] MaxWorkItemSizes
        {
            get {
                var sizes = Cl.GetInfoArray<UIntPtr>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_WORK_ITEM_SIZES);
                var result = new uint[sizes.Length];
                for (var i=0; i<sizes.Length; i++) {
                    result[i] = (uint)sizes[i];
                }
                return result;
            }
        }

        public uint MaxWriteImageArgs
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MAX_WRITE_IMAGE_ARGS); }
        }

        public uint MemBaseAddrAlign
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MEM_BASE_ADDR_ALIGN); }
        }

        public uint MinDataTypeAlignSize
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_MIN_DATA_TYPE_ALIGN_SIZE); }
        }

        public string Name
        {
            get { return Cl.GetInfoString(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_NAME); }
        }

        public string ClVersion
        {
            get { return Cl.GetInfoString(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_OPENCL_C_VERSION); }
        }

        public Platform Platform
        {
            get {
                var handle = Cl.GetInfo<IntPtr>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_NAME);
                return new Platform(handle);
            }
        }

        public uint PreferredVectorWidthChar
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR); }
        }

        public uint PreferredVectorWidthShort
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT); }
        }

        public uint PreferredVectorWidthInt
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT); }
        }

        public uint PreferredVectorWidthLong
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG); }
        }

        public uint PreferredVectorWidthFloat
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT); }
        }

        public uint PreferredVectorWidthDouble
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE); }
        }

        public string Profile
        {
            get { return Cl.GetInfoString(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_PROFILE); }
        }
//
//                                                CL_DEVICE_PROFILING_TIMER_RESOLUTION    
//                                                Return type: size_t
//
//                                                Describes the resolution of device timer. This is measured in nanoseconds.

        public CommandQueueProperties QueueProperties
        {
            get { return Cl.GetInfoEnum<CommandQueueProperties>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_QUEUE_PROPERTIES); }
        }

        public FpConfig SingleFpConfig
        {
            get { return Cl.GetInfoEnum<FpConfig>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_SINGLE_FP_CONFIG); }
        }

        public DeviceType Type
        {
            get { return Cl.GetInfoEnum<DeviceType>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_TYPE); }
        }

        public string Vendor
        {
            get { return Cl.GetInfoString(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_VENDOR); }
        }

        public uint VendorId
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_VENDOR_ID); }
        }

        public string Version
        {
            get { return Cl.GetInfoString(NativeMethods.clGetDeviceInfo, this.handle, CL_DEVICE_VERSION); }
        }

        public string DriverVersion
        {
            get { return Cl.GetInfoString(NativeMethods.clGetDeviceInfo, this.handle, CL_DRIVER_VERSION); }
        }

        // static factory methods

        public static Device[] GetDeviceIDs(Platform platform, DeviceType type)
        {
            ErrorCode error;
            uint count;

            error = NativeMethods.clGetDeviceIDs(platform.handle, type, 0, null, out count);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }

            var ids = new IntPtr[count] ;
            error = NativeMethods.clGetDeviceIDs(platform.handle, type, count, ids, out count);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }

            var res = new Device[count];
            for (var i=0; i<count; i++) {
                res[i] = new Device(ids[i]);
            }
            return res;
        }

        // utilities

        internal static Device[] FromIntPtr(IntPtr[] arr)
        {
            var res = new Device[arr.Length];
            for (var i=0; i<res.Length; i++) {
                res[i] = new Device(arr[i]);
            }
            return res;
        }

        internal static IntPtr[] ToIntPtr(Device[] devices)
        {
            var res = new IntPtr[devices.Length];
            for (var i=0; i<devices.Length; i++) {
                res[i] = devices[i].handle;
            }
            return res;
        }
    }
}
