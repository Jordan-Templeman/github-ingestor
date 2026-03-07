import { useState, type KeyboardEvent } from "react";
import { TextField, Stack, Button } from "@mui/material";
import FilterListIcon from "@mui/icons-material/FilterList";
import type { PushEventFilters as Filters } from "../../../store/api";

interface PushEventFiltersProps {
  onApply: (filters: Filters) => void;
  initialFilters: Filters;
}

const PushEventFiltersBar = ({
  onApply,
  initialFilters,
}: PushEventFiltersProps) => {
  const [actor, setActor] = useState(initialFilters.actor ?? "");
  const [repository, setRepository] = useState(
    initialFilters.repository ?? ""
  );

  const handleApply = () => {
    onApply({
      actor: actor.trim() || undefined,
      repository: repository.trim() || undefined,
    });
  };

  const handleClear = () => {
    setActor("");
    setRepository("");
    onApply({});
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "Enter") handleApply();
  };

  return (
    <Stack direction="row" spacing={2} alignItems="center" sx={{ mb: 2 }}>
      <TextField
        label="Actor"
        size="small"
        value={actor}
        onChange={(e) => setActor(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="octocat"
      />
      <TextField
        label="Repository"
        size="small"
        value={repository}
        onChange={(e) => setRepository(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="owner/repo"
      />
      <Button
        variant="contained"
        startIcon={<FilterListIcon />}
        onClick={handleApply}
      >
        Filter
      </Button>
      <Button variant="outlined" onClick={handleClear}>
        Clear
      </Button>
    </Stack>
  );
};

export default PushEventFiltersBar;
