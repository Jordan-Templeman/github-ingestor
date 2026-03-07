import { useMemo, useState, useCallback } from "react";
import {
  Container,
  Typography,
  Button,
  Stack,
  CircularProgress,
  Alert,
  Paper,
  Chip,
} from "@mui/material";
import RefreshIcon from "@mui/icons-material/Refresh";
import NavigateBeforeIcon from "@mui/icons-material/NavigateBefore";
import NavigateNextIcon from "@mui/icons-material/NavigateNext";
import {
  useGetPushEventsQuery,
  useGetActorsQuery,
  useGetRepositoriesQuery,
  PAGE_SIZE,
  type PushEventFilters,
} from "../../store/api";
import type { PushEvent } from "../../entities/PushEvent";
import type { Actor } from "../../entities/Actor";
import type { Repository } from "../../entities/Repository";
import PushEventFiltersBar from "./components/PushEventFilters";
import PushEventTable from "./components/PushEventTable";
import PushEventDetailDialog from "./components/PushEventDetailDialog";

const buildLookupMap = <T extends { id: string }>(
  items: T[] | undefined
): Map<string, T> => {
  const map = new Map<string, T>();
  items?.forEach((item) => map.set(item.id, item));
  return map;
};

const Dashboard = () => {
  const [filters, setFilters] = useState<PushEventFilters>({});
  const [page, setPage] = useState(0);
  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);

  const {
    data: events,
    isLoading: eventsLoading,
    error: eventsError,
    isFetching,
    refetch: refetchEvents,
  } = useGetPushEventsQuery({ filters, page });

  const { data: actors } = useGetActorsQuery();
  const { data: repositories } = useGetRepositoriesQuery();

  const actorMap = useMemo<Map<string, Actor>>(
    () => buildLookupMap(actors),
    [actors]
  );

  const repoMap = useMemo<Map<string, Repository>>(
    () => buildLookupMap(repositories),
    [repositories]
  );

  const handleViewDetail = useCallback((event: PushEvent) => {
    setSelectedEventId(event.id);
  }, []);

  const handleCloseDetail = useCallback(() => {
    setSelectedEventId(null);
  }, []);

  const handleApplyFilters = useCallback((newFilters: PushEventFilters) => {
    setFilters(newFilters);
    setPage(0);
  }, []);

  const handleRefresh = useCallback(() => {
    refetchEvents();
  }, [refetchEvents]);

  const handlePrevPage = useCallback(() => {
    setPage((prev) => Math.max(0, prev - 1));
  }, []);

  const handleNextPage = useCallback(() => {
    setPage((prev) => prev + 1);
  }, []);

  const hasNextPage = useMemo(
    () => events !== undefined && events.length === PAGE_SIZE,
    [events]
  );

  const selectedEvent = useMemo(
    () => events?.find((e) => e.id === selectedEventId),
    [events, selectedEventId]
  );

  const selectedActor = useMemo(
    () => (selectedEvent?.actorId ? actorMap.get(selectedEvent.actorId) : undefined),
    [selectedEvent, actorMap]
  );

  const selectedRepo = useMemo(
    () => (selectedEvent?.repositoryId ? repoMap.get(selectedEvent.repositoryId) : undefined),
    [selectedEvent, repoMap]
  );

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Stack
        direction="row"
        justifyContent="space-between"
        alignItems="center"
        sx={{ mb: 3 }}
      >
        <Stack direction="row" spacing={2} alignItems="center">
          <Typography variant="h4" component="h1">
            Push Events
          </Typography>
          {events && (
            <Chip
              label={`Page ${page + 1}`}
              color="primary"
              variant="outlined"
              size="small"
            />
          )}
        </Stack>
        <Button
          variant="outlined"
          startIcon={isFetching ? <CircularProgress size={18} /> : <RefreshIcon />}
          onClick={handleRefresh}
          disabled={isFetching}
        >
          Refresh
        </Button>
      </Stack>

      <Paper sx={{ p: 2, mb: 3 }} variant="outlined">
        <PushEventFiltersBar onApply={handleApplyFilters} initialFilters={filters} />
      </Paper>

      {eventsLoading && (
        <Stack alignItems="center" sx={{ py: 6 }}>
          <CircularProgress />
          <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
            Loading push events...
          </Typography>
        </Stack>
      )}
      {eventsError && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Failed to load push events.
        </Alert>
      )}
      {events && events.length === 0 && page === 0 && (
        <Alert severity="info">
          No push events found. Try adjusting your filters or click Refresh.
        </Alert>
      )}
      {events && events.length > 0 && (
        <PushEventTable
          events={events}
          actors={actorMap}
          repositories={repoMap}
          onViewDetail={handleViewDetail}
        />
      )}

      {events && (events.length > 0 || page > 0) && (
        <Stack direction="row" justifyContent="center" spacing={2} sx={{ mt: 2 }}>
          <Button
            variant="outlined"
            startIcon={<NavigateBeforeIcon />}
            onClick={handlePrevPage}
            disabled={page === 0 || isFetching}
          >
            Previous
          </Button>
          <Button
            variant="outlined"
            endIcon={<NavigateNextIcon />}
            onClick={handleNextPage}
            disabled={!hasNextPage || isFetching}
          >
            Next
          </Button>
        </Stack>
      )}

      <PushEventDetailDialog
        eventId={selectedEventId}
        actor={selectedActor}
        repository={selectedRepo}
        onClose={handleCloseDetail}
      />
    </Container>
  );
};

export default Dashboard;
