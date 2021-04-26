hook.Add("AddToolMenuCategories", "pointcloud", function()
	spawnmenu.AddToolCategory("Options", "Pointcloud", "Pointcloud")
end)

hook.Add("PopulateToolMenu", "pointcloud", function()
	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_changelog", "Changelog (Last updated: 16 Aug 2020)", "", "", function(pnl)
		pnl:ClearControls()

		pnl:Help([[16 Aug 2020:

			- Added a new performance system based on frame budgets (Some convars might be reset, renamed or removed because of this)
			- Added a new radar sweep sample mode
			- The minimap now hides with the rest of your HUD when using the camera tool]])

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
		pnl:Help([[The sample mode is purely down to user preference and has no impact on performance whatsoever.]])
		pnl:AddControl("ComboBox", {
			Label = "Sample mode",
			MenuButton = 0,
			CVars = {"pointcloud_samplemode"},
			Options = {
				["0. Disabled"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NONE},
				["1. Random noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NOISE},
				["2. Front-facing noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_FRONTFACING},
				["3. AutoMap (Experimental)"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_AUTOMAP},
				["4. Radar sweep"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_SWEEPING}
			}
		})

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

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_performance", "Performance", "", "", function(pnl)
		pnl:ClearControls()

		pnl:Help([[Options in this menu determine how many miliseconds certain features of the mod can take up per frame.

			Increasing budgets will lower your FPS but increase the speed of certain actions.]])

		pnl:NumSlider("Load budget", "pointcloud_budget_load", 20, 200, 0)
		pnl:NumSlider("Sampler budget", "pointcloud_budget_sampler", 5, 40, 0)
		pnl:NumSlider("Projection budget", "pointcloud_budget_projection", 1, 40, 0)
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_minimap", "Minimap", "", "", function(pnl)
		pnl:ClearControls()

		pnl:CheckBox("Enable minimap", "pointcloud_minimap_enabled")
		pnl:CheckBox("Enable line of sight", "pointcloud_minimap_mask")

		pnl:NumSlider("Width", "pointcloud_minimap_width", 1, ScrW(), 0)
		pnl:NumSlider("Height", "pointcloud_minimap_height", 1, ScrH(), 0)
		pnl:NumSlider("Zoom", "pointcloud_minimap_zoom", POINTCLOUD_MINZOOM, POINTCLOUD_MAXZOOM, 1)
		pnl:Help([[Changing the layer depth will adjust how many layers the minimap can draw below you at any time, which may affect performance on maps with a lot of verticality.

			Setting this to -1 will make it render every layer instead.]])
		pnl:NumSlider("Layer depth", "pointcloud_minimap_layerdepth", -1, 100, 0)

		pnl:CheckBox("Pixelated minimap", "pointcloud_minimap_pixelated")
		pnl:CheckBox("Pixelated line of sight", "pointcloud_minimap_mask_pixelated")

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Zoom out", Command = "pointcloud_minimap_zoomout", Label2 = "Zoom in", Command2 = "pointcloud_minimap_zoomin"})
		pnl:NumSlider("Step size", "pointcloud_minimap_zoomstep", 0.1, 1, 1)
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_projection", "Projection", "", "", function(pnl)
		pnl:ClearControls()

		pnl:NumSlider("Scale", "pointcloud_projection_scale", 0.001, 0.1, 3)

		pnl:AddControl("ComboBox", {
			Label = "Render mode",
			MenuButton = 0,
			CVars = {"pointcloud_projection_mode"},
			Options = {
				["1. Cubes"] = {pointcloud_projection_mode = POINTCLOUD_MODE_CUBE},
				["2. Points"] = {pointcloud_projection_mode = POINTCLOUD_MODE_POINTS},
				["3. Hologram"] = {pointcloud_projection_mode = POINTCLOUD_MODE_HOLOGRAM}
			}
		})

		pnl:AddControl("Color", {Label = "Hologram color", Red = "pointcloud_projection_color_r", Green = "pointcloud_projection_color_g", Blue = "pointcloud_projection_color_b"})

		pnl:Help("There's currently an issue where other addons break the control method used in singleplayer, use this button to toggle projections if that's the case for you")
		pnl:Button("Manual toggle").DoClick = function()
			pointcloud.Projection:Toggle()
		end

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Toggle projection", Command = "pointcloud_projection_key", ButtonSize = 22})
	end)
end)