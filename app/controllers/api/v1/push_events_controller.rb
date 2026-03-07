module Api
  module V1
    class PushEventsController < BaseController
      def index
        events = PushEvent.includes(:actor, :repository)
        events = apply_filters(events)
        events = events.limit(page_limit).offset(page_offset)

        render json: ::PushEventSerializer.new(events).serializable_hash.to_json, status: :ok
      end

      def show
        event = PushEvent.includes(:actor, :repository).find_by(id: params[:id])
        return render_not_found('PushEvent') unless event

        render json: ::PushEventSerializer.new(event).serializable_hash.to_json, status: :ok
      end

      private

      def apply_filters(scope)
        scope = filter_by_ref(scope)
        scope = filter_by_actor(scope)
        filter_by_repository(scope)
      end

      def filter_by_ref(scope)
        return scope if params.dig(:filter, :ref).blank?

        scope.where(ref: params.dig(:filter, :ref))
      end

      def filter_by_actor(scope)
        return scope if params.dig(:filter, :actor).blank?

        scope.joins(:actor).where(actors: { login: params.dig(:filter, :actor) })
      end

      def filter_by_repository(scope)
        return scope if params.dig(:filter, :repository).blank?

        scope.joins(:repository).where(repositories: { name: params.dig(:filter, :repository) })
      end
    end
  end
end
