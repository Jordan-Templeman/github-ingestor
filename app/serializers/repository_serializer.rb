class RepositorySerializer
  include JSONAPI::Serializer

  attributes :github_id, :name, :full_name, :url
end
