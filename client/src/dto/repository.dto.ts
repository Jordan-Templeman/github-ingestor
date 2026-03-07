import type { JsonApiCollectionDto } from "./jsonApi.dto";

/** Attributes shape as returned by RepositorySerializer */
export interface RepositoryAttributesDto {
  github_id: number;
  name: string;
  full_name: string;
  url: string;
}

export type RepositoryCollectionDto = JsonApiCollectionDto<
  "repository",
  RepositoryAttributesDto
>;
