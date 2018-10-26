#if !DISABLE_DHT
namespace MonoTorrent.Dht.Listeners
{
    using System;
    using System.Collections.Generic;
    using System.Text;
    using MonoTorrent.Client;
    using System.Net;
    using MonoTorrent.Common;

    public delegate void MessageReceived(byte[] buffer, IPEndPoint endpoint);

    public class DhtListener : UdpListener
    {
        public event MessageReceived MessageReceived;

        public DhtListener(IPEndPoint endpoint)
            : base(endpoint)
        {

        }

        protected override void OnMessageReceived(byte[] buffer, IPEndPoint endpoint)
        {
            MessageReceived h = MessageReceived;
            if (h != null)
                h(buffer, endpoint);
        }
    }
}
#endif
