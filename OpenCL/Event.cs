using System;
using System.Runtime.InteropServices;

namespace OpenCl
{
    public enum ExecutionStatus : int
    {
        Complete  = 0x0,
        Running   = 0x1,
        Submitted = 0x2,
        Queued    = 0x3,
    }

    public enum CommandType : uint
    {
        NDRangeKernel     = 0x11F0,
        Task              = 0x11F1,
        NativeKernel      = 0x11F2,
        ReadBuffer        = 0x11F3,
        WriteBuffer       = 0x11F4,
        CopyBuffer        = 0x11F5,
        ReadImage         = 0x11F6,
        WriteImage        = 0x11F7,
        CopyImage         = 0x11F8,
        CopyImageToBuffer = 0x11F9,
        CopyBufferToImage = 0x11FA,
        MapBuffer         = 0x11FB,
        MapImage          = 0x11FC,
        UnmapMemObject    = 0x11FD,
        Marker            = 0x11FE,
        AcquireGlObjects  = 0x11FF,
        ReleaseGlObjects  = 0x1200,
        ReadBufferRect    = 0x1201,
        WriteBufferRect   = 0x1202,
        CopyBufferRect    = 0x1203,
        User              = 0x1204,
        Barrier           = 0x1205,
        MigrateMemObjects = 0x1206,
        FillBuffer        = 0x1207,
        FillImage         = 0x1208,
        SvmFree           = 0x1209,
        SvmMemcpy         = 0x120A,
        SvmMemfill        = 0x120B,
        SvmMap            = 0x120C,
        SvmUnmap          = 0x120D,
    }

    public sealed class Event : RefCountedObject
    {
        private const uint CL_EVENT_COMMAND_QUEUE            = 0x11D0;
        private const uint CL_EVENT_COMMAND_TYPE             = 0x11D1;
        private const uint CL_EVENT_REFERENCE_COUNT          = 0x11D2;
        private const uint CL_EVENT_COMMAND_EXECUTION_STATUS = 0x11D3;
        private const uint CL_EVENT_CONTEXT                  = 0x11D4;

        internal Event(IntPtr handle) : base(handle) { }

        // Event attributes

        public CommandQueue CommandQueue
        {
            get {
                var queue = Cl.GetInfo<IntPtr>(NativeMethods.clGetEventInfo, this.handle, CL_EVENT_COMMAND_QUEUE);
                return new CommandQueue(queue);
            }
        }

        public CommandType CommandType
        {
            get { return Cl.GetInfoEnum<CommandType>(NativeMethods.clGetEventInfo, this.handle, CL_EVENT_COMMAND_TYPE); }
        }
        
        public uint ReferenceCount
        {
            get { return Cl.GetInfo<uint>(NativeMethods.clGetEventInfo, this.handle, CL_EVENT_REFERENCE_COUNT); }
        }
        
        public ExecutionStatus ExecutionStatus
        {
            get { return Cl.GetInfoEnum<ExecutionStatus>(NativeMethods.clGetEventInfo, this.handle, CL_EVENT_COMMAND_EXECUTION_STATUS); }
        }

        public Context Context
        {
            get {
                var ctx = Cl.GetInfo<IntPtr>(NativeMethods.clGetEventInfo, this.handle, CL_EVENT_CONTEXT);
                return new Context(ctx);
            }
        }

        // Event methods

        public static void WaitForEvents(Event[] eventWaitList)
        {
            var l = ToIntPtr(eventWaitList);
            NativeMethods.clWaitForEvents((uint)l.Length, l);
        }

        // RefCountedObject

		protected override void Retain()
        {
            NativeMethods.clRetainEvent(this.handle);
        }

		protected override void Release()
        {
			NativeMethods.clReleaseEvent(this.handle);
        }

        // utilities

        internal static Event[] FromIntPtr(IntPtr[] arr)
        {
            var res = new Event[arr.Length];
            for (var i=0; i<res.Length; i++) {
                res[i] = new Event(arr[i]);
            }
            return res;
        }

        internal static IntPtr[] ToIntPtr(Event[] events)
        {
            var res = new IntPtr[events.Length];
            for (var i=0; i<events.Length; i++) {
                res[i] = events[i].handle;
            }
            return res;
        }
    }
}
