import { Avatar, Divider, Stack, Typography } from "@mui/material";
import type { Actor } from "../../../entities/Actor";

interface ActorDetailProps {
  actor: Actor;
}

const ActorDetail = ({ actor }: ActorDetailProps) => (
  <>
    <Divider />
    <Typography variant="subtitle2">Actor</Typography>
    <Stack direction="row" spacing={2} alignItems="center">
      <Avatar
        src={actor.avatarUrl}
        alt={actor.login}
        sx={{ width: 32, height: 32 }}
      />
      <Typography variant="body2">{actor.displayLogin}</Typography>
    </Stack>
  </>
);

export default ActorDetail;
