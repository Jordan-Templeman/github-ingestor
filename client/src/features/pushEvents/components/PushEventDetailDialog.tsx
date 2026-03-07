import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Stack,
  CircularProgress,
  Alert,
} from "@mui/material";
import { useGetPushEventQuery } from "../../../store/api";
import type { Actor } from "../../../entities/Actor";
import type { Repository } from "../../../entities/Repository";
import DetailRow from "./DetailRow";
import ActorDetail from "./ActorDetail";
import RepositoryDetail from "./RepositoryDetail";

interface PushEventDetailDialogProps {
  eventId: string | null;
  actor: Actor | undefined;
  repository: Repository | undefined;
  onClose: () => void;
}

const PushEventDetailDialog = ({
  eventId,
  actor,
  repository,
  onClose,
}: PushEventDetailDialogProps) => {
  const { data: event, isLoading, error } = useGetPushEventQuery(eventId!, {
    skip: !eventId,
  });

  return (
    <Dialog open={!!eventId} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Push Event Details</DialogTitle>
      <DialogContent>
        {isLoading && <CircularProgress />}
        {error && <Alert severity="error">Failed to load event details.</Alert>}
        {event && (
          <Stack spacing={2} sx={{ pt: 1 }}>
            <DetailRow label="GitHub ID" value={event.githubId} />
            <DetailRow label="Ref" value={event.ref} />
            <DetailRow label="Head" value={event.head} mono />
            <DetailRow label="Before" value={event.before} mono />
            <DetailRow label="Push ID" value={String(event.pushId)} />
            {actor && <ActorDetail actor={actor} />}
            {repository && <RepositoryDetail repository={repository} />}
          </Stack>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
};

export default PushEventDetailDialog;
