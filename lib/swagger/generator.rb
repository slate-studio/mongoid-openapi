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
  end

  class_methods do
    REJECT_NAMES = %w(_id _keywords created_at updated_at).freeze
    ALLOW_TYPES  = %w(Object String)

    def generate_swagger
      generate_swagger_schemas
      generate_swagger_paths
    end

    def fetch_mounted_actions
      controller = to_s.underscore.gsub('::', '/').gsub('_controller','')
      # Code From rake routes
      all_routes = Rails.application.routes.routes
      inspector = ActionDispatch::Routing::RoutesInspector.new(all_routes)
      routes = inspector.format(ActionDispatch::Routing::ConsoleFormatter.new, controller)

      routes = routes.split("\n")
      # Delete Header of Table
      routes.shift
      actions = routes.map { |r| r.sub(/.*?#/, '') }
      actions
    end

    def collection_name
      @collection_name ||= to_s.split("::").last.sub(/Controller$/, '')
    end

    def resource_name
      @resource_name ||= collection_name.singularize
    end

    def generate_swagger_schemas(name=false)
      name ||= resource_name

      if resource_class
        # TODO: add support for resource class option
      else
        resource_class = name.constantize
      end

      swagger_schema name do
        # TODO: autogenerate list of required fields
        # key :required, %w(name email)

        resource_class.fields.each do |name, options|
          type = options.type.to_s
          if ALLOW_TYPES.include? type
            unless REJECT_NAMES.include? name
              property name do
                key :type, :string
                # TODO: autodetect property type
                # key :format, 'date-time'
              end
            end
          end
        end
      end

      # Using in operation: post as example for input
      # https://github.com/fotinakis/swagger-blocks#petscontroller
      swagger_schema "#{resource_class}Input" do
        allOf do
          schema do
            key :'$ref', resource_class
          end
          schema do
            property :id do
              key :type, :string
            end
          end
        end
      end

    end

    def generate_swagger_paths
      # TODO: generate not standart crud actions, if existed
      name    = resource_name
      plural  = collection_name
      path    = plural.underscore
      tags    = [ plural ]
      actions = fetch_mounted_actions

      if actions.include?('index') || actions.include?('create')
        swagger_path "/#{ path }" do
          if actions.include?('index')
            operation :get do
              key :tags, tags
              key :operationId, "index#{ plural }"
              key :produces, %w(application/json text/csv)

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
              key :operationId, "create#{ plural }"
              key :produces,    %w(application/json)
              parameter do
                key :name,     name.underscore.to_sym
                # key :in,       :form
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

      if actions.include?('show') ||
        actions.include?('update') ||
        actions.include?('destroy')

        swagger_path "/#{ path }/{id}" do
          if actions.include?('show')
            operation :get do
              key :tags, tags
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
              key :operationId, "update#{ name }"
              key :produces,    %w(application/json)
              parameter do
                key :name,     :id
                key :in,       :path
                key :required, true
                key :type,     :string
              end
              parameter do
                key :name,     name.underscore.to_sym
                key :in,       :form
                key :required, true
                schema do
                  key :'$ref', name # input
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
    end
  end
end
