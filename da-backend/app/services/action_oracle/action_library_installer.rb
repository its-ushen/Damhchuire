module ActionOracle
  class ActionLibraryInstaller
    def self.call(actions: ActionLibrary.actions)
      new(actions: actions).call
    end

    def initialize(actions:)
      @actions = actions
    end

    def call
      created = []
      updated = []

      Action.transaction do
        @actions.each do |definition|
          slug = definition.fetch(:slug)
          attributes = definition.except(:slug)
          action = Action.find_or_initialize_by(slug: slug)
          was_new = action.new_record?

          action.assign_attributes(attributes)
          next unless was_new || action.changed?

          action.save!
          (was_new ? created : updated) << slug
        end
      end

      {
        created: created.sort,
        updated: updated.sort
      }
    end
  end
end
