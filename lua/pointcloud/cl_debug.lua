pointcloud.Debug = pointcloud.Debug or {}

pointcloud.Debug.Enabled = CreateClientConVar("pointcloud_debug", "0", true, false)

pointcloud.Debug.Filesize = pointcloud.Debug.Filesize or 0
pointcloud.Debug.SamplerTime = 0
pointcloud.Debug.MinimapTime = 0
pointcloud.Debug.ProjectionTime = 0
pointcloud.Debug.RenderTargets = 0