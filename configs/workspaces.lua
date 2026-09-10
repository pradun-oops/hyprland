-- ==========================================================
-- 🖥️ Workspace-to-Monitor Binding Rules
-- Maps dedicated virtual workspaces across multi-display setups:
-- External Display (1-5) & Built-in Laptop Display (6-10).
-- ==========================================================

-- ==========================================================
-- 🖥️ Main Display (HDMI-A-1)
-- Workspaces 1 through 5 assigned to the primary external monitor.
-- ==========================================================
for ws = 1, 5 do
    hl.workspace_rule({ workspace = tostring(ws), monitor = "HDMI-A-1" })
end

-- ==========================================================
-- 💻 Secondary Display (eDP-1)
-- Workspaces 6 through 10 assigned to the internal laptop screen.
-- ==========================================================
for ws = 6, 10 do
    hl.workspace_rule({ workspace = tostring(ws), monitor = "eDP-1" })
end