require "../../templates/field.cr"
require "inflector"

module Amber::Recipes::Scaffold
  class Controller < Teeplate::FileTree
    include Amber::CLI::Helpers
    include FileEntries

    @name : String
    @fields : Array(Amber::CLI::Field)
    @visible_fields : Array(Amber::CLI::Field)
    @database : String
    @language : String
    @model : String
    @fields_hash = {} of String => String

    @template : String = ""
    @recipe : String

    def initialize(@name, @recipe, fields)
      @language = CLI.config.language
      @database = CLI.config.database
      @model = CLI.config.model
      @fields = fields.map { |field| Amber::CLI::Field.new(field, database: @database) }
      @fields += %w(created_at:time updated_at:time).map do |f|
        Amber::CLI::Field.new(f, hidden: true, database: @database)
      end
      @visible_fields = @fields.reject { |f| f.hidden }
      field_hash

      @template = RecipeFetcher.new("scaffold", @recipe).fetch
      @template += "/controller" unless @template.nil?

      add_routes :web, <<-ROUTE
        resources "/#{Inflector.pluralize(@name)}", #{class_name}Controller
      ROUTE
    end

    # setup the Liquid context
    def set_context(ctx)
      return if ctx.nil?

      ctx.set "class_name", @class_name
      ctx.set "display_name", @display_name
      ctx.set "name", @name 
      ctx.set "fields", @fields
      ctx.set "visible_fields", @visible_fields
      ctx.set "language", @language
      ctx.set "database", @database
      ctx.set "model", @model
      ctx.set "recipe", @recipe
    end

    def field_hash
      @fields.each do |f|
        if !%w(created_at updated_at).includes?(f.name)
          field_name = f.reference? ? "#{f.name}_id" : f.name
          @fields_hash[field_name] = default_value(f.cr_type) unless f.nil?
        end
      end
    end

    private def default_value(field_type)
      case field_type.downcase
      when "int32", "int64", "integer"
        "1"
      when "float32", "float64", "float"
        "1.00"
      when "bool", "boolean"
        "true"
      when "time", "timestamp"
        Time.now.to_s
      when "ref", "reference", "references"
        rand(100).to_s
      else
        "Fake"
      end
    end
  end
end