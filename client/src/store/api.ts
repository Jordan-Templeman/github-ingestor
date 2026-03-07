import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";
import type { PushEventCollectionDto, PushEventSingleDto } from "../dto/pushEvent.dto";
import type { ActorCollectionDto } from "../dto/actor.dto";
import type { RepositoryCollectionDto } from "../dto/repository.dto";
import type { PushEvent } from "../entities/PushEvent";
import type { Actor } from "../entities/Actor";
import type { Repository } from "../entities/Repository";
import { mapPushEventDto, mapActorDto, mapRepositoryDto } from "../dto/mappers";

export const PAGE_SIZE = 25;

export interface PushEventFilters {
  actor?: string;
  repository?: string;
}

export interface PushEventQueryArgs {
  filters: PushEventFilters;
  page: number;
}

const buildQueryString = ({ filters, page }: PushEventQueryArgs): string => {
  const params = new URLSearchParams();
  params.set("page[limit]", String(PAGE_SIZE));
  params.set("page[offset]", String(page * PAGE_SIZE));
  if (filters.actor) params.set("filter[actor]", filters.actor);
  if (filters.repository) params.set("filter[repository]", filters.repository);
  return params.toString();
};

export const api = createApi({
  reducerPath: "api",
  baseQuery: fetchBaseQuery({ baseUrl: "/api/v1" }),
  tagTypes: ["PushEvent", "Actor", "Repository"],
  endpoints: (builder) => ({
    getPushEvents: builder.query<PushEvent[], PushEventQueryArgs>({
      query: (args) => `push_events?${buildQueryString(args)}`,
      transformResponse: (response: PushEventCollectionDto) =>
        response.data.map(mapPushEventDto),
      providesTags: ["PushEvent"],
    }),

    getPushEvent: builder.query<PushEvent, string>({
      query: (id) => `push_events/${id}`,
      transformResponse: (response: PushEventSingleDto) =>
        mapPushEventDto(response.data),
    }),

    getActors: builder.query<Actor[], void>({
      query: () => "actors?page[limit]=100",
      transformResponse: (response: ActorCollectionDto) =>
        response.data.map(mapActorDto),
      providesTags: ["Actor"],
    }),

    getRepositories: builder.query<Repository[], void>({
      query: () => "repositories?page[limit]=100",
      transformResponse: (response: RepositoryCollectionDto) =>
        response.data.map(mapRepositoryDto),
      providesTags: ["Repository"],
    }),
  }),
});

export const {
  useGetPushEventsQuery,
  useGetPushEventQuery,
  useGetActorsQuery,
  useGetRepositoriesQuery,
} = api;
