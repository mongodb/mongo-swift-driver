/// If we are on < 4.1, define our own `deallocate()` that 
/// calls the old version of the method.
#if !swift(>=4.1)
internal extension UnsafeMutablePointer {
	internal func deallocate() {
		self.deallocate(capacity: 1)
	}
}
#endif
