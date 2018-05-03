import Foundation

extension Document: Codable {
	public func encode(to encoder: Encoder) throws {
		if let bsonEncoder = encoder as? _BsonEncoder {
			bsonEncoder.storage.containers.append(self)
			return
		}

		var container = encoder.container(keyedBy: _BsonKey.self)
		for (k, v) in self {
			try Document.recursivelyEncodeKeyed(v, forKey: k, to: &container)
		}
	}

	// swiftlint:disable:next cyclomatic_complexity
	private static func recursivelyEncodeKeyed(_ value: BsonValue?, forKey key: String, to container: inout KeyedEncodingContainer<_BsonKey>) throws {
		let k = _BsonKey(stringValue: key)!
		switch value {
		case let val as Binary:
			try container.encode(val, forKey: k)
		case let val as Bool:
			try container.encode(val, forKey: k)
		case let val as Date:
			try container.encode(val, forKey: k)
		case let val as Decimal128:
			try container.encode(val, forKey: k)
		case let val as Double:
			try container.encode(val, forKey: k)
		case let val as Int:
			try container.encode(val, forKey: k)
		case let val as Int32:
			try container.encode(val, forKey: k)
		case let val as Int64:
			try container.encode(val, forKey: k)
		case let val as CodeWithScope:
			try container.encode(val, forKey: k)
		case let val as MaxKey:
			try container.encode(val, forKey: k)
		case let val as MinKey:
			try container.encode(val, forKey: k)
		case let val as ObjectId:
			try container.encode(val, forKey: k)
		case let val as String:
			try container.encode(val, forKey: k)
		case nil:
			try container.encodeNil(forKey: k)
		case let val as [BsonValue?]:
			var nested = container.nestedUnkeyedContainer(forKey: k)
			for v in val {
				try Document.recursivelyEncodeUnkeyed(v, to: &nested)
			}
		case let val as Document:
			var nested = container.nestedContainer(keyedBy: _BsonKey.self, forKey: k)
			for (nestedK, nestedV) in val {
				try Document.recursivelyEncodeKeyed(nestedV, forKey: nestedK, to: &nested)
			}
		default:
			throw MongoError.typeError(message: "Encountered a non-encodable type in a Document: \(type(of: value))")
		}
	}

	// swiftlint:disable:next cyclomatic_complexity
	private static func recursivelyEncodeUnkeyed(_ value: BsonValue?, to container: inout UnkeyedEncodingContainer) throws {
		switch value {
		case let val as Binary:
			try container.encode(val)
		case let val as Bool:
			try container.encode(val)
		case let val as Date:
			try container.encode(val)
		case let val as Decimal128:
			try container.encode(val)
		case let val as Double:
			try container.encode(val)
		case let val as Int:
			try container.encode(val)
		case let val as Int32:
			try container.encode(val)
		case let val as Int64:
			try container.encode(val)
		case let val as CodeWithScope:
			try container.encode(val)
		case let val as MaxKey:
			try container.encode(val)
		case let val as MinKey:
			try container.encode(val)
		case let val as ObjectId:
			try container.encode(val)
		case let val as String:
			try container.encode(val)
		case nil:
			 try container.encodeNil()
		case let val as [BsonValue]:
			var nested = container.nestedUnkeyedContainer()
			for v in val {
				try Document.recursivelyEncodeUnkeyed(v, to: &nested)
			}
		case let val as Document:
			var nested = container.nestedContainer(keyedBy: _BsonKey.self)
			for (nestedK, nestedV) in val {
				try Document.recursivelyEncodeKeyed(nestedV, forKey: nestedK, to: &nested)
			}
		default:
			throw MongoError.typeError(message: "Encountered a non-encodable type in a Document: \(type(of: value))")
		}
	}

