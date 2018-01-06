namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;

    public sealed class Platform : HandleObject
    {
		private const uint CL_PLATFORM_PROFILE               = 0x0900;
		private const uint CL_PLATFORM_VERSION               = 0x0901;
		private const uint CL_PLATFORM_NAME                  = 0x0902;
		private const uint CL_PLATFORM_VENDOR                = 0x0903;
		private const uint CL_PLATFORM_EXTENSIONS            = 0x0904;
		private const uint CL_PLATFORM_HOST_TIMER_RESOLUTION = 0x0905;

		internal Platform(IntPtr handle) : base(handle) { }

		// Platform attributes

		public string Profile
		{
            get { return Cl.GetInfoString(NativeMethods.clGetPlatformInfo, this.handle, CL_PLATFORM_PROFILE); }
		}

		public string Version
		{
            get { return Cl.GetInfoString(NativeMethods.clGetPlatformInfo, this.handle, CL_PLATFORM_VERSION); }
		}

		public string Name
		{
            get { return Cl.GetInfoString(NativeMethods.clGetPlatformInfo, this.handle, CL_PLATFORM_NAME); }
		}

		public string Vendor
		{
            get { return Cl.GetInfoString(NativeMethods.clGetPlatformInfo, this.handle, CL_PLATFORM_VENDOR); }
		}

		public string[] Extensions
		{
			get {
                var res = Cl.GetInfoString(NativeMethods.clGetPlatformInfo, this.handle, CL_PLATFORM_EXTENSIONS);
				return res.Split(new char[] { ' ' });
			}
		}

        // static factory method

		public static Platform[] GetPlatformIDs()
		{
			ErrorCode error;
			uint count;

			error = NativeMethods.clGetPlatformIDs(0, null, out count);
			if (error != ErrorCode.Success) {
				throw new OpenClException(error);
			}

			var ids = new IntPtr[count] ;
			error = NativeMethods.clGetPlatformIDs(count, ids, out count);
			if (error != ErrorCode.Success) {
				throw new OpenClException(error);
			}

			var res = new Platform[count];
			for (var i=0; i<count; i++) {
				res[i] = new Platform(ids[i]);
			}
			return res;
		}
    }
    
}
