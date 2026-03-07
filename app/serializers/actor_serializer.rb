class ActorSerializer
  include JSONAPI::Serializer

  attributes :github_id, :login, :display_login, :avatar_url, :url
end
