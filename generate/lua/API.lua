--[[
@module API {
	ClassData       classData
	ClassTree       classTree
	ClassIconIndex  classIconIndex
	MemberIconIndex memberIconIndex
}

@type classData function ( className string ) data Class
Generates data for a given class.

@type Class {
	Name         string          -- name of the class
	Icon         ClassIcon       -- class's icon index
	Superclasses []ClassIconPair -- list of classes that the class inherits from
	Subclasses   []ClassIconPair -- sorted by ClassIconPair.Class
	Tags         [string]bool    -- Tags given to the class
	TagList      []string        -- sorted; excludes preliminary and deprecated tags
	Members      []MemberType    -- List of members per member type
	MemberSet    [string]Member  -- Member names paired with member items
	Enums        []EnumItem      -- sorted by Enum.Name
}

@type ClassIcon int
Represents the index of an icon on the explorer icon sheet.

@type MemberIcon int
Represents the index of an icon on the object browser icon sheet.

@type ClassIconPair {
	Class string
	Icon  ClassIcon
}
A class name paired with an icon.

@type MemberType {
	Type       string      -- the member type
	TypePlural string      -- plural form of the member type
	List       []Member    -- List of memebers
	Inherited  []Inherited -- a list of inherited members
	HasTags    bool        -- whether at least one member has tags
}
Represents the members of a class for a single member type.

@type Member {}

@type Property Member {
	Icon      MemberIcon   -- the member's icon index
	Name      string       -- the name of the member
	Type      string       -- the member type
	ValueType string       -- the property's value type
	Tags      [string]bool -- tags given to the member
	TagList   []string     -- tags in sorted list form
}
A single property member.

@type Function Member {
	Icon       MemberIcon           -- the member's icon index
	Name       string               -- the name of the member
	Type       string               -- the member type
	ReturnType string               -- the type returned by the function
	Arguments  []ParseAPI::Argument -- a list of the function's arguments
	Tags       [string]bool         -- tags given to the member
	TagList    []string             -- tags in sorted list form
}
A single function member.

@type YieldFunction Function
A single yield function member.

@type Callback Function
A single callback member.

@type Event Member {
	Icon       MemberIcon           -- the member's icon index
	Name       string               -- the name of the member
	Type       string               -- the member type
	Arguments  []ParseAPI::Argument -- a list of the event's arguments
	Tags       [string]bool         -- tags given to the member
	TagList    []string             -- tags in sorted list form
}
A single event member.

@type Inherited {
	Class  string -- the class inherited from
	Amount int    -- the number of members inherited
	Member string -- a string indicating the member type, displayed as a word
}
Represents the amount of members of a given type that a given class
inherits from the indicated class.

@type Enum {
	Name    string       -- the name of the enum
	Items   []EnumItem   -- a list of the enum's items, sorted by value
	Tags    [string]bool -- Tags given to the enum
	TagList []string     -- sorted; excludes preliminary and deprecated tags
}
A single enum.

@type EnumItem {
	Name    string        -- the item's name
	Value   int           -- the item's value
	Tags     [string]bool -- Tags given to the enum item
	TagList  []string     -- sorted; excludes preliminary and deprecated tags
}
A single enum item.


@type classTree function ( ) list []TreeNode
Generates a tree representing the inheritance relationship between every
class.

@type TreeNode {
	Class string     -- the class name
	Icon  ClassIcon  -- the class icon
	List  []TreeNode -- a list of classes that inherit the class
}
Represents a single node in the tree.

@type classIconIndex function ( className string ) index int
Returns the icon index for a given class. Returns 0 if an index does not exist
for the class.

@type memberIconIndex function ( member Member ) index int
Returns the icon index for a given member.

]]

local ExplorerIndex = require 'ExplorerImageIndex'

-- The order in which member types will be displayed
local MemberTypeOrder = {
	Property      = 1;
	Function      = 2;
	YieldFunction = 3;
	Event         = 4;
	Callback      = 5;
}

-- Maps to the plural form of a member type
local MemberTypePlural = {
	Callback      = 'Callbacks';
	Event         = 'Events';
	Function      = 'Functions';
	Property      = 'Properties';
	YieldFunction = 'YieldFunctions';
}

