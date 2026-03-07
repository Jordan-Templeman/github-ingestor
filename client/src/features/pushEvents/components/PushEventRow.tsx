import { TableCell, TableRow, IconButton, Tooltip, Chip, Avatar, Stack } from "@mui/material";
import VisibilityIcon from "@mui/icons-material/Visibility";
import type { PushEvent } from "../../../entities/PushEvent";
import type { Actor } from "../../../entities/Actor";
import type { Repository } from "../../../entities/Repository";

interface PushEventRowProps {
  event: PushEvent;
  actor: Actor | undefined;
  repository: Repository | undefined;
  onViewDetail: (event: PushEvent) => void;
}

const formatRef = (ref: string): string =>
  ref.replace(/^refs\/heads\//, "");

const truncateHash = (hash: string): string =>
  hash.slice(0, 7);

const PushEventRow = ({
  event,
  actor,
  repository,
  onViewDetail,
}: PushEventRowProps) => (
  <TableRow hover>
    <TableCell>{event.githubId}</TableCell>
    <TableCell>
      <Stack direction="row" gap="4px" alignItems="center">
        <Avatar
          src={actor?.avatarUrl}
          alt={actor?.login}
          sx={{ width: 24, height: 24 }}
        />
        {actor?.login ?? "—"}
      </Stack>
    </TableCell>
    <TableCell>{repository?.name ?? "—"}</TableCell>
    <TableCell>
      <Chip label={formatRef(event.ref)} size="small" />
    </TableCell>
    <TableCell>
      <code>{truncateHash(event.head)}</code>
    </TableCell>
    <TableCell align="center">
      <Tooltip title="View details">
        <IconButton size="small" onClick={() => onViewDetail(event)}>
          <VisibilityIcon fontSize="small" />
        </IconButton>
      </Tooltip>
    </TableCell>
  </TableRow>
);

export default PushEventRow;
