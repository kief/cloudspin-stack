require 'fileutils'

module Cloudspin
  module Stack
    class Instance

      include FileUtils

      attr_reader :id,
        :configuration,
        :working_folder,
        :backend_configuration,
        :terraform_command_arguments

      def initialize(
            id:,
            stack_definition:,
            base_working_folder:,
            configuration:
      )
        validate_id(id)
        @id = id
        @stack_definition = stack_definition
        @working_folder   = "#{base_working_folder}/#{id}"
        @configuration    = configuration
        @backend_configuration = configuration.backend_configuration
        @terraform_command_arguments = {}
        # puts "DEBUG: instance working_folder: #{@working_folder}"
      end

      def self.from_folder(
            *instance_configuration_files,
            definition_location:,
            base_folder: '.',
            base_working_folder:
      )
        self.from_files(
            instance_configuration_files,
            stack_definition: Definition.from_location(
                definition_location,
                definition_cache_folder: "#{base_folder}/.cloudspin/definitions",
                stack_configuration: InstanceConfiguration.load_configuration_values(instance_configuration_files)['stack']
            ),
            base_folder: base_folder,
            base_working_folder: base_working_folder
          )
      end

      def self.from_files(
            *instance_configuration_files,
            stack_definition:,
            base_folder: '.',
            base_working_folder:
      )
        instance_configuration = InstanceConfiguration.from_files(
          instance_configuration_files,
          stack_definition: stack_definition,
          base_folder: base_folder
        )

        self.new(
            id: instance_configuration.instance_identifier,
            stack_definition: stack_definition,
            base_working_folder: base_working_folder,
            configuration: instance_configuration
          )
      end

      def prepare
        clean_working_folder
        create_working_folder
        copy_instance_source
        prepare_state
        @working_folder
      end

      def clean_working_folder
        FileUtils.rm_rf(working_folder)
      end

      def create_working_folder
        mkdir_p File.dirname(working_folder)
      end

      def copy_instance_source
        cp_r @stack_definition.source_path, working_folder
      end

      def ensure_folder(folder)
        FileUtils.mkdir_p folder
        Pathname.new(folder).realdirpath.to_s
      end

      def prepare_state
        @backend_configuration.prepare(working_folder: working_folder)
      end

      def validate_id(raw_id)
        raise "Stack instance ID '#{raw_id}' won't work. It needs to work as a filename." if /[^0-9A-Za-z.\-\_]/ =~ raw_id
        raise "Stack instance ID '#{raw_id}' won't work. No double dots allowed." if /\.\./ =~ raw_id
        raise "Stack instance ID '#{raw_id}' won't work. First character should be a letter." if /^[^A-Za-z]/ =~ raw_id
      end

      def parameter_values
        configuration.parameter_values
      end

      def resource_values
        configuration.resource_values
      end

      def terraform_variables
        parameter_values.merge(resource_values) { |key, oldval, newval|
          raise "Duplicate values for terraform variable '#{key}' ('#{oldval}' and '#{newval}')"
        }.merge({ 'instance_identifier' => id })
      end

      def terraform_init_arguments
        # TODO: Unsmell these
        # (maybe backend_configuration belongs attached directly to this class?)
        @backend_configuration.terraform_init_parameters
      end

      def terraform_command_arguments
        @backend_configuration.terraform_command_parameters
      end

      # def migrate
      #   RubyTerraform.clean(directory: working_folder)
      #   mkdir_p File.dirname(working_folder)
      #   cp_r @stack_definition.source_path, working_folder
      #   Dir.chdir(working_folder) do
      #   # cp @backend_configuration.local_state_folder
      #     terraform_init
      #     # terraform_state_push()
      #     RubyTerraform.plan(terraform_command_parameters)
      #   end
      # end

      # def init
        # if @backend_configuration.migrate_state?
        #   prepare_state_for_migration
        # end
      # end

      # def prepare_state_for_migration
      #   # puts "DEBUG: Preparing to migrate state from #{@backend_configuration.local_statefile}"
      #   cp @backend_configuration.local_statefile, "#{working_folder}/terraform.tfstate"
      # end

    end
  end
end
