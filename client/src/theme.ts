import { createTheme } from "@mui/material/styles";

const theme = createTheme({
  palette: {
    primary: {
      main: "#1976d2",
    },
    secondary: {
      main: "#7c4dff",
    },
    background: {
      default: "#f5f7fa",
    },
  },
  typography: {
    h4: {
      fontWeight: 600,
    },
  },
  components: {
    MuiTableHead: {
      styleOverrides: {
        root: {
          backgroundColor: "#f0f4f8",
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        head: {
          fontWeight: 600,
          color: "#475569",
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          fontFamily: "monospace",
          fontSize: "0.8rem",
        },
      },
    },
  },
});

export default theme;
