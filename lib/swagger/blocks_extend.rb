## This extension includes new generate_model_fields(model) method
# which describe in swagger fields fo passed model
require 'swagger/extend_blocks_methods'
module Swagger
  module Blocks
    class SchemaNode
      include ExtendBlocksMethods
    end
    class PropertyNode
      include ExtendBlocksMethods
    end
    class ItemsNode
      include ExtendBlocksMethods
    end
  end
end
