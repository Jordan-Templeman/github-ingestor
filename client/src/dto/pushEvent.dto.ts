import type { JsonApiCollectionDto, JsonApiSingleDto } from "./jsonApi.dto";

/** Attributes shape as returned by PushEventSerializer */
export interface PushEventAttributesDto {
  github_id: string;
  ref: string;
  head: string;
  before: string;
  push_id: number;
}

export type PushEventCollectionDto = JsonApiCollectionDto<
  "push_event",
  PushEventAttributesDto
>;

export type PushEventSingleDto = JsonApiSingleDto<
  "push_event",
  PushEventAttributesDto
>;
