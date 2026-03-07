import type { ActorAttributesDto } from "./actor.dto";
import type { JsonApiResourceDto } from "./jsonApi.dto";
import type { PushEventAttributesDto } from "./pushEvent.dto";
import type { RepositoryAttributesDto } from "./repository.dto";
import type { Actor } from "../entities/Actor";
import type { PushEvent } from "../entities/PushEvent";
import type { Repository } from "../entities/Repository";

export function mapPushEventDto(
  resource: JsonApiResourceDto<"push_event", PushEventAttributesDto>
): PushEvent {
  return {
    id: resource.id,
    githubId: resource.attributes.github_id,
    ref: resource.attributes.ref,
    head: resource.attributes.head,
    before: resource.attributes.before,
    pushId: resource.attributes.push_id,
    actorId: resource.relationships?.actor?.data
      ? (resource.relationships.actor.data as { id: string }).id
      : null,
    repositoryId: resource.relationships?.repository?.data
      ? (resource.relationships.repository.data as { id: string }).id
      : null,
  };
}

export function mapActorDto(
  resource: JsonApiResourceDto<"actor", ActorAttributesDto>
): Actor {
  return {
    id: resource.id,
    githubId: resource.attributes.github_id,
    login: resource.attributes.login,
    displayLogin: resource.attributes.display_login,
    avatarUrl: resource.attributes.avatar_url,
    url: resource.attributes.url,
  };
}

export function mapRepositoryDto(
  resource: JsonApiResourceDto<"repository", RepositoryAttributesDto>
): Repository {
  return {
    id: resource.id,
    githubId: resource.attributes.github_id,
    name: resource.attributes.name,
    fullName: resource.attributes.full_name,
    url: resource.attributes.url,
  };
}
