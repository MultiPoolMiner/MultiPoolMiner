namespace MonoTorrent.Common
{
    using System;
    using System.Collections.Generic;
    using System.Text;

    public interface ITorrentFileSource
    {
        IEnumerable<FileMapping> Files { get; }
        string TorrentName { get; }
    }
}
