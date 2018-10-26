namespace MonoTorrent.Tracker
{
    using System;
    using System.Collections.Generic;
    using System.Text;

    public class TimedOutEventArgs : PeerEventArgs
    {
        public TimedOutEventArgs(Peer peer, SimpleTorrentManager manager)
            : base(peer, manager)
        {

        }
    }
}
