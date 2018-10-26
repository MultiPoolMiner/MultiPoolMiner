namespace MonoTorrent.Common
{
    using System;
    using System.Net.Sockets;

    public interface INatManager
    {
        void Open(ProtocolType protocol, int port);
        void Close();
    }
}
