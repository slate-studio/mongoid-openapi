# EXTRA LINKS:
# - https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md
# - https://github.com/fotinakis/swagger-blocks
# - https://github.com/westfieldlabs/apivore
# - https://github.com/notonthehighstreet/svelte

module SwaggerGenerator
  extend ActiveSupport::Concern
  require 'action_dispatch/routing/inspector'

  included do
    include Swagger::Blocks
    class_attribute :swagger_base_path
    class_attribute :swagger_collection_name
    class_attribute :swagger_relative_path
    class_attribute :swagger_ignore_custom_actions
    class_attribute :swagger_resource_class_name
    class_attribute :swagger_scopes
    class_attribute :swagger_json_requests
  end

  class_methods do
    REJECT_NAMES = %w(_id).freeze
    # Available property/model fields types in Swagger:
    # http://files.slatestudio.com/gG30
    ALLOW_TYPES  = %w(Object BSON::ObjectId Time String Integer Array Date Mongoid::Boolean Symbol)

    def swagger_options(options)
      self.swagger_base_path             = options[:base_path]
      self.swagger_collection_name       = options[:collection_name]
      self.swagger_relative_path         = options[:relative_path]
      self.swagger_ignore_custom_actions = options[:ignore_custom_actions]
      self.swagger_resource_class_name   = options[:resource_class_name]
      self.swagger_scopes                = options[:scopes]
      self.swagger_json_requests         = options[:json_requests]
    end

    def generate_swagger
      generate_swagger_schemas
      generate_swagger_paths
    end

    def fetch_mounted_routes
      parsed_routes = []
      crud_actions  = ['index', 'show', 'create', 'update', 'destroy']
      controller = to_s.underscore.gsub('::', '/').gsub('_controller','')
      # Code From rake routes
      all_routes = Rails.application.routes.routes
      inspector = ActionDispatch::Routing::RoutesInspector.new(all_routes)
      routes = inspector.format(ActionDispatch::Routing::ConsoleFormatter.new, controller)

      routes = routes.split("\n")
      # Delete Header of Table
      routes.shift
      # Parse routes
      routes.each do |r|
        action = r.sub(/.*?#/, '')
        route  = r.split(" ")
        path   = route[-2].gsub('(.:format)','')
        method = route[-3].underscore
        parsed_routes.push( { action: action,
                              path: path,
                              method: method } )
      end
      custom_routes = parsed_routes
                      .select { |r| crud_actions.exclude?(r[:action]) }
      actions = routes.map { |r| r.sub(/.*?#/, '') }
      return actions, custom_routes
    end

    def collection_name
      @collection_name ||= to_s.split("::").last.sub(/Controller$/, '')
    end

    def resource_name
      @resource_name ||= collection_name.singularize
    end

    def fetch_required_fields(resource_class)
      validators = resource_class.validators
      presence_validators =
        validators
        .select { |v| v.class == Mongoid::Validatable::PresenceValidator }
      required_fields = presence_validators.map { |v| v.attributes.first }
      required_fields << '_id'
      required_fields
    end

    def generate_swagger_schemas
      self.swagger_resource_class_name ||= resource_name
      resource_class = swagger_resource_class_name.constantize
      required_fields = fetch_required_fields(resource_class)
      class_name = swagger_resource_class_name.underscore.to_sym

      swagger_schema swagger_resource_class_name do
        key :required, required_fields
        resource_class.fields.each do |name, options|
          type = options.type.to_s
          if ALLOW_TYPES.include? type
            defaul_value = options.options[:default]
            property name do
              # TODO: describe type :file
              case type
              when 'Symbol'
                klass = options.options[:klass].to_s
                constant = name.sub('_', '').upcase
                values = "#{klass}::#{constant}"
                values = values.constantize
                key :type, :string
                key :enum, values
              when 'Array'
                key :type, :array
                # TODO: autodetect type of Array Item
                items do
                  key :type, :string
                end
              when 'BSON::ObjectId'
                key :type, :string
                key :format, :uuid
              when 'Date'
                key :type, :string
                key :format, :date
              when 'Time'
                key :type, :string
                key :format, 'date-time'
              when 'Mongoid::Boolean'
                key :type, :boolean
                key :default, defaul_value
              when 'Integer'
                key :type, :integer
                key :default, defaul_value.to_i
              else
                key :type, :string
                key :default, defaul_value.to_s
              end
            end
          end
        end
      end

      # Using in operation: post as example for input
      # Put only reqired fields for creating object
      swagger_schema "#{resource_class}Input" do
        property class_name, type: :object do
          key :required, required_fields
          input_fields = required_fields.map { |r_f| r_f.to_s }
          resource_class.fields.each do |name, options|
            type = options.type.to_s
            if ALLOW_TYPES.include? type
              unless REJECT_NAMES.include? name
                if input_fields.include? name
                  defaul_value = options.options[:default]
                  property name do
                    case type
                    when 'Symbol'
                      klass = options.options[:klass].to_s
                      constant = name.sub('_', '').upcase
                      values = "#{klass}::#{constant}"
                      values = values.constantize
                      key :type, :string
                      key :enum, values
                    when 'Array'
                      key :type, :array
                      items do
                        key :type, :string
                      end
                    when 'BSON::ObjectId'
                      key :type, :string
                      key :format, :uuid
                    when 'Date'
                      key :type, :string
                      key :format, :date
                    when 'Time'
                      key :type, :string
                      key :format, 'date-time'
                    when 'Mongoid::Boolean'
                      key :type, :boolean
                      key :default, defaul_value
                    when 'Integer'
                      key :type, :integer
                      key :default, defaul_value.to_i
                    else
                      key :type, :string
                      key :default, defaul_value.to_s
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    def generate_swagger_paths
      self.swagger_ignore_custom_actions ||= false
      self.swagger_json_requests         ||= false
      self.swagger_base_path             ||= ''
      self.swagger_relative_path         ||= collection_name.underscore
      self.swagger_resource_class_name   ||= resource_name
      self.swagger_collection_name       ||= collection_name
      self.swagger_scopes                ||= nil

      path   = swagger_relative_path
      name   = swagger_resource_class_name
      json   = swagger_json_requests
      plural = swagger_collection_name
      scopes = swagger_scopes
      tags   = [ plural ]
      actions, custom_routes = fetch_mounted_routes

      if json
        path = "#{path}.json"
      end

      if actions.include?('index') || actions.include?('create')
        swagger_path "/#{ path }" do
          if actions.include?('index')
            operation :get do
              key :tags, tags
              key :summary, "Index"
              key :operationId, "index#{ plural }"
              key :produces, %w(application/json text/csv)

              if scopes && scopes.size > 0
                scopes.each do |scope|
                  scope_type = scope[:type] || :string
                  parameter do
                    key :name,     scope[:name]
                    key :in,       :query
                    key :required, false
                    key :type,     scope_type
                    key :format,   :int32
                  end
                end
              end

              parameter do
                key :name,     :page
                key :in,       :query
                key :required, false
                key :type,     :integer
                key :format,   :int32
              end

              parameter do
                key :name,     :perPage
                key :in,       :query
                key :required, false
                key :type,     :integer
                key :format,   :int32
              end

              parameter do
                key :name,     :search
                key :in,       :query
                key :required, false
                key :type,     :string
              end

              response 200 do
                schema type: :array do
                  items do
                    key :'$ref', name
                  end
                end
              end
            end
          end

          if actions.include?('create')
            operation :post do
              key :tags, tags
              key :summary, "Create"
              key :operationId, "create#{ plural }"
              key :produces,    %w(application/json)
              parameter do
                key :name,     "body{#{name.underscore.to_sym}}"
                key :in,       :body
                key :required, true
                schema do
                  key :'$ref', "#{name}Input"
                end
              end
              response 200 do
                schema do
                  key :'$ref', name
                end
              end
            end
          end
        end
      end

      path = swagger_relative_path
      path = "#{path}/{id}"
      if json
        path = "#{path}.json"
      end

      if actions.include?('show') ||
        actions.include?('update') ||
        actions.include?('destroy')

        swagger_path "/#{ path }" do
          if actions.include?('show')
            operation :get do
              key :tags, tags
              key :summary, "Show"
              key :operationId, "show#{ name }ById"
              key :produces,    %w(application/json)
              parameter do
                key :name,     :id
                key :in,       :path
                key :required, true
                key :type,     :string
              end
              response 200 do
                schema do
                  key :'$ref', name
                end
              end
            end
          end

          if actions.include?('update')
            operation :put do
              key :tags, tags
              key :summary, "Update"
              key :operationId, "update#{ name }"
              key :produces,    %w(application/json)
              parameter do
                key :name,     :id
                key :in,       :path
                key :required, true
                key :type,     :string
              end
              parameter do
                key :name,     "body{#{name.underscore.to_sym}}"
                key :in,       :body
                key :required, true
                schema do
                  key :'$ref', "#{name}Input"
                end
              end
              response 200 do
                schema do
                  key :'$ref', name
                end
              end
            end
          end

          if actions.include?('destroy')
            operation :delete do
              key :tags, tags
              key :summary, "Destroy"
              key :operationId, "delete#{ name }"
              parameter do
                key :name,     :id
                key :in,       :path
                key :required, true
                key :type,     :string
              end
              response 204 do
                key :description, "#{ name } deleted"
              end
            end
          end
        end
      end
      unless swagger_ignore_custom_actions
        generate_swagger_custom_paths(custom_routes)
      end
    end

    def generate_swagger_custom_paths(custom_routes)
      name   = swagger_resource_class_name || resource_name
      plural = swagger_collection_name || collection_name
      tags   = [ plural ]

      custom_routes.each do |route|
        path = route[:path].gsub(swagger_base_path, '')
        if path.include?(':id')
          path = path.gsub(':id', '{id}')
          swagger_path "#{ path }" do
            operation route[:method] do
              key :tags, tags
              key :summary, 'Default action schema is used, custom Swagger description is required.'
              key :operationId, "#{ route[:action] }#{ name }ById"
              key :produces,    %w(application/json)
              parameter do
                key :name,     :id
                key :in,       :path
                key :required, true
                key :type,     :string
              end
              response 200 do
                schema do
                  key :'$ref', name
                end
              end
            end
          end
        else
          swagger_path "#{ path }" do
            operation route[:method] do
              key :tags, tags
              key :summary, 'Default action schema is used, custom Swagger description is required.'
              key :operationId, "#{ route[:action] }#{ name }ById"
              key :produces,    %w(application/json)
              response 200 do
                schema do
                  key :'$ref', name
                end
              end
            end
          end
        end
      end
    end

  end
end
