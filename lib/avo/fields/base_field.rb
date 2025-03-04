module Avo
  module Fields
    class BaseField
      extend ActiveSupport::DescendantsTracker
      extend Avo::Fields::FieldExtensions::HasFieldName
      include Avo::Fields::FieldExtensions::VisibleInDifferentViews

      attr_reader :id
      attr_reader :block
      attr_reader :required
      attr_reader :readonly
      attr_reader :sortable
      attr_reader :nullable
      attr_reader :null_values
      attr_reader :format_using
      attr_reader :placeholder
      attr_reader :help
      attr_reader :default
      attr_reader :visible
      attr_reader :as_label
      attr_reader :as_avatar
      attr_reader :as_description

      # Private options
      attr_reader :updatable
      attr_reader :computable # if allowed to be computable
      attr_reader :computed # if block is present
      attr_reader :computed_value # the value after computation

      # Hydrated payload
      attr_reader :model
      attr_reader :view
      attr_reader :resource
      attr_reader :action
      attr_reader :user
      attr_reader :panel_name

      class_attribute :field_name_attribute

      def initialize(id, _options: {}, **args, &block)
        super(id, **args, &block)

        @id = id
        @name = args[:name]
        @translation_key = args[:translation_key]
        @translation_enabled = false
        @block = block
        @required = args[:required] || false
        @readonly = args[:readonly] || false
        @sortable = args[:sortable] || false
        @nullable = args[:nullable] || false
        @null_values = args[:null_values] || [nil, ""]
        @format_using = args[:format_using] || nil
        @placeholder = args[:placeholder] || id.to_s.humanize(keep_id_suffix: true)
        @help = args[:help] || nil
        @default = args[:default] || nil
        @visible = args[:visible] || true
        @as_label = args[:as_label] || false
        @as_avatar = args[:as_avatar] || false
        @as_description = args[:as_description] || false

        @updatable = true
        @computable = true
        @computed = block.present?
        @computed_value = nil

        # Set the visibility
        show_on args[:show_on] if args[:show_on].present?
        hide_on args[:hide_on] if args[:hide_on].present?
        only_on args[:only_on] if args[:only_on].present?
        except_on args[:except_on] if args[:except_on].present?
      end

      def hydrate(model: nil, resource: nil, action: nil, view: nil, panel_name: nil, user: nil, translation_enabled: nil)
        @model = model if model.present?
        @view = view if view.present?
        @resource = resource if resource.present?
        @action = action if action.present?
        @user = user if user.present?
        @panel_name = panel_name if panel_name.present?
        @translation_enabled = translation_enabled if translation_enabled.present?

        self
      end

      def translation_key
        return "avo.field_translations.#{@id}" if @translation_enabled

        @translation_key
      end

      def name
        return @name if @name.present?

        return I18n.t(translation_key, count: 1).capitalize if translation_key

        @id.to_s.humanize(keep_id_suffix: true)
      end

      def visible?
        if visible.present? && visible.respond_to?(:call)
          visible.call resource: @resource
        else
          visible
        end
      end

      def value(property = nil)
        property ||= id

        # Get model value
        final_value = @model.send(property) if (model_or_class(@model) == "model") && @model.respond_to?(property)

        if (@view === :new) || @action.present?
          final_value = if default.present? && default.respond_to?(:call)
            default.call
          else
            default
          end
        end

        # Run callback block if present
        if computable && block.present?
          final_value = block.call @model, @resource, @view, self
        end

        # Run the value through resolver if present
        final_value = @format_using.call final_value if @format_using.present?

        final_value
      end

      def fill_field(model, key, value, params)
        return model unless model.methods.include? key.to_sym

        model.send("#{key}=", value)

        model
      end

      # Try to see if the field has a different database ID than it's name
      def database_id(model)
        foreign_key
      rescue
        id
      end

      def has_own_panel?
        false
      end

      def resolve_attribute(value)
        value
      end

      def to_permitted_param
        id.to_sym
      end

      def view_component_name
        "#{type.camelize}Field"
      end

      def component_for_view(view = :index)
        "Avo::Fields::#{view_component_name}::#{view.to_s.camelize}Component".safe_constantize
      end

      def model_errors
        return {} if model.nil?

        model.errors
      end

      def type
        self.class.name.demodulize.to_s.underscore.gsub("_field", "")
      end

      def custom?
        !method(:initialize).source_location.first.include?("lib/avo/field")
      rescue
        true
      end

      private

      def model_or_class(model)
        if model.instance_of?(String)
          "class"
        else
          "model"
        end
      end
    end
  end
end
