class PushEventSerializer
  include JSONAPI::Serializer

  attributes :github_id, :ref, :head, :before, :push_id

  belongs_to :actor
  belongs_to :repository
end
