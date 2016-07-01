# Mongoid OpenAPI

Rails concern to implement CRUD API controllers for
[Mongoid](https://github.com/mongodb/mongoid) models using Open API
([Swagger](http://swagger.io/)) specification.

## Swagger generator
Automatic generate powerful representation of your RESTful API.

Setup:
- Add to you Controller ```include SwaggerGenerator```
- Add to the end of controller:  ```generate_swagger``` to generate swagger description of current controller's actions
- To integrate these description with Swagger UI - [Add routes and create Swagger Controller](https://github.com/fotinakis/swagger-blocks#docs-controller)
- Check Swagger UI at `localhost:3000/docs/api/swaggers`

### Swagger generator has several configurations/options
swagger_options:
- `json_requests: true` - make all call in json format
- `scopes: [ { name: :selects, type: :boolean } ]` - add [sope](https://github.com/plataformatec/has_scope) to swagger
- `resource_class_name: 'UserProfessional'` - customize resource/model name. For case, when you have ProfileController, but working/using UserProfessional model here
- `ignore_custom_actions: true` - don't generate custom/not CRUD actions
- `collection_name: 'Bootstrap'` - For Customize tags and OperationId postfix
- `base_path: '/api/admin'` - if you using `key :basePath` in [Swagger Controller](https://github.com/fotinakis/swagger-blocks#docs-controller) write it here
- `relative_path: 'professional/projects'` (Will be depricated and using only `base_path`) - use relative path without basePath for actions.Might be helpfull when `key :basePath, '/api'` present in [Swagger Controller](https://github.com/fotinakis/swagger-blocks#docs-controller), to prevent generating paths: `'api/api/professional/projects'`