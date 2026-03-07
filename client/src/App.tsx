import { AppBar, Toolbar, Typography, Box } from "@mui/material";
import GitHubIcon from "@mui/icons-material/GitHub";
import Dashboard from "./features/pushEvents/Dashboard";

const App = () => (
  <Box sx={{ minHeight: "100vh", bgcolor: "background.default" }}>
    <AppBar position="static" elevation={1}>
      <Toolbar>
        <GitHubIcon sx={{ mr: 1.5 }} />
        <Typography variant="h6" component="div">
          GitHub Ingestor
        </Typography>
      </Toolbar>
    </AppBar>
    <Dashboard />
  </Box>
);

export default App;
