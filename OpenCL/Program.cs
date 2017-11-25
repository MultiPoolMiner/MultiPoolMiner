namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;
    using System.Linq.Expressions;
    using System.Text;

    public delegate void ProgramNotify(Program program, object userData);

    internal delegate void ProgramNotifyInternal(IntPtr program, IntPtr userData);

    internal class ProgramNotifyData
    {
        private ProgramNotify callback;
        private object data;
        private GCHandle handle;
        public ProgramNotifyData(ProgramNotify callback, object data)
        {
            this.callback = callback;
            this.data = data;
            this.handle = GCHandle.Alloc(this);
        }
        internal GCHandle Handle
        {
            get {
                if (!this.handle.IsAllocated) {
                    throw new InvalidOperationException();
                }
                return this.handle;
            }
        }
        public static void Callback(IntPtr program, IntPtr userData)
        {
            var h = GCHandle.FromIntPtr(userData);
            var d = h.Target as ProgramNotifyData;
            d.callback(new Program(program), d.data);
            h.Free();
        }
    }

    public enum BuildStatus : int
    {
        Success    =  0,
        None       = -1,
        Error      = -2,
        InProgress = -3,
    }

    public enum BinaryType : uint
    {
        None           = 0x0,
        CompiledObject = 0x1,
        Library        = 0x2,
        Executable     = 0x4,
    }

    public sealed class BuildInfo
    {
        private const uint CL_PROGRAM_BUILD_STATUS                     = 0x1181;
        private const uint CL_PROGRAM_BUILD_OPTIONS                    = 0x1182;
        private const uint CL_PROGRAM_BUILD_LOG                        = 0x1183;
        private const uint CL_PROGRAM_BINARY_TYPE                      = 0x1184;
        private const uint CL_PROGRAM_BUILD_GLOBAL_VARIABLE_TOTAL_SIZE = 0x1185;

        private readonly Program owner;

        internal BuildInfo(Program owner)
        {
            this.owner = owner;
        }

        public BuildStatus GetStatus(Device device)
        {
            return Cl.GetBuildInfoEnum<BuildStatus>(NativeMethods.clGetProgramBuildInfo, this.owner.handle, device.handle, CL_PROGRAM_BUILD_STATUS);
        }

        public string GetOptions(Device device)
        {
            return Cl.GetBuildInfoString(NativeMethods.clGetProgramBuildInfo, this.owner.handle, device.handle, CL_PROGRAM_BUILD_OPTIONS);
        }

        public string GetLog(Device device)
        {
            return Cl.GetBuildInfoString(NativeMethods.clGetProgramBuildInfo, this.owner.handle, device.handle, CL_PROGRAM_BUILD_LOG);
        }

        public BinaryType GetBinaryType(Device device)
        {
            return Cl.GetBuildInfoEnum<BinaryType>(NativeMethods.clGetProgramBuildInfo, this.owner.handle, device.handle, CL_PROGRAM_BINARY_TYPE);
        }

    }

    public sealed class Program : RefCountedObject
    {
        private const uint CL_PROGRAM_REFERENCE_COUNT = 0x1160;
        private const uint CL_PROGRAM_CONTEXT         = 0x1161;
        private const uint CL_PROGRAM_NUM_DEVICES     = 0x1162;
        private const uint CL_PROGRAM_DEVICES         = 0x1163;
        private const uint CL_PROGRAM_SOURCE          = 0x1164;
        private const uint CL_PROGRAM_BINARY_SIZES    = 0x1165;
        private const uint CL_PROGRAM_BINARIES        = 0x1166;
        private const uint CL_PROGRAM_NUM_KERNELS     = 0x1167;
        private const uint CL_PROGRAM_KERNEL_NAMES    = 0x1168;
        private const uint CL_PROGRAM_IL              = 0x1169;

        internal Program(IntPtr handle) : base(handle) { }

        // Program attributes

        public uint ReferenceCount
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetProgramInfo, this.handle, CL_PROGRAM_REFERENCE_COUNT); }
        }

        public Context Context
        {
            get {
                var ctx = Cl.GetInfo<IntPtr>(NativeMethods.clGetProgramInfo, this.handle, CL_PROGRAM_CONTEXT);
                return new Context(ctx);
            }
        }

        public uint NumDevices
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetProgramInfo, this.handle, CL_PROGRAM_NUM_DEVICES); }
        }

        public Device[] Devices
        {
            get { return Device.FromIntPtr(Cl.GetInfoArray<IntPtr>(NativeMethods.clGetProgramInfo, this.handle, CL_PROGRAM_DEVICES)); }
        }

        public string Source
        {
            get { return Cl.GetInfoString(NativeMethods.clGetProgramInfo, this.handle, CL_PROGRAM_SOURCE); }
        }

        public IntPtr[] BinarySizes
        {
            get { return Cl.GetInfoArray<IntPtr>(NativeMethods.clGetProgramInfo, this.handle, CL_PROGRAM_BINARY_SIZES); }
        }

        public byte[][] Binaries
        {
            get { throw new NotImplementedException(); }
        }

        // Program build attributes

        private BuildInfo bi;

        public BuildInfo BuildInfo
        {
            get {
                if (this.bi == null) {
                    this.bi = new BuildInfo(this);
                }
                return this.bi;
            }
        }

        // Program methods

        public void BuildProgram(Device[] deviceList, string options, ProgramNotify callback, object userData)
        {
            var dev = Device.ToIntPtr(deviceList);
            var pfn = (ProgramNotifyData)null;
            var pcb = (ProgramNotifyInternal)null;
            var ptr = IntPtr.Zero;
            if (callback != null) {
                pfn = new ProgramNotifyData(callback, userData);
                pcb = ProgramNotifyData.Callback;
                ptr = GCHandle.ToIntPtr(pfn.Handle);
            }
            var err = NativeMethods.clBuildProgram(this.handle, (uint)dev.Length, dev, options, pcb, ptr);
            if (err != ErrorCode.Success) {
                throw new OpenClException(err);
            }
        }

        // RefCountedObject

        protected override void Retain()
        {
			NativeMethods.clRetainProgram(this.handle);
        }

		protected override void Release()
        {
			NativeMethods.clReleaseProgram(this.handle);
        }

        // static factory methods

        public static Program CreateProgramWithSource(Context context, string[] sources)
        {
            ErrorCode error;
            IntPtr[] buffers = new IntPtr[sources.Length];
            for (var i=0; i<sources.Length; i++) {
                buffers[i] = Marshal.StringToHGlobalAnsi(sources[i]);
            }
            IntPtr[] lengths = new IntPtr[sources.Length];
            for (var i=0; i<sources.Length; i++) {
                lengths[i] = (IntPtr)sources[i].Length;
            }
            var handle = NativeMethods.clCreateProgramWithSource(context.handle, (uint)sources.Length, sources, lengths, out error);
            for (var i=0; i<sources.Length; i++) {
                Marshal.FreeHGlobal(buffers[i]);
            }
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return new Program(handle);
        }

        public static Program CreateProgramWithExpression(Context context, Expression[] expressions)
        {
            var n = expressions.Length;
            var sources = new string[n];
            for (var i=0; i<n; i++) {
                var vi = new ClVisitor();
                vi.Visit(expressions[i]);
                sources[i] = vi.Text;
            }
            return CreateProgramWithSource(context, sources);
        }
    }

    internal sealed class ClVisitor : ExpressionVisitor
    {
        private readonly StringBuilder builder;

        public ClVisitor()
        {
            this.builder = new StringBuilder();
        }

        public string Text
        {
            get { return this.builder.ToString(); }
        }

        // ExpressionVisitor methods

        protected override Expression VisitBlock(BlockExpression node)
        {
            this.builder.AppendLine("{");
            base.VisitBlock(node);
            this.builder.AppendLine("}");
            return node;
        }
    }
}
