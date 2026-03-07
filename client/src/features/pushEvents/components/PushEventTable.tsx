import {
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
} from "@mui/material";
import type { PushEvent } from "../../../entities/PushEvent";
import type { Actor } from "../../../entities/Actor";
import type { Repository } from "../../../entities/Repository";
import PushEventRow from "./PushEventRow";

interface PushEventTableProps {
  events: PushEvent[];
  actors: Map<string, Actor>;
  repositories: Map<string, Repository>;
  onViewDetail: (event: PushEvent) => void;
}

const PushEventTable = ({
  events,
  actors,
  repositories,
  onViewDetail,
}: PushEventTableProps) => (
  <TableContainer component={Paper} variant="outlined">
    <Table size="small">
      <TableHead>
        <TableRow>
          <TableCell>ID</TableCell>
          <TableCell>Actor</TableCell>
          <TableCell>Repository</TableCell>
          <TableCell>Ref</TableCell>
          <TableCell>Head</TableCell>
          <TableCell align="center">Actions</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {events.map((event) => (
          <PushEventRow
            key={event.id}
            event={event}
            actor={event.actorId ? actors.get(event.actorId) : undefined}
            repository={
              event.repositoryId
                ? repositories.get(event.repositoryId)
                : undefined
            }
            onViewDetail={onViewDetail}
          />
        ))}
      </TableBody>
    </Table>
  </TableContainer>
);

export default PushEventTable;
