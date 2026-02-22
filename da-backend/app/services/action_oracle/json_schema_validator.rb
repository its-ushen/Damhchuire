module ActionOracle
  class JsonSchemaValidator
    class ValidationError < StandardError; end

    def self.validate!(schema:, data:, pointer: "$")
      return if schema.blank? || schema == {}

      new.send(:validate_schema!, deep_stringify(schema), data, pointer)
    end

    def self.deep_stringify(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, child), out|
          out[key.to_s] = deep_stringify(child)
        end
      when Array
        value.map { |item| deep_stringify(item) }
      else
        value
      end
    end

    private

    def validate_schema!(schema, data, pointer)
      validate_type!(schema["type"], data, pointer) if schema.key?("type")
      validate_enum!(schema["enum"], data, pointer) if schema.key?("enum")
      validate_const!(schema["const"], data, pointer) if schema.key?("const")

      schema_type = normalized_type(schema, data)
      case schema_type
      when "object"
        validate_object!(schema, data, pointer)
      when "array"
        validate_array!(schema, data, pointer)
      end
    end

    def normalized_type(schema, data)
      type = schema["type"]
      return type.first if type.is_a?(Array) && type.length == 1
      return type if type.is_a?(String)
      return "object" if data.is_a?(Hash) && schema.key?("properties")
      return "array" if data.is_a?(Array) && schema.key?("items")

      nil
    end

    def validate_type!(expected, data, pointer)
      return if expected.nil?

      allowed = Array(expected)
      return if allowed.any? { |type| matches_type?(type, data) }

      raise ValidationError, "#{pointer}: expected type #{allowed.join("|")}, got #{ruby_type_name(data)}"
    end

    def validate_enum!(allowed_values, data, pointer)
      return if Array(allowed_values).include?(data)

      raise ValidationError, "#{pointer}: value is not one of enum values"
    end

    def validate_const!(expected, data, pointer)
      return if data == expected

      raise ValidationError, "#{pointer}: value does not match const"
    end

    def validate_object!(schema, data, pointer)
      unless data.is_a?(Hash)
        raise ValidationError, "#{pointer}: expected object"
      end

      required = Array(schema["required"]).map(&:to_s)
      required.each do |required_key|
        next if fetch_hash_value(data, required_key).first

        raise ValidationError, "#{pointer}: missing required key '#{required_key}'"
      end

      properties = schema["properties"].is_a?(Hash) ? schema["properties"] : {}
      properties.each do |key, property_schema|
        present, value = fetch_hash_value(data, key)
        next unless present

        validate_schema!(self.class.deep_stringify(property_schema), value, "#{pointer}.#{key}")
      end

      additional_properties = schema["additionalProperties"]
      return if additional_properties.nil? || additional_properties == true

      unknown_keys = data.keys.map(&:to_s) - properties.keys

      if additional_properties == false && unknown_keys.any?
        raise ValidationError, "#{pointer}: unexpected keys #{unknown_keys.join(", ")}"
      end

      return unless additional_properties.is_a?(Hash)

      unknown_keys.each do |key|
        _, value = fetch_hash_value(data, key)
        validate_schema!(self.class.deep_stringify(additional_properties), value, "#{pointer}.#{key}")
      end
    end

    def validate_array!(schema, data, pointer)
      unless data.is_a?(Array)
        raise ValidationError, "#{pointer}: expected array"
      end

      item_schema = schema["items"]
      return unless item_schema.is_a?(Hash)

      data.each_with_index do |item, index|
        validate_schema!(self.class.deep_stringify(item_schema), item, "#{pointer}[#{index}]")
      end
    end

    def matches_type?(expected_type, data)
      case expected_type
      when "object"
        data.is_a?(Hash)
      when "array"
        data.is_a?(Array)
      when "string"
        data.is_a?(String)
      when "integer"
        data.is_a?(Integer)
      when "number"
        data.is_a?(Numeric)
      when "boolean"
        data == true || data == false
      when "null"
        data.nil?
      else
        false
      end
    end

    def fetch_hash_value(hash, key)
      if hash.key?(key)
        [ true, hash[key] ]
      elsif hash.key?(key.to_sym)
        [ true, hash[key.to_sym] ]
      else
        [ false, nil ]
      end
    end

    def ruby_type_name(value)
      return "null" if value.nil?

      value.class.name
    end
  end
end
