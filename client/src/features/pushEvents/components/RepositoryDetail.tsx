import { Divider, Typography } from "@mui/material";
import type { Repository } from "../../../entities/Repository";
import DetailRow from "./DetailRow";

interface RepositoryDetailProps {
  repository: Repository;
}

const RepositoryDetail = ({ repository }: RepositoryDetailProps) => (
  <>
    <Divider />
    <Typography variant="subtitle2">Repository</Typography>
    <DetailRow label="Name" value={repository.name} />
    {repository.fullName && (
      <DetailRow label="Full Name" value={repository.fullName} />
    )}
  </>
);

export default RepositoryDetail;
