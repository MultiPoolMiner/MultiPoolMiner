namespace MonoTorrent.Tracker
{
    using System;
    using System.Collections.Generic;
    using System.Text;

    public class TrackerException : Exception
    {
        public TrackerException()
            : base()
        {
        }

        public TrackerException(string message)
            : base(message)
        {
        }
    }
}
