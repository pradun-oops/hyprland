hl.config({
    animations = {
        enabled = true,
    }
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 5,
    bezier = "default",
    style = "slide",
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 4,
    bezier = "default",
    style = "slide",
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 6,
    bezier = "default",
})

hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 5,
    bezier = "default",
})

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 6,
    bezier = "default",
    style = "slide",
})

hl.animation({
    leaf = "border",
    enabled = true,
    speed = 8,
    bezier = "default",
})

hl.animation({
    leaf = "specialWorkspaceIn",
    enabled = true,
    speed = 4.5,
    bezier = "default",
    style = "slidefadevert -20%",
})

hl.animation({
    leaf = "specialWorkspaceOut",
    enabled = true,
    speed = 4.5,
    bezier = "default",
    style = "slidefadevert -20%",
})