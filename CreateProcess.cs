// http://www.daveamenta.com/2013-08/powershell-start-process-without-taking-focus/

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
 
[StructLayout(LayoutKind.Sequential)]
public struct PROCESS_INFORMATION {
    public IntPtr hProcess;
    public IntPtr hThread;
    public uint dwProcessId;
    public uint dwThreadId;
}
 
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct STARTUPINFO {
    public uint cb;
    public string lpReserved;
    public string lpDesktop;
    public string lpTitle;
    public uint dwX;
    public uint dwY;
    public uint dwXSize;
    public uint dwYSize;
    public uint dwXCountChars;
    public uint dwYCountChars;
    public uint dwFillAttribute;
    public STARTF dwFlags;
    public ShowWindow wShowWindow;
    public short cbReserved2;
    public IntPtr lpReserved2;
    public IntPtr hStdInput;
    public IntPtr hStdOutput;
    public IntPtr hStdError;
}
 
[StructLayout(LayoutKind.Sequential)]
public struct SECURITY_ATTRIBUTES {
    public int length;
    public IntPtr lpSecurityDescriptor;
    public bool bInheritHandle;
}
 
[Flags]
public enum CreationFlags : int {
    NONE = 0,
    DEBUG_PROCESS = 0x00000001,
    DEBUG_ONLY_THIS_PROCESS = 0x00000002,
    CREATE_SUSPENDED = 0x00000004,
    DETACHED_PROCESS = 0x00000008,
    CREATE_NEW_CONSOLE = 0x00000010,
    CREATE_NEW_PROCESS_GROUP = 0x00000200,
    CREATE_UNICODE_ENVIRONMENT = 0x00000400,
    CREATE_SEPARATE_WOW_VDM = 0x00000800,
    CREATE_SHARED_WOW_VDM = 0x00001000,
    CREATE_PROTECTED_PROCESS = 0x00040000,
    EXTENDED_STARTUPINFO_PRESENT = 0x00080000,
    CREATE_BREAKAWAY_FROM_JOB = 0x01000000,
    CREATE_PRESERVE_CODE_AUTHZ_LEVEL = 0x02000000,
    CREATE_DEFAULT_ERROR_MODE = 0x04000000,
    CREATE_NO_WINDOW = 0x08000000,
}
 
[Flags]
public enum STARTF : uint {
    STARTF_USESHOWWINDOW = 0x00000001,
    STARTF_USESIZE = 0x00000002,
    STARTF_USEPOSITION = 0x00000004,
    STARTF_USECOUNTCHARS = 0x00000008,
    STARTF_USEFILLATTRIBUTE = 0x00000010,
    STARTF_RUNFULLSCREEN = 0x00000020,  // ignored for non-x86 platforms
    STARTF_FORCEONFEEDBACK = 0x00000040,
    STARTF_FORCEOFFFEEDBACK = 0x00000080,
    STARTF_USESTDHANDLES = 0x00000100,
}
 
public enum ShowWindow : short {
    SW_HIDE = 0,
    SW_SHOWNORMAL = 1,
    SW_NORMAL = 1,
    SW_SHOWMINIMIZED = 2,
    SW_SHOWMAXIMIZED = 3,
    SW_MAXIMIZE = 3,
    SW_SHOWNOACTIVATE = 4,
    SW_SHOW = 5,
    SW_MINIMIZE = 6,
    SW_SHOWMINNOACTIVE = 7,
    SW_SHOWNA = 8,
    SW_RESTORE = 9,
    SW_SHOWDEFAULT = 10,
    SW_FORCEMINIMIZE = 11,
    SW_MAX = 11
}
 
public static class Kernel32 {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CreateProcess(
        string lpApplicationName, 
        string lpCommandLine, 
        ref SECURITY_ATTRIBUTES lpProcessAttributes, 
        ref SECURITY_ATTRIBUTES lpThreadAttributes,
        bool bInheritHandles, 
        CreationFlags dwCreationFlags, 
        IntPtr lpEnvironment,
        string lpCurrentDirectory, 
        ref STARTUPINFO lpStartupInfo, 
        out PROCESS_INFORMATION lpProcessInformation);
}