-- Maps a member type and state to an index on the object browser icon sheet
local MemberIconIndex = {
	              --  Default, Protected, Locked
	Property      = {       6,         7,     14 };
	Function      = {       4,         5,     13 };
	YieldFunction = {       4,         5,     13 };
	Event         = {      11,        12,     15 };
	Callback      = {      16,        16,     16 };
}

-- Maps member tags to one of the states in the MemberIconIndex table
local MemberTagState = {
	RobloxPlaceSecurity  = 3; -- Locked
	LocalUserSecurity    = 2; -- Protected
	WritePlayerSecurity  = 2; -- Protected
	RobloxScriptSecurity = 2; -- Protected
	RobloxSecurity       = 2; -- Protected
	security1            = 2; -- Protected
	PluginSecurity       = 2; -- Protected
}

local function classIconIndex(class)
	return ExplorerIndex[class] or 0
end

local function memberIconIndex(member)
	local ref = 1
	for tag,state in pairs(MemberTagState) do
		if member.tags[tag] then
			ref = state
			break
		end
	end
	return MemberIconIndex[member.type][ref]
end

local API = {}

function API.ClassData(dump,className)
	local classLookup = {}
	local memberSet = {}
	local memberTypeLookup = {}
	local types = {}
	local enums = {}

	for i = 1,#dump do
		local item = dump[i]

		local tags = {}
		local tagList = {}
		for tag in pairs(item.tags) do
			tags[tag] = true
			if tag ~= 'preliminary' and tag ~='deprecated' then
				tagList[#tagList+1] = tag
			end
		end
		table.sort(tagList)
		local new = {}
		new.Tags = tags
		new.TagList = tagList
		for k,v in pairs(item) do
			if k ~= 'tags' and k ~= 'type' then
				new[k] = v
			end
		end

		if item.type == 'Class' then
			if not memberTypeLookup[item.Name] then
				memberTypeLookup[item.Name] = {}
			end
			classLookup[item.Name] = new
		elseif item.Class then
			local memberTypes = memberTypeLookup[item.Class]
			if not memberTypes then
				memberTypes = {}
				memberTypeLookup[item.Class] = memberTypes
			end

			local memberType = memberTypes[item.type]
			if not memberType then
				memberType = {
					List = {};
					Inherited = {};
					HasTags = false;
					HasHistory = false;
					Type = item.type;
					TypePlural = MemberTypePlural[item.type];
				}
				memberTypes[item.type] = memberType
			end

			new.Type = item.type
			new.Icon = memberIconIndex(item)
			if #tagList > 0 then
				memberType.HasTags = true
			end
			if #new.History > 0 then
				memberType.HasHistory = true
			end
			table.insert(memberType.List,new)

			if item.Class == className then
				memberSet[item.Name] = new

				if item.ValueType then
					types[item.ValueType] = true
				end
				if item.ReturnType then
					types[item.ReturnType] = true
				end
				if item.Arguments then
					for i = 1,#item.Arguments do
						types[item.Arguments[i].Type] = true
					end
				end
			end
		elseif item.type == 'Enum' then
			enums[#enums+1] = new
		end
	end

	local enumsHaveHistory = false
	do
		local i = 1
		local n = #enums
		while i <= n do
			if types[enums[i].Name] then
				if #enums[i].History > 0 then
					enumsHaveHistory = true
				end
				i = i + 1
			else
				table.remove(enums,i)
				n = n - 1
			end
		end

		table.sort(enums,function(a,b)
			return a.Name < b.Name
		end)
	end

	local class = {
		Name = className;
		Icon = classIconIndex(className);
		Tags = classLookup[className].Tags;
		TagList = classLookup[className].TagList;
		History = classLookup[className].History;
		Description = classLookup[className].Description;
		Members = {};
		MemberSet = memberSet;
		Enums = {List=enums,HasHistory=enumsHaveHistory};
	}

	-- add subclasses
	local subclasses = {}
	for name,class in pairs(classLookup) do
		if class.Superclass == className then
			subclasses[#subclasses+1] = {
				Icon = classIconIndex(name);
				Class = name;
			}
		end
	end
	table.sort(subclasses,function(a,b)
		return a.Class < b.Class
	end)
	class.Subclasses = subclasses

	local memberTypes = memberTypeLookup[className]

	do
		local superclasses = {}
		class.Superclasses = superclasses
		local name = className
		while true do
			name = classLookup[name].Superclass
			if not name then
				break
			end
			-- superclasses
			table.insert(superclasses,{
				Icon = classIconIndex(name);
				Class = name;
			})

			-- add inherited members
			if memberTypeLookup[name] then
				for superTypeName,superMemberType in pairs(memberTypeLookup[name]) do
					if not memberTypes[superTypeName] then
						memberTypes[superTypeName] = {
							List = {};
							Inherited = {};
							HasTags = false;
							Type = superTypeName;
							TypePlural = MemberTypePlural[superTypeName];
						}
					end

					table.insert(memberTypes[superTypeName].Inherited,{
						Class = name;
						Amount = #superMemberType.List;
						Member = (#superMemberType.List == 1 and memberTypes[superTypeName].Type or memberTypes[superTypeName].TypePlural):lower();
					})
				end
			end
		end
	end

	local function sort(a,b)
		local da = a.Tags.deprecated
		local db = b.Tags.deprecated
		if da and db or not da and not db then
			return a.Name < b.Name
		else
			-- put deprecated items at the end of the list
			return db
		end
	end

	-- add list of member types
	for _,memberType in pairs(memberTypes) do
		table.sort(memberType.List,sort)
		table.insert(class.Members,memberType)
	end

	-- sort member types
	table.sort(class.Members,function(a,b)
		return MemberTypeOrder[a.Type] < MemberTypeOrder[b.Type]
	end)

	return class
end

function API.EnumData(dump,enumName)
	local enum
	local items = {}
	local classes = {}

	local function addMember(item)
		local class = classes[item.Class]
		if not class then
			class = {
				Name = item.Class;
				Icon = classIconIndex(item.Class);
				Members = {};
			}
			classes[item.Class] = class
		end
		class.Members[#class.Members+1] = {
			Class = item.Class;
			Name = item.Name;
			Icon = memberIconIndex(item);
		}
	end

	local hasHistory = false
	for i = 1,#dump do
		local item = dump[i]

		local new
		if item.type == 'Enum' or item.type == 'EnumItem' then
			local tags = {}
			local tagList = {}
			for tag in pairs(item.tags) do
				tags[tag] = true
				tagList[#tagList+1] = tag
			end
			table.sort(tagList)
			new = {}
			new.Tags = tags
			new.TagList = tagList
			for k,v in pairs(item) do
				if k ~= 'tags' and k ~= 'type' then
					new[k] = v
				end
			end
		end

		if item.type == 'Enum' and item.Name == enumName then
			enum = new
		elseif item.type == 'EnumItem' and item.Enum == enumName then
			items[#items+1] = new
			if #item.History > 0 then
				hasHistory = true
			end
		elseif item.ValueType == enumName or item.ReturnType == enumName then
			addMember(item)
		elseif item.Arguments then
			for i = 1,#item.Arguments do
				if item.Arguments[i].Type == enumName then
					addMember(item)
					break
				end
			end
		end
	end

	if not enum then
		error('invalid enum `' .. tostring(enumName)..'`',2)
	end

	table.sort(items,function(a,b)
		return a.Value < b.Value
	end)

	local function sort(a,b)
		return a.Name < b.Name
	end

	local usage = {}
	for _,class in pairs(classes) do
		usage[#usage+1] = class
		table.sort(class.Members,sort)
	end

	table.sort(usage,sort)

	return {
		Name = enum.Name;
		Tags = enum.Tags;
		TagList = enum.TagList;
		History = enum.History;
		Description = enum.Description;
		HasHistory = hasHistory;
		Items = items;
		Usage = usage;
	}
end

function API.ClassTree(dump)
	local classes = {}
	for i = 1,#dump do
		local item = dump[i]
		if item.type == 'Class' then
			classes[item.Name] = item
		end
	end

	local sorted = {}
	for k in pairs(classes) do
		sorted[#sorted+1] = k
	end
	table.sort(sorted)

	local list = {}

	local function r(root,t)
		for i = 1,#sorted do
			local name = sorted[i]
			local class = classes[name]
			if class.Superclass == root then
				local q = {
					Class = name;
					Icon = classIconIndex(name);
					History = class.History;
					List = {};
				}
				t[#t+1] = q
				r(name,q.List)
			end
		end
	end

	r(nil,list)

	return list
end

API.ClassIconIndex = classIconIndex
API.MemberIconIndex = memberIconIndex

return API
