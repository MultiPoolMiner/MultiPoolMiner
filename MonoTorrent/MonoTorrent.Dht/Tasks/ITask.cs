#if !DISABLE_DHT
namespace MonoTorrent.Dht
{
    using System;
    using System.Collections.Generic;
    using System.Text;

    interface ITask
    {
        event EventHandler<TaskCompleteEventArgs> Completed;

        bool Active { get; }
        void Execute();
    }
}
#endif
