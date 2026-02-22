module ActionOracle
  class TemplateRenderer
    PLACEHOLDER_RE = /\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}/.freeze

    class MissingVariableError < StandardError; end

    def self.render_string(template, values)
      template.to_s.gsub(PLACEHOLDER_RE) do
        key = Regexp.last_match(1)
        replacement = dig_value(values, key)
        raise MissingVariableError, "missing template value: #{key}" if replacement.nil?

        replacement.to_s
      end
    end

    def self.render_json(value, values)
      case value
      when String
        render_string(value, values)
      when Array
        value.map { |item| render_json(item, values) }
      when Hash
        value.each_with_object({}) do |(key, val), rendered|
          rendered[key] = render_json(val, values)
        end
      else
        value
      end
    end

    def self.dig_value(values, key_path)
      key_path.split(".").reduce(values) do |current, key|
        return nil unless current.is_a?(Hash)

        if current.key?(key)
          current[key]
        elsif current.key?(key.to_sym)
          current[key.to_sym]
        else
          return nil
        end
      end
    end
  end
end
