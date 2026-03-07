module Api
  module V1
    class ActorsController < BaseController
      def index
        actors = Actor.all
        actors = actors.where(login: params.dig(:filter, :login)) if params.dig(:filter, :login).present?
        actors = actors.order(id: :asc).limit(page_limit).offset(page_offset)

        render json: ::ActorSerializer.new(actors).serializable_hash, status: :ok
      end

      def show
        actor = Actor.find_by(id: params[:id])
        return render_not_found('Actor') unless actor

        render json: ::ActorSerializer.new(actor).serializable_hash, status: :ok
      end
    end
  end
end
