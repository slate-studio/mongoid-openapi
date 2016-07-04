module ExtendBlocksMethods
  extend ActiveSupport::Concern
  # Available property/model fields types in Swagger:
  # http://files.slatestudio.com/gG30
  ALLOW_TYPES  = %w(Object BSON::ObjectId Time String Integer Array Date Mongoid::Boolean Symbol)
  REJECT_NAMES = %w(_id).freeze

  def generate_model_fields(resource_class, only_required=false)
    required_fields = fetch_required_fields(resource_class)
    if only_required
      input_fields = required_fields.map { |r_f| r_f.to_s unless REJECT_NAMES.include? r_f.to_s }
      input_fields = input_fields.compact
    else
      input_fields = resource_class.fields.map { |name, options| name }
    end
    key :required, required_fields
    resource_class.fields.each do |name, options|
      type = options.type.to_s
      if ALLOW_TYPES.include? type
        if input_fields.include? name
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
end