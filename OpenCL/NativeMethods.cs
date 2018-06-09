//  
//  NativeMethods.cs
//  opencl-sharp
//
//  Copyright (c) 2016 Markus Uhr. All rights reserved.
//

namespace OpenCl
{
    using System;
    using System.Runtime.InteropServices;

    internal class NativeMethods
    {
        private NativeMethods()
        {
        }

        //
        // Platform
        //

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetPlatformIDs(uint numEntries, IntPtr[] platforms, out uint numPlatforms);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetPlatformInfo(IntPtr platform, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        //
        // Device
        //

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetDeviceIDs(IntPtr platform, DeviceType deviceType, uint numEntries, IntPtr[] devices, out uint numDevices);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetDeviceInfo(IntPtr device, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        //
        // Context
        //

        [DllImport("OpenCL")]
        internal static extern IntPtr clCreateContext(ContextProperty[] properties, uint numDevices, IntPtr[] devices, ContextNotifyInternal pfnNotify, IntPtr userData, out ErrorCode errcodeRet);

        [DllImport("OpenCL")]
        internal static extern IntPtr clCreateContextFromType(ContextProperty[] properties, DeviceType deviceType, ContextNotifyInternal pfnNotify, IntPtr userData, out ErrorCode errcodeRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clRetainContext(IntPtr context);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clReleaseContext(IntPtr context);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetContextInfo(IntPtr context, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        //
        // Program
        //

        [DllImport("OpenCL")]
        internal static extern ErrorCode clUnloadCompiler();

        [DllImport("OpenCL")]
        internal static extern IntPtr clCreateProgramWithSource(
            IntPtr context,
            uint count,
            [In] string[] strings,
            [In] IntPtr[] lengths,
            out ErrorCode errcodeRet);

        [DllImport("OpenCL")]
        internal static extern IntPtr clCreateProgramWithBinary(
            IntPtr context,
            uint numDevices,
            [In] IntPtr[] deviceList,
            [In] IntPtr[] lengths,
            [In] IntPtr[] binaries,
            [Out] int[] binaryStatus,
            out ErrorCode errcodeRet);

        [DllImport("OpenCL")]
        internal static extern IntPtr clCreateProgramWithIL(
            IntPtr context,
            byte[] binary,
            IntPtr length,
            out ErrorCode errcodeRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clRetainProgram(IntPtr program);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clReleaseProgram(IntPtr program);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clBuildProgram(IntPtr program, uint numDevices, IntPtr[] deviceList, string options, ProgramNotifyInternal pfnNotify, IntPtr userData);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetProgramInfo(IntPtr program, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetProgramBuildInfo(IntPtr program, IntPtr device, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        //
        // Kernel
        //

        [DllImport("OpenCL")]
        internal static extern IntPtr clCreateKernel(IntPtr program, string kernelName, out ErrorCode errcodeRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clCreateKernelsInProgram(IntPtr program, uint numKernels, IntPtr[] kernels, out uint numKernelsRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clRetainKernel(IntPtr kernel);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clReleaseKernel(IntPtr kernel);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clSetKernelArg(IntPtr kernel, uint argIndex, IntPtr argSize, IntPtr argValue);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clSetKernelArg(IntPtr kernel, uint argIndex, IntPtr argSize, ref IntPtr argValue);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetKernelInfo(IntPtr kernel, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetKernelWorkGroupInfo(IntPtr kernel, IntPtr device, KernelWorkGroupInfo paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        //
        // Mem
        //

		[DllImport("OpenCL")]
		internal static extern IntPtr clCreateBuffer(IntPtr context, MemFlags flags, IntPtr size, IntPtr hostPtr, [Out] [MarshalAs(UnmanagedType.I4)] out ErrorCode errcodeRet);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clRetainMemObject(IntPtr memObj);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clReleaseMemObject(IntPtr memObj);

//		[DllImport("OpenCL")]
//		internal static extern ErrorCode clGetSupportedImageFormats(IntPtr context, MemFlags flags, MemObjectType imageType, uint numEntries, [Out] [MarshalAs(UnmanagedType.LPArray)] ImageFormat[] imageFormats, out uint numImageFormats);

		[DllImport("OpenCL")]
		internal static extern IntPtr clCreateImage2D(IntPtr context, MemFlags flags, IntPtr imageFormat, IntPtr imageWidth, IntPtr imageHeight, IntPtr imageRowPitch, IntPtr hostPtr, out ErrorCode errcodeRet);

		[DllImport("OpenCL")]
		internal static extern IntPtr clCreateImage3D(IntPtr context, MemFlags flags, IntPtr imageFormat, IntPtr imageWidth, IntPtr imageHeight, IntPtr imageDepth, IntPtr imageRowPitch, IntPtr imageSlicePitch, IntPtr hostPtr, out ErrorCode errcodeRet);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clGetMemObjectInfo(IntPtr memObj, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clGetImageInfo(IntPtr image, ImageInfo paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

		//
		// CommandQueue
		//

		[DllImport("OpenCL")]
		internal static extern IntPtr clCreateCommandQueue(IntPtr context, IntPtr device, [MarshalAs(UnmanagedType.U8)] CommandQueueProperties properties, out ErrorCode error);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clRetainCommandQueue(IntPtr commandQueue);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clReleaseCommandQueue(IntPtr commandQueue);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clGetCommandQueueInfo(IntPtr commandQueue, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

		[DllImport("OpenCL")]
		internal static extern ErrorCode clSetCommandQueueProperty(IntPtr commandQueue, [MarshalAs(UnmanagedType.U8)] CommandQueueProperties properties, bool enable, [MarshalAs(UnmanagedType.U8)] out CommandQueueProperties oldProperties);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueReadBuffer(
            IntPtr commandQueue,
            IntPtr buffer,
            uint blockingRead,
            IntPtr offsetInBytes,
            IntPtr lengthInBytes,
            IntPtr ptr,
            uint numEventsInWaitList,
            IntPtr[] eventWaitList,
            out IntPtr e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueWriteBuffer(
            IntPtr commandQueue,
            IntPtr buffer,
            uint blockingWrite,
            IntPtr offsetInBytes,
            IntPtr lengthInBytes,
            IntPtr ptr,
            uint numEventsInWaitList,
            IntPtr[] eventWaitList,
            out IntPtr e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueFillBuffer(
            IntPtr commandQueue,
            IntPtr buffer,
            IntPtr pattern,
            IntPtr patternSize,
            IntPtr offsetInBytes,
            IntPtr sizeInBytes,
            uint numEventsInWaitList,
            IntPtr[] eventWaitList,
            out IntPtr e);

        // [DllImport("OpenCL")]
        // internal static extern ErrorCode clEnqueueFillBuffer(
        //     IntPtr commandQueue,
        //     IntPtr buffer,
        //     ref X pattern,
        //     IntPtr patternSize,
        //     IntPtr offsetInBytes,
        //     IntPtr sizeInBytes,
        //     uint numEventsInWaitList,
        //     IntPtr[] eventWaitList,
        //     out IntPtr e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueCopyBuffer(
            IntPtr commandQueue,
            IntPtr srcBuffer,
            IntPtr dstBuffer,
            IntPtr srcOffset,
            IntPtr dstOffset,
            IntPtr cb,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 6)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueReadImage(IntPtr commandQueue,
            IntPtr image,
            uint blockingRead,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] origin,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] region,
            IntPtr rowPitch,
            IntPtr slicePitch,
            IntPtr ptr,
            uint numEventsIntWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 8)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueWriteImage(IntPtr commandQueue,
            IntPtr image,
            uint blockingWrite,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] origin,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] region,
            IntPtr rowPitch,
            IntPtr slicePitch,
            IntPtr ptr,
            uint numEventsIntWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 8)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueCopyImage(IntPtr commandQueue,
            IntPtr srcImage,
            IntPtr dstImage,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] srcOrigin,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] dstOrigin,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] region,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 6)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueCopyImageToBuffer(IntPtr commandQueue,
            IntPtr srcImage,
            IntPtr dstBuffer,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] srcOrigin,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] region,
            IntPtr dstOffset,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 6)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueCopyBufferToImage(IntPtr commandQueue,
            IntPtr srcBuffer,
            IntPtr dstImage,
            IntPtr srcOffset,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] dstOrigin,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] region,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 6)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern IntPtr clEnqueueMapBuffer(IntPtr commandQueue,
            IntPtr buffer,
            uint blockingMap,
            MapFlags mapFlags,
            IntPtr offset,
            IntPtr cb,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 6)] Event[] eventWaitList,
            [Out] out Event e,
            out ErrorCode errCodeRet);

        [DllImport("OpenCL")]
        internal static extern IntPtr clEnqueueMapImage(IntPtr commandQueue,
            IntPtr image,
            uint blockingMap,
            MapFlags mapFlags,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] origin,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeConst = 3)] IntPtr[] region,
            out IntPtr imageRowPitch,
            out IntPtr imageSlicePitch,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 8)] Event[] eventWaitList,
            [Out] out Event e,
            out ErrorCode errCodeRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueUnmapMemObject(IntPtr commandQueue,
            IntPtr memObj,
            IntPtr mappedPtr,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 3)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueNDRangeKernel(
            IntPtr commandQueue,
            IntPtr kernel,
            uint workDim,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] IntPtr[] globalWorkOffset,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] IntPtr[] globalWorkSize,
            [In] [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] IntPtr[] localWorkSize,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 6)] Event[] eventWaitList,
            [Out] out IntPtr e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueNDRangeKernel(
            IntPtr commandQueue,
            IntPtr kernel,
            uint workDim,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt)] uint[] globalWorkOffset,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt)] uint[] globalWorkSize,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt)] uint[] localWorkSize,
            uint numEventsInWaitList,
            IntPtr[] eventWaitList,
            [Out] out IntPtr e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueNDRangeKernel(
            IntPtr commandQueue,
            IntPtr kernel,
            int workDim,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt)] int[] globalWorkOffset,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt)] int[] globalWorkSize,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt)] int[] localWorkSize,
            int numEventsInWaitList,
            IntPtr[] eventWaitList,
            [Out] out IntPtr e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueTask(
            IntPtr commandQueue,
            IntPtr kernel,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 2)] Event[] eventWaitList,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueMarker(
            IntPtr commandQueue,
            [Out] out Event e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueWaitForEvents(
            IntPtr commandQueue,
            uint numEventsInWaitList,
            [In] [MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.SysUInt, SizeParamIndex = 1)] Event[] eventWaitList);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clEnqueueBarrier(IntPtr commandQueue);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clFinish(IntPtr commandQueue);

        //
        // Event
        //

        [DllImport("OpenCL")]
        internal static extern ErrorCode clWaitForEvents(uint numEvents, IntPtr[] eventWaitList);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clGetEventInfo(IntPtr e, uint paramName, IntPtr paramValueSize, IntPtr paramValue, out IntPtr paramValueSizeRet);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clRetainEvent(IntPtr e);

        [DllImport("OpenCL")]
        internal static extern ErrorCode clReleaseEvent(IntPtr e);

        //
        // Extension Functions
        //

        [DllImport("OpenCL")]
        internal static extern IntPtr clGetExtensionFunctionAddressForPlatform(IntPtr platform, string name);
    }
}
