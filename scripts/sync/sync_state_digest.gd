class_name SyncStateDigest
extends RefCounted


static func compute(value: Variant) -> String:
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	assert(start_error == OK, "Unable to initialize synchronization state digest.")
	context.update(canonicalize(value).to_utf8_buffer())
	return context.finish().hex_encode()


static func canonicalize(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "bool:%s" % str(value)
		TYPE_INT:
			return "int:%d" % value
		TYPE_FLOAT:
			return "float:%.17g" % value
		TYPE_STRING, TYPE_STRING_NAME:
			return "string:%s" % JSON.stringify(String(value))
		TYPE_ARRAY:
			var array_parts := PackedStringArray()
			for item: Variant in value:
				array_parts.append(canonicalize(item))
			return "array:[%s]" % ",".join(array_parts)
		TYPE_PACKED_STRING_ARRAY:
			return canonicalize(Array(value))
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort_custom(_key_precedes)
			var dictionary_parts := PackedStringArray()
			for key: Variant in keys:
				dictionary_parts.append("%s=%s" % [canonicalize(key), canonicalize(value[key])])
			return "dictionary:{%s}" % ",".join(dictionary_parts)
		_:
			assert(false, "Unsupported synchronization digest value type: %s" % type_string(typeof(value)))
			return "unsupported"


static func _key_precedes(left: Variant, right: Variant) -> bool:
	return canonicalize(left) < canonicalize(right)
