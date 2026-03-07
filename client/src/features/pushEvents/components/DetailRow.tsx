import { Stack, Typography, type SxProps, type Theme } from "@mui/material";

interface DetailRowProps {
  label: string;
  value: string;
  mono?: boolean;
}

const monoStyle: SxProps<Theme> = { fontFamily: "monospace" };

const DetailRow = ({ label, value, mono = false }: DetailRowProps) => (
  <Stack direction="row" spacing={2} justifyContent="space-between">
    <Typography variant="body2" color="text.secondary" sx={{ minWidth: 100 }}>
      {label}
    </Typography>
    <Typography variant="body2" sx={mono ? monoStyle : undefined}>
      {value}
    </Typography>
  </Stack>
);

export default DetailRow;
