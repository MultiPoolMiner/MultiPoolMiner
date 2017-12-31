using module .\Include.psm1

enum CreationFlags {
    NONE = 0
    DEBUG_PROCESS = 0x00000001
    DEBUG_ONLY_THIS_PROCESS = 0x00000002
    CREATE_SUSPENDED = 0x00000004
    DETACHED_PROCESS = 0x00000008
    CREATE_NEW_CONSOLE = 0x00000010
    CREATE_NEW_PROCESS_GROUP = 0x00000200
    CREATE_UNICODE_ENVIRONMENT = 0x00000400
    CREATE_SEPARATE_WOW_VDM = 0x00000800
    CREATE_SHARED_WOW_VDM = 0x00001000
    CREATE_PROTECTED_PROCESS = 0x00040000
    EXTENDED_STARTUPINFO_PRESENT = 0x00080000
    CREATE_BREAKAWAY_FROM_JOB = 0x01000000
    CREATE_PRESERVE_CODE_AUTHZ_LEVEL = 0x02000000
    CREATE_DEFAULT_ERROR_MODE = 0x04000000
    CREATE_NO_WINDOW = 0x08000000
}

enum ShowWindow {
    SW_HIDE = 0
    SW_SHOWNORMAL = 1
    SW_NORMAL = 1
    SW_SHOWMINIMIZED = 2
    SW_SHOWMAXIMIZED = 3
    SW_MAXIMIZE = 3
    SW_SHOWNOACTIVATE = 4
    SW_SHOW = 5
    SW_MINIMIZE = 6
    SW_SHOWMINNOACTIVE = 7
    SW_SHOWNA = 8
    SW_RESTORE = 9
    SW_SHOWDEFAULT = 10
    SW_FORCEMINIMIZE = 11
    SW_MAX = 11
}

enum STARTF {
    STARTF_USESHOWWINDOW = 0x00000001
    STARTF_USESIZE = 0x00000002
    STARTF_USEPOSITION = 0x00000004
    STARTF_USECOUNTCHARS = 0x00000008
    STARTF_USEFILLATTRIBUTE = 0x00000010
    STARTF_RUNFULLSCREEN = 0x00000020 #ignored for non-x86 platforms
    STARTF_FORCEONFEEDBACK = 0x00000040
    STARTF_FORCEOFFFEEDBACK = 0x00000080
    STARTF_USESTDHANDLES = 0x00000100
}

enum Priority {
    Idle
    BelowNormal
    Normal
    AboveNormal
    High
    RealTime
}

function Invoke-CreateProcess {

    param (
        [Parameter(Mandatory = $True)][string]$Binary,
        [Parameter(Mandatory = $False)][string]$Args = $null,
        [CreationFlags][Parameter(Mandatory = $True)]$CreationFlags,
        [ShowWindow][Parameter(Mandatory = $True)]$ShowWindow,
        [StartF][Parameter(Mandatory = $True)]$StartF,
        [Priority][Parameter(Mandatory = $True)]$Priority,
        [Parameter(Mandatory = $False)][String]$WorkingDirectory = ""
	)  
    
    Add-Type -TypeDefinition @"
	using System;
	using System.Diagnostics;
	using System.Runtime.InteropServices;
	
	[StructLayout(LayoutKind.Sequential)]
	public struct PROCESS_INFORMATION
	{
		public IntPtr hProcess; public IntPtr hThread; public uint dwProcessId; public uint dwThreadId;
	}
	
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct STARTUPINFO
	{
		public uint cb; public string lpReserved; public string lpDesktop; public string lpTitle;
		public uint dwX; public uint dwY; public uint dwXSize; public uint dwYSize; public uint dwXCountChars;
		public uint dwYCountChars; public uint dwFillAttribute; public uint dwFlags; public short wShowWindow;
		public short cbReserved2; public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput;
		public IntPtr hStdError;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct SECURITY_ATTRIBUTES
	{
		public int length; public IntPtr lpSecurityDescriptor; public bool bInheritHandle;
	}
	
	public static class Kernel32
	{
		[DllImport("kernel32.dll", SetLastError=true)]
		public static extern bool CreateProcess(
			string lpApplicationName, string lpCommandLine, ref SECURITY_ATTRIBUTES lpProcessAttributes, 
			ref SECURITY_ATTRIBUTES lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, 
			IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, 
			out PROCESS_INFORMATION lpProcessInformation);
	}
"@

    # StartupInfo Struct
	$StartupInfo = New-Object STARTUPINFO
	$StartupInfo.dwFlags = $StartF # StartupInfo.dwFlag
	$StartupInfo.wShowWindow = $ShowWindow # StartupInfo.ShowWindow
	$StartupInfo.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($StartupInfo) # Struct Size
	
	# ProcessInfo Struct
	$ProcessInfo = New-Object PROCESS_INFORMATION
	
	# SECURITY_ATTRIBUTES Struct (Process & Thread)
	$SecAttr = New-Object SECURITY_ATTRIBUTES
	$SecAttr.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($SecAttr)
	
	if (-not $WorkingDirectory) {
        # CreateProcess --> lpCurrentDirectory
    	$WorkingDirectory = (Get-Item -Path ".\" -Verbose).FullName
    }
	
	# Call CreateProcess
	[Kernel32]::CreateProcess($Binary, $Args, [ref]$SecAttr, [ref]$SecAttr, $true, $CreationFlags, [IntPtr]::Zero, $WorkingDirectory, [ref]$StartupInfo, [ref]$ProcessInfo) | Out-Null

	$Process = Get-Process -Id $ProcessInfo.dwProcessId
    $Process.Handle | Out-Null
    $Process
    
    $Process.PriorityClass = "$Priority"
}

function Get-ForegroundWindow {
    Add-Type -TypeDefinition @"
  using System;
  using System.Runtime.InteropServices;
  public class Tricks {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

    Get-Process | Where-Object {$_.MainWindowHandle -eq [tricks]::GetForegroundWindow()}
}
