#if !DISABLE_DHT
namespace MonoTorrent.Dht
{
    using System;
    using System.Collections.Generic;
    using System.Text;
    using MonoTorrent.BEncoding;

    internal static class TransactionId
    {
        private static byte[] current = new byte[2];

        public static BEncodedString NextId()
        {
            lock (current)
            {
                BEncodedString result = new BEncodedString((byte[])current.Clone());
                if (current[0]++ == 255)
                    current[1]++;
                return result;
            }
        }
    }
}
#endif
