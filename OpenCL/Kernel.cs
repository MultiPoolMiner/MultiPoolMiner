using System;
using System.Runtime.InteropServices;

namespace OpenCl
{
    public sealed class Kernel : RefCountedObject
    {
		internal Kernel(IntPtr handle) : base(handle) { }

        private const uint CL_KERNEL_FUNCTION_NAME          = 0x1190;
        private const uint CL_KERNEL_NUM_ARGS               = 0x1191;
        private const uint CL_KERNEL_REFERENCE_COUNT        = 0x1192;
        private const uint CL_KERNEL_CONTEXT                = 0x1193;
        private const uint CL_KERNEL_PROGRAM                = 0x1194;
        private const uint CL_KERNEL_ATTRIBUTES             = 0x1195;
        private const uint CL_KERNEL_MAX_NUM_SUB_GROUPS     = 0x11B9;
        private const uint CL_KERNEL_COMPILE_NUM_SUB_GROUPS = 0x11BA;

        // Kernel attributes

        public string FunctionName
        {
            get { return Cl.GetInfoString(NativeMethods.clGetKernelInfo, this.handle, CL_KERNEL_FUNCTION_NAME); }
        }

        public uint NumArgs
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetKernelInfo, this.handle, CL_KERNEL_NUM_ARGS); }
        }

        public uint ReferenceCount
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetKernelInfo, this.handle, CL_KERNEL_REFERENCE_COUNT); }
        }

        public Context Context
        {
            get {
                var ctx = Cl.GetInfo<IntPtr>(NativeMethods.clGetKernelInfo, this.handle, CL_KERNEL_CONTEXT);
                return new Context(ctx);
            }
        }

        public Program Program
        {
            get {
                var prog = Cl.GetInfo<IntPtr>(NativeMethods.clGetKernelInfo, this.handle, CL_KERNEL_PROGRAM);
                return new Program(prog);
            }
        }

        public string[] Attributes
        {
            get {
                var res = Cl.GetInfoString(NativeMethods.clGetKernelInfo, this.handle, CL_KERNEL_ATTRIBUTES);
                return res.Split(new char[] { ' ' });
            }
        }

        // Kernel methods

        public void SetKernelArg<T>(uint idx, T val) where T: struct
        {
            var size = (IntPtr)Marshal.SizeOf<T>();
            GCHandle gch = GCHandle.Alloc(val, GCHandleType.Pinned);
            try {
                var error = NativeMethods.clSetKernelArg(this.handle, idx, size, gch.AddrOfPinnedObject());
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                gch.Free();
            }
        }

        public void SetKernelArg(uint idx, HandleObject val)
        {
            var size = (IntPtr)Marshal.SizeOf<IntPtr>();
            IntPtr obj = val.handle;
            var error = NativeMethods.clSetKernelArg(this.handle, idx, size, ref obj);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
        }

        // RefCountedObject

		protected override void Retain()
        {
            NativeMethods.clRetainKernel(this.handle);
        }

		protected override void Release()
        {
            NativeMethods.clReleaseKernel(this.handle);
        }

        // static factory methods

        public static Kernel CreateKernel(Program program, string name)
        {
            ErrorCode error;
            var handle = NativeMethods.clCreateKernel(program.handle, name, out error);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return new Kernel(handle);
        }

        public static Kernel[] CreateKernelsInProgram(Program program)
        {
            ErrorCode error;
            uint numKernels;
            error = NativeMethods.clCreateKernelsInProgram(program.handle, 0, null, out numKernels);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            IntPtr[] kernels = new IntPtr[numKernels];
            error = NativeMethods.clCreateKernelsInProgram(program.handle, numKernels, kernels, out numKernels);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return Kernel.FromIntPtr(kernels);
        }

        // utilities

        internal static Kernel[] FromIntPtr(IntPtr[] arr)
        {
            var res = new Kernel[arr.Length];
            for (var i=0; i<res.Length; i++) {
                res[i] = new Kernel(arr[i]);
            }
            return res;
        }

        internal static IntPtr[] ToIntPtr(Kernel[] kernels)
        {
            var res = new IntPtr[kernels.Length];
            for (var i=0; i<kernels.Length; i++) {
                res[i] = kernels[i].handle;
            }
            return res;
        }
    }
}
