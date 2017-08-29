using System;

namespace OpenCl
{
	public abstract class RefCountedObject : HandleObject, IDisposable
    {
		protected RefCountedObject(IntPtr handle) : base(handle) { }

        ~RefCountedObject()
        {
            Dispose(false);
        }

        protected abstract void Retain();

		protected abstract void Release();

		// IDisposable

		private bool disposed = false;

		public void Dispose()
		{
			Dispose(true);
			GC.SuppressFinalize(this);
		}

        protected virtual void Dispose(bool disposing)
		{
			if (!disposed) {
				Release();
				disposed = true;
			}
		}
    }
}
