namespace MonoTorrent.Client.Tracker
{
    using System;
    using System.Collections.Generic;
    using System.Text;
    using MonoTorrent.Common;

    public class ScrapeParameters
    {
        private InfoHash infoHash;


        public InfoHash InfoHash
        {
            get { return infoHash; }
        }

        public ScrapeParameters(InfoHash infoHash)
        {
            this.infoHash = infoHash;
        }
    }
}
