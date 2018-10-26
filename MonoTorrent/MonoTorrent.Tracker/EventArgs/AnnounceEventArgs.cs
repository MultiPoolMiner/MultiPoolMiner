namespace MonoTorrent.Tracker
{
    using System;
    using System.Collections.Generic;
    using System.Text;

    public class AnnounceEventArgs : PeerEventArgs
    {
        public AnnounceEventArgs(Peer peer, SimpleTorrentManager manager)
            : base(peer, manager)
        {

        }
    }
}
