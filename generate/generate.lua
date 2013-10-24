if #({...}) == 0 then
	print([[
USAGE

lua generate.lua [-c] [folders]

folders               One or more folders to output generated files.
-c         --clear    Clear folders before outputting.
]])
	return
end

-- add lua directory to path
do
	local c = {}
	for l in package.config:gmatch('[^\r\n]+') do
		c[#c+1] = l
	end

	-- ';./lua/?.lua'
	package.path = package.path .. table.concat{c[2],'.',c[1],'lua',c[1],c[3],'.lua'}
end

local utl = require 'utl'
local slt = require 'slt2'
local format = require 'format'

local API = require 'API'
local APIDump = require 'APIDump'
local APIjson = require'APIToJSON'(APIDump,true)

local tmplIndex = slt.loadfile('resources/templates/index.html','{{','}}')
local tmplClass = slt.loadfile('resources/templates/class.html','{{','}}')

local function generate(base)
	local resources = utl.resource({
		{base,'image','icon-explorer.png'};
		{base,'image','icon-objectbrowser.png'};

		{base,'css','api.css'};
		{base,'css','ref.css'};

		{base,'js','jquery-1.10.2.min.js'};
		{base,'js','fuse.min.js'};

		{base,'js','search.js'};
	})

	utl.write(base .. '/search-db.json',APIjson)

	-- index.html
	utl.write(base .. '/index.html',
		slt.render(tmplIndex,{
			format = format;
			resources = resources;
			tree = API.ClassTree();
		}) --:gsub('[\r\n\t]*','')
	)

	local function writeClass(class)
		local f = io.open(base .. '/class/' .. class .. '.html','w')
		local output = slt.render(tmplClass,{
			format = format;
			resources = resources;
			class = API.ClassData(class);
		}) --:gsub('[\r\n\t]*','')
		f:write(output)
		f:flush()
		f:close()
	end

	for i = 1,#APIDump do
		if APIDump[i].type == 'Class' then
			writeClass(APIDump[i].Name)
		end
	end
end

local args = {...}
local clearFolders = false
if args[1] == '-c' or args[1] == '--clear' then
	table.remove(args,1)
	clearFolders = true
end
for i = 1,#args do
	local base = utl.normpath(args[i] .. '/api')
	utl.makedir(base .. '/class')
	if clearFolders then utl.cleardir(base) end
	generate(base)
	print('generated',args[i])
end