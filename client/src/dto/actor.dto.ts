import type { JsonApiCollectionDto } from "./jsonApi.dto";

/** Attributes shape as returned by ActorSerializer */
export interface ActorAttributesDto {
  github_id: number;
  login: string;
  display_login: string;
  avatar_url: string;
  url: string;
}

export type ActorCollectionDto = JsonApiCollectionDto<
  "actor",
  ActorAttributesDto
>;