		public init(from decoder: Decoder) throws {
		// if it's a BsonDecoder we should just short-circuit and return the container document
		if let bsonDecoder = decoder as? _BsonDecoder {
			let topContainer = bsonDecoder.storage.topContainer
			guard let doc = topContainer as? Document else {
				throw DecodingError._typeMismatch(at: [], expectation: Document.self, reality: topContainer)
			}
			self = doc
		// Otherwise get a keyed container and decode each key one by one
		} else {
			let container = try decoder.container(keyedBy: _BsonKey.self)
			var output = Document()
			for key in container.allKeys {
				let k = key.stringValue
				output[k] = try Document.recursivelyDecodeKeyed(key: key, container: container)
			}
			self = output
		}
	}

	/// Switch through all possible BSON types (a document can contain any) and try recursively decoding the value
	/// stored under `key` as that type from the provided keyed container.
	// swiftlint:disable:next cyclomatic_complexity
	private static func recursivelyDecodeKeyed(key: _BsonKey, container: KeyedDecodingContainer<_BsonKey>) throws -> BsonValue {
		if let value = try? container.decode(Double.self, forKey: key) {
			return value
		} else if let value = try? container.decode(String.self, forKey: key) {
			return value
		} else if let value = try? container.decode(Binary.self, forKey: key) {
			return value
		} else if let value = try? container.decode(ObjectId.self, forKey: key) {
			return value
		} else if let value = try? container.decode(Bool.self, forKey: key) {
			return value
		} else if let value = try? container.decode(Date.self, forKey: key) {
			return value
		} else if let value = try? container.decode(RegularExpression.self, forKey: key) {
			return value
		} else if let value = try? container.decode(CodeWithScope.self, forKey: key) {
			return value
		} else if let value = try? container.decode(Int.self, forKey: key) {
			return value
		} else if let value = try? container.decode(Int32.self, forKey: key) {
			return value
		} else if let value = try? container.decode(Int64.self, forKey: key) {
			return value
		} else if let value = try? container.decode(Decimal128.self, forKey: key) {
			return value
		} else if let value = try? container.decode(MinKey.self, forKey: key) {
			return value
		} else if let value = try? container.decode(MaxKey.self, forKey: key) {
			return value
		} else if var nested = try? container.nestedUnkeyedContainer(forKey: key) {
			var res = [BsonValue]()
			while !nested.isAtEnd {
				res.append(try recursivelyDecodeUnkeyed(container: &nested))
			}
			return res
		// this will recursively call Document.init(from: decoder Decoder)
		} else if let value = try? container.decode(Document.self, forKey: key) {
			return value
		} else {
			throw MongoError.typeError(message: "Encountered a value in an keyed container under key \(key.stringValue) that could not be decoded to any BSON type")
		}
	}

	/// Switch through all possible BSON types (a document can contain any) and try recursively decoding the next value
	/// as that type from the provided unkeyed container.
	private static func recursivelyDecodeUnkeyed(container: inout UnkeyedDecodingContainer) throws -> BsonValue {
		if let value = try? container.decode(Double.self) {
			return value
		} else if let value = try? container.decode(String.self) {
			return value
		} else if let value = try? container.decode(Binary.self) {
			return value
		} else if let value = try? container.decode(ObjectId.self) {
			return value
		} else if let value = try? container.decode(Bool.self) {
			return value
		} else if let value = try? container.decode(Date.self) {
			return value
		} else if let value = try? container.decode(RegularExpression.self) {
			return value
		} else if let value = try? container.decode(CodeWithScope.self) {
			return value
		} else if let value = try? container.decode(Int.self) {
			return value
		} else if let value = try? container.decode(Int32.self) {
			return value
		} else if let value = try? container.decode(Int64.self) {
			return value
		} else if let value = try? container.decode(Decimal128.self) {
			return value
		} else if let value = try? container.decode(MinKey.self) {
			return value
		} else if let value = try? container.decode(MaxKey.self) {
			return value
		} else if var nested = try? container.nestedUnkeyedContainer() {
			var res = [BsonValue]()
			while !nested.isAtEnd {
				res.append(try recursivelyDecodeUnkeyed(container: &nested))
			}
			return res
		// this will recursively call Document.init(from: decoder Decoder)
		} else if let value = try? container.decode(Document.self) {
			return value
		} else {
			throw MongoError.typeError(message: "Encountered a value in an unkeyed container that could not be decoded to any BSON type")
		}
	}
}
