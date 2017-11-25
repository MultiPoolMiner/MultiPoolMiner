namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;

    [Flags]
    public enum CommandQueueProperties : ulong
    { 
        None                     = 0,
        OutOfOrderExecModeEnable = (1 << 0),
        ProfilingEnable          = (1 << 1),
    }

    public sealed class CommandQueue : RefCountedObject
    {
		internal CommandQueue(IntPtr handle) : base(handle) { }

        private const uint CL_QUEUE_CONTEXT         = 0x1090;
        private const uint CL_QUEUE_DEVICE          = 0x1091;
        private const uint CL_QUEUE_REFERENCE_COUNT = 0x1092;
        private const uint CL_QUEUE_PROPERTIES      = 0x1093;
        private const uint CL_QUEUE_SIZE            = 0x1094;
        private const uint CL_QUEUE_DEVICE_DEFAULT  = 0x1095;

        // CommandQueue attributes

        public Context Context
        {
            get {
                var ctx = Cl.GetInfo<IntPtr>(NativeMethods.clGetCommandQueueInfo, this.handle, CL_QUEUE_CONTEXT);
                return new Context(ctx);
            }
        }
        
        public Device Device
        {
            get {
                var dev = Cl.GetInfo<IntPtr>(NativeMethods.clGetCommandQueueInfo, this.handle, CL_QUEUE_DEVICE);
                return new Device(dev);
            }
        }
        
        public uint ReferenceCount
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetCommandQueueInfo, this.handle, CL_QUEUE_REFERENCE_COUNT); }
        }

        public CommandQueueProperties Properties
        {
            get { return Cl.GetInfoEnum<CommandQueueProperties>(NativeMethods.clGetCommandQueueInfo, this.handle, CL_QUEUE_PROPERTIES); }
        }

        public uint Size
        {
            get { return (uint)Cl.GetInfo<IntPtr>(NativeMethods.clGetCommandQueueInfo, this.handle, CL_QUEUE_SIZE); }
        }

        public CommandQueue DeviceDefault
        {
            get {
                var queue = Cl.GetInfo<IntPtr>(NativeMethods.clGetCommandQueueInfo, this.handle, CL_QUEUE_DEVICE_DEFAULT);
                return new CommandQueue(queue);
            }
        }

        // CommandQueue methods

        public Event EnqueueReadBuffer<T>(Mem<T> buffer, bool blockingRead, T[] ptr) where T: struct
        {
            return EnqueueReadBuffer(buffer, blockingRead, ptr, null);
        }

        public Event EnqueueReadBuffer<T>(Mem<T> buffer, bool blockingRead, T[] ptr, Event[] eventWaitList) where T: struct
        {
            var offset = 0;
            var length = buffer.Size;
            if (length > (uint)(Marshal.SizeOf<T>()*ptr.Length)) {
                throw new ArgumentException(String.Format("Data array is to small: expected length >= {0}, found {1}.", length, Marshal.SizeOf<T>()*ptr.Length));
            }
            var numEvents = 0;
            IntPtr[] events = null;
            if (eventWaitList != null) {
                numEvents = eventWaitList.Length;
                events = Event.ToIntPtr(eventWaitList);
            }
            IntPtr result = IntPtr.Zero;
            GCHandle gch = GCHandle.Alloc(ptr, GCHandleType.Pinned);
            try {
                var error = NativeMethods.clEnqueueReadBuffer(
                    this.handle,
                    buffer.handle,
                    blockingRead ? 1u : 0u,
                    (IntPtr)offset,
//                    (IntPtr)(Marshal.SizeOf<T>()*ptr.Length),
                    (IntPtr)length,
                    gch.AddrOfPinnedObject(),
                    (uint)numEvents,
                    events,
                    out result);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                gch.Free();
            }
            return new Event(result);
        }

        public Event EnqueueReadBuffer<T>(Mem<T> buffer, bool blockingRead, uint offset, uint length, T[] ptr, Event[] eventWaitList) where T: struct
        {
            var numEvents = 0;
            IntPtr[] events = null;
            if (eventWaitList != null) {
                numEvents = eventWaitList.Length;
                events = Event.ToIntPtr(eventWaitList);
            }
            IntPtr result = IntPtr.Zero;
            GCHandle gch = GCHandle.Alloc(ptr, GCHandleType.Pinned);
            try {
                var error = NativeMethods.clEnqueueReadBuffer(
                    this.handle,
                    buffer.handle,
                    blockingRead ? 1u : 0u,
                    (IntPtr)offset,
                    (IntPtr)length,
                    gch.AddrOfPinnedObject(),
                    (uint)numEvents,
                    events,
                    out result);
                if (error != ErrorCode.Success) {
                    throw new OpenClException(error);
                }
            }
            finally {
                gch.Free();
            }
            return new Event(result);
        }

        public Event EnqueueNDRangeKernel(Kernel kernel, uint[] globalWorkOffset, uint[] globalWorkSize, uint[] localWorkSize, Event[] eventWaitList)
        {
            var workDim = globalWorkSize.Length;
            if (globalWorkOffset != null && globalWorkOffset.Length != workDim) {
                throw new ArgumentException(String.Format("Invalid length of globalWorkOffset array: expected {0}, found {1}.", workDim, globalWorkOffset.Length));
            }
            if (localWorkSize != null && localWorkSize.Length != workDim) {
                throw new ArgumentException(String.Format("Invalid length of localWorkSize array: expected {0}, found {1}.", workDim, localWorkSize.Length));
            }
            var numEvents = 0;
            IntPtr[] events = null;
            if (eventWaitList != null) {
                numEvents = eventWaitList.Length;
                events = Event.ToIntPtr(eventWaitList);
            }
            IntPtr result;
            var error = NativeMethods.clEnqueueNDRangeKernel(this.handle, kernel.handle, (uint)workDim, globalWorkOffset, globalWorkSize, localWorkSize, (uint)numEvents, events, out result);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return new Event(result);
        }        

        public Event EnqueueNDRangeKernel(Kernel kernel, int[] globalWorkOffset, int[] globalWorkSize, int[] localWorkSize, Event[] eventWaitList)
        {
            var workDim = globalWorkSize.Length;
            if (globalWorkOffset != null && globalWorkOffset.Length != workDim) {
                throw new ArgumentException(String.Format("Invalid length of globalWorkOffset array: expected {0}, found {1}.", workDim, globalWorkOffset.Length));
            }
            if (localWorkSize != null && localWorkSize.Length != workDim) {
                throw new ArgumentException(String.Format("Invalid length of localWorkSize array: expected {0}, found {1}.", workDim, localWorkSize.Length));
            }
            var numEvents = 0;
            IntPtr[] events = null;
            if (eventWaitList != null) {
                numEvents = eventWaitList.Length;
                events = Event.ToIntPtr(eventWaitList);
            }
            IntPtr result;
            var error = NativeMethods.clEnqueueNDRangeKernel(this.handle, kernel.handle, workDim, globalWorkOffset, globalWorkSize, localWorkSize, numEvents, events, out result);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return new Event(result);
        }

        public void Finish()
        {
            NativeMethods.clFinish(this.handle);
        }

        // RefCountedObject

		protected override void Retain()
        {
			NativeMethods.clRetainCommandQueue(this.handle);
        }

		protected override void Release()
        {
			NativeMethods.clReleaseCommandQueue(this.handle);
        }

        // static factory methods

        public static CommandQueue CreateCommandQueue(Context context, Device device)
        {
            return CreateCommandQueue(context, device, CommandQueueProperties.None);
        }

        public static CommandQueue CreateCommandQueue(Context context, Device device, CommandQueueProperties properties)
        {
            ErrorCode error;
            var res = NativeMethods.clCreateCommandQueue(context.handle, device.handle, properties, out error);
            if (error != ErrorCode.Success) {
                throw new OpenClException(error);
            }
            return new CommandQueue(res);
        }
    }
}
