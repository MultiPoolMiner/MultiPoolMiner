#if !DISABLE_DHT
namespace MonoTorrent.Dht
{
    using System;
    using System.Collections.Generic;
    using System.Text;

    internal class NodeAddedEventArgs : EventArgs
    {
        private Node node;

        public Node Node
        {
            get { return node; }
        }

        public NodeAddedEventArgs(Node node)
        {
            this.node = node;
        }
    }
}
#endif
