export interface PushEvent {
  id: string;
  githubId: string;
  ref: string;
  head: string;
  before: string;
  pushId: number;
  actorId: string | null;
  repositoryId: string | null;
}
