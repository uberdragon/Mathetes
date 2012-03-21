module Cinch
  module Plugins
    class PluginManagement
      include Cinch::Plugin

      match(/plugin load (\S+)(?: (\S+))?/, method: :load_plugin)
      match(/plugin unload (\S+)/, method: :unload_plugin)
      match(/plugin reload (\S+)(?: (\S+))?/, method: :reload_plugin)
      match(/plugin set (\S+) (\S+) (.+)$/, method: :set_option)
      def load_plugin(m, plugin, mapping)
        return unless allowed_user?(m.user)

        mapping ||= plugin.gsub(/(.)([A-Z])/) { |_|
          $1 + "_" + $2
        }.downcase # we downcase here to also catch the first letter

        file_name = "lib/cinch/plugins/#{mapping}.rb"
        unless File.exist?(file_name)
          m.reply "Could not load #{plugin} because #{file_name} does not exist."
          return
        end

        begin
          load(file_name)
        rescue
          m.reply "Could not load #{plugin}."
          raise
        end

        begin
          const = Cinch::Plugins.const_get(plugin)
        rescue NameError
          m.reply "Could not load #{plugin} because no matching class was found."
          return
        end

        @bot.plugins.register_plugin(const)
        m.reply "Successfully loaded #{plugin}"
      end

      def unload_plugin(m, plugin)
        return unless allowed_user?(m.user)

        begin
          plugin_class = Cinch::Plugins.const_get(plugin)
        rescue NameError
          m.reply "Could not unload #{plugin} because no matching class was found."
          return
        end

        @bot.plugins.select {|p| p.class == plugin_class}.each do |p|
          @bot.plugins.unregister_plugin(p)
        end

        Cinch::Plugins.__send__(:remove_const, plugin)

        m.reply "Successfully unloaded #{plugin}"
      end

      def reload_plugin(m, plugin, mapping)
        return unless allowed_user?(m.user)

        unload_plugin(m, plugin)
        load_plugin(m, plugin, mapping)
      end

      def set_option(m, plugin, option, value)
        return unless allowed_user?(m.user)

        @bot.config.plugins.options[plugin][option.to_sym] = eval(value)
      end

      private
      # @param [User] user
      # @return [Boolean]
      def allowed_user?(user)
        user.refresh
        config[:allowed_users].include?(user.authname)
      end
    end
  end
end