/// An extension to add a custom method for deallocation.
internal extension UnsafeMutablePointer {
	/// `deallocate(capacity:)` is deprecated as of Swift 4.1, but
	/// its preferred alternative `deallocate()` does not exist
	/// in < 4.1.
	internal func versionCheckDeallocate() {
		#if swift(>=4.1)
		self.deallocate()
		#else
		self.deallocate(capacity: 1)
		#endif
	}
}