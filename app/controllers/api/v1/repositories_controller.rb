module Api
  module V1
    class RepositoriesController < BaseController
      def index
        repositories = Repository.all
        repositories = repositories.where(name: params.dig(:filter, :name)) if params.dig(:filter, :name).present?
        repositories = repositories.order(id: :asc).limit(page_limit).offset(page_offset)

        render json: ::RepositorySerializer.new(repositories).serializable_hash, status: :ok
      end

      def show
        repository = Repository.find_by(id: params[:id])
        return render_not_found('Repository') unless repository

        render json: ::RepositorySerializer.new(repository).serializable_hash, status: :ok
      end
    end
  end
end
