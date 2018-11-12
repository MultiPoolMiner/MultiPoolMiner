#if !DISABLE_NAT
namespace MonoTorrent.Nat
{
    using System;

    /// <summary>
    /// Protocol that should be used for searching a NAT device. 
    /// </summary>
    [Flags]
    public enum PortMapper
    {
        /// <summary>
        /// Use only Port Mapping Protocol
        /// </summary>
        Pmp = 1,

        /// <summary>
        /// Use only Universal Plug and Play
        /// </summary>
        Upnp = 2
    }
}
#endif
