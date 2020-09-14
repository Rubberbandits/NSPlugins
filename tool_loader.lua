local PLUGIN = PLUGIN
PLUGIN.name = "Toolgun Tool Loader"
PLUGIN.desc = "Allows plugins to easily load new tools for the toolgun."
PLUGIN.author = "rusty"
PLUGIN.ToolObj = PLUGIN.ToolObj or {}

local ToolObj = PLUGIN.ToolObj

/*
	ToolObject
	Major hack pasted directly from the toolgun swep.
*/

local SWEP = weapons.GetStored("gmod_tool")

function ToolObj:Create()

	local o = {}

	setmetatable( o, self )
	self.__index = self

	o.Mode				= nil
	o.SWEP				= nil
	o.Owner				= nil
	o.ClientConVar		= {}
	o.ServerConVar		= {}
	o.Objects			= {}
	o.Stage				= 0
	o.Message			= "start"
	o.LastMessage		= 0
	o.AllowedCVar		= 0

	return o

end

function ToolObj:CreateConVars()

	local mode = self:GetMode()

	if ( CLIENT ) then

		for cvar, default in pairs( self.ClientConVar ) do

			CreateClientConVar( mode .. "_" .. cvar, default, true, true )

		end

		return
	end

	-- Note: I changed this from replicated because replicated convars don't work
	-- when they're created via Lua.

	if ( SERVER ) then

		self.AllowedCVar = CreateConVar( "toolmode_allow_" .. mode, 1, FCVAR_NOTIFY )

		for cvar, default in pairs( self.ServerConVar ) do
			CreateConVar( mode .. "_" .. cvar, default, FCVAR_ARCHIVE )
		end
	end

end

function ToolObj:GetServerInfo( property )

	local mode = self:GetMode()

	return GetConVarString( mode .. "_" .. property )

end

function ToolObj:BuildConVarList()

	local mode = self:GetMode()
	local convars = {}

	for k, v in pairs( self.ClientConVar ) do convars[ mode .. "_" .. k ] = v end

	return convars

end

function ToolObj:GetClientInfo( property )

	return self:GetOwner():GetInfo( self:GetMode() .. "_" .. property )

end

function ToolObj:GetClientNumber( property, default )

	return self:GetOwner():GetInfoNum( self:GetMode() .. "_" .. property, tonumber( default ) or 0 )

end

function ToolObj:Allowed()

	if ( CLIENT ) then return true end
	return self.AllowedCVar:GetBool()

end

-- Now for all the ToolObj redirects

function ToolObj:Init() end

function ToolObj:GetMode()		return self.Mode end
function ToolObj:GetSWEP()		return self.SWEP end
function ToolObj:GetOwner()		return self:GetSWEP().Owner or self.Owner end
function ToolObj:GetWeapon()	return self:GetSWEP().Weapon or self.Weapon end

function ToolObj:LeftClick()	return false end
function ToolObj:RightClick()	return false end
function ToolObj:Reload()		self:ClearObjects() end
function ToolObj:Deploy()		self:ReleaseGhostEntity() return end
function ToolObj:Holster()		self:ReleaseGhostEntity() return end
function ToolObj:Think()		self:ReleaseGhostEntity() end

--[[---------------------------------------------------------
	Checks the objects before any action is taken
	This is to make sure that the entities haven't been removed
-----------------------------------------------------------]]
function ToolObj:CheckObjects()

	for k, v in pairs( self.Objects ) do

		if ( !v.Ent:IsWorld() && !v.Ent:IsValid() ) then
			self:ClearObjects()
		end

	end

end

if CLIENT then
	-- Tool should return true if freezing the view angles
	function ToolObj:FreezeMovement()
		return false 
	end

	-- The tool's opportunity to draw to the HUD
	function ToolObj:DrawHUD()
	end
end

/*
	Load Tool into spawnmenu
*/

if CLIENT then
	-- Keep the tool list handy
	local TOOLS_LIST = SWEP.Tool

	-- Add the STOOLS to the tool menu
	hook.Add( "PopulateToolMenu", "AddSToolsToMenu", function()

		for ToolName, TOOL in pairs( TOOLS_LIST ) do

			print(ToolName)

			if ( TOOL.AddToMenu != false ) then

				spawnmenu.AddToolMenuOption( TOOL.Tab or "Main",
											TOOL.Category or "New Category",
											ToolName,
											TOOL.Name or "#" .. ToolName,
											TOOL.Command or "gmod_tool " .. ToolName,
											TOOL.ConfigName or ToolName,
											TOOL.BuildCPanel )

			end

		end

	end )

	--
	-- Search
	--
	search.AddProvider( function( str )

		local list = {}

		for k, v in pairs( TOOLS_LIST ) do

			local niceName = v.Name or "#" .. k
			if ( niceName:StartWith( "#" ) ) then niceName = language.GetPhrase( niceName:sub( 2 ) ) end

			if ( !k:lower():find( str, nil, true ) && !niceName:lower():find( str, nil, true ) ) then continue end

			local entry = {
				text = niceName,
				icon = spawnmenu.CreateContentIcon( "tool", nil, {
					spawnname = k,
					nicename = v.Name or "#" .. k
				} ),
				words = { k }
			}

			table.insert( list, entry )

			if ( #list >= GetConVarNumber( "sbox_search_maxresults" ) / 32 ) then break end

		end

		return list

	end )
end

/*
	Hooks
*/

function PLUGIN:InitializedPlugins()
	for id,plugin in next, nut.plugin.list do
		self:LoadTools(id)
	end

	if CLIENT then
		RunConsoleCommand("spawnmenu_reload")
	end
end

/*
	Methods
*/

function PLUGIN:LoadTools(pluginID)
	local plugin = nut.plugin.list[pluginID]
	local files = file.Find(plugin.path .. "/stools/*.lua", "LUA")
	
	for _,tool in ipairs(files) do
		local char1, char2, toolmode = string.find( tool, "([%w_]*).lua" )

		TOOL = ToolObj:Create()
		TOOL.Mode = toolmode

		AddCSLuaFile( plugin.path .. "/stools/" .. tool )
		include( plugin.path .. "/stools/" .. tool )

		TOOL:CreateConVars()

		SWEP.Tool[ toolmode ] = TOOL

		TOOL = nil
	end
end
