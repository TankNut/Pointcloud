hook.Add("AddToolMenuCategories", "pointcloud", function()
	spawnmenu.AddToolCategory("Options", "Pointcloud", "Pointcloud")
end)

hook.Add("PopulateToolMenu", "pointcloud", function()
	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_changelog", "Changelog (Last updated: 13 Aug 2020)", "", "", function(pnl)
		pnl:ClearControls()

		pnl:Help([[13 Aug 2020 (Hotfix):

			- Fixed an error when turning off the addon as it's loading a file]])

		pnl:Help([[13 Aug 2020:

			- Automap now follows the sample rate option instead of doing 10 times as much work
			- Automap samples can now 'bounce' off of the sky, allowing it to better deal with open areas]])

		pnl:Help([[10 Aug 2020:

			- Added an experimental automap sample mode]])

		pnl:Help([[08 Aug 2020:

			- Fixed some error spam (Surprised nobody reported this)
			- Improved the way the addon behaves when enabling/disabling, it now clears all data and starts loading fresh when re-enabled]])

		pnl:Help([[06 Aug 2020 (Hotfix #2):

			- Fixed the pointcloud folder not being created]])

		pnl:Help([[06 Aug 2020 (Hotfix):

			- Fixed the clear current map button not working
			- Added a button to manually toggle projections from the options menu]])

		pnl:Help([[06 Aug 2020:

			- Reorganized almost everything interally
			- Added this changelog
			- Loading is now done asynchronously to support larger files without crashing the game
			- Added a new option: Load budget
			- Fixed minimaps cutting off near the max map size]])

		pnl:Help([[03 Aug 2020:

			Initial release]])
	end)
	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_general", "General settings", "", "", function(pnl)
		pnl:ClearControls()

		pnl:CheckBox("Enable", "pointcloud_enabled")
		pnl:Help([[Changing the resolution might help alleviate performance issues caused by the size of the map and the amount of data being stored but will decrease clarity and accuracy.

			This option can cause your game to slow down considerably as things are saved and loaded. Don't worry, this is normal.]])
		pnl:AddControl("ComboBox", {
			Label = "Resolution",
			MenuButton = 0,
			CVars = {"pointcloud_resolution"},
			Options = {
				["1. High (32 units/point)"] = {pointcloud_resolution = 32},
				["2. Medium (64 units/point)"] = {pointcloud_resolution = 64},
				["3. Low (128 units/point)"] = {pointcloud_resolution = 128}
			}
		})
		pnl:Help([[The sampler determines how the world around you is discovered and is easily the most performance intensive part of this addon.

			Performance issues can be helped by lowering the sample rate but doing so will slow the mapping process. The sample mode on the other hand is purely there for user preference and has no impact on performance whatsoever.]])
		pnl:AddControl("ComboBox", {
			Label = "Sample mode",
			MenuButton = 0,
			CVars = {"pointcloud_samplemode"},
			Options = {
				["0. Disabled"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NONE},
				["1. Random noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NOISE},
				["2. Front-facing noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_FRONTFACING},
				["3. AutoMap (Experimental)"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_AUTOMAP}
			}
		})
		pnl:NumSlider("Sample rate", "pointcloud_samplerate", 20, 180, 0)

		pnl:Help("Increasing the load budget will decrease the amount of time it takes for a map to load but has the side effect of lowering your FPS until it's done.")
		pnl:NumSlider("Load budget (ms/frame)", "pointcloud_loadbudget", 20, 200, 0)

		pnl:CheckBox("Show debug info (Requires minimap)", "pointcloud_debug")

		pnl:Help("If you for any reason want to delete all maps or a specific subset, you can find the directory containing the map files in garrysmod/data/pointcloud")
		pnl:Button("Clear current map (current resolution)").DoClick = function()
			file.Delete(pointcloud.Persistence:GetFileName())

			pointcloud:Clear()
		end
		pnl:Button("Clear current map (all resolutions)").DoClick = function()
			for _, v in pairs(file.Find("pointcloud/" .. game.GetMap() .. "-*.dat", "DATA")) do
				file.Delete("pointcloud/" .. v)
			end

			pointcloud:Clear()
		end
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_minimap", "Minimap", "", "", function(pnl)
		pnl:ClearControls()

		pnl:CheckBox("Enable minimap", "pointcloud_minimap_enabled")

		pnl:NumSlider("Width", "pointcloud_minimap_width", 1, ScrW(), 0)
		pnl:NumSlider("Height", "pointcloud_minimap_height", 1, ScrH(), 0)
		pnl:NumSlider("Zoom", "pointcloud_minimap_zoom", POINTCLOUD_MINZOOM, POINTCLOUD_MAXZOOM, 1)
		pnl:Help([[Changing the layer depth will adjust how many layers the minimap can draw below you at any time, which may affect performance on maps with a lot of verticality.

			Setting this to -1 will make it render every layer instead.]])
		pnl:NumSlider("Layer depth", "pointcloud_minimap_layerdepth", -1, 100, 0)

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Zoom out", Command = "pointcloud_minimap_zoomout", Label2 = "Zoom in", Command2 = "pointcloud_minimap_zoomin"})
		pnl:NumSlider("Step size", "pointcloud_minimap_zoomstep", 0.1, 1, 1)
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_projection", "Projection", "", "", function(pnl)
		pnl:ClearControls()

		pnl:NumSlider("Scale", "pointcloud_projection_scale", 0.01, 0.1, 2)
		pnl:NumSlider("Height offset", "pointcloud_projection_height", 0, 128, 0)

		pnl:AddControl("ComboBox", {
			Label = "Render mode",
			MenuButton = 0,
			CVars = {"pointcloud_projection_mode"},
			Options = {
				["1. Cubes"] = {pointcloud_projection_mode = POINTCLOUD_MODE_CUBE},
				["2. Points"] = {pointcloud_projection_mode = POINTCLOUD_MODE_POINTS}
			}
		})

		pnl:Help("There's currently an issue where other addons break the control method used in singleplayer, use this button to toggle projections if that's the case for you")
		pnl:Button("Manual toggle").DoClick = function()
			pointcloud.Projection:Toggle()
		end

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Toggle projection", Command = "pointcloud_projection_key", ButtonSize = 22})
	end)
end)