# frozen_string_literal: true

module RadpVagrant
  # Deep merges configuration with array concatenation
  # Inheritance: global common -> cluster common -> guest
  module ConfigMerger
    class << self
      # Merge configuration from three levels
      # Arrays are concatenated, not merged by key
      # Provisions support phase: pre (default) / post for execution order control
      def merge_guest_config(global_common, cluster_common, guest)
        result = {}
        result = deep_merge(result, normalize_common(global_common)) if global_common
        result = deep_merge(result, normalize_common(cluster_common)) if cluster_common
        result = deep_merge(result, guest) if guest

        # Re-process provisions to respect phase field
        # Order: global_pre -> cluster_pre -> guest -> cluster_post -> global_post
        result['provisions'] = merge_provisions_with_phase(
          global_common&.dig('provisions'),
          cluster_common&.dig('provisions'),
          guest&.dig('provisions')
        )

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

      # Merge provisions respecting the phase field
      # Common provisions can have phase: pre (default) or post
      # Order: global_pre -> cluster_pre -> guest -> cluster_post -> global_post
      def merge_provisions_with_phase(global_common_provisions, cluster_common_provisions, guest_provisions)
        global_pre, global_post = split_by_phase(global_common_provisions)
        cluster_pre, cluster_post = split_by_phase(cluster_common_provisions)
        guest = Array(guest_provisions).map { |p| deep_dup(p) }

        # Build final order
        result = []
        result.concat(global_pre)
        result.concat(cluster_pre)
        result.concat(guest)
        result.concat(cluster_post)
        result.concat(global_post)
        result
      end

      # Split provisions by phase field
      # Returns [pre_provisions, post_provisions]
      # Default phase is 'pre'
      def split_by_phase(provisions)
        return [[], []] if provisions.nil? || provisions.empty?

        pre = []
        post = []

        provisions.each do |provision|
          p = deep_dup(provision)
          phase = p['phase'] || 'pre'

          if phase == 'post'
            post << p
          else
            pre << p
          end
        end

        [pre, post]
      end

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
