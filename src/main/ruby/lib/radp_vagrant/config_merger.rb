# frozen_string_literal: true

module RadpVagrant
  # Deep merges configuration with array concatenation
  # Inheritance: global common -> cluster common -> guest
  module ConfigMerger
    class << self
      # Merge configuration from three levels
      # Arrays are concatenated, not merged by key
      def merge_guest_config(global_common, cluster_common, guest)
        result = {}
        result = deep_merge(result, normalize_common(global_common)) if global_common
        result = deep_merge(result, normalize_common(cluster_common)) if cluster_common
        result = deep_merge(result, guest) if guest
        result
      end

      # Deep merge two hashes
      # - Arrays: concatenate
      # - Hashes: recursive merge
      # - Scalars: override
      def deep_merge(base, override)
        return deep_dup(override) if base.nil?
        return deep_dup(base) if override.nil?

        return base + override if base.is_a?(Array) && override.is_a?(Array)
        return override unless base.is_a?(Hash) && override.is_a?(Hash)

        result = base.dup
        override.each do |key, value|
          result[key] = if result.key?(key)
                          deep_merge(result[key], value)
                        else
                          deep_dup(value)
                        end
        end
        result
      end

      private

      # Normalize common config to guest-compatible structure
      # Converts synced-folders.{type}[] to synced-folders[] with type field
      def normalize_common(common)
        return nil if common.nil?

        result = common.dup

        # Normalize synced-folders
        if common['synced-folders'].is_a?(Hash)
          result['synced-folders'] = normalize_synced_folders(common['synced-folders'])
        end

        result
      end

      # Convert { basic: [...], nfs: [...] } to [{ type: 'basic', ...}, { type: 'nfs', ...}]
      def normalize_synced_folders(folders_by_type)
        result = []
        folders_by_type.each do |type, folders|
          next unless folders.is_a?(Array)

          folders.each do |folder|
            result << folder.merge('type' => type.to_s)
          end
        end
        result
      end

      def deep_dup(obj)
        case obj
        when Hash
          obj.transform_values { |v| deep_dup(v) }
        when Array
          obj.map { |v| deep_dup(v) }
        else
          obj
        end
      end
    end
  end
end
