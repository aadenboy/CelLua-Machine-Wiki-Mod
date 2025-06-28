--core setup

success,utf8 = pcall(require, "utf8")
if not success then error("No utf8 library. Are you on the latest version of LOVE?") end
ip = require "interpolation"
getsplash = require "splashes"
quanta = require "quanta"

layers = {[0]={},{}}
initiallayers = {[0]={},{}}
placeables = {}
stilldata = {}	--data that shouldn't follow cells when they are moved
copycells = {}
undocells,maxundo = {},10
isinitial = true
updatekey = 0
supdatekey = 0
stickkey = 0
chosen = {id=0,rot=0,size=1,shape="Square",mode="All",data={}}    
selection = {on=false,w=0,h=0,x=0,y=0,ox=0,oy=0}
copied = {}
pasting = false
openedtab = -1
openedsubtab = -1
placecells = true
width,height,depth = 100,100,2
newwidth,newheight = 100,100
newcellsize,newpadding = 100,0
delay,tpuborder = .2,1,.5,.5,2
bordercells = {1,41,12,205,51,141,150,151,152,126,176,428,929,930,1186,931,932,1156,1171,933,934,1174,938,939,940,941}
cam = {x=0,y=0,tarx=0,tary=0,zoom=20,tarzoom=20,zoomlevel=4}
zoomlevels,defaultzoom = {2,4,10,20,40,80,160},4
delta,winxm,winym,centerx,centery = 0,1,1,400,300
dtime,itime = 0,0
hudrot,hudlerp = 0,0
paused = false
inmenu = false
moreui = true
portals = {}
reverseportals = {}
title,subtitle = "",""
puzzle = true
clear,winscreen = false,false
level = nil
mainmenu = "title"
wikimenu = nil
menustack = {}
tickcount,subtick = 0,1
switches = {}
searched = ""
richtexts = {}
truequeue = {}
collectedkeys = {}

graphicsmax = love.graphics.getSystemLimits().texturesize
absolutedraw, rendercelltext = false, true
cellcounts = {}
subticking = 0
forcespread = {}
overallcount = 0
--[[
	subticking modes
	0 - no subtucking
	1 - subticks
	2 - subsubticks (every cell individually)
	3 - force propagation
]]

function wrap(func) -- because coroutine.wrap doesn't give status info
    local co = coroutine.create(func)
    local function wrapped(...)
        local ok, result = coroutine.resume(co, ...)
        if not ok then
            error(result, 2)
        end
        return result
    end
    return wrapped, co
end
function yield(case, ret)
	if case and coroutine.running() then
		coroutine.yield(ret)
	end
end

function logforce(cx,cy,cdir,vars,oldcell,doyield)
	if subticking == 3 then
		table.insert(forcespread, {
			x = cx, y = cy,
			lx = vars.lastx,
			ly = vars.lasty,
			dir = cdir, ldir = vars.lastdir,
			rot = oldcell.rot,
			forcetype = vars.forcetype,
			cell = oldcell,
			drawcell = table.copy(oldcell),
			revealtick = overallcount + 2 -- edge case with pushing for some unknown reason
		})
		oldcell.vars.forceinterp = #forcespread
		yield(doyield == nil or doyield, true)
	end
end

recording = false
recorddata = {}
recordinginput = false
inputrecording = ""

directory = love.filesystem.getSourceBaseDirectory()

math.randomseed(os.time())

math.halfpi = math.pi/2

function math.lerp(a,b,c)
	if c ~= c then return b end	--thanks to lua f*ckery NaN is not equal to NaN
	return a+(b-a)*c
end

function math.graphiclerp(a,b,c)
	if c ~= c or not fancy then return b end
	return a+(b-a)*c
end

function math.round(a)
	return math.floor(a+.5)
end

function math.distSqr(a,b)
	return (a*a+b*b)
end

function math.angle(x,y)
	return math.atan2(y,x)
end

function math.angleTo4(x,y)
	return (math.atan2(y,x)/math.pi*2)%4
end

function math.randomsign()
	return math.random() < .5 and -1 or 1
end

function table.copy(t)
	local newt = {}
	for k,v in pairs(t) do
		if type(v) == "table" and k ~= "eatencells" and (k ~= "lastvars" or fancy) then v = table.copy(v) end
		newt[k] = v
	end
	return newt
end

function table.merge(t1,t2)
	for k,v in pairs(t2) do
		t1[k] = t1[k] or v
	end
	return t1
end

function table.multimerge(t1,t2,...)
	if t2 then
		for k,v in pairs(t2) do
			t1[k] = t1[k] or v
		end
		table.multimerge(t1,...)
	end
	return t1
end

function table.safeinsert(parenttable,tname,value)
	parenttable[tname] = parenttable[tname] or {}
	table.insert(parenttable[tname],value)
end    

function sortfunc(a,b)
	if type(a) == "number" then
		if type(b) == "number" then return a < b
		else return true end
	elseif type(a) == "string" then
		if type(b) == "number" then return false
		elseif type(b) == "string" then return a < b
		else return true end
	else return false end
end

function sortedpairs(t)
	local a = {}
	for n in pairs(t) do table.insert(a,n) end
	table.sort(a,sortfunc)
	local i = 0
	local iter = function()
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

function get(val,...)
	if type(val) ~= "function" then return val else return val(...) end
end

function rainbow(a)	--the most important function /s
	return {(math.sin(-love.timer.getTime()))+0.75,(math.sin(-love.timer.getTime()+math.pi*2/3))+0.75,(math.sin(-love.timer.getTime()+math.pi*4/3))+0.75,a}
end

function fastrainbow(a)
	return {(math.sin(-love.timer.getTime()*math.pi))+0.75,(math.sin(-love.timer.getTime()*math.pi+math.pi*2/3))+0.75,(math.sin(-love.timer.getTime()*math.pi+math.pi*4/3))+0.75,a}
end

function monochrome(a)
	local v = math.sin(love.timer.getTime())/2+.5
	return {v,v,v,a}
end

function fastmonochrome(a)
	local v = math.sin(love.timer.getTime()*math.pi)/2+.5
	return {v,v,v,a}
end

function lerpcolor(a,b)
	return function()
		local c1 = get(a)
		local c2 = get(b)
		local t = math.sin(love.timer.getTime())/2+.5
		return {math.lerp(c1[1],c2[1],t),math.lerp(c1[2],c2[2],t),math.lerp(c1[3],c2[3],t)}
	end
end

function fastlerpcolor(a,b)
	return function()
		local c1 = get(a)
		local c2 = get(b)
		local t = math.sin(love.timer.getTime()*math.pi)/2+.5
		return {math.lerp(c1[1],c2[1],t),math.lerp(c1[2],c2[2],t),math.lerp(c1[3],c2[3],t)}
	end
end

width6chars = {
	"#","$","*","+","0","2","3","4","5","6","7","8","9","?","A",
	"B","C","D","E","F","G","H","P","R","U","Z","_","a","b","d",
	"e","g","h","k","n","o","p","q","u","v","x","y","z","~"
}

function getobfuscated(l)
	return function()
		local s = ""
		for i=1,l do
			s = s..width6chars[math.random(#width6chars)]
		end
		return s
	end
end

function ctrl()
	return love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")
end

function getempty(eaten)
	return {id=0,rot=0,lastvars={0,0,0},eatencells=eaten,vars={},tick=tickcount}
end

function GetSFX(name)
	return sounds[name].audio
end

function GetMusic(name)
	return music[name].audio
end

function Play(aud)
	if settings.sfxvolume > 0 then
		local s = GetSFX(aud)
		if s:tell() > .05 then s:stop() end
		s:play()
	end
end

function PlayMusic(aud)
	for i=1,#music do
		local s = GetMusic(i)
		s:stop()
	end
	local s = GetMusic(aud)
	s:play()
end

--textures
shaders = {}

shaders.color = love.graphics.newShader([[
uniform number red;
uniform number green;
uniform number blue;
uniform number alpha;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords){
	vec4 col = Texel(texture, texture_coords);
	number Y = (col.r + col.g + col.b) / 3.;
	return vec4(Y*red,Y*green,Y*blue,col.a*alpha);
}
]])

shaders.invert = love.graphics.newShader([[
uniform number alpha;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords){
	vec4 col = Texel(texture, texture_coords);
	return vec4(1.-col.r,1.-col.g,1.-col.b,col.a*alpha);
}
]])

shaders.invertcolor = love.graphics.newShader([[
uniform number red;
uniform number green;
uniform number blue;
uniform number alpha;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords){
	vec4 col = Texel(texture, texture_coords);
	number Y = 1. - (col.r + col.g + col.b) / 3.;
	return vec4(Y*red,Y*green,Y*blue,col.a*alpha);
}
]])

shaders.hsv = love.graphics.newShader([[
uniform number hue;
uniform number sat;
uniform number val;
uniform int invert;
uniform number alpha;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords){
	vec4 col = Texel(texture, texture_coords);
	number R;
	number G;
	number B;
	if (sat == 1.){
		R = col.r;
		G = col.g;
		B = col.b;
	}else if (sat == 0.){
		number Y = (col.r + col.g + col.b) / 3.;
		R = Y;
		G = Y;
		B = Y;
	}else{
		number Y = (col.r + col.g + col.b) / 3.;
		R = Y+(col.r-Y)*sat;
		G = Y+(col.g-Y)*sat;
		B = Y+(col.b-Y)*sat;
	}
	number M = max(max(R,G),B);
	number m = min(min(R,G),B);
	number d = M-m;
	number H;
	if (d == 0.){
		H = 0.;
	} else if (M == R){
		H = mod(60. * mod((G-B)/d,6.) + hue, 360.);
	} else if (M == G){
		H = mod(60. * ((B-R)/d+2.) + hue, 360.);
	} else {
		H = mod(60. * ((R-G)/d+4.) + hue, 360.);
	}
	number S = 0.;
	if (M != 0.){
		S = d/M;
	}
	number V = M * val;
	number v = V*(1.-S);
	number z = d*(1.-abs(mod(H/60.,2.)-1.)) * val;
	if (H < 60.) {
		R = V;
		G = v+z;
		B = v;
	} else if (H < 120.) {
		R = v+z;
		G = V;
		B = v;
	} else if (H < 180.) {
		R = v;
		G = V;
		B = v+z;
	} else if (H < 240.) {
		R = v;
		G = v+z;
		B = V;
	} else if (H < 300.) {
		R = v+z;
		G = v;
		B = V;
	} else {
		R = V;
		G = v;
		B = v+z;
	}
	if (invert == 1){
		R = 1.-R;
		G = 1.-G;
		B = 1.-B;
	}
	return vec4(R,G,B,col.a*alpha);
}
]])

shaders.shadow = love.graphics.newShader([[
uniform number alpha;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords){
	vec4 col = Texel(texture, texture_coords); 
	return vec4(0,0,0,col.a*alpha);
}
]])

shaders.space = love.graphics.newShader([[
uniform number alpha;
uniform number time;

//https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
number pi = 3.14159265358979323846;
float rand(vec2 c){
	return fract(sin(dot(c.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
float noise(vec2 p, float freq ){
	float unit = 800./freq;
	vec2 ij = floor(p/unit);
	vec2 xy = mod(p,unit)/unit;
	//xy = 3.*xy*xy-2.*xy*xy*xy;
	xy = .5*(1.-cos(pi*xy));
	float a = rand((ij+vec2(0.,0.)));
	float b = rand((ij+vec2(1.,0.)));
	float c = rand((ij+vec2(0.,1.)));
	float d = rand((ij+vec2(1.,1.)));
	float x1 = mix(a, b, xy.x);
	float x2 = mix(c, d, xy.x);
	return mix(x1, x2, xy.y);
}
float pNoise(vec2 p, int res){
	float persistance = .5;
	float n = 0.;
	float normK = 0.;
	float f = 4.;
	float amp = 1.;
	for (int i = 0; i<res; i++){
		n+=amp*noise(p, f);
		f*=2.;
		normK+=amp;
		amp*=persistance;
	}
	float nf = n/normK;
	return nf*nf*nf*nf;
}

number phi = 1.61803398874989484820459;
float starNoise(vec2 xy) {
	return fract(tan(distance(xy*phi, xy))*xy.x);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords){
	vec4 col = Texel(texture, texture_coords);
	number star = max(starNoise(screen_coords)-.995,0.)*200. * (starNoise((fract(time)*.5+.25)*screen_coords)*.2+.8);
	number back = .05+pNoise(screen_coords*10.,25)/10.;
	return vec4(star+back,star,star+back*2.,col.a*alpha);
}
]])

shaders.matrix = love.graphics.newShader([[
uniform number alpha;
uniform number time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords){
	vec4 col = Texel(texture, texture_coords);
	number h_line_1 = max(0.,-(mod(floor(screen_coords.x-time*8.),64.))+1.);
	number v_line_1 = max(0.,-(mod(floor(screen_coords.y-time*8.),64.))+1.);
	number h_line_2 = max(0.,-(mod(floor(screen_coords.x+.5+time*4.+24.),48.))+1.);
	number v_line_2 = max(0.,-(mod(floor(screen_coords.y+.5+time*4.),48.))+1.);
	return vec4(0.,max(h_line_1,v_line_1) + max(h_line_2,v_line_2)/4.,0.,col.a*alpha);
}
]])

function randomshader()
	return shaders[({"color","invert","invertcolor","hsv","inverthsv","space","matrix"})[math.random(7)]]
end

love.graphics.setDefaultFilter("nearest")

tex = {}

function GetTex(key,failsafe)
	return tex[key] or tex[failsafe] or tex.X
end

function GreyscaleData(data)
	for x=0,data:getWidth()-1 do
		for y=0,data:getHeight()-1 do
			local r,g,b,a = data:getPixel(x,y)
			local v = (r+g+b)/3
			data:setPixel(x,y,v,v,v,a)
		end
	end
	return data
end

function InvertData(data)
	for x=0,data:getWidth()-1 do
		for y=0,data:getHeight()-1 do
			local r,g,b,a = data:getPixel(x,y)
			data:setPixel(x,y,1-r,1-g,1-b,a)
		end
	end
	return data
end

function NewTex(val,key)
	UnloadTex(key)
	local t = {}
	tex[key] = t
	local f = function()
		local path = "textures/"
		if love.filesystem.getInfo(texpath..val..".png") then path = texpath end
		if not love.filesystem.getInfo(path..val..".png") then
			DEBUG(path..val..".png not found!")
			tex[key] = nil
			return
		end
		t.normal = love.graphics.newImage(path..val..".png")
		t.size = {w=t.normal:getWidth(),h=t.normal:getHeight(),w2=t.normal:getWidth()*.5,h2=t.normal:getHeight()*.5}
		t.path = val
		--[[local data = love.image.newImageData(path..val..".png")
		t.greyscale = love.graphics.newImage(GreyscaleData(data))
		t.greyscaleinverted = love.graphics.newImage(InvertData(data))
		data:release()
		data = love.image.newImageData(path..val..".png")
		t.inverted = love.graphics.newImage(InvertData(data))
		data:release()]]
	end
	if postloading then f()
	else table.insert(truequeue, f) end
end

function UnloadTex(key)
	if tex[key] then
		if tex[key].normal then
			tex[key].normal:release()
		end
		tex[key] = nil
	end
end

function MakeTextures()
	if tex[0] then
		for k,v in pairs(tex) do
			if v.path then
				NewTex(v.path,k)
			end
		end
		return
	end
	NewTex("bg",0)
	NewTex("wall",1)
	NewTex("mover",2)
	NewTex("generator",3)
	NewTex("push",4)
	NewTex("slide",5)
	NewTex("onedirectional",6)
	NewTex("twodirectional",7)
	NewTex("threedirectional",8)
	NewTex("rotator_cw",9)
	NewTex("rotator_ccw",10)
	NewTex("rotator_180",11)
	NewTex("trash",12)
	NewTex("enemy",13)
	NewTex("puller",14)
	NewTex("mirror",15)
	NewTex("diverger",16)
	NewTex("redirector",17)
	NewTex("gear_cw",18)
	NewTex("gear_ccw",19)
	NewTex("ungeneratable",20)
	NewTex("repulsor",21)
	NewTex("weight",22)
	NewTex("crossgenerator",23)
	NewTex("strongenemy",24)
	NewTex("freezer",25)
	NewTex("cwgenerator",26)
	NewTex("ccwgenerator",27)
	NewTex("advancer",28)
	NewTex("impulsor",29)
	NewTex("flipper",30)
	NewTex("bidiverger",31)
	NewTex("gate_or",32)
	NewTex("gate_and",33)
	NewTex("gate_xor",34)
	NewTex("gate_nor",35)
	NewTex("gate_nand",36)
	NewTex("gate_xnor",37)
	NewTex("straightdiverger",38)
	NewTex("crossdiverger",39)
	NewTex("twistgenerator",40)
	NewTex("ghost",41)
	NewTex("bias",42)
	NewTex("shield",43)
	NewTex("intaker",44)
	NewTex("replicator",45)
	NewTex("crossreplicator",46)
	NewTex("fungal",47)
	NewTex("forker",48)
	NewTex("triforker",49)
	NewTex("superrepulsor",50)
	NewTex("demolisher",51)
	NewTex("opposition",52)
	NewTex("crossopposition",53)
	NewTex("slideopposition",54)
	NewTex("supergenerator",55)
	NewTex("crossmirror",56)
	NewTex("birotator",57)
	NewTex("driller",58)
	NewTex("auger",59)
	NewTex("corkscrew",60)
	NewTex("bringer",61)
	NewTex("outdirector",62)
	NewTex("indirector",63)
	NewTex("cw-director",64)
	NewTex("ccw-director",65)
	NewTex("semirotator_cw",66)
	NewTex("semirotator_ccw",67)
	NewTex("semirotator_180",68)
	NewTex("toughslide",69)
	NewTex("pararotator",70)
	NewTex("grabber",71)
	NewTex("heaver",72)
	NewTex("lugger",73)
	NewTex("hoister",74)
	NewTex("raker",75)
	NewTex("borer",76)
	NewTex("carrier",77)
	NewTex("omnipower",78)
	NewTex("ice",79)
	NewTex("octomirror",80)
	NewTex("grapulsor_cw",81)
	NewTex("grapulsor_ccw",82)
	NewTex("bivalvediverger",83)	--these come before the normal valves because i had ideas here that didnt work out and i didnt wanna shift more ids so i just replaced them
	NewTex("paravalvediverger_cw",84)
	NewTex("paravalvediverger_ccw",85)
	NewTex("bivalvedisplacer",86)
	NewTex("paravalvedisplacer_cw",87)
	NewTex("paravalvedisplacer_ccw",88)
	NewTex("semiflipper_h",89)
	NewTex("semiflipper_v",90)
	NewTex("displacer",91)
	NewTex("bidisplacer",92)
	NewTex("valvediverger_cw",93)
	NewTex("valvediverger_ccw",94)
	NewTex("valvedisplacer_cw",95)
	NewTex("valvedisplacer_ccw",96)
	NewTex("cwforker",97)
	NewTex("ccwforker",98)
	NewTex("divider",99)
	NewTex("tridivider",100)
	NewTex("cwdivider",101)
	NewTex("ccwdivider",102)
	NewTex("conditional",103)
	NewTex("antiweight",104)
	NewTex("transmitter",105)
	NewTex("shifter",106)
	NewTex("crossshifter",107)
	NewTex("minigear_cw",108)
	NewTex("minigear_ccw",109)
	NewTex("cwcloner",110)
	NewTex("ccwcloner",111)
	NewTex("locker",112)
	NewTex("redirectgenerator",113)
	NewTex("nudger",114)
	NewTex("slicer",115)
	NewTex("marker",116)
	NewTex("marker_X",117)
	NewTex("marker_warn",118)
	NewTex("marker_check",119)
	NewTex("marker_question",120)
	NewTex("marker_arrow",121)
	NewTex("marker_darrow",122)
	NewTex("crimson",123)
	NewTex("warped",124)
	NewTex("corruption",125)
	NewTex("hallow",126)
	NewTex("cancer",127)
	NewTex("bacteria",128)
	NewTex("bioweapon",129)
	NewTex("prion",130)
	NewTex("greygoo",131)
	NewTex("virus",132)
	NewTex("tumor",133)
	NewTex("infection",134)
	NewTex("pathogen",135)
	NewTex("pushclamper",136)
	NewTex("pullclamper",137)
	NewTex("grabclamper",138)
	NewTex("swapclamper",139)
	NewTex("toughtwodirectional",140)
	NewTex("megademolisher",141)
	NewTex("resistance",142)
	NewTex("tentative",143)
	NewTex("restrictor",144)
	NewTex("megashield",145)
	NewTex("timewarper",146)
	NewTex("timegenerator",147)
	NewTex("crosstimewarper",148)
	NewTex("life",149)
	NewTex("spinnercw",150)
	NewTex("spinnerccw",151)
	NewTex("spinner180",152)
	NewTex("key",153)
	NewTex("door",154)
	NewTex("crossintaker",155)
	NewTex("magnet",156)
	NewTex("toughonedirectional",157)
	NewTex("toughthreedirectional",158)
	NewTex("toughpush",159)
	NewTex("missile",160)
	NewTex("lifemissile",161)
	NewTex("staller",162)
	NewTex("bulkenemy",163)
	NewTex("swivelenemy",164)
	NewTex("storage",165)
	NewTex("memory",166)
	NewTex("trigenerator",167)
	NewTex("bigenerator",168)
	NewTex("cwdigenerator",169)
	NewTex("ccwdigenerator",170)
	NewTex("tricloner",171)
	NewTex("bicloner",172)
	NewTex("cwdicloner",173)
	NewTex("ccwdicloner",174)
	NewTex("transporter",175)
	NewTex("tainter",176)
	NewTex("superreplicator",177)
	NewTex("scissor",178)
	NewTex("triscissor",179)
	NewTex("multiplier",180)
	NewTex("trimultiplier",181)
	NewTex("cwscissor",182)
	NewTex("ccwscissor",183)
	NewTex("cwmultiplier",184)
	NewTex("ccwmultiplier",185)
	NewTex("spooner",186)
	NewTex("trispooner",187)
	NewTex("cwspooner",188)
	NewTex("ccwspooner",189)
	NewTex("compounder",190)
	NewTex("tricompounder",191)
	NewTex("cwcompounder",192)
	NewTex("ccwcompounder",193)
	NewTex("gate_imply",194)
	NewTex("gate_conimply",195)
	NewTex("gate_nimply",196)
	NewTex("gate_connimply",197)
	NewTex("converter",198)
	NewTex("truemover",199)
	NewTex("truepuller",200)
	NewTex("truedriller",201)
	NewTex("truemirror",202)
	NewTex("truegear_cw",203)
	NewTex("truegear_ccw",204)
	NewTex("phantom",205)
	NewTex("lluea/move",206)
	NewTex("bar",207)
	NewTex("diodediverger",208)
	NewTex("crossdiodediverger",209)
	NewTex("twistdiverger",210)
	NewTex("glunkisource",211)
	NewTex("glunki",212)
	NewTex("toughmover",213)
	NewTex("spiritpush",214)
	NewTex("spiritslide",215)
	NewTex("spiritonedirectional",216)
	NewTex("spirittwodirectional",217)
	NewTex("spiritthreedirectional",218)
	NewTex("superacid",219)
	NewTex("acid",220)
	NewTex("portal",221)
	NewTex("timerepulsor",222)
	NewTex("coin",223)
	NewTex("coindiverger",224)
	NewTex("toughtrash",225)
	NewTex("semitrash",226)
	NewTex("conveyorgrapulsor",227)
	NewTex("crossconveyorgrapulsor",228)
	NewTex("constructor",229)
	NewTex("coinextractor",230)
	NewTex("silicon",231)
	NewTex("gravitizer",232)
	NewTex("filter",233)
	NewTex("rfire",234)
	NewTex("creator",235)
	NewTex("transformer",237)
	NewTex("crosstransformer",238)
	NewTex("player",239)
	NewTex("fire",240)
	NewTex("megafire",241)
	NewTex("fireball",242)
	NewTex("megafireball",243)
	NewTex("superenemy",244)
	NewTex("megarotator_cw",245)
	NewTex("megarotator_ccw",246)
	NewTex("megarotator_180",247)
	NewTex("superimpulsor",248)
	NewTex("semisilicon",249)
	NewTex("biintaker",250)
	NewTex("tetraintaker",251)
	NewTex("slime",252)
	NewTex("scissorclamper",253)
	NewTex("cwshifter",254)
	NewTex("ccwshifter",255)
	NewTex("bishifter",256)
	NewTex("trishifter",257)
	NewTex("ccwdishifter",258)
	NewTex("cwdishifter",259)
	NewTex("cwrelocator",260)
	NewTex("ccwrelocator",261)
	NewTex("birelocator",262)
	NewTex("trirelocator",263)
	NewTex("ccwdirelocator",264)
	NewTex("cwdirelocator",265)
	NewTex("degravitizer",266)
	NewTex("transmutator",267)
	NewTex("crosstransmutator",268)
	NewTex("crasher",269)
	NewTex("tugger",270)
	NewTex("yanker",271)
	NewTex("lifter",272)
	NewTex("hauler",273)
	NewTex("dragger",274)
	NewTex("mincer",275)
	NewTex("cutter",276)
	NewTex("screwdriver",277)
	NewTex("piercer",278)
	NewTex("slasher",279)
	NewTex("chiseler",280)
	NewTex("lacerator",281)
	NewTex("carver",282)
	NewTex("apeiropower",283)
	NewTex("supermover",284)
	NewTex("thawer",285)
	NewTex("megafreezer",286)
	NewTex("semifreezer",287)
	NewTex("fragileplayer",288)
	NewTex("pullplayer",289)
	NewTex("grabplayer",290)
	NewTex("drillplayer",291)
	NewTex("nudgeplayer",292)
	NewTex("fragilepullplayer",293)
	NewTex("fragilegrabplayer",294)
	NewTex("fragiledrillplayer",295)
	NewTex("fragilenudgeplayer",296)
	NewTex("sliceplayer",297)
	NewTex("fragilesliceplayer",298)
	NewTex("quantumenemy",299)
	NewTex("trashdiode",300)
	NewTex("brokengenerator",301)
	NewTex("brokenreplicator",302)
	NewTex("remover",303)
	NewTex("brokenmover",304)
	NewTex("brokenpuller",305)
	NewTex("termite_cw",306)
	NewTex("termite_ccw",307)
	NewTex("minishield",308)
	NewTex("microshield",309)
	NewTex("immobilizer",310)
	NewTex("inclusiveadvancer",311)
	NewTex("balloon",312)
	NewTex("supermirror",313)
	NewTex("crosssupermirror",314)
	NewTex("diagonalmirror",315)
	NewTex("crossdiagonalmirror",316)
	NewTex("triintaker",317)
	NewTex("sentry",318)
	NewTex("seeker",319) 
	NewTex("turret",320)
	NewTex("decoy",321)
	NewTex("cog_cw",322)
	NewTex("cog_ccw",323)
	NewTex("minicog_cw",324)
	NewTex("minicog_ccw",325)
	NewTex("junk",326)
	NewTex("builder",327)
	NewTex("crossbuilder",328)
	NewTex("cwbuilder",329)
	NewTex("ccwbuilder",330)
	NewTex("bibuilder",331)
	NewTex("tribuilder",332)
	NewTex("cwdibuilder",333)
	NewTex("ccwdibuilder",334)
	NewTex("cwsmith",335)
	NewTex("ccwsmith",336)
	NewTex("bismith",337)
	NewTex("trismith",338)
	NewTex("cwdismith",339)
	NewTex("ccwdismith",340)
	NewTex("memoryreplicator",341)
	NewTex("physicalgenerator",342)
	NewTex("physicalreplicator",343)
	NewTex("chainsaw_cw",344)
	NewTex("chainsaw_ccw",345)
	NewTex("repulsemover",346)
	NewTex("jumptrash",347)
	NewTex("squishtrash",348)
	NewTex("jumpphantom",349)
	NewTex("squishphantom",350)
	NewTex("omnicell",351)
	NewTex("adjustablemover",352)
	NewTex("adjustablepuller",353)
	NewTex("adjustablegrabber",354)
	NewTex("adjustabledriller",355)
	NewTex("adjustableslicer",356)
	NewTex("adjustablenudger",357)
	NewTex("strongmissile",358)
	NewTex("supermissile",359)
	NewTex("explosiveenemy",360)
	NewTex("megaexplosiveenemy",361)
	NewTex("collider",362)
	NewTex("paragenerator",363)
	NewTex("tetragenerator",364)
	NewTex("stronggenerator",365)
	NewTex("weakgenerator",366)
	NewTex("explosivemissile",367)
	NewTex("megaexplosivemissile",368)
	NewTex("vine",369)
	NewTex("deadvine",370)
	NewTex("delta",371)
	NewTex("deaddelta",372)
	NewTex("toxic",373)
	NewTex("deadtoxic",374)
	NewTex("chorus",375)
	NewTex("deadchorus",376)
	NewTex("gamma",377)
	NewTex("deadgamma",378)
	NewTex("poison",379)
	NewTex("deadpoison",380)
	NewTex("slope",381)
	NewTex("cwslope",382)
	NewTex("ccwslope",383)
	NewTex("parabole",384)
	NewTex("biparabole",385)
	NewTex("arc",386)
	NewTex("biarc",387)
	NewTex("cwparabole",388)
	NewTex("ccwparabole",389)
	NewTex("stair",390)
	NewTex("cwstair",391)
	NewTex("ccwstair",392)
	NewTex("backgenerator",393)
	NewTex("backreplicator",394)
	NewTex("physicalbackgenerator",395)
	NewTex("physicalbackreplicator",396)
	NewTex("bireplicator",397)
	NewTex("trireplicator",398)
	NewTex("tetrareplicator",399)
	NewTex("strongheaver",400)
	NewTex("inversion",401)
	NewTex("spring",402)
	NewTex("crystal",403)
	NewTex("semicrystal",404)
	NewTex("quasicrystal",405)
	NewTex("hemicrystal",406)
	NewTex("henacrystal",407)
	NewTex("semirepulsor",408)
	NewTex("quasirepulsor",409)
	NewTex("hemirepulsor",410)
	NewTex("henarepulsor",411)
	NewTex("recursor",412)
	NewTex("semiimpulsor",413)
	NewTex("quasiimpulsor",414)
	NewTex("hemiimpulsor",415)
	NewTex("henaimpulsor",416)
	NewTex("fan",417)
	NewTex("semifan",418)
	NewTex("quasifan",419)
	NewTex("hemifan",420)
	NewTex("henafan",421)
	NewTex("lockpick",422)
	NewTex("superalkali",423)
	NewTex("graviton",424)
	NewTex("tetramidas",425)
	NewTex("tetradirectionalmidas",426)
	NewTex("directionalcreator",427)
	NewTex("wrap",428)
	NewTex("cwdiverger",429)
	NewTex("ccwdiverger",430)
	NewTex("cwdisplacer",431)
	NewTex("ccwdisplacer",432)
	NewTex("divalvediverger",433)
	NewTex("divalvedisplacer",434)
	NewTex("superfan",435)
	NewTex("dumpster",436)
	NewTex("crossdumpster",437)
	NewTex("dodgetrash",438)
	NewTex("dodgephantom",439)
	NewTex("evadetrash",440)
	NewTex("evadephantom",441)
	NewTex("superrotator_cw",442)
	NewTex("superrotator_ccw",443)
	NewTex("superrotator_180",444)
	NewTex("reflector",445)
	NewTex("crossreflector",446)
	NewTex("anchor",447)
	NewTex("hypergenerator",448)
	NewTex("gear_180",449)
	NewTex("minigear_180",450)
	NewTex("cog_180",451)
	NewTex("minicog_180",452)
	NewTex("friendlysentry",453)
	NewTex("friendlyseeker",454)
	NewTex("friendlyturret",455)
	NewTex("friendlymissile",456) 
	NewTex("crosssupergenerator",457)
	NewTex("cwsupergenerator",458)
	NewTex("ccwsupergenerator",459)
	NewTex("cwsupercloner",460)
	NewTex("ccwsupercloner",461)
	NewTex("pin",462)
	NewTex("directionaltrash",463)
	NewTex("pull_extension",464)
	NewTex("sapper",465)
	NewTex("push_extension",466)
	NewTex("megasapper",467)
	NewTex("minisapper",468)
	NewTex("fastgear_cw",469)
	NewTex("fastgear_ccw",470)
	NewTex("fastcog_cw",471)
	NewTex("fastcog_ccw",472)
	NewTex("fastergear_cw",473)
	NewTex("fastergear_ccw",474)
	NewTex("fastercog_cw",475)
	NewTex("fastercog_ccw",476)
	NewTex("grab_extension",477)
	NewTex("megamirror",478)
	NewTex("megareflector",479)
	NewTex("superreflector",480)
	NewTex("crosssuperreflector",481)
	NewTex("skewgear_cw",482)
	NewTex("skewgear_ccw",483)
	NewTex("skewgear_180",484)
	NewTex("skewcog_cw",485)
	NewTex("skewcog_ccw",486)
	NewTex("skewcog_180",487)
	for i=0,11 do
		NewTex("rotatordiverger/"..i,"rotatordiverger"..i)
	end
	NewTex("bimirror",489)
	NewTex("dimirror",490)
	NewTex("trimirror",491)
	NewTex("termirror",492)
	NewTex("amethyst",493)
	NewTex("semiamethyst",494)
	NewTex("quasiamethyst",495)
	NewTex("hemiamethyst",496)
	NewTex("henaamethyst",497)
	NewTex("diagonalcrystal",498)
	NewTex("diagonalsemicrystal",499)
	for i=1,8 do
		NewTex("confetti/confetti_"..i,"confetti"..i)
	end
	NewTex("diagonalquasicrystal",501)
	NewTex("diagonalhemicrystal",502)
	NewTex("diagonalhenacrystal",503)
	NewTex("octocrystal",504)
	NewTex("cwtransformer",505)
	NewTex("ccwtransformer",506)
	NewTex("cwtransfigurer",507)
	NewTex("ccwtransfigurer",508)
	NewTex("cwtransmutator",509)
	NewTex("ccwtransmutator",510)
	NewTex("cwtransmogrifier",511)
	NewTex("ccwtransmogrifier",512)
	NewTex("crosssuperreplicator",513)
	NewTex("bisuperreplicator",514)
	NewTex("trisuperreplicator",515)
	NewTex("tetrasuperreplicator",516)
	NewTex("superintaker",517)
	NewTex("supercrossintaker",518)
	NewTex("superbiintaker",519)
	NewTex("supertriintaker",520)
	NewTex("supertetraintaker",521)
	NewTex("perpetualrotator_cw",522)
	NewTex("perpetualrotator_ccw",523)
	NewTex("perpetualrotator_180",524)
	NewTex("perpetualrotator_stop",525)
	NewTex("maker",526)
	NewTex("crossmaker",527)
	NewTex("bimaker",528)
	NewTex("trimaker",529)
	NewTex("tetramaker",530)
	NewTex("directionalcrossmaker",531)
	NewTex("directionalbimaker",532)
	NewTex("directionaltrimaker",533)
	NewTex("directionaltetramaker",534)
	NewTex("perpetualflipper",535)
	NewTex("bitransformer",536)
	NewTex("tritransformer",537)
	NewTex("cwditransformer",538)
	NewTex("ccwditransformer",539)
	NewTex("bitransfigurer",540)
	NewTex("tritransfigurer",541)
	NewTex("cwditransfigurer",542)
	NewTex("ccwditransfigurer",543)
	NewTex("bitransmutator",544)
	NewTex("tritransmutator",545)
	NewTex("cwditransmutator",546)
	NewTex("ccwditransmutator",547)
	NewTex("bitransmogrifier",548)
	NewTex("tritransmogrifier",549)
	NewTex("cwditransmogrifier",550)
	NewTex("ccwditransmogrifier",551)
	NewTex("apeirocell",552)
	NewTex("oneway_wall",553)
	NewTex("crossway_wall",554)
	NewTex("biway_wall",555)
	NewTex("triway_wall",556)
	NewTex("tetraway_wall",557)
	NewTex("oneway_trash",558)
	NewTex("crossway_trash",559)
	NewTex("biway_trash",560)
	NewTex("triway_trash",561)
	NewTex("tetraway_trash",562)
	NewTex("switch_off",563)
	NewTex("switch_on","switch_on")
	NewTex("switch_door",564)
	NewTex("switch_gate",565)
	NewTex("regenerativestaller",566)
	NewTex("brokenstaller","brokenstaller")
	NewTex("customlife",567)
	NewTex("deadcustomlife",568)
	NewTex("orientator",569)
	NewTex("crossorientator",570)
	NewTex("cworientator",571)
	NewTex("ccworientator",572)
	NewTex("biorientator",573)
	NewTex("triorientator",574)
	NewTex("cwdiorientator",575)
	NewTex("ccwdiorientator",576)
	NewTex("cwaligner",577)
	NewTex("ccwaligner",578)
	NewTex("bialigner",579)
	NewTex("trialigner",580)
	NewTex("cwdialigner",581)
	NewTex("ccwdialigner",582)
	NewTex("wirelesstransmitter",583)
	NewTex("superkey",584)
	NewTex("cwturner",585)
	NewTex("ccwturner",586)
	NewTex("180turner",587)
	NewTex("rotatablegravitizer",588)
	NewTex("strongsentry",589)
	NewTex("supersentry",590)
	NewTex("explosivesentry",591)
	NewTex("megaexplosivesentry",592)
	NewTex("friendlystrongsentry",593)
	NewTex("friendlysupersentry",594)
	NewTex("friendlyexplosivesentry",595)
	NewTex("friendlymegaexplosivesentry",596)
	NewTex("friendlystrongmissile",597)
	NewTex("friendlysupermissile",598)
	NewTex("friendlyexplosivemissile",599)
	NewTex("friendlymegaexplosivemissile",600)
	NewTex("antifilter",601)
	NewTex("skewfire",602)
	NewTex("skewfireball",603)
	NewTex("customLtL",604)
	NewTex("deadcustomLtL",605)
	NewTex("bisupergenerator",606)
	NewTex("trisupergenerator",607)
	NewTex("cwdisupergenerator",608)
	NewTex("ccwdisupergenerator",609)
	NewTex("bisupercloner",610)
	NewTex("trisupercloner",611)
	NewTex("cwdisupercloner",612)
	NewTex("ccwdisupercloner",613)
	NewTex("platformerplayer",614)
	NewTex("bitimewarper",615)
	NewTex("tritimewarper",616)
	NewTex("tetratimewarper",617)
	NewTex("brokenpush",618)
	NewTex("armorer",619)
	NewTex("brokenslide",620)
	NewTex("brokenonedirectional",621)
	NewTex("brokentwodirectional",622)
	NewTex("brokenthreedirectional",623)
	NewTex("rutzice",624)
	NewTex("cwcycler",625)
	NewTex("ccwcycler",626)
	NewTex("cwcrosscycler",627)
	NewTex("ccwcrosscycler",628)
	NewTex("curvedmirror",629)
	NewTex("bicurvedmirror",630)
	NewTex("constrictor",631)
	NewTex("cwbicycler",632)
	NewTex("ccwbicycler",633)
	NewTex("cwtricycler",634)
	NewTex("ccwtricycler",635)
	NewTex("cwtetracycler",636)
	NewTex("ccwtetracycler",637)
	NewTex("impeder",638)
	NewTex("restrainer",639)
	NewTex("megaflipper",640)
	NewTex("superflipper",641)
	NewTex("paracycler",642)
	NewTex("monogeneratable",643)
	NewTex("x-generatable",644)
	NewTex("metageneratable",645)
	NewTex("snipergenerator",646)
	NewTex("semislime",647)
	NewTex("quasislime",648)
	NewTex("honey",649)
	NewTex("semihoney",650)
	NewTex("quasihoney",651)
	NewTex("convertgenerator",652)
	NewTex("convertshifter",653)
	NewTex("diagonalflipper",654)
	NewTex("semidiagonalflipper_h",655)
	NewTex("semidiagonalflipper_v",656)
	NewTex("tricurvedmirror",657)
	NewTex("diagonalreflector",658)
	NewTex("crossdiagonalreflector",659)
	NewTex("octoreflector",660)
	NewTex("bireflector",661)
	NewTex("direflector",662)
	NewTex("trireflector",663)
	NewTex("terreflector",664)
	NewTex("physicalshifter",665)
	NewTex("physicalbackshifter",666)
	NewTex("backshifter",667)
	NewTex("adjustableweight",668)
	NewTex("adjustableresistance",669)
	NewTex("phantomdemolisher",670)
	NewTex("phantommegademolisher",671)
	NewTex("chainsaw_180",672)
	NewTex("physicalsupergenerator",673)
	NewTex("physicalsuperbackgenerator",674)
	NewTex("superbackgenerator",675)
	NewTex("physicalsuperreplicator",676)
	NewTex("physicalsuperbackreplicator",677)
	NewTex("superbackreplicator",678)
	NewTex("twistshifter",679)
	NewTex("marker_exclamation",680)
	NewTex("marker_stop",681)
	NewTex("marker_like",682)
	NewTex("marker_dislike",683)
	NewTex("ceiling",684)
	NewTex("ghostceiling",686)
	NewTex("trashceiling",688)
	NewTex("phantomceiling",690)
	NewTex("pushceiling",692)
	NewTex("attacktrash",694)
	NewTex("attackphantom",695)
	NewTex("unpushable",696)
	NewTex("unpullable",697)
	NewTex("ungrabbable",698)
	NewTex("unswappable",699)
	NewTex("bendmover",700)
	NewTex("bendgenerator",701)
	NewTex("flipflopdiverger",702)
	NewTex("flipflopdisplacer",703)
	NewTex("trailer",704)
	NewTex("togglekey",705)
	NewTex("toggledoor",706)
	NewTex("togglegate",707)
	NewTex("label",708)
	NewTex("flipspinner",709)
	NewTex("diagonalflipspinner",710)
	NewTex("flipturner",711)
	NewTex("diagonalflipturner",712)
	NewTex("diagonalmegaflipper",713)
	NewTex("diagonalsuperflipper",714)
	NewTex("diagonalperpetualflipper",715)
	NewTex("supersquishacid",716)
	NewTex("squishacid",717)
	NewTex("rowmover",718)
	NewTex("rowpuller",719)
	NewTex("rowadvancer",720)
	NewTex("semisuperrepulsor",721)
	NewTex("quasisuperrepulsor",722)
	NewTex("hemisuperrepulsor",723)
	NewTex("henasuperrepulsor",724)
	NewTex("semisuperfan",725)
	NewTex("quasisuperfan",726)
	NewTex("hemisuperfan",727)
	NewTex("henasuperfan",728)
	NewTex("semisuperimpulsor",729)
	NewTex("quasisuperimpulsor",730)
	NewTex("hemisuperimpulsor",731)
	NewTex("henasuperimpulsor",732)
	NewTex("bulktrash",733)
	NewTex("bulkphantom",734)
	NewTex("chainsaw_blade",735)
	NewTex("petrifier",736)
	NewTex("midas",737)
	NewTex("crossmidas",738)
	NewTex("bimidas",739)
	NewTex("trimidas",740)
	NewTex("megaredirector",741)
	NewTex("crossdirectionalmidas",742)
	NewTex("bidirectionalmidas",743)
	NewTex("tridirectionalmidas",744)
	NewTex("painter",745)
	NewTex("antiwrap",746)
	NewTex("warp",747)
	NewTex("crosswarp",748)
	NewTex("cwphysicalgenerator",749)
	NewTex("ccwphysicalgenerator",750)
	NewTex("cwphysicalcloner",751)
	NewTex("ccwphysicalcloner",752)
	NewTex("cwphysicalbackgenerator",753)
	NewTex("ccwphysicalbackgenerator",754)
	NewTex("cwphysicalbackcloner",755)
	NewTex("ccwphysicalbackcloner",756)
	NewTex("cwbackgenerator",757)
	NewTex("ccwbackgenerator",758)
	NewTex("cwbackcloner",759)
	NewTex("ccwbackcloner",760)
	NewTex("memorytransformer",761)
	NewTex("memorytransmutator",762)
	NewTex("rowrepulsor",763)
	NewTex("semirowrepulsor",764)
	NewTex("quasirowrepulsor",765)
	NewTex("hemirowrepulsor",766)
	NewTex("henarowrepulsor",767)
	NewTex("ally",768)
	NewTex("supercwphysicalgenerator",769)
	NewTex("superccwphysicalgenerator",770)
	NewTex("supercwphysicalcloner",771)
	NewTex("superccwphysicalcloner",772)
	NewTex("supercwphysicalbackgenerator",773)
	NewTex("superccwphysicalbackgenerator",774)
	NewTex("supercwphysicalbackcloner",775)
	NewTex("superccwphysicalbackcloner",776)
	NewTex("supercwbackgenerator",777)
	NewTex("superccwbackgenerator",778)
	NewTex("supercwbackcloner",779)
	NewTex("superccwbackcloner",780)
	NewTex("seizer",781)
	NewTex("biforker",782)
	NewTex("bidivider",783)
	NewTex("paraforker",784)
	NewTex("paradivider",785)
	NewTex("cwneutrino",786)
	NewTex("ccwneutrino",787)
	NewTex("hemislime",788)
	NewTex("henaslime",789)
	NewTex("hemihoney",790)
	NewTex("henahoney",791)
	NewTex("strongseeker",792)
	NewTex("superseeker",793)
	NewTex("explosiveseeker",794)
	NewTex("megaexplosiveseeker",795)
	NewTex("strongturret",796)
	NewTex("superturret",797)
	NewTex("explosiveturret",798)
	NewTex("megaexplosiveturret",799)
	NewTex("friendlystrongseeker",800)
	NewTex("friendlysuperseeker",801)
	NewTex("friendlyexplosiveseeker",802)
	NewTex("friendlymegaexplosiveseeker",803)
	NewTex("friendlystrongturret",804)
	NewTex("friendlysuperturret",805)
	NewTex("friendlyexplosiveturret",806)
	NewTex("friendlymegaexplosiveturret",807)
	NewTex("distortion",808)
	NewTex("rust",809)
	NewTex("algae",810)
	NewTex("alteration",811)
	NewTex("silvergoo",812)
	NewTex("mold",813)
	NewTex("chainsaw_still",814)
	NewTex("spikes",815)
	NewTex("centerspike",816)
	NewTex("singlespike",817)
	NewTex("laser_off",818)
	NewTex("laser",819)
	NewTex("stapler",820)
	NewTex("dispenser",821)
	NewTex("dropoff",822)
	NewTex("dropper",823)
	NewTex("settlecompel",824)
	NewTex("motocompel",825)
	NewTex("decompel",826)
	NewTex("angryenemy",827)
	NewTex("megaangryenemy",828)
	NewTex("advancerplayer",829)
	NewTex("fragileadvancerplayer",830)
	NewTex("cracker",831)
	NewTex("superspring",832)
	NewTex("supertimewarper",833)
	NewTex("supercrosstimewarper",834)
	NewTex("superbitimewarper",835)
	NewTex("supertritimewarper",836)
	NewTex("supertetratimewarper",837)
	NewTex("angrysuperenemy",838)
	NewTex("megaangrysuperenemy",839)
	NewTex("superpush",840)
	NewTex("superslide",841)
	NewTex("superonedirectional",842)
	NewTex("supertwodirectional",843)
	NewTex("superthreedirectional",844)
	NewTex("armedplayer",845)
	NewTex("spy",846)
	NewTex("snipershifter",847)
	NewTex("jumpdemolisher",848)
	NewTex("jumpmegademolisher",849)
	NewTex("dodgedemolisher",850)
	NewTex("dodgemegademolisher",851)
	NewTex("evadedemolisher",852)
	NewTex("evademegademolisher",853)
	NewTex("attackdemolisher",854)
	NewTex("attackmegademolisher",855)
	NewTex("directionalphantom",856)
	NewTex("directionaldemolisher",857)
	NewTex("directionalmegademolisher",858)
	NewTex("squishdemolisher",859)
	NewTex("squishmegademolisher",860)
	NewTex("bulkdemolisher",861)
	NewTex("bulkmegademolisher",862)
	NewTex("alkali",863)
	NewTex("supersquishalkali",864)
	NewTex("squishalkali",865)
	NewTex("crossphysicalreplicator",866)
	NewTex("crossphysicalbackreplicator",867)
	NewTex("crossbackreplicator",868)
	NewTex("physicalbireplicator",869)
	NewTex("physicalbibackreplicator",870)
	NewTex("bibackreplicator",871)
	NewTex("physicaltrireplicator",872)
	NewTex("physicaltribackreplicator",873)
	NewTex("tribackreplicator",874)
	NewTex("physicaltetrareplicator",875)
	NewTex("physicaltetrabackreplicator",876)
	NewTex("tetrabackreplicator",877)
	NewTex("supercrossphysicalreplicator",878)
	NewTex("supercrossphysicalbackreplicator",879)
	NewTex("supercrossbackreplicator",880)
	NewTex("superphysicalbireplicator",881)
	NewTex("superphysicalbibackreplicator",882)
	NewTex("superbibackreplicator",883)
	NewTex("superphysicaltrireplicator",884)
	NewTex("superphysicaltribackreplicator",885)
	NewTex("supertribackreplicator",886)
	NewTex("superphysicaltetrareplicator",887)
	NewTex("superphysicaltetrabackreplicator",888)
	NewTex("supertetrabackreplicator",889)
	NewTex("physicaltrash",890)
	NewTex("physicalphantom",891)
	NewTex("dextrophysicaltrash",892)
	NewTex("dextrophysicalphantom",893)
	NewTex("levophysicaltrash",894)
	NewTex("levophysicalphantom",895)
	NewTex("gooer",896)
	NewTex("physicaldemolisher",897)
	NewTex("physicalmegademolisher",898)
	NewTex("dextrophysicaldemolisher",899)
	NewTex("dextrophysicalmegademolisher",900)
	NewTex("levophysicaldemolisher",901)
	NewTex("levophysicalmegademolisher",902)
	NewTex("tunneller",903)
	NewTex("digger",904)
	NewTex("impacter",905)
	NewTex("neutrino",906)
	NewTex("neutral",907)
	NewTex("victoryswitch",908)
	NewTex("victoryswitch_on","victoryswitch_on")
	NewTex("failureswitch",909)
	NewTex("failureswitch_on","failureswitch_on")
	NewTex("inputpush",910)
	NewTex("inputslide",911)
	NewTex("inputonedirectional",912)
	NewTex("inputtwodirectional",913)
	NewTex("inputthreedirectional",914)
	NewTex("inputenemy",915)
	NewTex("inputdoor",916)
	NewTex("inputgate",917)
	NewTex("inputstorage",918)
	NewTex("sapphire",919)
	NewTex("semisapphire",920)
	NewTex("quasisapphire",921)
	NewTex("hemisapphire",922)
	NewTex("henasapphire",923)
	NewTex("tourmaline",924)
	NewTex("semitourmaline",925)
	NewTex("quasitourmaline",926)
	NewTex("hemitourmaline",927)
	NewTex("henatourmaline",928)
	NewTex("wall_grass",929)
	NewTex("wall_dirt",930)
	NewTex("wall_cobble",931)
	NewTex("wall_sand",932)
	NewTex("wall_magma",933)
	NewTex("wall_wood",934)
	NewTex("tunnelclamper",935)
	NewTex("unscissorable",936)
	NewTex("untunnellable",937)
	NewTex("wall_mossystone",938)
	NewTex("wall_copper",939)
	NewTex("wall_silver",940)
	NewTex("wall_gold",941)
	NewTex("diamond",942)
	NewTex("semidiamond",943)
	NewTex("quasidiamond",944)
	NewTex("hemidiamond",945)
	NewTex("henadiamond",946)
	NewTex("emerald",947)
	NewTex("semiemerald",948)
	NewTex("quasiemerald",949)
	NewTex("hemiemerald",950)
	NewTex("henaemerald",951)
	NewTex("topaz",952)
	NewTex("semitopaz",953)
	NewTex("quasitopaz",954)
	NewTex("hemitopaz",955)
	NewTex("henatopaz",956)
	NewTex("skewrotator_cw",957)
	NewTex("skewrotator_ccw",958)
	NewTex("skewrotator_180",959)
	NewTex("rotator_rng",960)
	NewTex("semirotator_rng",961)
	NewTex("megarotator_rng",962)
	NewTex("skewrotator_rng",963)
	NewTex("superrotator_rng",964)
	NewTex("spinnerrng",965)
	NewTex("rngturner",966)
	NewTex("perpetualrotator_rng",967)
	NewTex("gear_rng",968)
	NewTex("fastgear_rng",969)
	NewTex("fastergear_rng",970)
	NewTex("minigear_rng",971)
	NewTex("skewgear_rng",972)
	NewTex("cog_rng",973)
	NewTex("fastcog_rng",974)
	NewTex("fastercog_rng",975)
	NewTex("minicog_rng",976)
	NewTex("skewcog_rng",977)
	NewTex("rngslope",978)
	NewTex("rngstair",979)
	NewTex("rngdiverger",980)
	NewTex("rngdisplacer",981)
	NewTex("edgerngdiverger",982)
	NewTex("edgerngdisplacer",983)
	NewTex("randulsor",984)
	NewTex("semirandulsor",985)
	NewTex("quasirandulsor",986)
	NewTex("hemirandulsor",987)
	NewTex("henarandulsor",988)
	NewTex("rngredirector",989)
	NewTex("rngsemiredirector",990)
	NewTex("rngquasiredirector",991)
	NewTex("rnghemiredirector",992)
	NewTex("rnghenaredirector",993)
	NewTex("quasirotator_cw",994)
	NewTex("quasirotator_ccw",995)
	NewTex("quasirotator_180",996)
	NewTex("quasirotator_rng",997)
	NewTex("hemirotator_cw",998)
	NewTex("hemirotator_ccw",999)
	NewTex("fireworkenemy",1000)
	NewTex("hemirotator_180",1001)
	NewTex("hemirotator_rng",1002)
	NewTex("henarotator_cw",1003)
	NewTex("henarotator_ccw",1004)
	NewTex("henarotator_180",1005)
	NewTex("henarotator_rng",1006)
	NewTex("vacuum",1007)
	NewTex("semivacuum",1008)
	NewTex("quasivacuum",1009)
	NewTex("hemivacuum",1010)
	NewTex("henavacuum",1011)
	NewTex("rowimpulsor",1012)
	NewTex("semirowimpulsor",1013)
	NewTex("quasirowimpulsor",1014)
	NewTex("hemirowimpulsor",1015)
	NewTex("henarowimpulsor",1016)
	NewTex("slant",1017)
	NewTex("cwslant",1018)
	NewTex("ccwslant",1019)
	NewTex("rngslant",1020)
	NewTex("gear_flip",1021)
	NewTex("gear_dflip",1022)
	NewTex("minigear_flip",1023)
	NewTex("minigear_dflip",1024)
	NewTex("skewgear_flip",1025)
	NewTex("skewgear_dflip",1026)
	NewTex("cog_flip",1027)
	NewTex("cog_dflip",1028)
	NewTex("minicog_flip",1029)
	NewTex("minicog_dflip",1030)
	NewTex("skewcog_flip",1031)
	NewTex("skewcog_dflip",1032)
	NewTex("deleter",1033)
	NewTex("crossdeleter",1034)
	NewTex("bideleter",1035)
	NewTex("trideleter",1036)
	NewTex("tetradeleter",1037)
	NewTex("superdeleter",1038)
	NewTex("supercrossdeleter",1039)
	NewTex("superbideleter",1040)
	NewTex("supertrideleter",1041)
	NewTex("supertetradeleter",1042)
	NewTex("injector",1043)
	NewTex("skewredirector",1044)
	NewTex("superredirector",1045)
	NewTex("spinnerredirect",1046)
	NewTex("redirectturner",1047)
	NewTex("skewflipper",1048)
	NewTex("diagonalskewflipper",1049)
	NewTex("physicalmaker",1050)
	NewTex("physicalcrossmaker",1051)
	NewTex("physicalbimaker",1052)
	NewTex("physicaltrimaker",1053)
	NewTex("physicaltetramaker",1054)
	NewTex("physicaldirectionalcrossmaker",1055)
	NewTex("physicaldirectionalbimaker",1056)
	NewTex("physicaldirectionaltrimaker",1057)
	NewTex("physicaldirectionaltetramaker",1058)
	NewTex("physicalbackmaker",1059)
	NewTex("physicalbackcrossmaker",1060)
	NewTex("physicalbackbimaker",1061)
	NewTex("physicalbacktrimaker",1062)
	NewTex("physicalbacktetramaker",1063)
	NewTex("physicalbackdirectionalcrossmaker",1064)
	NewTex("physicalbackdirectionalbimaker",1065)
	NewTex("physicalbackdirectionaltrimaker",1066)
	NewTex("physicalbackdirectionaltetramaker",1067)
	NewTex("backmaker",1068)
	NewTex("backcrossmaker",1069)
	NewTex("backbimaker",1070)
	NewTex("backtrimaker",1071)
	NewTex("backtetramaker",1072)
	NewTex("backdirectionalcrossmaker",1073)
	NewTex("backdirectionalbimaker",1074)
	NewTex("backdirectionaltrimaker",1075)
	NewTex("backdirectionaltetramaker",1076)
	NewTex("worm",1077)
	NewTex("cwworm",1078)
	NewTex("ccwworm",1079)
	NewTex("180worm",1080)
	NewTex("flipcwworm",1081)
	NewTex("flipccwworm",1082)
	NewTex("partialconverter",1083)
	NewTex("multdiverger",1084)
	NewTex("divdiverger",1085)
	NewTex("cwslicer",1086)
	NewTex("ccwslicer",1087)
	NewTex("convertconstructor",1088)
	NewTex("brokensupergenerator",1089)
	NewTex("brokensuperreplicator",1090)
	NewTex("adjustableslope",1091)
	NewTex("adjustablecwslope",1092)
	NewTex("adjustableccwslope",1093)
	NewTex("adjustablerngslope",1094)
	NewTex("adjustablegem",1095)
	NewTex("adjustablesemigem",1096)
	NewTex("adjustablequasigem",1097)
	NewTex("adjustablehemigem",1098)
	NewTex("adjustablehenagem",1099)
	NewTex("semitimerepulsor",1100)
	NewTex("quasitimerepulsor",1101)
	NewTex("hemitimerepulsor",1102)
	NewTex("henatimerepulsor",1103)
	NewTex("timeimpulsor",1104)
	NewTex("semitimeimpulsor",1105)
	NewTex("quasitimeimpulsor",1106)
	NewTex("hemitimeimpulsor",1107)
	NewTex("henatimeimpulsor",1108)
	NewTex("flower",1109)
	NewTex("deadflower",1110)
	NewTex("epsilon",1111)
	NewTex("deadepsilon",1112)
	NewTex("cyanide",1113)
	NewTex("deadcyanide",1114)
	NewTex("supragenerator",1115)
	NewTex("sawblade_0","sawblade0")
	NewTex("sawblade_1","sawblade1")
	NewTex("sawblademover",1117)
	NewTex("zone_cw",1118)
	NewTex("zone_ccw",1119)
	NewTex("zone_180",1120)
	NewTex("zone_rng",1121)
	NewTex("zone_redirect",1122)
	NewTex("zone_timewarp",1123)
	NewTex("zone_conveyor",1124)
	NewTex("custominfector",1125)
	NewTex("twirler_cw",1126)
	NewTex("twirler_ccw",1127)
	NewTex("twirler_180",1128)
	NewTex("twirler_rng",1129)
	NewTex("twirler_flip",1130)
	NewTex("twirler_dflip",1131)
	NewTex("twirler_redirect",1132)
	NewTex("particles/proton",1133)
	NewTex("particles/antiproton",1134)
	NewTex("particles/neutron",1135)
	NewTex("particles/antineutron",1136)
	NewTex("particles/electron",1137)
	NewTex("particles/antielectron",1138)
	NewTex("particles/muon",1139)
	NewTex("particles/antimuon",1140)
	NewTex("particles/tau",1141)
	NewTex("particles/antitau",1142)
	NewTex("particles/graviton",1143)
	NewTex("particles/exoticon",1144)
	NewTex("particles/pion",1145)
	NewTex("particles/antipion",1146)
	NewTex("particles/strangelet",1147)
	NewTex("particles/antistrangelet",1148)
	NewTex("particles/wboson",1149)
	NewTex("settlestorage",1150)
	NewTex("motostorage",1151)
	NewTex("reshifter",1152)
	NewTex("crossreshifter",1153)
	NewTex("metafungal",1154)
	NewTex("icicle",1155)
	NewTex("wall_snow",1156)
	NewTex("observer",1157)
	NewTex("friendlyobserver",1158)
	NewTex("springboard",1159)
	NewTex("crusher",1160)
	NewTex("supercrusher",1161)
	NewTex("trespasser",1162)
	for i=0,9 do
		NewTex("dashblock_"..i,"dashblock"..i)
	end
	NewTex("activator",1164)
	NewTex("superally",1165)
	NewTex("superneutral",1166)
	NewTex("chaser",1167)
	NewTex("superchaser",1168)
	NewTex("friendlychaser",1169)
	NewTex("friendlysuperchaser",1170)
	NewTex("wall_ice",1171)
	NewTex("fearfulenemy",1172)
	NewTex("fearfulally",1173)
	NewTex("wall_wool",1174)
	NewTex("crushrepulsor",1175)
	NewTex("crushsemirepulsor",1176)
	NewTex("crushquasirepulsor",1177)
	NewTex("crushhemirepulsor",1178)
	NewTex("crushhenarepulsor",1179)
	for i=1,8 do
		NewTex("keys/"..i,"keycollectable"..i)
		NewTex("keys/d"..i,"keydoor"..i)
	end
	NewTex("imaginaryweight",1182)
	NewTex("imaginaryantiweight",1183)
	NewTex("imaginarybias",1184)
	NewTex("imaginaryresistance",1185)
	NewTex("wall_stone",1186)
	NewTex("coil",1187)
	NewTex("adjustablecoil",1188)
	NewTex("capacitor",1189)
	NewTex("adjustablecapacitor",1190)
	NewTex("conductance",1191)
	NewTex("superconductance",1192)
	NewTex("adjustableconductance",1193)
	NewTex("superresistance",1194)
	NewTex("inhibation",1195)
	NewTex("imaginaryconductance",1196)
	NewTex("inductor",1197)
	NewTex("adjustableinductor",1198)
	NewTex("bolter",1199)
	NewTex("script",1200)
	NewTex("placeable","placeable")
	NewTex("placeableW","placeableW")
	NewTex("placeableR","placeableR")
	NewTex("placeableO","placeableO")
	NewTex("placeableY","placeableY")
	NewTex("placeableG","placeableG")
	NewTex("placeableC","placeableC")
	NewTex("placeableB","placeableB")
	NewTex("placeableP","placeableP")
	NewTex("rotatable","rotatable")
	NewTex("180_rotatable","rotatable180")
	NewTex("h_flippable","hflippable")
	NewTex("v_flippable","vflippable")
	NewTex("du_flippable","duflippable")
	NewTex("dd_flippable","ddflippable")
	NewTex("bggrass","bggrass")
	NewTex("bgdirt","bgdirt")
	NewTex("bgstone","bgstone")
	NewTex("bgcobble","bgcobble")
	NewTex("bgsand","bgsand")
	NewTex("bgsnow","bgsnow")
	NewTex("bgice","bgice")
	NewTex("bgmagma","bgmagma")
	NewTex("bgwood","bgwood")
	NewTex("bgwool","bgwool")
	NewTex("bgplate","bgplate")
	NewTex("bgmossystone","bgmossystone")
	NewTex("bgcopper","bgcopper")
	NewTex("bgsilver","bgsilver")
	NewTex("bggold","bggold")
	NewTex("bgspace","bgspace")
	NewTex("bgmatrix","bgmatrix")
	NewTex("bgvoid","bgvoid")
	NewTex("lluea/move","lluea0")
	NewTex("lluea/grab","lluea1")
	NewTex("lluea/pull","lluea2")
	NewTex("lluea/drill","lluea3")
	NewTex("lluea/slice","lluea4")
	NewTex("lluea/moveR","lluea0r")
	NewTex("lluea/grabR","lluea1r")
	NewTex("lluea/pullR","lluea2r")
	NewTex("lluea/drillR","lluea3r")
	NewTex("lluea/sliceR","lluea4r")
	NewTex("lluea/moveL","lluea0l")
	NewTex("lluea/grabL","lluea1l")
	NewTex("lluea/pullL","lluea2l")
	NewTex("lluea/drillL","lluea3l")
	NewTex("lluea/sliceL","lluea4l")
	NewTex("omnicell/base","omnicellbase")
	for i=1,23 do
		NewTex("omnicell/u"..i,"omnicell_u"..i)
		NewTex("omnicell/r"..i,"omnicell_r"..i)
		NewTex("omnicell/d"..i,"omnicell_d"..i)
		NewTex("omnicell/l"..i,"omnicell_l"..i)
	end
	NewTex("omnicell/movebase","omnicellmovebase")
	NewTex("omnicell/controlledbase","omnicellcontrolledbase")
	for i=1,6 do
		NewTex("omnicell/ul"..i,"omnicell_ul"..i)
		NewTex("omnicell/ur"..i,"omnicell_ur"..i)
		NewTex("omnicell/dr"..i,"omnicell_dr"..i)
		NewTex("omnicell/dl"..i,"omnicell_dl"..i)
	end
	NewTex("omnicell/move_u1","omnicell_move_u1")
	NewTex("omnicell/move_r1","omnicell_move_r1")
	NewTex("omnicell/move_d1","omnicell_move_d1")
	NewTex("omnicell/move_l1","omnicell_move_l1")
	for i=1,4 do
		NewTex("omnicell/rot_"..i,"omnicell_rot"..i)
	end
	NewTex("omnicell/nudge","omnicell_nudge")
	NewTex("omnicell/push","omnicell_push")
	NewTex("omnicell/pull","omnicell_pull")
	NewTex("omnicell/grab","omnicell_grab")
	NewTex("omnicell/shove","omnicell_shove")
	NewTex("omnicell/drill","omnicell_drill")
	NewTex("omnicell/slice","omnicell_slice")
	NewTex("laser_charge","laser_charge")
	NewTex("laser_on","laser_on")
	NewTex("laser","laser")
	NewTex("laser_white","laser_white")
	NewTex("laser_colorable","laser_colorable")
	NewTex("laser_invertcolorable","laser_invertcolorable")
	NewTex("laser_cross","laser_cross")
	NewTex("laser_white_cross","laser_white_cross")
	NewTex("laser_colorable_cross","laser_colorable_cross")
	NewTex("laser_invertcolorable_cross","laser_invertcolorable_cross")
	NewTex("spyoverlay","spyoverlay")
	NewTex("particles/neutral","particle_neutral")
	NewTex("particles/red","particle_red")
	NewTex("particles/green","particle_green")
	NewTex("particles/blue","particle_blue")
	NewTex("particles/cyan","particle_cyan")
	NewTex("particles/purple","particle_purple")
	NewTex("particles/yellow","particle_yellow")
	NewTex("particles/orange","particle_orange")
	NewTex("particles/lime","particle_lime")
	NewTex("particles/redoverlay","particle_redoverlay")
	NewTex("particles/greenoverlay","particle_greenoverlay")
	NewTex("particles/blueoverlay","particle_blueoverlay")
	NewTex("pixel","pix")
	NewTex("sparkle","sparkle")
	NewTex("firework_white","firework_white")
	NewTex("firework_glow","firework_glow")
	NewTex("smoke","smoke")
	NewTex("eraser","eraser")
	NewTex("nonexistant","X")
	NewTex("nonexistant_bg","Xbg")
	NewTex("effects/frozen","frozen")
	NewTex("effects/protected","protected")
	NewTex("effects/armored","armored")
	NewTex("effects/locked","locked")
	NewTex("effects/bolted","bolted")
	NewTex("effects/clamp-push","clamp-push")
	NewTex("effects/clamp-pull","clamp-pull")
	NewTex("effects/clamp-grab","clamp-grab")
	NewTex("effects/clamp-swap","clamp-swap")
	NewTex("effects/clamp-scissor","clamp-scissor")
	NewTex("effects/clamp-tunnel","clamp-tunnel")
	NewTex("effects/permaclamp-push","permaclamp-push")
	NewTex("effects/permaclamp-pull","permaclamp-pull")
	NewTex("effects/permaclamp-grab","permaclamp-grab")
	NewTex("effects/permaclamp-swap","permaclamp-swap")
	NewTex("effects/permaclamp-scissor","permaclamp-scissor")
	NewTex("effects/permaclamp-tunnel","permaclamp-tunnel")
	NewTex("effects/sticky","sticky")
	NewTex("effects/viscous","viscous")
	NewTex("effects/thawed","thawed")
	NewTex("effects/coins","coins")
	NewTex("effects/timerep_r","timerep_r")
	NewTex("effects/timerep_l","timerep_l")
	NewTex("effects/timerep_u","timerep_u")
	NewTex("effects/timerep_d","timerep_d")
	NewTex("effects/timeimp_r","timeimp_r")
	NewTex("effects/timeimp_l","timeimp_l")
	NewTex("effects/timeimp_u","timeimp_u")
	NewTex("effects/timeimp_d","timeimp_d")
	for i=0,7 do
		NewTex("effects/grav"..i,"grav"..i)
	end
	NewTex("effects/perpetualrotate_-1","perpetualrot-1")
	for i=1,7 do
		NewTex("effects/perpetualrotate_"..i,"perpetualrot"..i)
	end
	NewTex("effects/compel_settle","compelled1")
	NewTex("effects/compel_moto","compelled2")
	NewTex("cover","spiked")
	NewTex("effects/tag_enemy","tag_enemy")
	NewTex("effects/tag_ally","tag_ally")
	NewTex("effects/tag_player","tag_player")
	NewTex("effects/ghostified","ghostified")
	NewTex("effects/ungeneratable","ungeneratable")
	NewTex("effects/petrified","petrified")
	NewTex("effects/gooey","gooey")
	NewTex("effects/input","inputfrozen")
	NewTex("effects/inputclicked","inputclicked")
	NewTex("menubar","menubar")
	NewTex("effects/invalidrot","invalidrot")
	NewTex("effects/placeableoverlay","placeable_overlay")
	NewTex("effects/placeableWoverlay","placeableW_overlay")
	NewTex("effects/placeableRoverlay","placeableR_overlay")
	NewTex("effects/placeableOoverlay","placeableO_overlay")
	NewTex("effects/placeableYoverlay","placeableY_overlay")
	NewTex("effects/placeableGoverlay","placeableG_overlay")
	NewTex("effects/placeableCoverlay","placeableC_overlay")
	NewTex("effects/placeableBoverlay","placeableB_overlay")
	NewTex("effects/placeablePoverlay","placeableP_overlay")
	NewTex("effects/rotatableoverlay","rotatable_overlay")
	NewTex("effects/180rotatableoverlay","rotatable180_overlay")
	NewTex("effects/hflipoverlay","hflippable_overlay")
	NewTex("effects/vflipoverlay","vflippable_overlay")
	NewTex("effects/duflipoverlay","duflippable_overlay")
	NewTex("effects/ddflipoverlay","ddflippable_overlay")
	NewTex("difficulty/easier","difficulty1")
	NewTex("difficulty/easy","difficulty2")
	NewTex("difficulty/medium","difficulty3")
	NewTex("difficulty/hard","difficulty4")
	NewTex("difficulty/harder","difficulty5")
	NewTex("difficulty/extreme","difficulty6")
	NewTex("difficulty/easiersuper","difficulty7")
	NewTex("difficulty/easysuper","difficulty8")
	NewTex("difficulty/mediumsuper","difficulty9")
	NewTex("difficulty/hardsuper","difficulty10")
	NewTex("difficulty/hardersuper","difficulty11")
	NewTex("difficulty/extremesuper","difficulty12")
	NewTex("copy","copy")
	NewTex("cut","cut")
	NewTex("paste","paste")
	NewTex("folder","folder")
	NewTex("fill","fill")
	NewTex("bigui","bigui")
	NewTex("popups","popups")
	NewTex("debug","debug")
	NewTex("fancy","fancy")
	NewTex("subtick0","subtick0")
	NewTex("subtick1","subtick1")
	NewTex("subtick2","subtick2")
	NewTex("subtick3","subtick3")
	NewTex("subtick4","subtick4")
	NewTex("delete","delete")
	NewTex("checkoff","checkoff")
	NewTex("checkon","checkon")
	NewTex("playerlevel","playerlevel")
	NewTex("zoomin","zoomin")
	NewTex("zoomout","zoomout")
	NewTex("menu","menu")
	NewTex("pencil","pencil")
	NewTex("edit_all","edit_all")
	NewTex("edit_or","edit_or")
	NewTex("edit_and","edit_and")
	NewTex("shape_square","shape_square")
	NewTex("shape_circle","shape_circle")
	NewTex("randrot","randrot")
	NewTex("music","music")
	NewTex("select","select")
	NewTex("add","add")
	NewTex("subtract","subtract")
	NewTex("puzzle","puzzle")
	NewTex("brushup","brushup")
	NewTex("brushdown","brushdown")
	NewTex("playercam","playercam")
	NewTex("paint","paint")
	NewTex("invertcolorpaint","invertcolorpaint")
	NewTex("invertpaint","invertpaint")
	NewTex("invispaint","invispaint")
	NewTex("HSV","hsvpaint")
	NewTex("invertHSV","inverthsvpaint")
	NewTex("shadowpaint","shadowpaint")
	NewTex("blendmode","blendmode")
	NewTex("timerepulsor","timerep_tool")
	NewTex("gravitizer","grav_tool")
	NewTex("perpetualrotator_cw","prot_tool")
	NewTex("armorer","armor_tool")
	NewTex("bolter","bolt_tool")
	NewTex("coin","coin_tool")
	NewTex("enemy","tag_tool")
	NewTex("cover","spikes_tool")
	NewTex("petrifier","petrify_tool")
	NewTex("gooer","goo_tool")
	NewTex("settlecompel","compel_tool")
	NewTex("quantumenemy","entangle_tool")
	NewTex("inputgate","input_tool")
	NewTex("permaclamp_icon","permaclamp_tool")
	NewTex("spiritpush","ghost_tool")
	NewTex("scatter","scatter")
	NewTex("action","action")
	NewTex("stamp","stamp")
	NewTex("addstamp","addstamp")
	NewTex("favorite","favorite")
	NewTex("search","search")
	NewTex("joystick","joystick")
	NewTex("joystickbg","joystickbg")
	NewTex("logo","logo")
	NewTex("exportimage","exportimage")
	NewTex("rendertext","rendertext")
	NewTex("countcells","countcells")
	NewTex("record","recordvideo")
	NewTex("inputrecord","recordinput")
	NewTex("forces/push","forcepush")
	NewTex("forces/nudge","forcenudge")
	NewTex("forces/pull","forcepull")
	NewTex("forces/grab","forcegrab")
	NewTex("forces/grabL","forcegrabL")
	NewTex("forces/grabR","forcegrabR")
	NewTex("forces/slice","forceslice")
	NewTex("forces/sliceL","forcesliceL")
	NewTex("forces/sliceR","forcesliceR")
	NewTex("forces/tunnel","forcetunnel")
	NewTex("forces/dig","forcedig")
	NewTex("forces/staple","forcestaple")
	NewTex("forces/swap","forceswap")
end

function MakePackBtn(i,pack)
	local b = NewButton(0,function() return i*120 - packscroll end,400,100,"pix","texpack"..i,nil,nil,function() SetPack(pack.name) end,nil,function() return mainmenu == "packs" end,"center",3000,nil,{1,1,1,0},{1,1,1,0},{1,1,1,0})
	b.drawfunc = function(x,y,b)
		if y < 600*winym+200 and y > -200 then
			MenuRect(x-b.w*uiscale/2,y-b.h*uiscale/2,400*uiscale,110*uiscale,texpath == pack.path and {.5,1,.5,.5},texpath == pack.path and {.5,1,.5,1})
			love.graphics.setColor(1,1,1)
			love.graphics.draw(pack.icon,x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,100/pack.icon:getWidth()*uiscale,100/pack.icon:getHeight()*uiscale)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf(pack.name,x-(b.w/2-116)*uiscale,y-(b.h/2-11)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			love.graphics.setColor(1,1,1)
			love.graphics.printf(pack.name,x-(b.w/2-115)*uiscale,y-(b.h/2-10)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			if pack.desc then
				love.graphics.setColor(0,0,0,.5)
				love.graphics.printf(pack.desc,x-(b.w/2-116)*uiscale,y-(b.h/2-31)*uiscale,280,"left",0,uiscale,uiscale)
				love.graphics.setColor(1,1,1)
				love.graphics.printf(pack.desc,x-(b.w/2-115)*uiscale,y-(b.h/2-30)*uiscale,280,"left",0,uiscale,uiscale)
			end
			if pack.contributors then
				love.graphics.setColor(0,0,0,.5)
				love.graphics.printf(pack.contributors,x-(b.w/2-116)*uiscale,y-(b.h/2-96)*uiscale,280,"right",0,uiscale,uiscale)
				love.graphics.setColor(1,1,1)
				love.graphics.printf(pack.contributors,x-(b.w/2-115)*uiscale,y-(b.h/2-95)*uiscale,280,"right",0,uiscale,uiscale)
			end
		end
	end
	maxpackscroll = i*120
end

default_config = [[return {
	desc="The default texture pack.",
	contributors="KyYay",
	defaultzoom=4,
	zoomlevels={2,4,10,20,40,80,160},
	voidcolor={.125,.125,.125},
	bgcolor={.375,.375,.375,.25},
	textcolor={1,1,1},
	shadowdist=3/20,
	storagemult=10/20,
	makermult=8/20,
	memorymult=4/20,
}]]

function LoadTexturePacks()
	texturepacks = {Default={
		icon=love.graphics.newImage("textures/puller.png"),
		path="textures/",
		name="Default",
		desc="The default texture pack.",
		contributors="KyYay",
		defaultzoom=4,
		zoomlevels={2,4,10,20,40,80,160},
		voidcolor={.125,.125,.125},
		bgcolor={.375,.375,.375,.25},
		textcolor={1,1,1},
		shadowdist=3/20,
		storagemult=10/20,
		makermult=8/20,
		memorymult=4/20,
	}}
	MakePackBtn(0,texturepacks.Default)
	if not love.filesystem.getInfo("texturepacks") then
		love.filesystem.createDirectory("texturepacks")
	end
	local items = love.filesystem.getDirectoryItems("texturepacks")
	table.sort(items)
	for i,v in ipairs(items) do
		if LoadPack(v) then
			MakePackBtn(i,texturepacks[v])
		end
	end
end

function LoadPack(name)
	local path = "texturepacks/"..name
	local info = love.filesystem.getInfo(path)
	if info and info.type == "directory" then
		local pack = {
			icon = love.filesystem.getInfo(path.."/icon.png") and love.graphics.newImage(path.."/icon.png") or love.graphics.newImage("textures/nonexistant.png"),
			path = path.."/",
			name = name,
		}
		if love.filesystem.getInfo(path.."/config.lua") then 
			local f = loadstring(love.filesystem.read(path.."/config.lua"))
			setfenv(f,{})
			success,config = pcall(f)
			if type(config) == "table" then
				table.merge(pack,config)
			end
		end
		pack.defaultzoom = pack.defaultzoom or 4
		pack.zoomlevels = pack.zoomlevels or {2,4,10,20,40,80,160}
		pack.voidcolor = pack.voidcolor or {.125,.125,.125}
		pack.bgcolor = pack.bgcolor or {.375,.375,.375,.25}
		pack.textcolor = pack.textcolor or {1,1,1}
		pack.shadowdist = pack.shadowdist or 3/20
		pack.storagemult = pack.storagemult or 10/20
		pack.makermult = pack.makermult or 8/20
		pack.memorymult = pack.memorymult or 4/20
		texturepacks[name] = pack
		return true
	end
end

function SetPack(name)
	if not texturepacks[name] then name = "Default" end
	if texpath ~= texturepacks[name].path then
		local pack = texturepacks[name]
		defaultzoom = pack.defaultzoom
		zoomlevels = pack.zoomlevels
		cellsize = zoomlevels[defaultzoom]
		voidcolor = pack.voidcolor
		bgcolor = pack.bgcolor
		textcolor = pack.textcolor
		shadowdist = pack.shadowdist
		storagemult = pack.storagemult
		makermult = pack.makermult
		memorymult = pack.memorymult
		settings.texturepack = name
		texpath = pack.path 
		postloading = false
		MakeTextures()
		LoadDefaultParticles()
		love.graphics.setBackgroundColor(voidcolor)
	end
end

font = love.graphics.newFont("nokiafc22.ttf",8)
serifbold = love.graphics.newFont("7-12-serif-bold.ttf",16)
serif = love.graphics.newFont("7-12-serif.ttf",16)
font:setFallbacks(serifbold,serif)
love.graphics.setFont(font)

--cell info

cellinfo = {
	[0] = {name="Empty",					desc="Nothing."},
	[1] = {name="Wall",						desc="Unbreakable. This also implies being immovable."},
	[2] = {name="Mover",					desc="Constantly attempts to move forwards, pushing stuff in it's way."},
	[3] = {name="Generator",				desc="Clones the cell behind it and pushes it out the front."},
	[4] = {name="Pushable",					desc="Does nothing; Can be moved in any direction."},
	[5] = {name="Slider",					desc="Can only be moved towards the marked directions."},
	[6] = {name="One-Directional",			desc="Can only be moved towards the marked directions."},
	[7] = {name="Two-Directional",			desc="Can only be moved towards the marked directions."},
	[8] = {name="Three-Directional",		desc="Can only be moved towards the marked directions."},
	[9] = {name="CW Rotator",				desc="Rotates neighboring cells 90 degrees clockwise."},
	[10] = {name="CCW Rotator",				desc="Rotates neighboring cells 90 degrees counter-clockwise."},
	[11] = {name="180 Rotator",				desc="Rotates neighboring cells 180 degrees."},
	[12] = {name="Trash",					desc="Deletes all cells that go into it. Is unbreakable, but can be rotated."},
	[13] = {name="Enemy",					desc="When a cell touches it, it kills both itself and the cell that it collided with.\nEnemy-tagged by default, meaning it must be destroyed to complete a level."},
	[14] = {name="Puller",					desc="Moves forward and pulls cells. Can not push."},
	[15] = {name="Mirror",					desc="Swaps the two cells it's arrows point to. Swap force ignores divergers."},
	[16] = {name="Diverger",				desc="Diverts whatever comes into it through the arrow."},
	[17] = {name="Redirector",				desc="Sets the rotation of neighboring cells to it's own rotation. Cannot be affected by other Redirectors."},
	[18] = {name="CW Gear",					desc="Rotates surrounding cells around itself clockwise using swap force. Gets jammed by unbreakable cells and other Gears."},
	[19] = {name="CCW Gear",				desc="Rotates surrounding cells around itself counter-clockwise using swap force. Gets jammed by unbreakable cells and other Gears."},
	[20] = {name="Ungeneratable",			desc="When something tries to generate it, it will instead generate nothing but force."},
	[21] = {name="Repulsor",				desc="Applies a pushing force in 4 directions."},
	[22] = {name="Weight",					desc="Absorbs 1 unit of force."},
	[23] = {name="Cross Generator",			desc="Two generators combined."},
	[24] = {name="Strong Enemy",			desc="An enemy that takes two hits to kill."},
	[25] = {name="Freezer",					desc="Stops the cells adjacent to it from activating."},
	[26] = {name="CW Generator",			desc="Clockwise-bent Generator."},
	[27] = {name="CCW Generator",			desc="Counter-clockwise-bent Generator."},
	[28] = {name="Advancer",				desc="Puller + Mover."},
	[29] = {name="Impulsor",				desc="Pulls cells towards it in 4 directions."},
	[30] = {name="Flipper",					desc="Flips cells based on it's rotation; if it's horizontal, it flips horizontally, and vertically if it's orientated vertically."},
	[31] = {name="Bidiverger",				desc="Two Divergers combined."},
	[32] = {name="OR Gate",					desc="Conditional generator; generates when the condition\n(A or B) is true. Inputs are on it's sides."},
	[33] = {name="AND Gate",				desc="Conditional generator; generates when the condition\n(A and B) is true. Inputs are on it's sides."},
	[34] = {name="XOR Gate",				desc="Conditional generator; generates when the condition\n(A != B) is true. Inputs are on it's sides."},
	[35] = {name="NOR Gate",				desc="Conditional generator; generates when the condition\n(A or B) is false. Inputs are on it's sides."},
	[36] = {name="NAND Gate",				desc="Conditional generator; generates when the condition\n(A and B) is false. Inputs are on it's sides."},
	[37] = {name="XNOR Gate",				desc="Conditional generator; generates when the condition\n(A != B) is false. Inputs are on it's sides."},
	[38] = {name="Straight Diverger",		desc="Diverger with no bend."},
	[39] = {name="Cross Diverger",			desc="Two Straight divergers combined."},
	[40] = {name="Twist Generator",			desc="Flips the cell that it generates, across the same axis as the arrow."},
	[41] = {name="Ghost",					desc="Wall that can not be generated."},
	[42] = {name="Bias",					desc="Adds to any force going it's direction and subtracts from any force going against it."},
	[43] = {name="Shield",					desc="Prevents the cells surrounding it from colliding with enemies or being affected by dangerous forces like infection or transformation."},
	[44] = {name="Intaker",					desc="Pulls cells that are in front of it towards it. The front acts like a trash cell."},
	[45] = {name="Replicator",				desc="Clones the cell in front of it."},
	[46] = {name="Cross Replicator",		desc="Two Replicators combined."},
	[47] = {name="Fungal",					desc="When this cell is pushed, the cell that pushed it will be converted into another Fungal cell."},
	[48] = {name="Forker",					desc="Like a Diverger that clones the cell."},
	[49] = {name="Triforker",				desc="Forker with three outputs."},
	[50] = {name="Super Repulsor",			desc="Pushes cells across infinite distance with infinite force."},
	[51] = {name="Demolisher",				desc="Similar to a trash cell, but when a cell is pushed in, the demolisher destroys it's neighbors."},
	[52] = {name="Opposition",				desc="Can only be pushed, pulled, or grabbed towards certain directions, indicated by the arrows."},
	[53] = {name="Cross Opposition",		desc="Two Oppositions combined."},
	[54] = {name="Slider Opposition",		desc="Opposition that only restricts two sides, while the others are pushable."},
	[55] = {name="Super Generator",			desc="A Generator that generates the entire row of cells behind it."},
	[56] = {name="Cross Mirror",			desc="Two mirrors combined."},
	[57] = {name="Birotator",				desc="Rotates CW on one half and CCW on the other half."},
	[58] = {name="Driller",					desc="Attempts to swaps the cell in front of it with itself."},
	[59] = {name="Auger",					desc="Driller + Mover.\nAttempts to push before drilling."},
	[60] = {name="Corkscrew",				desc="Driller + Puller + Mover."},
	[61] = {name="Bringer",					desc="Driller + Puller."},
	[62] = {name="Outwards Redirector",		desc="Forces neighboring cells to face away from itself."},
	[63] = {name="Inwards Redirector",		desc="Forces neighboring cells to face towards itself."},
	[64] = {name="CW Redirector",			desc="Forces neighboring cells to face clockwise around itself."},
	[65] = {name="CCW Redirector",			desc="Forces neighboring cells to face counter-clockwise around itself."},
	[66] = {name="CW Semirotator",			desc="Only rotates on 2 faces."},
	[67] = {name="CCW Semirotator",			desc="Only rotates on 2 faces."},
	[68] = {name="180 Semirotator",			desc="Only rotates on 2 faces."},
	[69] = {name="Tough Slider",			desc="Acts like a wall on 2 sides and like a push on the other 2."},
	[70] = {name="Pararotator",				desc="Rotates CW on two sides and CCW on the other two sides."},
	[71] = {name="Grabber",					desc="Drags the cells to it's sides along with it."},
	[72] = {name="Heaver",					desc="Grabber + Mover."},
	[73] = {name="Lugger",					desc="Puller + Grabber."},
	[74] = {name="Hoister",					desc="Puller + Grabber + Mover."},
	[75] = {name="Raker",					desc="Driller + Grabber."},
	[76] = {name="Borer",					desc="Grabber + Mover + Driller."},
	[77] = {name="Carrier",					desc="Puller + Grabber + Driller."},
	[78] = {name="Omnipower",				desc="Puller + Grabber + Mover + Driller."},
	[79] = {name="Ice",						desc="Causes cells to slip past when they move near it."},
	[80] = {name="Tetramirror",				desc="4 mirrors combined."},
	[81] = {name="CW Grapulsor",			desc="Applies clockwise grabbing force to it's neighbors."},
	[82] = {name="CCW Grapulsor",			desc="Applies counter-clockwise grabbing force to it's neighbors."},
	[83] = {name="Bivalve Diverger",		desc="Valve Diverger with three inputs."},
	[84] = {name="CW Paravalve Diverger",	desc="Straight Diverger with two extra curved inputs."},
	[85] = {name="CCW Paravalve Diverger",	desc="Straight Diverger with two extra curved inputs."},
	[86] = {name="Bivalve Displacer",		desc="Bivalve Diverger that doesn't rotate cells."},
	[87] = {name="CW Paravalve Displacer",	desc="CW Paravalve Diverger that doesn't rotate cells."},
	[88] = {name="CCW Paravalve Displacer",	desc="CCW Paravalve Diverger that doesn't rotate cells."},
	[89] = {name="Semiflipper A",			desc="Only flips on 2 sides."},
	[90] = {name="Semiflipper B",			desc="Only flips on 2 sides."},
	[91] = {name="Displacer",				desc="Diverger that doesn't rotate cells."},
	[92] = {name="Bidisplacer",				desc="Bidiverger that doesn't rotate cells."},
	[93] = {name="CW Valve Diverger",		desc="One-way Diverger with two input faces."},
	[94] = {name="CCW Valve Diverger",		desc="One-way Diverger with two input faces."},
	[95] = {name="CW Valve Displacer",		desc="CW Valve Diverger that doesn't rotate cells."},
	[96] = {name="CCW Valve Displacer",		desc="CCW Valve Diverger that doesn't rotate cells."},
	[97] = {name="CW Forker",				desc="Forker with a straight and rotated output."},
	[98] = {name="CCW Forker",				desc="Forker with a straight and rotated output."},
	[99] = {name="Divider",					desc="Forker that doesn't rotate cells."},
	[100] = {name="Tridivider",				desc="Triforker that doesn't rotate cells."},
	[101] = {name="CW Divider",				desc="CW Forker that doesn't rotate cells."},
	[102] = {name="CCW Divider",			desc="CCW Forker that doesn't rotate cells."},
	[103] = {name="Conditional",			desc="The weight of this cell depends on it's rotation.\n(0-3, increases clockwise)"},
	[104] = {name="Anti-Weight",			desc="Adds 1 unit of force to applied forces."},
	[105] = {name="Transmitter",			desc="When rotated, flipped, or given an effect such as protection, it applies the effects to it's neighbors aswell."},
	[106] = {name="Shifter",				desc="Pulls cells in from the back and pushes them out the front."},
	[107] = {name="Cross Shifter",			desc="Two Shifters combined."},
	[108] = {name="CW Minigear",			desc="CW Gear that only affects 4 cells."},
	[109] = {name="CCW Minigear",			desc="CCW Gear that only affects 4 cells."},
	[110] = {name="CW Cloner",				desc="CW Generator that does not rotate the generated cell."},
	[111] = {name="CCW Cloner",				desc="CCW Generator that does not rotate the generated cell."},
	[112] = {name="Locker",					desc="Prevents the cells adjacent to it from being rotated or flipped."},
	[113] = {name="Redirect Generator",		desc="Generator that rotates the generated cell so it faces the same way as itself."},
	[114] = {name="Nudger",					desc="Moves forward, but does not push cells."},
	[115] = {name="Slicer",					desc="Moves forward; upon hitting a cell, it will attempt to push the cell out of the way in a direction perpendicular to it's own."},
	[116] = {name="Full Marker",			desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[117] = {name="X Marker",				desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[118] = {name="Warning Marker",			desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[119] = {name="Check Marker",			desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[120] = {name="Question Marker",		desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[121] = {name="Arrow Marker",			desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[122] = {name="Diagonal Arrow Marker",	desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[123] = {name="Crimson",				desc="Turns adjacent cells into Crimson cells."},
	[124] = {name="Warped",					desc="Turns diagonally adjacent cells into Warped cells."},
	[125] = {name="Corruption",				desc="Turns surrounding cells into Corruption cells."},
	[126] = {name="Hallow",					desc="Unbreakable. When a cell tries to push it, it turns into a another Hallow."},
	[127] = {name="Cancer",					desc="Similar to Crimson, but can spread onto air cells."},
	[128] = {name="Bacteria",				desc="Similar to Crimson, but can ONLY spread onto air cells."},
	[129] = {name="Bioweapon",				desc="Similar to Warped, but can spread onto air cells."},
	[130] = {name="Prion",					desc="Similar to Warped, but can ONLY spread onto air cells."},
	[131] = {name="Grey Goo",				desc="Similar to Corruption, but can spread onto air cells."},
	[132] = {name="Virus",					desc="Similar to Corruption, but can ONLY spread onto air cells."},
	[133] = {name="Tumor",					desc="Similar to Bacteria, but only spreads 50% of the time."},
	[134] = {name="Infection",				desc="Similar to Crimson, but only spreads 50% of the time."},
	[135] = {name="Pathogen",				desc="Similar to Cancer, but only spreads 50% of the time."},
	[136] = {name="Push Clamper",			desc="Prevents cells from being pushed."},
	[137] = {name="Pull Clamper",			desc="Prevents cells from being pulled."},
	[138] = {name="Grab Clamper",			desc="Prevents cells from being grabbed."},
	[139] = {name="Swap Clamper",			desc="Prevents cells from being swapped."},
	[140] = {name="Tough Two-Directional",	desc="Acts like a wall on 2 sides (+1 corner) and like a push on the other 2."},
	[141] = {name="Megademolisher",			desc="Similar to a Demolisher, but affects diagonal neighbors too."},
	[142] = {name="Resistance",				desc="Can only be pushed with exactly 1 unit of force."},
	[143] = {name="Tentative",				desc="Like Resistance, but the amount of force it needs is dependant on it's rotation.\n(1-4, increases clockwise)"},
	[144] = {name="Restrictor",				desc="Only allows 1 unit of force to pass through."},
	[145] = {name="Megashield",				desc="Like a Shield, but affects a 5x5 area."},
	[146] = {name="Timewarper",				desc="Reverts the space it's pointing at back to what it was in the initial state."},
	[147] = {name="Time Generator",			desc="Generates whatever the space behind it had in the initial state."},
	[148] = {name="Cross Timewarper",		desc="Two Timewarpers in one."},
	[149] = {name="Life",					desc="Spreads like Conway's Game of Life.\nInfects non-Life cells."},
	[150] = {name="CW Spinner",				desc="Unbreakable. When a cell touches it, it rotates the cell clockwise."},
	[151] = {name="CCW Spinner",			desc="Unbreakable. When a cell touches it, it rotates the cell counter-clockwise."},
	[152] = {name="180 Spinner",			desc="Unbreakable. When a cell touches it, it rotates the cell 180 degrees."},
	[153] = {name="Key",					desc="When it gets pushed into a Door cell, it destroys itself and the Door."},
	[154] = {name="Door",					desc="Unbreakable, but when a Key cell is pushed into it they destroy eachother."},
	[155] = {name="Cross Intaker",			desc="Two Intakers combined."},
	[156] = {name="Magnet",					desc="Magnets can attract or repel each other. Same colors repel, different colors attract."},
	[157] = {name="Tough One-Directional",	desc="Acts like a wall on 3 sides and like a push on one."},
	[158] = {name="Tough Three-Directional",desc="Acts like a wall on 1 side (+2 corners) and like a push on the other 3."},
	[159] = {name="Tough Pushable",			desc="Can't be affected by cells diagonally."},
	[160] = {name="Missile",				desc="Like a moving enemy, but it isn't enemy-tagged."},
	[161] = {name="Life Missile",			desc="Upon hitting something, it turns into a Life cell."},
	[162] = {name="Staller",				desc="Like a Wall, but upon collision, it will be destroyed."},
	[163] = {name="Bulk Enemy",				desc="Like an Enemy, but it will also stop force similar to a Wall.\nIn other words, a Staller that also destroys the attacking cell."},
	[164] = {name="Swivel Enemy",			desc="The HP of this enemy is measured by it's rotation.\n(1-4, increases clockwise)"},
	[165] = {name="Storage",				desc="If a cell moves into it, it will store the cell until another cell bumps it out."},
	[166] = {name="Memory Generator",		desc="Like a Generator, but once it sees a cell it will generate that cell infinitely until it sees another. Also updates before other Generators."},
	[167] = {name="Trigenerator",			desc="Generator that generates three cells at once."},
	[168] = {name="Bigenerator",			desc="Generator that generates two cells at once."},
	[169] = {name="CW Digenerator",			desc="Generator that generates two cells at once."},
	[170] = {name="CCW Digenerator",		desc="Generator that generates two cells at once."},
	[171] = {name="Tricloner",				desc="Trigenerator that doesn't rotate the generated cell."},
	[172] = {name="Bicloner",				desc="Bigenerator that doesn't rotate the generated cell."},
	[173] = {name="CW Dicloner",			desc="CW Digenerator that doesn't rotate the generated cell."},
	[174] = {name="CCW Dicloner",			desc="CCW Digenerator that doesn't rotate the generated cell."},
	[175] = {name="Transporter",			desc="Like a Storage cell, but once it holds a cell, it will act like a nudger, then release the cell when it hits a wall. The direction it releases it will be favored towards the rotation of the stored cell, but it will always be perpendicular to the Transporter's direction."},
	[176] = {name="Tainter",				desc="Like a Trash cell, but when it eats a cell it spreads in the direction that the cell came from."},
	[177] = {name="Super Replicator",		desc="Like a Replicator, but it replicates the entire row of cells in front of it."},
	[178] = {name="Scissor",				desc="Upon moving into a cell, it will attempt to split the cell in two and push it out it's sides."},
	[179] = {name="Triscissor",				desc="Scissor with three outputs."},
	[180] = {name="Multiplier",				desc="Scissor that doesn't rotate split cells."},
	[181] = {name="Trimultiplier",			desc="Triscissor that doesn't rotate split cells."},
	[182] = {name="CW Scissor",				desc="Scissor with a straight and curved output."},
	[183] = {name="CCW Scissor",			desc="Scissor with a straight and curved output."},
	[184] = {name="CW Multiplier",			desc="CW Scissor that doesn't rotate split cells."},
	[185] = {name="CCW Multiplier",			desc="CCW Scissor that doesn't rotate split cells."},
	[186] = {name="Spooner",				desc="Like a reversed Forker; if multiple cells go in, only one cell comes out."},
	[187] = {name="Trispooner",				desc="Spooner with three inputs."},
	[188] = {name="CW Spooner",				desc="Spooner with a straight and curved input."},
	[189] = {name="CCW Spooner",			desc="Spooner with a straight and curved input."},
	[190] = {name="Compounder",				desc="Spooner that doesn't rotate cells."},
	[191] = {name="Tricompounder",			desc="Trispooner that doesn't rotate cells."},
	[192] = {name="CW Compounder",			desc="CW Spooner that doesn't rotate cells."},
	[193] = {name="CCW Compounder",			desc="CCW Spooner that doesn't rotate cells."},
	[194] = {name="IMPLY Gate",				desc="Conditional generator; generates when the condition\n(!A or B) is true. Inputs are on it's sides."},
	[195] = {name="CON-IMPLY Gate",			desc="Conditional generator; generates when the condition\n(A or !B) is true. Inputs are on it's sides."},
	[196] = {name="NIMPLY Gate",			desc="Conditional generator; generates when the condition\n(!A or B) is false. Inputs are on it's sides."},
	[197] = {name="CON-NIMPLY Gate",		desc="Conditional generator; generates when the condition\n(A or !B) is false. Inputs are on it's sides."},
	[198] = {name="Converter",				desc="When a cell enters for the first time, the Converter stores the cell. The next time a cell enters, it will be converted into the stored cell."},
	[199] = {name="True Mover",				desc="Unbreakable Mover that cannot be stopped."},
	[200] = {name="True Puller",			desc="Unbreakable Puller that cannot be stopped."},
	[201] = {name="True Driller",			desc="Unbreakable Driller that cannot be stopped."},
	[202] = {name="True Mirror",			desc="Unbreakable Mirror that cannot be stopped."},
	[203] = {name="CW True Gear",			desc="Unbreakable CW Gear that cannot be stopped."},
	[204] = {name="CCW True Gear",			desc="Unbreakable CCW Gear that cannot be stopped."},
	[205] = {name="Phantom",				desc="Trash that cannot be generated. Additionally, it makes no noise."},
	[206] = {name="Lluea",					desc="A mover with AI. Turns when it hits a wall, can die and turn into it's non-living equivalent from overpopulation. They will also eat infectious cells, and reproduce or gain a force when doing so. If one goes 200 ticks without eating (100 if recently split), it will die."},
	[207] = {name="Bar",					desc="When pushed or pulled, it will attempt to grab the cells at it's sides."},
	[208] = {name="Diode Diverger",			desc="One-way Straight Diverger."},
	[209] = {name="Crossdiode Diverger",	desc="One-way Cross Divergers."},
	[210] = {name="Twist Diverger",			desc="Like a Straight Diverger, but it flips the cell that goes through it like a Twist Generator."},
	[211] = {name="Glunki",					desc="Creates trails to bring cells to itself and digest them, which takes 25 ticks each cell. If a Glunki is enveloped by the Protection effect or goes 250 ticks with no food, it dies and releases the cell. Glunki trails cannot go too far or control is lost."},
	[212] = {name="Glunki Trail",			desc="Glunki trail."},
	[213] = {name="Tough Mover",			desc="Mover but unbreakable from the sides."},
	[214] = {name="Spirit Pushable",		desc="Pushable that cannot be generated."},
	[215] = {name="Spirit Slider",			desc="Slider that cannot be generated."},
	[216] = {name="Spirit One-Directional",	desc="One-Directional that cannot be generated."},
	[217] = {name="Spirit Two-Directional",	desc="Two-Directional that cannot be generated."},
	[218] = {name="Spirit Three-Directional",desc="Three-Directional that cannot be generated."},
	[219] = {name="Super Acid",				desc="Acid with infinite HP."},
	[220] = {name="Acid",					desc="Acts like an Enemy, but it can only destroy a cell when it gets pushed into one. Acids cannot destroy eachother."},
	[221] = {name="Portal",					desc="Portal. Has an ID and a Target ID. Anything that goes in a portal will come out a portal with the same ID as the entrance portal's Target ID."},
	[222] = {name="Time Repulsor",			desc="Repulses cells some ticks after they get near it. Cannot stack multiple times in the same direction."},
	[223] = {name="Coin",					desc="Adds 1 to a cell's coin count."},
	[224] = {name="Coin Diverger",			desc="Acts like a Cross Diverger to cells with enough coins, acts like a Wall otherwise. Also subtracts that amount of coins from the cell when they pass through."},
	[225] = {name="Tough Trash",			desc="Acts like a Trash on two sides and a Wall on the others."},
	[226] = {name="Semitrash",				desc="Acts like a Trash on two sides and a Pushable on the others."},
	[227] = {name="Conveyor Grapulsor",		desc="Grapulsor but... well, the arrows explain it."},
	[228] = {name="Cross Conveyor Grapulsor",desc="Two conveyor grapulsors in one."},
	[229] = {name="Constructor",			desc="An unbreakable Builder."},
	[230] = {name="Coin Extractor",			desc="Extracts coins from cells."},
	[231] = {name="Silicon",				desc="Sticks to other silicon cells.\n(Note that stickiness doesn't work perfectly with pulling and grabbing...)"},
	[232] = {name="Gravitizer",				desc="Causes cells near it to start falling in the direction it's pointing in."},
	[233] = {name="Filter Diverger",		desc="Like a Straight Diverger, but insert a cell on the top or bottom, and it will delete any cell with the same ID."},
	[234] = {name="Realistic Fire",			desc="Spreads randomly onto nearby cells, floats around randomly, and dies after a random amount of time. Just fun to watch."},
	[235] = {name="Creator",				desc="Like an unbreakable Tetramaker."},
	[236] = {name="Particle",				desc="Basic particle. Stores momentum, but has no other traits."},
	[237] = {name="Transformer",			desc="Transforms the cell in front of it into the cell behind it."},
	[238] = {name="Cross Transformer",		desc="Two Transformers combined."},
	[239] = {name="Player",					desc="When unpaused, controlled with the arrow keys or WASD.\nAdditionally, is Player-tagged, meaning if there was at least one player at the start, and then all are destroyed, the level is failed, unless all Enemies are defeated at the same time."},
	[240] = {name="Fire",					desc="Spreads onto adjacent cells and dies after a tick."},
	[241] = {name="Megafire",				desc="Like fire, but affects diagonal neighbors too."},
	[242] = {name="Fireball",				desc="Moving Fire."},
	[243] = {name="Megafireball",			desc="Moving Megafire."},
	[244] = {name="Super Enemy",			desc="Enemy with infinite health; effectively a trash cell that can't delete protected cells."},
	[245] = {name="CW Megarotator",			desc="CW Rotator that affects diagonal neighbors too."},
	[246] = {name="CCW Megarotator",		desc="CCW Rotator that affects diagonal neighbors too."},
	[247] = {name="180 Megarotator",		desc="180 Rotator that affects diagonal neighbors too."},
	[248] = {name="Super Impulsor",			desc="Pulls cells towards it from infinite distance with infinite force."},
	[249] = {name="Semisilicon",			desc="Only acts like a silicon on 2 sides."},
	[250] = {name="Biintaker",				desc="Two combined opposite-sided Intakers."},
	[251] = {name="Tetraintaker",			desc="Intaker in all four directions."},
	[252] = {name="Slime",					desc="Causes nearby cells to stick to each other like Silicon.\nNote: Stuck forcers or movers might have trouble propertly exerting force."},
	[253] = {name="Scissor Clamper",		desc="Prevents cells from being scissored."},
	[254] = {name="CW Shifter",				desc="Clockwise-bent Shifter."},
	[255] = {name="CCW Shifter",			desc="Counter-clockwise-bent Shifter."},
	[256] = {name="Bishifter",				desc="Shifter that outputs two cells at once."},
	[257] = {name="Trishifter",				desc="Shifter that outputs three cells at once."},
	[258] = {name="CCW Dishifter",			desc="Shifter that outputs two cells at once."},
	[259] = {name="CW Dishifter",			desc="Shifter that outputs two cells at once."},
	[260] = {name="CW Relocator",			desc="CCW Shifter that does not rotate the outputted cell."},
	[261] = {name="CCW Relocator",			desc="CW Shifter that does not rotate the outputted cell."},
	[262] = {name="Birelocator",			desc="Bishifter that doesn't rotate the outputted cell."},
	[263] = {name="Trirelocator",			desc="Trishifter that doesn't rotate the outputted cell."},
	[264] = {name="CCW Direlocator",		desc="CW Dishifter that doesn't rotate the outputted cell."},
	[265] = {name="CW Direlocator",			desc="CCW Dishifter that doesn't rotate the outputted cell."},
	[266] = {name="Degravitizer",			desc="Un-gravitizes cells."},
	[267] = {name="Transmutator",			desc="Like a Transformer combined with a Shifter."},
	[268] = {name="Cross Transmutator",		desc="Two Transmutators combined."},
	[269] = {name="Crasher",				desc="Mover + Slicer.\nAttempts to push before slicing."},
	[270] = {name="Tugger",					desc="Puller + Slicer."},
	[271] = {name="Yanker",					desc="Puller + Mover + Slicer."},
	[272] = {name="Lifter",					desc="Grabber + Slicer."},
	[273] = {name="Hauler",					desc="Grabber + Mover + Slicer."},
	[274] = {name="Dragger",				desc="Puller + Grabber + Slicer."},
	[275] = {name="Mincer",					desc="Puller + Grabber + Mover + Slicer."},
	[276] = {name="Cutter",					desc="Driller + Slicer.\nAttempts to slice before drilling."},
	[277] = {name="Screwdriver",			desc="Driller + Mover + Slicer.\nAttempts to push, then slice, then drill."},
	[278] = {name="Piecer",					desc="Driller + Puller + Slicer."},
	[279] = {name="Slasher",				desc="Driller + Puller + Mover + Slicer."},
	[280] = {name="Chiseler",				desc="Driller + Grabber + Slicer."},
	[281] = {name="Lacerator",				desc="Driller + Grabber + Mover + Slicer."},
	[282] = {name="Carver",					desc="Driller + Puller + Grabber + Slicer."},
	[283] = {name="Apeiropower",			desc="Driller + Puller + Grabber + Mover + Slicer."},
	[284] = {name="Super Mover",			desc="A mover with infinite force that moves infinitely fast."},
	[285] = {name="Thawer",					desc="Prevents cells from being frozen."},
	[286] = {name="Megafreezer",			desc="Freezes diagonal neighbors as well."},
	[287] = {name="Semifreezer",			desc="Only freezes 2 neighbors."},
	[288] = {name="Fragile Player",			desc="A player that can be crashed into like an enemy. Can't crash itself into cells."},
	[289] = {name="Puller Player",			desc="A player that pulls."},
	[290] = {name="Grabber Player",			desc="A player that grabs."},
	[291] = {name="Driller Player",			desc="A player that drills."},
	[292] = {name="Nudger Player",			desc="A player that cannot push."},
	[293] = {name="Fragile Puller Player",	desc="A player that pulls and can be crashed into like an enemy."},
	[294] = {name="Fragile Grabber Player",	desc="A player that grabs and can be crashed into like an enemy."},
	[295] = {name="Fragile Driller Player",	desc="A player that drills and can be crashed into like an enemy."},
	[296] = {name="Fragile Nudger Player",	desc="A player that cannot push and can be crashed into like an enemy."},
	[297] = {name="Slicer Player",			desc="A player that slices."},
	[298] = {name="Fragile Slicer Player",	desc="A player that slices and can be crashed into like an enemy."},
	[299] = {name="Quantum Enemy",			desc="When killed, all Quantum Enemies or cells that are quantum-entangled to the same ID are destroyed as well."},
	[300] = {name="Trash Diode Diverger",	desc="Diode Diverger that acts like a Trash cell on the front."},
	[301] = {name="Broken Generator",		desc="Generator that can only be used once; destroyed after usage."},
	[302] = {name="Broken Replicator",		desc="Replicator that can only be used once; destroyed after usage."},
	[303] = {name="Remover",				desc="Mover that tries to delete the cell in front of it if it cannot move. Cannot delete protected cells."},
	[304] = {name="Broken Mover",			desc="Mover that dies once it pushes a cell."},
	[305] = {name="Broken Puller",			desc="Puller that dies once it pulls a cell."},
	[306] = {name="CW Termite",				desc="Attempts to move around walls."},
	[307] = {name="CCW Termite",			desc="Attempts to move around walls."},
	[308] = {name="Minishield",				desc="Like a Shield, but only affects adjacent neighbors."},
	[309] = {name="Microshield",			desc="Only protects itself."},
	[310] = {name="Immobilizer",			desc="Applies the effect of all Clampers."},
	[311] = {name="Inclusive Advancer",		desc="Only moves if it can both push and pull."},
	[312] = {name="Balloon",				desc="If pushed against a wall, it will be destroyed."},
	[313] = {name="Super Mirror",			desc="Swaps an entire row of cells."},
	[314] = {name="Cross Super Mirror",		desc="Two Super Mirrors combined."},
	[315] = {name="Diagonal Mirror",		desc="Diagonal Mirror."},
	[316] = {name="Cross Diagonal Mirror",	desc="Two Diagonal Mirrors combined."},
	[317] = {name="Triintaker",				desc="Three Intakers combined."},
	[318] = {name="Sentry",					desc="Aims towards Players and fires Missiles. Can also be destroyed like an Enemy."},
	[319] = {name="Seeker",					desc="Like a Missile, but it attempts to move toward a Player if they can see one orthogonally. Also tries to turn if it would crash otherwise into a wall."},
	[320] = {name="Turret",					desc="Sentry that fires Seekers."},
	[321] = {name="Decoy",					desc="Tricks Sentries, Turrets, and Seekers into thinking it's a Player."},
	[322] = {name="CW Cog",					desc="CW Gear that does not rotate cells."},
	[323] = {name="CCW Cog",				desc="CCW Gear that does not rotate cells."},
	[324] = {name="CW Minicog",				desc="CW Minigear that does not rotate cells."},
	[325] = {name="CCW Minicog",			desc="CCW Minigear that does not rotate cells."},
	[326] = {name="Junk",					desc="Pushable that is enemy-tagged by default."},
	[327] = {name="Builder",				desc="Generator that generates whenever it is pushed from behind.\nAlso, these are literally the most dangerous cells in the game, do NOT put two of them near eachother your game WILL die"},
	[328] = {name="Cross Builder",			desc="Two Builders combined."},
	[329] = {name="CW Builder",				desc="CW bent Builder."},
	[330] = {name="CCW Builder",			desc="CCW bent Builder."},
	[331] = {name="Bibuilder",				desc="Builder with two outputs."},
	[332] = {name="Tribuilder",				desc="Builder with three outputs."},
	[333] = {name="CW Dibuilder",			desc="Builder with a straight and curved output."},
	[334] = {name="CCW Dibuilder",			desc="Builder with a straight and curved output."},
	[335] = {name="CW Smith",				desc="CW Builder that does not rotate cells."},
	[336] = {name="CCW Smith",				desc="CCW Builder that does not rotate cells."},
	[337] = {name="Bismith",				desc="Bibuilder that does not rotate cells."},
	[338] = {name="Trismith",				desc="Tribuilder that does not rotate cells."},
	[339] = {name="CW Dismith",				desc="CW Dibuilder that does not rotate cells."},
	[340] = {name="CCW Dismith",			desc="CCW Dibuilder that does not rotate cells."},
	[341] = {name="Memory Replicator",		desc="Replicator equivalent of Memory Generator."},
	[342] = {name="Physical Generator",		desc="When blocked from generating a cell, it will attempt to move backwards to generate it."},
	[343] = {name="Physical Replicator",	desc="When blocked from replicating a cell, it will attempt to move backwards to replicate it."},
	[344] = {name="CW Chainsaw",			desc="Creates a deadly chainsaw blade and spins around clockwise."},
	[345] = {name="CCW Chainsaw",			desc="Creates a deadly chainsaw blade and spins around counter-clockwise."},
	[346] = {name="Repulse Mover",			desc="Pushes the cells at it's sides and moves forward."},
	[347] = {name="Jump Trash",				desc="When it eats a cell, it jumps away from the direction the cell was eaten in."},
	[348] = {name="Squish Trash",			desc="Only acts like a trash cell if it gets squished against a wall."},
	[349] = {name="Jump Phantom",			desc="Phantom + Jump Trash."},
	[350] = {name="Squish Phantom",			desc="Phantom + Squish Trash."},
	[351] = {name="Omnicell",				desc="You can edit the sides and HP of this cell!"},
	[352] = {name="Adjustable Mover",		desc="The speed, delay, and maximum moved cells of this Mover can be changed!\n(Time is ticks since last movement)"},
	[353] = {name="Adjustable Puller",		desc="The speed, delay, and maximum moved cells of this Puller can be changed!\n(Time is ticks since last movement)"},
	[354] = {name="Adjustable Grabber",		desc="The speed, delay, and maximum moved cells of this Grabber can be changed!\n(Time is ticks since last movement)"},
	[355] = {name="Adjustable Driller",		desc="The speed and delay of this Driller can be changed!\n(Time is ticks since last movement)"},
	[356] = {name="Adjustable Slicer",		desc="The speed and delay of this Slicer can be changed!\n(Time is ticks since last movement)"},
	[357] = {name="Adjustable Nudger",		desc="The speed and delay of this Nudger can be changed!\n(Time is ticks since last movement)"},
	[358] = {name="Strong Missile",			desc="Like a moving Strong Enemy."},
	[359] = {name="Super Missile",			desc="Like a moving Super Enemy."},
	[360] = {name="Explosive Enemy",		desc="An enemy that kills the cells near it like a Demolisher when it dies."},
	[361] = {name="Mega-Explosive Enemy",	desc="An enemy that kills 8 cells around it like a Megademolisher when it dies."},
	[362] = {name="Collider",				desc="Like a Storage cell, but once it holds a cell, it will act like a nudger, then once it hits a wall, it will transform into the cell inside it."},
	[363] = {name="Paragenerator",			desc="Two opposing Generators combined."},
	[364] = {name="Tetragenerator",			desc="Four Generators in one."},
	[365] = {name="Strong Generator",		desc="Generator that pushes with infinite force."},
	[366] = {name="Weak Generator",			desc="Generator that cannot push."},
	[367] = {name="Explosive Missile",		desc="Missile that explodes like an Explosive Enemy."},
	[368] = {name="Mega-Explosive Missile",	desc="Missile that explodes like a Mega-Explosive Enemy."},
	[369] = {name="Vine",					desc="Spreads around cells in a CW fashion."},
	[370] = {name="Dead Vine",				desc="Dead Vine."},
	[371] = {name="Delta",					desc="Spreads onto cells in a CW fashion."},
	[372] = {name="Dead Delta",				desc="Dead Delta."},
	[373] = {name="Toxic",					desc="Spreads onto cells and air in a CW fashion."},
	[374] = {name="Dead Toxic",				desc="Dead Toxic."},
	[375] = {name="Chorus",					desc="Spreads around cells in a CCW fashion."},
	[376] = {name="Dead Chorus",			desc="Dead Chorus."},
	[377] = {name="Gamma",					desc="Spreads onto cells in a CCW fashion."},
	[378] = {name="Dead Gamma",				desc="Dead Gamma."},
	[379] = {name="Poison",					desc="Spreads onto cells and air in a CCW fashion."},
	[380] = {name="Dead Poison",			desc="Dead Poison."},
	[381] = {name="Slope",					desc="Like a Displacer, but doesn't rotate the direction of the force. Look, it's hard to explain, just play around with it."},
	[382] = {name="CW Slope",				desc="Always slopes clockwise."},
	[383] = {name="CCW Slope",				desc="Always slopes counter-clockwise."},
	[384] = {name="Parabole",				desc="When pushed it will divert the force to the side but will also be pushed itself."},
	[385] = {name="Biparabole",				desc="Two Paraboles."},
	[386] = {name="Arc",					desc="Parabole that doesn't rotate."},
	[387] = {name="Biarc",					desc="Biparabole that doesn't rotate."},
	[388] = {name="CW Tetraparabole",		desc="Parabole that always goes clockwise."},
	[389] = {name="CCW Tetraparabole",		desc="Parabole that always goes counter-clockwise."},
	[390] = {name="Stair",					desc="Basically a slower Slope."},
	[391] = {name="CW Stair",				desc="Always stairs clockwise."},
	[392] = {name="CCW Stair",				desc="Always stairs counter-clockwise."},
	[393] = {name="Backgenerator",			desc="Acts like a Physical Generator that is always blocked."},
	[394] = {name="Backreplicator",			desc="Acts like a Physical Replicator that is always blocked."},
	[395] = {name="Physical Backgenerator",	desc="If blocked from going backwards, it acts like a Generator."},
	[396] = {name="Physical Backreplicator",desc="If blocked from going backwards, it acts like a Replicator."},
	[397] = {name="Bireplicator",			desc="Two-sided Replicator."},
	[398] = {name="Trireplicator",			desc="Three-sided Replicator."},
	[399] = {name="Tetrareplicator",		desc="Four-sided Replicator."},
	[400] = {name="Shover",					desc="Grabbed cells will push instead of nudge."},
	[401] = {name="Inversion",				desc="Inverts whatever happens to it."},
	[402] = {name="Spring",					desc="Can be compressed into other Spring cells. When the force compressing them is removed, it will uncompress violently."},
	[403] = {name="Crystal",				desc="Swaps the cells 1 space away and 2 spaces away."},
	[404] = {name="Semicrystal",			desc="2-opposite-sided Crystal."},
	[405] = {name="Quasicrystal",			desc="1-sided Crystal."},
	[406] = {name="Hemicrystal",			desc="2-sided Crystal."},
	[407] = {name="Henacrystal",			desc="3-sided Crystal."},
	[408] = {name="Semirepulsor",			desc="2-opposite-sided Repulsor."},
	[409] = {name="Quasirepulsor",			desc="1-sided Repulsor."},
	[410] = {name="Hemirepulsor",			desc="2-sided Repulsor."},
	[411] = {name="Henarepulsor",			desc="3-sided Repulsor."},
	[412] = {name="Recursor",				desc="At recursion 0, it generates Pushables. At any higher level, it generates itself with a lower recursion."},
	[413] = {name="Semiimpulsor",			desc="2-opposite-sided Impulsor."},
	[414] = {name="Quasiimpulsor",			desc="1-sided Impulsor."},
	[415] = {name="Hemiimpulsor",			desc="2-sided Impulsor."},
	[416] = {name="Henaimpulsor",			desc="3-sided Impulsor."},
	[417] = {name="Fan",					desc="A Repulsor with a range of 2 cells."},
	[418] = {name="Semifan",				desc="2-opposite-sided Fan."},
	[419] = {name="Quasifan",				desc="1-sided Fan."},
	[420] = {name="Hemifan",				desc="2-sided Fan."},
	[421] = {name="Henafan",				desc="3-sided Fan."},
	[422] = {name="Lockpick",				desc="Can only push Pushables in directions that would otherwise stop them."},
	[423] = {name="Super Alkali",			desc="Acts like a moving Super Acid."},
	[424] = {name="Graviton",				desc="Nudger, but when it hits a cell it will gravitize it and disappear."},
	[425] = {name="Tetramidas",				desc="4-sided Midas."},
	[426] = {name="Directional Tetramidas",	desc="Tetramidas that rotates the output depending on the transformation direction."},
	[427] = {name="Directional Creator",	desc="Like an unbreakable Directional Tetramaker."},
	[428] = {name="Wrap",					desc="Wraps around to the nearest Wrap cell in the opposite direction that something enters in."},
	[429] = {name="CW Tetradiverger",		desc="Diverts clockwise."},
	[430] = {name="CCW Tetradiverger",		desc="Diverts counter-clockwise."},
	[431] = {name="CW Tetradisplacer",		desc="Diverts clockwise without rotating."},
	[432] = {name="CCW Tetradisplacer",		desc="Diverts counter-clockwise without rotating."},
	[433] = {name="Divalve Diverger",		desc="Valve Diverger with two opposing inputs."},
	[434] = {name="Divalve Displacer",		desc="Divalve Diverger that doesn't rotate cells."},
	[435] = {name="Super Fan",				desc="Super Repulsor with infinite range."},
	[436] = {name="Dumpster",				desc="Deletes unprotected cells across a certain axis."},
	[437] = {name="Cross Dumpster",			desc="Two Dumpsters combined."},
	[438] = {name="Dodge Trash",			desc="When it eats a cell, it moves leftwards from the direction the cell was eaten from."},
	[439] = {name="Dodge Phantom",			desc="Phantom + Dodge Trash."},
	[440] = {name="Evade Trash",			desc="Dodge Trash that moves right instead of left."},
	[441] = {name="Evade Phantom",			desc="Phantom + Evade Trash."},
	[442] = {name="CW Super Rotator",		desc="Rotates an entire structure."},
	[443] = {name="CCW Super Rotator",		desc="Rotates an entire structure."},
	[444] = {name="180 Super Rotator",		desc="Rotates an entire structure."},
	[445] = {name="Reflector",				desc="Mirror that flips."},
	[446] = {name="Cross Reflector",		desc="Two Reflectors combined."},
	[447] = {name="Anchor",					desc="When rotated, it rotates everything it's connected to around itself like a gear."},
	[448] = {name="Hyper Generator",		desc="Generates an entire structure."},
	[449] = {name="180 Gear",				desc="Rotates surrounding cells all the way around."},
	[450] = {name="180 Minigear",			desc="Rotates neighboring cells all the way around."},
	[451] = {name="180 Cog",				desc="180 Gear that doesn't rotate cells."},
	[452] = {name="180 Minicog",			desc="180 Minigear that doesn't rotate cells."},
	[453] = {name="Friendly Sentry",		desc="Sentry that targets Enemies."},
	[454] = {name="Friendly Seeker",		desc="Seeker that targets Enemies."},
	[455] = {name="Friendly Turret",		desc="Turret that targets Enemies and shoots Friendly Seekers."},
	[456] = {name="Friendly Missile",		desc="Missile that is not targetted by friendlies."},
	[457] = {name="Cross Super Generator",	desc="Two Super Generators."},
	[458] = {name="CW Super Generator",		desc="CW-Bent Super Generator."},
	[459] = {name="CCW Super Generator",	desc="CCW-Bent Super Generator."},
	[460] = {name="CW Super Cloner",		desc="CW Super Generator that doesn't rotate cells."},
	[461] = {name="CCW Super Cloner",		desc="CCW Super Generator that doesn't rotate cells."},
	[462] = {name="Pin",					desc="Anchor that doesn't rotate cells."},
	[463] = {name="Directional Trash",		desc="Moves in the direction it's facing when it eats a cell."},
	[464] = {name="Pull Extension",			desc="When moved by some force, it will attempt to \"extend\" that force with it's own."},
	[465] = {name="Sapper",					desc="Destroys Sentries and Turrets in a 3x3 area."},
	[466] = {name="Push Extension",			desc="When moved by some force, it will attempt to \"extend\" that force with it's own."},
	[467] = {name="Megasapper",				desc="Destroys Sentries and Turrets in a 5x5 area."},
	[468] = {name="Minisapper",				desc="Destroys neighboring Sentries and Turrets."},
	[469] = {name="CW Fast Gear",			desc="90 degree CW Gear."},
	[470] = {name="CCW Fast Gear",			desc="90 degree CCW Gear."},
	[471] = {name="CW Fast Cog",			desc="90 degree CW Cog."},
	[472] = {name="CCW Fast Cog",			desc="90 degree CCW Cog."},
	[473] = {name="CW Faster Gear",			desc="135 degree CW Gear."},
	[474] = {name="CCW Faster Gear",		desc="135 degree CCW Gear."},
	[475] = {name="CW Faster Cog",			desc="135 degree CW Cog."},
	[476] = {name="CCW Faster Cog",			desc="135 degree CCW Cog."},
	[477] = {name="Grab Extension",			desc="When moved by some force, it will attempt to \"extend\" that force with it's own."},
	[478] = {name="Megamirror",				desc="A mirror that swaps 3 rows."},
	[479] = {name="Megareflector",			desc="A reflector that swaps and flips 3 rows."},
	[480] = {name="Super Reflector",		desc="Swaps and flips an entire row of cells."},
	[481] = {name="Cross Super Reflector",	desc="Two Super Reflectors combined."},
	[482] = {name="CW Skewgear",			desc="Diagonal-affecting Gear."},
	[483] = {name="CCW Skewgear",			desc="Diagonal-affecting Gear."},
	[484] = {name="180 Skewgear",			desc="Diagonal-affecting Gear."},
	[485] = {name="CW Skewcog",				desc="Diagonal-affecting Cog."},
	[486] = {name="CCW Skewcog",			desc="Diagonal-affecting Cog."},
	[487] = {name="180 Skewcog",			desc="Diagonal-affecting Cog."},
	[488] = {name="Rotator Diverger",		desc="Rotates or flips cells that pass through it."},
	[489] = {name="Bimirror",				desc="Mirror + Diagonal Mirror."},
	[490] = {name="Dimirror",				desc="Mirror + Diagonal Mirror."},
	[491] = {name="Trimirror",				desc="Mirror + 2 Diagonal Mirrors."},
	[492] = {name="Termirror",				desc="2 Mirrors + Diagonal Mirror."},
	[493] = {name="Amethyst",				desc="Swaps the cells at a 1/2 slope away from it."},
	[494] = {name="Semiamethyst",			desc="2-sided Amethyst."},
	[495] = {name="Quasiamethyst",			desc="1-sided Amethyst."},
	[496] = {name="Hemiamethyst",			desc="2-sided Amethyst."},
	[497] = {name="Henaamethyst",			desc="3-sided Amethyst."},
	[498] = {name="Diagonal Crystal",		desc="Diagonal crystal."},
	[499] = {name="Diagonal Semicrystal",	desc="2-sided Diagonal Crystal."},
	[500] = {name="Confetti",				desc="Moves like confetti. #505050sorta.#x"},
	[501] = {name="Diagonal Quasicrystal",	desc="1-sided Diagonal Crystal."},
	[502] = {name="Diagonal Hemicrystal",	desc="2-sided Diagonal Crystal."},
	[503] = {name="Diagonal Henacrystal",	desc="3-sided Diagonal Crystal."},
	[504] = {name="Bicrystal",				desc="Crystal + Diagonal Crystal."},
	[505] = {name="CW Transformer",			desc="Bent Transformer."},
	[506] = {name="CCW Transformer",		desc="Bent Transformer."},
	[507] = {name="CW Transfigurer",		desc="Non-rotating bent Transformer."},
	[508] = {name="CCW Transfigurer",		desc="Non-rotating bent Transformer."},
	[509] = {name="CW Transmutator",		desc="Bent Transmutator."},
	[510] = {name="CCW Transmutator",		desc="Bent Transmutator."},
	[511] = {name="CW Transmogrifier",		desc="Non-rotating bent Transmutator."},
	[512] = {name="CCW Transmogrifier",		desc="Non-rotating bent Transmutator."},
	[513] = {name="Cross Super Replicator",	desc="2 Super Replicators."},
	[514] = {name="Super Bireplicator",		desc="2 opposite-sided Super Replicators."},
	[515] = {name="Super Trireplicator",	desc="3 Super Replicators."},
	[516] = {name="Super Tetrareplicator",	desc="4 Super Replicators."},
	[517] = {name="Super Intaker",			desc="Intaker that sucks in an entire row."},
	[518] = {name="Cross Super Intaker",	desc="2 Super Intakers."},
	[519] = {name="Super Biintaker",		desc="2 opposite-sided Super Intakers."},
	[520] = {name="Super Triintaker",		desc="3 Super Intakers."},
	[521] = {name="Super Tetraintaker",		desc="4 Super Intakers."},
	[522] = {name="CW Perpetual Rotator",	desc="Makes cells rotate CW forever."},
	[523] = {name="CCW Perpetual Rotator",	desc="Makes cells rotate CCW forever."},
	[524] = {name="180 Perpetual Rotator",	desc="Makes cells rotate 180 degrees forever."},
	[525] = {name="Perpetual Rotator Stopper",desc="Stops perpetual rotation."},
	[526] = {name="Maker",					desc="Creates cells of any type.\n(Click to insert cell)"},
	[527] = {name="Cross Maker",			desc="2 Makers."},
	[528] = {name="Bimaker",				desc="2 opposite-sided Makers."},
	[529] = {name="Trimaker",				desc="3 Makers."},
	[530] = {name="Tetramaker",				desc="4 Makers."},
	[531] = {name="Directional Cross Maker",desc="2 Makers that rotate the generated cell depending on direction."},
	[532] = {name="Directional Bimaker",	desc="2 opposite-sided Makers that rotate the generated cell depending on direction."},
	[533] = {name="Directional Trimaker",	desc="3 Makers that rotate the generated cell depending on direction."},
	[534] = {name="Directional Tetramaker",	desc="4 Makers that rotate the generated cell depending on direction."},
	[535] = {name="Perpetual Flipper",		desc="Makes cells flip forever."},
	[536] = {name="Bitransformer",			desc="Transformer with 2 outputs."},
	[537] = {name="Tritransformer",			desc="Transformer with 3 outputs."},
	[538] = {name="CW Ditransformer",		desc="Transformer with 2 outputs."},
	[539] = {name="CCW Ditransformer",		desc="Transformer with 2 outputs."},
	[540] = {name="Bitransfigurer",			desc="Bitransformer that doesn't rotate."},
	[541] = {name="Tritransfigurer",		desc="Tritransformer that doesn't rotate."},
	[542] = {name="CW Ditransfigurer",		desc="CW Ditransformer that doesn't rotate."},
	[543] = {name="CCW Ditransfigurer",		desc="CW Ditransformer that doesn't rotate."},
	[544] = {name="Bitransmutator",			desc="Transmutator with 2 outputs."},
	[545] = {name="Tritransmutator",		desc="Transmutator with 3 outputs."},
	[546] = {name="CW Ditransmutator",		desc="Transmutator with 2 outputs."},
	[547] = {name="CCW Ditransmutator",		desc="Transmutator with 2 outputs."},
	[548] = {name="Bitransmogrifier",		desc="Bitransmutator that doesn't rotate."},
	[549] = {name="Tritransmogrifier",		desc="Tritransmutator that doesn't rotate."},
	[550] = {name="CW Ditransmogrifier",	desc="CW Ditransmutator that doesn't rotate."},
	[551] = {name="CCW Ditransmogrifier",	desc="CW Ditransmutator that doesn't rotate."},
	[552] = {name="Apeirocell",				desc="Omnicell but even more insane"},
	[553] = {name="One-way Wall",			desc="A one-way Wall."},
	[554] = {name="Cross-way Wall",			desc="Two one-way Walls."},
	[555] = {name="Bi-way Wall",			desc="Two opposing one-way Walls."},
	[556] = {name="Tri-way Wall",			desc="Three one-way Walls."},
	[557] = {name="Tetra-way Wall",			desc="Four one-way Walls."},
	[558] = {name="One-way Trash",			desc="A one-way Trash."},
	[559] = {name="Cross-way Trash",		desc="Two one-way Trashes."},
	[560] = {name="Bi-way Trash",			desc="Two opposing one-way Trashes."},
	[561] = {name="Tri-way Trash",			desc="Three one-way Trashes."},
	[562] = {name="Tetra-way Trash",		desc="Four one-way Trashes."},
	[563] = {name="Switch",					desc="Toggles a switch ID when a cell enters it."},
	[564] = {name="Switch Door",			desc="Turns non-solid when it's switch ID is on."},
	[565] = {name="Switch Gate",			desc="Turns solid when it's switch ID is on."},
	[566] = {name="Regenerative Staller",	desc="Staller that can regenerate."},
	[567] = {name="Custom Life",			desc="Customizable Life."},
	[568] = {name="Dead Custom Life",		desc="Dead Customizable Life."},
	[569] = {name="Orientator",				desc="Sets the rotation of the cell in front of it to the rotation of the cell behind it. #505050no one will ever use these#x"},
	[570] = {name="Cross Orientator",		desc="Two Orientators combined."},
	[571] = {name="CW Orientator",			desc="CW bent Orientator."},
	[572] = {name="CCW Orientator",			desc="CCW bent Orientator."},
	[573] = {name="Biorientator",			desc="Orientator with two outputs."},
	[574] = {name="Triorientator",			desc="Orientator with three outputs."},
	[575] = {name="CW Diorientator",		desc="Orientator with a straight and curved output."},
	[576] = {name="CCW Diorientator",		desc="Orientator with a straight and curved output."},
	[577] = {name="CW Aligner",				desc="CW Orientator that does not rotate cells."},
	[578] = {name="CCW Aligner",			desc="CCW Orientator that does not rotate cells."},
	[579] = {name="Bialigner",				desc="Biorientator that does not rotate cells."},
	[580] = {name="Trialigner",				desc="Triorientator that does not rotate cells."},
	[581] = {name="CW Dialigner",			desc="CW Diorientator that does not rotate cells."},
	[582] = {name="CCW Dialigner",			desc="CCW Diorientator that does not rotate cells."},
	[583] = {name="Wireless Transmitter",	desc="Transmits to all other Wireless Transmitters with the same ID."},
	[584] = {name="Super Key",				desc="Key that doesn't disappear upon usage."},
	[585] = {name="CW Turner",				desc="Turns cells that push it clockwise."},
	[586] = {name="CCW Turner",				desc="Turns cells that push it counter-clockwise."},
	[587] = {name="180 Turner",				desc="Turns cells that push it 180."},
	[588] = {name="Rotatable Gravitizer",	desc="Gravity will rotate when the cell is rotated."},
	[589] = {name="Strong Sentry",			desc="Shoots Strong Missiles and turns into a Sentry on death."},
	[590] = {name="Super Sentry",			desc="Shoots Super Missiles and has infinite HP."},
	[591] = {name="Explosive Sentry",		desc="Shoots Explosive Missiles and explodes on death."},
	[592] = {name="Mega-Explosive Sentry",	desc="Shoots Mega-Explosive Missiles and explodes on death."},
	[593] = {name="Friendly Strong Sentry",	desc="Shoots Friendly Strong Missiles and turns into a Friendly Sentry on death."},
	[594] = {name="Friendly Super Sentry",	desc="Shoots Friendly Super Missiles and has infinite HP."},
	[595] = {name="Friendly Explosive Sentry",desc="Shoots Friendly Explosive Missiles and explodes on death."},
	[596] = {name="Friendly Mega-Explosive Sentry",desc="Shoots Friendly Mega-Explosive Missiles and explodes on death."},
	[597] = {name="Friendly Strong Missile",desc="Turns into a Friendly Missile on death."},
	[598] = {name="Friendly Super Missile",	desc="Friendly and has infinite HP."},
	[599] = {name="Friendly Explosive Missile",desc="Friendly and explodes on death."},
	[600] = {name="Friendly Mega-Explosive Missile",desc="Friendly and explodes bigger on death."},
	[601] = {name="Anti-Filter Diverger",	desc="Deletes everything except its assigned cell."},
	[602] = {name="Skewfire",				desc="Diagonal-only Fire."},
	[603] = {name="Skewfireball",			desc="Moving Skewfire."},
	[604] = {name="Custom LtL",				desc="Customizable Larger than Life ruleset."},
	[605] = {name="Dead Custom LtL",		desc="Dead Custom LtL."},
	[606] = {name="Super Bigenerator",		desc="Super Generator that generates three rows at once."},
	[607] = {name="Super Trigenerator",		desc="Super Generator that generates two rows at once."},
	[608] = {name="CW Super Digenerator",	desc="Super Generator that generates two rows at once."},
	[609] = {name="CCW Super Digenerator",	desc="Super Generator that generates two rows at once."},
	[610] = {name="Super Bicloner",			desc="Super Trigenerator that doesn't rotate the generated cells."},
	[611] = {name="Super Tricloner",		desc="Super Bigenerator that doesn't rotate the generated cells."},
	[612] = {name="CW Super Dicloner",		desc="CW Super Digenerator that doesn't rotate the generated cells."},
	[613] = {name="CCW Super Dicloner",		desc="CCW Super Digenerator that doesn't rotate the generated cells."},
	[614] = {name="Platformer Player",		desc="Player with gravity that can jump."},
	[615] = {name="Bitimewarper",			desc="Two opposing Timewarpers in one."},
	[616] = {name="Tritimewarper",			desc="Three Timewarpers in one."},
	[617] = {name="Tetratimewarper",		desc="Four Timewarpers in one."},
	[618] = {name="Broken Pushable",		desc="Pushable that dies when moved."},
	[619] = {name="Armorer",				desc="Permanently protects cells. Also does not kill Infectious cells."},
	[620] = {name="Broken Slider",			desc="Slider that dies when moved."},
	[621] = {name="Broken One-Directional",	desc="One-Directional that dies when moved."},
	[622] = {name="Broken Two-Directional",	desc="Two-Directional that dies when moved."},
	[623] = {name="Broken Three-Directional",desc="Three-Directional that dies when moved."},
	[624] = {name="Rutzice",				desc="No one quite knows where this robot came from, but it is easy to see it is heavily damaged. It appears to try to self-replicate after absorbing material, and it's AI mutates drastically on frequent occasions."},
	[625] = {name="CW Cycler",				desc="Cycles the 3 cells in front of it clockwise."},
	[626] = {name="CCW Cycler",				desc="Cycles the 3 cells in front of it counter-clockwise."},
	[627] = {name="CW Cross Cycler",		desc="Two CW Cyclers."},
	[628] = {name="CCW Cross Cycler",		desc="Two CCW Cyclers."},
	[629] = {name="Curved Mirror",			desc="A curved Mirror."},
	[630] = {name="Bicurved Mirror",		desc="Two curved Mirrors."},
	[631] = {name="Constrictor",			desc="One-sided Restrictor."},
	[632] = {name="CW Bicycler",			desc="Two-sided CW Cycler."},
	[633] = {name="CCW Bicycler",			desc="Two-sided CCW Cycler."},
	[634] = {name="CW Tricycler",			desc="Three-sided CW Cycler."},
	[635] = {name="CCW Tricycler",			desc="Three-sided CCW Cycler."},
	[636] = {name="CW Tetracycler",			desc="Four-sided CW Cycler."},
	[637] = {name="CCW Tetracycler",		desc="Four-sided CCW Cycler."},
	[638] = {name="Impeder",				desc="Blocks all force on the front; if moved from another side, it will rotate to block that side."},
	[639] = {name="Restrainer",				desc="One-sided Resistance."},
	[640] = {name="Megaflipper",			desc="Flipper that also flips diagonal neighbors."},
	[641] = {name="Super Flipper",			desc="Flips an entire structure."},
	[642] = {name="Paracycler",				desc="Exactly what it looks like."},
	[643] = {name="Monogeneratable",		desc="When generated, it turns into an ungeneratable."},
	[644] = {name="X-Generatable",			desc="Like a monogeneratable with a customizable amount of \"layers\"."},
	[645] = {name="Metageneratable",		desc="When generated, the copy's Generation decreases. If it would decrease to 0, it turns into the stored cell instead."},
	[646] = {name="Sniper Generator",		desc="When it generates a cell, it spits it out infinitely far."},
	[647] = {name="Semislime",				desc="Two-sided Slime."},
	[648] = {name="Quasislime",				desc="One-sided Slime."},
	[649] = {name="Honey",					desc="Sticky, but does not stick with slime."},
	[650] = {name="Semihoney",				desc="Two-sided Honey."},
	[651] = {name="Quasihoney",				desc="One-sided Honey."},
	[652] = {name="Convert Generator",		desc="Converts the generated cell to what it contains."},
	[653] = {name="Convert Shifter",		desc="Converts the shifted cell to what it contains."},
	[654] = {name="Diagonal Flipper",		desc="Flips diagonally."},
	[655] = {name="Diagonal Semiflipper A",	desc="Flips diagonally on 2 sides."},
	[656] = {name="Diagonal Semiflipper B",	desc="Flips diagonally on 2 sides."},
	[657] = {name="Tricurved Mirror",		desc="i cant find a better name for this"},
	[658] = {name="Diagonal Reflector",		desc="Diagonal reflector."},
	[659] = {name="Cross Diagonal Reflector",desc="Two diagonal reflectors."},
	[660] = {name="Tetrareflector",			desc="Four reflectors."},
	[661] = {name="Bireflector",			desc="Reflector and diagonal reflector."},
	[662] = {name="Direflector",			desc="Reflector and diagonal reflector."},
	[663] = {name="Trireflector",			desc="Reflector and two diagonal reflectors."},
	[664] = {name="Terreflector",			desc="Two reflectors and a diagonal reflector."},
	[665] = {name="Physical Shifter",		desc="Physical Generator, but as a Shifter."},
	[666] = {name="Physical Backshifter",	desc="Physical Backgenerator, but as a Shifter."},
	[667] = {name="Backshifter",			desc="Backgenerator, but as a Shifter."},
	[668] = {name="Adjustable Weight",		desc="Weight with adjustable mass."},
	[669] = {name="Adjustable Resistance",	desc="Resistance with adjustable mass."},
	[670] = {name="Phantom Demolisher",		desc="Phantom + Demolisher."},
	[671] = {name="Phantom Megademolisher",	desc="Phantom + Megademolisher."},
	[672] = {name="180 Chainsaw",			desc="Creates a deadly chainsaw blade and spins around 180 degrees."},
	[673] = {name="Physical Super Generator",desc="Physical Generator that generates an entire row."},
	[674] = {name="Physical Super Backgenerator",desc="Physical Backgenerator that generates an entire row."},
	[675] = {name="Super Backgenerator",	desc="Backgenerator that generates an entire row."},
	[676] = {name="Physical Super Replicator",desc="Physical Replicator that generates an entire row."},
	[677] = {name="Physical Super Backreplicator",desc="Physical Backreplicator that generates an entire row."},
	[678] = {name="Super Backreplicator",	desc="Backreplicator that generates an entire row."},
	[679] = {name="Twist Shifter",			desc="Shifter that flips like a Twist Generator."},
	[680] = {name="Exclamation Marker",		desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[681] = {name="Stop Marker",			desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[682] = {name="Like Marker",			desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[683] = {name="Dislike Marker",			desc="Decoration. Transparent to cells; disappears after being moved onto."},
	[684] = {name="Wall Ceiling",			desc="Goes above cells; hides cells under it."},	
	[685] = {name="Fake Wall",				desc="Goes above cells; hides cells under it."},	
	[686] = {name="Ghost Ceiling",			desc="Goes above cells; hides cells under it."},	
	[687] = {name="Fake Ghost",				desc="Goes above cells; hides cells under it."},	
	[688] = {name="Trash Ceiling",			desc="Goes above cells; hides cells under it."},	
	[689] = {name="Fake Trash",				desc="Goes above cells; hides cells under it."},	
	[690] = {name="Phantom Ceiling",		desc="Goes above cells; hides cells under it."},	
	[691] = {name="Fake Phantom",			desc="Goes above cells; hides cells under it."},	
	[692] = {name="Pushable Ceiling",		desc="Goes above cells; hides cells under it."},	
	[693] = {name="Fake Pushable",			desc="Goes above cells; hides cells under it."},
	[694] = {name="Attack Trash",			desc="Jumps towards the direction it eats a cell from."},
	[695] = {name="Attack Phantom",			desc="Phantom + Attack Trash."},
	[696] = {name="Unpushable",				desc="Cannot be pushed."},
	[697] = {name="Unpullable",				desc="Cannot be pulled."},
	[698] = {name="Ungrabbable",			desc="Cannot be grabbed."},
	[699] = {name="Unswappable",			desc="Cannot be swapped."},
	[700] = {name="Bendmover",				desc="If it's push is blocked, it will attempt to \"bend\" the push."},
	[701] = {name="Bendgenerator",			desc="If it's push is blocked, it will attempt to \"bend\" the push."},
	[702] = {name="Flip-Flop Diverger",		desc="Flips when a cell enters."},
	[703] = {name="Flip-Flop Displacer",	desc="Flips when a cell enters."},
	[704] = {name="Trailer",				desc="When it moves, it leaves the cell inside behind."},
	[705] = {name="Toggle Key",				desc="Toggles Toggle Doors/Gates."},
	[706] = {name="Toggle Door",			desc="Turns into a Toggle Gate when a Toggle Key is pushed into it."},
	[707] = {name="Toggle Gate",			desc="Turns into a Toggle Door when a Toggle Key is pushed into it."},
	[708] = {name="Label",					desc="Places rendered text. Style guide:\n\\\\n: Newline, \\\\o(num): Obfuscated, \\\\i: Italics (global)\n\\#______: Color, #x: Reset Color, \\#r/\\#R: Rainbow, \\#m/\\#M: Monochrome\n\\#a-b/\\#a_b: Gradient color"},
	[709] = {name="Flip Spinner",			desc="Flipper version of Spinner."},
	[710] = {name="Diagonal Flip Spinner",	desc="Diagonal Flipper version of Spinner."},
	[711] = {name="Flip Turner",			desc="Flipper version of Turner."},
	[712] = {name="Diagonal Flip Turner",	desc="Diagonal Flipper version of Turner."},
	[713] = {name="Diagonal Megaflipper",	desc="Diagonal Megaflipper."},
	[714] = {name="Diagonal Super Flipper",	desc="Diagonal Super Flipper."},
	[715] = {name="Diagonal Perpetual Flipper",	desc="Diagonal Perpetual Flipper."},
	[716] = {name="Super Squish Acid",		desc="Like Squish Trash, but as Super Acid."},
	[717] = {name="Squish Acid",			desc="Like Squish Trash, but as Acid."},
	[718] = {name="Rowmover",				desc="Moves a whole row, without stopping at air."},
	[719] = {name="Rowpuller",				desc="Pulls a whole row, without stopping at air."},
	[720] = {name="Rowadvancer",			desc="Advances a whole row, without stopping at air."},
	[721] = {name="Super Semirepulsor",		desc="Two-sided Super Repulsor."},
	[722] = {name="Super Quasirepulsor",	desc="One-sided Super Repulsor."},
	[723] = {name="Super Hemirepulsor",		desc="Two-sided Super Repulsor."},
	[724] = {name="Super Henarepulsor",		desc="Three-sided Super Repulsor."},
	[725] = {name="Super Semifan",			desc="Two-sided Super Fan."},
	[726] = {name="Super Quasifan",			desc="One-sided Super Fan."},
	[727] = {name="Super Hemifan",			desc="Two-sided Super Fan."},
	[728] = {name="Super Henafan",			desc="Three-sided Super Fan."},
	[729] = {name="Super Semiimpulsor",		desc="Two-sided Super Impulsor."},
	[730] = {name="Super Quasiimpulsor",	desc="One-sided Super Impulsor."},
	[731] = {name="Super Hemiimpulsor",		desc="Two-sided Super Impulsor."},
	[732] = {name="Super Henaimpulsor",		desc="Three-sided Super Impulsor."},
	[733] = {name="Bulk Trash",				desc="Trash that acts similar to a Staller."},
	[734] = {name="Bulk Phantom",			desc="Phantom + Bulk Trash."},
	[735] = {name="Chainsaw Blade",			desc="this used to have a string id. then i decided that was dumb"},
	[736] = {name="Petrifier",				desc="Makes the cells around it unbreakable, like Walls.\nMost cells will still retain their functionality."},
	[737] = {name="Midas",					desc="Transforms the cell it points to into the cell it holds.\nIs immune to transformation."},
	[738] = {name="Cross Midas",			desc="2-sided Midas."},
	[739] = {name="Bimidas",				desc="2-sided Midas."},
	[740] = {name="Trimidas",				desc="3-sided Midas."},
	[741] = {name="Megaredirector",			desc="A Redirector that also redirects diagonal neighbors."},
	[742] = {name="Directional Cross Midas",desc="Cross Midas that rotates the output depending on the transformation direction."},
	[743] = {name="Directional Bimidas",	desc="Bimidas that rotates the output depending on the transformation direction."},
	[744] = {name="Directional Trimidas",	desc="Trimidas that rotates the output depending on the transformation direction."},
	[745] = {name="Painter",				desc="Paints the cell it's pointing at with it's own paint."},
	[746] = {name="Anti-Wrap",				desc="Like the Wrap cell, but it checks forwards instead of backwards."},
	[747] = {name="Warp",					desc="Wrap + Anti-Wrap."},
	[748] = {name="Cross Warp",				desc="Two Warp cells in one."},
	[749] = {name="CW Physical Generator",	desc="CW-Bent Physical Generator."},
	[750] = {name="CCW Physical Generator",	desc="CCW-Bent Physical Generator."},
	[751] = {name="CW Physical Cloner",		desc="CW-Bent Physical Cloner."},
	[752] = {name="CCW Physical Cloner",	desc="CCW-Bent Physical Cloner."},
	[753] = {name="CW Physical Backgenerator",desc="CW-Bent Physical Backgenerator."},
	[754] = {name="CCW Physical Backgenerator",desc="CCW-Bent Physical Backgenerator."},
	[755] = {name="CW Physical Backcloner",	desc="CW-Bent Physical Backcloner."},
	[756] = {name="CCW Physical Backcloner",desc="CCW-Bent Physical Backcloner."},
	[757] = {name="CW Backgenerator",		desc="CW-Bent Backgenerator."},
	[758] = {name="CCW Backgenerator",		desc="CCW-Bent Backgenerator."},
	[759] = {name="CW Backcloner",			desc="CW-Bent Backcloner."},
	[760] = {name="CCW Backcloner",			desc="CCW-Bent Backcloner."},
	[761] = {name="Memory Transformer",		desc="Memory version of Transformer."},
	[762] = {name="Memory Transmutator",	desc="Memory version of Transmutator."},
	[763] = {name="Rowrepulsor",			desc="Pushes whole rows away from it."},
	[764] = {name="Semirowrepulsor",		desc="2-sided Rowrepulsor."},
	[765] = {name="Quasirowrepulsor",		desc="1-sided Rowrepulsor."},
	[766] = {name="Hemirowrepulsor",		desc="2-sided Rowrepulsor."},
	[767] = {name="Henarowrepulsor",		desc="3-sided Rowrepulsor."},
	[768] = {name="Ally",					desc="Like an Enemy, but is instead Ally-tagged by default. If the number of allies drops below the number there was in the initial state, the player fails the level."},
	[769] = {name="CW Super Physical Generator",	desc="CW-Bent Super Physical Generator."},
	[770] = {name="CCW Super Physical Generator",	desc="CCW-Bent Super Physical Generator."},
	[771] = {name="CW Super Physical Cloner",		desc="CW-Bent Super Physical Cloner."},
	[772] = {name="CCW Super Physical Cloner",	desc="CCW-Bent Super Physical Cloner."},
	[773] = {name="CW Super Physical Backgenerator",desc="CW-Bent Super Physical Backgenerator."},
	[774] = {name="CCW Super Physical Backgenerator",desc="CCW-Bent Super Physical Backgenerator."},
	[775] = {name="CW Super Physical Backcloner",	desc="CW-Bent Super Physical Backcloner."},
	[776] = {name="CCW Super Physical Backcloner",desc="CCW-Bent Super Physical Backcloner."},
	[777] = {name="CW Super Backgenerator",		desc="CW-Bent Super Backgenerator."},
	[778] = {name="CCW Super Backgenerator",		desc="CCW-Bent Super Backgenerator."},
	[779] = {name="CW Super Backcloner",			desc="CW-Bent Super Backcloner."},
	[780] = {name="CCW Super Backcloner",			desc="CCW-Bent Super Backcloner."},
	[781] = {name="Seizer",					desc="Takes cells from the side and puts them in front of itself if it isn't pushing anything."},
	[782] = {name="Biforker",				desc="Two forkers combined at a 90 degree angle."},
	[783] = {name="Bidivider",				desc="Two dividers combined at a 90 degree angle."},
	[784] = {name="Paraforker",				desc="Two forkers combined at a 180 degree angle."},
	[785] = {name="Paradivider",			desc="Two dividers combined at a 180 degree angle."},
	[786] = {name="CW Neutrino",			desc="Moves forward and pushes cells to the right, then pulls them back into place."},
	[787] = {name="CCW Neutrino",			desc="Moves forward and pushes cells to the left, then pulls them back into place."},
	[788] = {name="Hemislime",				desc="Two-sided Slime."},
	[789] = {name="Henaslime",				desc="Three-sided Slime."},
	[790] = {name="Hemihoney",				desc="Two-sided Honey."},
	[791] = {name="Henahoney",				desc="Three-sided Honey."},
	[792] = {name="Strong Seeker",			desc="Targets friendlies, becomes a Seeker on death."},
	[793] = {name="Super Seeker",			desc="Seeker with infinite HP."},
	[794] = {name="Explosive Seeker",		desc="Seeker that explodes."},
	[795] = {name="Mega-Explosive Seeker",	desc="Seeker that explodes."},
	[796] = {name="Strong Turret",			desc="Shoots Strong Seekers at friendlies, becomes a Turret on death."},
	[797] = {name="Super Turret",			desc="Shoots Super Seekers, has infinite HP."},
	[798] = {name="Explosive Turret",		desc="Shoots Explosive Seekers, explodes on death."},
	[799] = {name="Mega-Explosive Turret",	desc="Shoots Mega-Explosive Seekers, explodes on death."},
	[800] = {name="Friendly Strong Seeker",	desc="Targets enemies, becomes a Seeker on death."},
	[801] = {name="Friendly Super Seeker",	desc="Friendly Seeker with infinite HP."},
	[802] = {name="Friendly Explosive Seeker",desc="Friendly Seeker that explodes."},
	[803] = {name="Friendly Mega-Explosive Seeker",desc="Friendly Seeker that explodes."},
	[804] = {name="Friendly Strong Turret",	desc="Shoots Friendly Strong Seekers at friendlies, becomes a Turret on death."},
	[805] = {name="Friendly Super Turret",	desc="Shoots Friendly Super Seekers, has infinite HP."},
	[806] = {name="Friendly Explosive Turret",desc="Shoots Friendly Explosive Seekers, explodes on death."},
	[807] = {name="Friendly Mega-Explosive Turret",desc="Shoots Friendly Mega-Explosive Seekers, explodes on death."},
	[808] = {name="Distortion",				desc="Similar to Warped, but only spreads 50% of the time."},
	[809] = {name="Rust",					desc="Similar to Bioweapon, but only spreads 50% of the time."},
	[810] = {name="Algae",					desc="Similar to Prion, but only spreads 50% of the time."},
	[811] = {name="Alteration",				desc="Similar to Corruption, but only spreads 50% of the time."},
	[812] = {name="Silver Goo",				desc="Similar to Grey Goo, but only spreads 50% of the time."},
	[813] = {name="Mold",					desc="Similar to Virus, but only spreads 50% of the time."},
	[814] = {name="Chainsaw",				desc="Non-rotating Chainsaw."},
	[815] = {name="Spikes",					desc="Decorative 1-sided Trash cell for levels.\nAdditionally, is invisible to Seekers."},
	[816] = {name="Center Spikes",			desc="Decorative Trash cell for levels.\nAdditionally, is invisible to Seekers."},
	[817] = {name="Single Spike",			desc="Decorative 1-sided Trash cell for levels.\nAdditionally, is invisible to Seekers."},
	[818] = {name="Laser",					desc="When a friendly cell walks in front of it, it shoots a laser after a tick."},
	[819] = {name="Laser Beam",				desc="uhhh"},
	[820] = {name="Stapler",				desc="When it passes cells, it pulls them to behind it."},
	[821] = {name="Dispenser",				desc="Like a Transporter that drops cells behind it."},
	[822] = {name="Dropoff",				desc="Like a Transporter, but when it moves into a cell, it picks it up and ejects it's old cell."},
	[823] = {name="Dropper",				desc="Dispenser + Dropoff"},
	[824] = {name="Settlecompeller",		desc="If an affected cell moves, it dies."},
	[825] = {name="Motocompeller",			desc="If an affected cell stays still, it dies."},
	[826] = {name="Decompeller",			desc="Removes a cell's compel."},
	[827] = {name="Angry Enemy",			desc="Collides with adjacent cells."},
	[828] = {name="Furious Enemy",			desc="Collides with surrounding cells."},
	[829] = {name="Advancer Player",		desc="A player that pushes and pulls."},
	[830] = {name="Fragile Advancer Player",desc="A player that pushes and pulls and can be crashed into like an enemy."},
	[831] = {name="Cracker",				desc="Like an Enemy, but isn't tagged, and can store a cell that gets released upon destruction."},
	[832] = {name="Super Spring",			desc="A spring that uncompresses infinitely."},
	[833] = {name="Super Timewarper",		desc="Timewarps a row of cells."},
	[834] = {name="Cross Super Timewarper",	desc="Timewarps 2 rows of cells."},
	[835] = {name="Super Bitimewarper",		desc="Timewarps 2 rows of cells."},
	[836] = {name="Super Tritimewarper",	desc="Timewarps 3 rows of cells."},
	[837] = {name="Super Tetratimewarper",	desc="Timewarps 4 rows of cells."},
	[838] = {name="Angry Super Enemy",		desc="Angry Enemy with infinite HP."},
	[839] = {name="Furious Super Enemy",	desc="Furious Enemy with infinite HP."},
	[840] = {name="Super Pushable",			desc="Pushable with infinite HP."},
	[841] = {name="Super Slider",			desc="Slider with infinite HP."},
	[842] = {name="Super One-Directional",	desc="One-Directional with infinite HP."},
	[843] = {name="Super Two-Directional",	desc="Two-Directional with infinite HP."},
	[844] = {name="Super Three-Directional",desc="Three-Directional with infinite HP."},
	[845] = {name="Armed Player",			desc="Player that can shoot with Z/Enter."},
	[846] = {name="Spy Player",				desc="Player that can disguise as a neighboring cell to trick Sentries.\nCannot disguise as ungeneratable cells like Ghost.\nAlso cannot disguise as a cell if the cell is moving."},
	[847] = {name="Sniper Shifter",			desc="Shifter that spits cells out infinitely far."},
	[848] = {name="Jump Demolisher",		desc="Jump Trash + Demolisher."},
	[849] = {name="Jump Megademolisher",	desc="Jump Trash + Megademolisher."},
	[850] = {name="Dodge Demolisher",		desc="Dodge Trash + Demolisher."},
	[851] = {name="Dodge Megademolisher",	desc="Dodge Trash + Megademolisher."},
	[852] = {name="Evade Demolisher",		desc="Evade Trash + Demolisher."},
	[853] = {name="Evade Megademolisher",	desc="Evade Trash + Megademolisher."},
	[854] = {name="Attack Demolisher",		desc="Attack Trash + Demolisher."},
	[855] = {name="Attack Megademolisher",	desc="Attack Trash + Megademolisher."},
	[856] = {name="Directional Phantom",	desc="Directional Trash + Phantom."},
	[857] = {name="Directional Demolisher",	desc="Directional Trash + Demolisher."},
	[858] = {name="Directional Megademolisher",desc="Directional Trash + Megademolisher."},
	[859] = {name="Squish Demolisher",		desc="Squish Trash + Demolisher."},
	[860] = {name="Squish Megademolisher",	desc="Squish Trash + Megademolisher."},
	[861] = {name="Bulk Demolisher",		desc="Bulk Trash + Demolisher."},
	[862] = {name="Bulk Megademolisher",	desc="Bulk Trash + Megademolisher."},
	[863] = {name="Alkali",					desc="Acts like a moving Acid."},
	[864] = {name="Super Squish Alkali",	desc="Acts like a moving Super Squish Acid."},
	[865] = {name="Squish Alkali",			desc="Acts like a moving Squish Acid."},
	[866] = {name="Cross Physical Replicator",desc="Two Physical Replicators."},
	[867] = {name="Cross Physical Backreplicator",desc="Two Physical Backreplicators."},
	[868] = {name="Cross Backreplicator",	desc="Two Backreplicators."},
	[869] = {name="Physical Bireplicator",	desc="Two Physical Replicators."},
	[870] = {name="Physical Bibackreplicator",desc="Two Physical Backreplicators."},
	[871] = {name="Bibackreplicator",		desc="Two Backreplicators."},
	[872] = {name="Physical Trireplicator",	desc="Three Physical Replicators."},
	[873] = {name="Physical Tribackreplicator",desc="Three Physical Backreplicators."},
	[874] = {name="Tribackreplicator",		desc="Three Backreplicators."},
	[875] = {name="Physical Tetrareplicator",desc="Four Physical Replicators."},
	[876] = {name="Physical Tetrabackreplicator",desc="Four Physical Backreplicators."},
	[877] = {name="Tetrabackreplicator",	desc="Four Backreplicators."},
	[878] = {name="Cross Physical Super Replicator",desc="Two Physical Super Replicators."},
	[879] = {name="Cross Physical Super Backreplicator",desc="Two Physical Super Backreplicators."},
	[880] = {name="Cross Super Backreplicator",desc="Two Super Backreplicators."},
	[881] = {name="Physical Super Bireplicator",desc="Two Physical Super Replicators."},
	[882] = {name="Physical Super Bibackreplicator",desc="Two Physical Super Backreplicators."},
	[883] = {name="Super Bibackreplicator",	desc="Two Super Backreplicators."},
	[884] = {name="Physical Super Trireplicator",desc="Three Physical Super Replicators."},
	[885] = {name="Physical Super Tribackreplicator",desc="Three Physical Super Backreplicators."},
	[886] = {name="Super Tribackreplicator",desc="Three Super Backreplicators."},
	[887] = {name="Physical Super Tetrareplicator",desc="Four Physical Super Replicators."},
	[888] = {name="Physical Super Tetrabackreplicator",desc="Four Physical Super Backreplicators."},
	[889] = {name="Super Tetrabackreplicator",desc="Four Super Backreplicators."},
	[890] = {name="Physical Trash",			desc="When it eats a cell, it exerts a force on the other side."},
	[891] = {name="Physical Phantom",		desc="Physical Trash + Phantom."},
	[892] = {name="Dextrophysical Trash",	desc="When it eats a cell, it exerts a force on the CW side."},
	[893] = {name="Dextrophysical Phantom",	desc="Dextrophysical Trash + Phantom."},
	[894] = {name="Levophysical Trash",		desc="When it eats a cell, it exerts a force on the CCW side."},
	[895] = {name="Levophysical Phantom",	desc="Levophysical Trash + Phantom."},
	[896] = {name="Gooer",					desc="Freezes cells in place until they are moved."},
	[897] = {name="Physical Demolisher",	desc="Physical Trash + Demolisher."},
	[898] = {name="Physical Megademolisher",desc="Physical Trash + Megademolisher."},
	[899] = {name="Dextrophysical Demolisher",desc="Dextrophysical Trash + Demolisher."},
	[900] = {name="Dextrophysical Megademolisher",desc="Dextrophysical Trash + Megademolisher."},
	[901] = {name="Levophysical Demolisher",desc="Levophysical Trash + Demolisher."},
	[902] = {name="Levophysical Megademolisher",desc="Levophysical Trash + Megademolisher."},
	[903] = {name="Tunneller",				desc="Teleports through cells. Cannot teleport through unbreakables."},
	[904] = {name="Digger",					desc="Mover + Tunneller."},
	[905] = {name="Impacter",				desc="Collider that pushes."},
	[906] = {name="Neutrino",				desc="Moves forward and pushes cells to the side, then pulls them back into place."},
	[907] = {name="Neutral",				desc="Like an Enemy, but is instead Player-tagged by default. If there was at least one Player-tagged cell at the start, and then all are destroyed, the level is failed, unless all Enemies are defeated at the same time."},
	[908] = {name="Victory Switch",			desc="If all Victory Switches of an ID are enabled, you win the level."},
	[909] = {name="Faliure Switch",			desc="If all Faliure Switches of an ID are enabled, you lose the level."},
	[910] = {name="Input Pushable",			desc="While the simulation is running, it can be dragged around."},
	[911] = {name="Input Slider",			desc="While the simulation is running, it can be dragged around on one axis."},
	[912] = {name="Input One Directional",	desc="While the simulation is running, it can be dragged around in one direction."},
	[913] = {name="Input Two Directional",	desc="While the simulation is running, it can be dragged around in two directions."},
	[914] = {name="Input Three Directional",desc="While the simulation is running, it can be dragged around in three directions."},
	[915] = {name="Input Enemy",			desc="Can be clicked to be destroyed.\nIsn't enemy-tagged like normal Enemies."},
	[916] = {name="Input Door",				desc="Can be clicked to be opened."},
	[917] = {name="Input Gate",				desc="Can be clicked to be closed."},
	[918] = {name="Input Storage",			desc="Can be clicked to turn it into the cell inside of it.\nDoes not absorb cells like a normal Storage."},
	[919] = {name="Sapphire",				desc="Swaps the cells at a 1/3 slope away from it."},
	[920] = {name="Semisapphire",			desc="2-sided Sapphire."},
	[921] = {name="Quasisapphire",			desc="1-sided Sapphire."},
	[922] = {name="Hemisapphire",			desc="2-sided Sapphire."},
	[923] = {name="Henasapphire",			desc="3-sided Sapphire."},
	[924] = {name="Tourmaline",				desc="Swaps the cells at a 2/3 slope away from it."},
	[925] = {name="Semitourmaline",			desc="2-sided Tourmaline."},
	[926] = {name="Quasitourmaline",		desc="1-sided Tourmaline."},
	[927] = {name="Hemitourmaline",			desc="2-sided Tourmaline."},
	[928] = {name="Henatourmaline",			desc="3-sided Tourmaline."},
	[929] = {name="Grass Wall",				desc="A grassy green wall."},
	[930] = {name="Dirt Wall",				desc="A dirty brown wall."},
	[931] = {name="Cobble Wall",			desc="A cobblestone wall."},
	[932] = {name="Sand Wall",				desc="A sandy yellow wall."},
	[933] = {name="Magma Wall",				desc="A magma orange wall."},
	[934] = {name="Wood Wall",				desc="A wooden brown wall."},
	[935] = {name="Tunnel Clamper",			desc="Prevents cells from being tunnelled through."},
	[936] = {name="Unscissorable",			desc="Cannot be scissored."},
	[937] = {name="Untunnellable",			desc="Cannot be tunnelled through."},
	[938] = {name="Mossy Stone Wall",		desc="A mossy stone wall."},
	[939] = {name="Copper Wall",			desc="A shiny copper wall."},
	[940] = {name="Silver Wall",			desc="A shiny silver wall."},
	[941] = {name="Gold Wall",				desc="A shiny gold wall."},
	[942] = {name="Diamond",				desc="Swaps the cells at a 1/4 slope away from it."},
	[943] = {name="Semidiamond",			desc="2-sided Diamond."},
	[944] = {name="Quasidiamond",			desc="1-sided Diamond."},
	[945] = {name="Hemidiamond",			desc="2-sided Diamond."},
	[946] = {name="Henadiamond",			desc="3-sided Diamond."},
	[947] = {name="Emerald",				desc="Swaps the cells at a 2/4 slope away from it."},
	[948] = {name="Semiemerald",			desc="2-sided Emerald."},
	[949] = {name="Quasiemerald",			desc="1-sided Emerald."},
	[950] = {name="Hemiemerald",			desc="2-sided Emerald."},
	[951] = {name="Henaemerald",			desc="3-sided Emerald."},
	[952] = {name="Topaz",					desc="Swaps the cells at a 3/4 slope away from it."},
	[953] = {name="Semitopaz",				desc="2-sided Topaz."},
	[954] = {name="Quasitopaz",				desc="1-sided Topaz."},
	[955] = {name="Hemitopaz",				desc="2-sided Topaz."},
	[956] = {name="Henatopaz",				desc="3-sided Topaz."},
	[957] = {name="CW Skewrotator",			desc="CW Rotator that only affects diagonal neighbors."},
	[958] = {name="CCW Skewrotator",		desc="CCW Rotator that only affects diagonal neighbors."},
	[959] = {name="180 Skewrotator",		desc="180 Rotator that only affects diagonal neighbors."},
	[960] = {name="Random Rotator",			desc="Rotator that rotates either CW or CCW."},
	[961] = {name="Random Semirotator",		desc="Only rotates on 2 faces."},
	[962] = {name="Random Megarotator",		desc="Random Rotator that affects diagonal neighbors too."},
	[963] = {name="Random Skewrotator",		desc="Random Rotator that only affects diagonal neighbors."},
	[964] = {name="Random Super Rotator",	desc="Rotates an entire structure."},
	[965] = {name="Random Spinner",			desc="Unbreakable. When a cell touches it, it rotates the cell randomly."},
	[966] = {name="Random Turner",			desc="Turns cells that push it randomly."},
	[967] = {name="Random Perpetual Rotator",desc="Rotates cells randomly forever."},
	[968] = {name="Random Gear",			desc="Like a Random Rotator, but as a Gear.\nCan rotate cells strangely because normal Gears only rotate cells that were at corners."},
	[969] = {name="Random Fast Gear",		desc="90 degree Random Gear."},
	[970] = {name="Random Faster Gear",		desc="135 degree Random Gear."},
	[971] = {name="Random Minigear",		desc="Random Gear that only affects 4 cells."},
	[972] = {name="Random Skewgear",		desc="Diagonal-affecting Gear."},
	[973] = {name="Random Cog",				desc="Random Gear that doesn't rotate cells."},
	[974] = {name="Random Fast Cog",		desc="Random Fast Gear that doesn't rotate cells."},
	[975] = {name="Random Faster Cog",		desc="Random Faster Gear that doesn't rotate cells."},
	[976] = {name="Random Minicog",			desc="Random Minigear that doesn't rotate cells."},
	[977] = {name="Random Skewcog",			desc="Random Skewgear that doesn't rotate cells."},
	[978] = {name="Random Slope",			desc="Slopes randomly."},
	[979] = {name="Random Stair",			desc="Stairs randomly."},
	[980] = {name="Random Diverger",		desc="Randomly chooses an output direction."},
	[981] = {name="Random Displacer",		desc="Randomly chooses an output direction."},
	[982] = {name="Edge Random Diverger",	desc="Random Diverger with a side removed."},
	[983] = {name="Edge Random Displacer",	desc="Random Displacer with a side removed."},
	[984] = {name="Randulsor",				desc="Randomly impulses or repulses."},
	[985] = {name="Semirandulsor",			desc="2-sided Randulsor."},
	[986] = {name="Quasirandulsor",			desc="1-sided Randulsor."},
	[987] = {name="Hemirandulsor",			desc="2-sided Randulsor."},
	[988] = {name="Henarandulsor",			desc="3-sided Randulsor."},
	[989] = {name="Random Redirectior",		desc="Sets the cells around it to a random rotation."},
	[990] = {name="Random Semiredirectior",	desc="2-sided Random Redirector."},
	[991] = {name="Random Quasiredirectior",desc="1-sided Random Redirector."},
	[992] = {name="Random Hemiredirectior",	desc="2-sided Random Redirector."},
	[993] = {name="Random Henaredirectior",	desc="3-sided Random Redirector."},
	[994] = {name="CW Quasirotator",		desc="1-sided CW Rotator."},
	[995] = {name="CCW Quasirotator",		desc="1-sided CCW Rotator."},
	[996] = {name="180 Quasirotator",		desc="1-sided 180 Rotator."},
	[997] = {name="Random Quasirotator",	desc="1-sided Random Rotator."},
	[998] = {name="CW Hemirotator",			desc="2-sided CW Rotator."},
	[999] = {name="CCW Hemirotator",		desc="2-sided CCW Rotator."},
	[1000] = {name="Firework Enemy",		desc="This little guy's pretty happy about his ID!\nIsn't tagged as an enemy, just here to celebrate."},
	[1001] = {name="180 Hemirotator",		desc="2-sided 180 Rotator."},
	[1002] = {name="Random Hemirotator",	desc="2-sided Random Rotator."},
	[1003] = {name="CW Henarotator",		desc="3-sided CW Rotator."},
	[1004] = {name="CCW Henarotator",		desc="3-sided CCW Rotator."},
	[1005] = {name="180 Henarotator",		desc="3-sided 180 Rotator."},
	[1006] = {name="Random Henarotator",	desc="3-sided Random Rotator."},
	[1007] = {name="Vacuum",				desc="3-range Impulsor."},
	[1008] = {name="Semivacuum",			desc="2-sided Vacuum"},
	[1009] = {name="Quasivacuum",			desc="1-sided Vacuum"},
	[1010] = {name="Hemivacuum",			desc="2-sided Vacuum"},
	[1011] = {name="Henavacuum",			desc="3-sided Vacuum"},
	[1012] = {name="Rowimpulsor",			desc="Pulls whole rows towards it."},
	[1013] = {name="Semirowimpulsor",		desc="2-sided Rowimpulsor."},
	[1014] = {name="Quasirowimpulsor",		desc="1-sided Rowimpulsor."},
	[1015] = {name="Hemirowimpulsor",		desc="2-sided Rowimpulsor."},
	[1016] = {name="Henarowimpulsor",		desc="3-sided Rowimpulsor."},
	[1017] = {name="Slant",					desc="Like the opposite of a Stair."},
	[1018] = {name="CW Slant",				desc="Always slants clockwise."},
	[1019] = {name="CCW Slant",				desc="Always slants counter-clockwise."},
	[1020] = {name="Random Slant",			desc="Slants randomly."},
	[1021] = {name="Flip Gear",				desc="Like a gear, but instead of rotating cells around it, it flips cells around it."},
	[1022] = {name="Diagonal Flip Gear",	desc="Flip Gear that flips diagonally."},
	[1023] = {name="Flip Minigear",			desc="Flip Gear that only affects 4 cells."},
	[1024] = {name="Diagonal Flip Minigear",desc="Diagonal Flip Gear that only affects 4 cells."},
	[1025] = {name="Flip Skewgear",			desc="Flip Gear that only affects diagonal cells."},
	[1026] = {name="Diagonal Flip Skewgear",desc="Diagonal Flip Gear that only affects diagonal cells."},
	[1027] = {name="Flip Cog",				desc="Flip Gear that doesn't flip cells."},
	[1028] = {name="Diagonal Flip Cog",		desc="Diagonal Flip Gear that doesn't flip cells."},
	[1029] = {name="Flip Minicog",			desc="Flip Minigear that doesn't flip cells."},
	[1030] = {name="Diagonal Flip Minicog",	desc="Diagonal Flip Minigear that doesn't flip cells."},
	[1031] = {name="Flip Skewcog",			desc="Flip Skewgear that doesn't flip cells."},
	[1032] = {name="Diagonal Flip Skewcog",	desc="Diagonal Flip Skewgear that doesn't flip cells."},
	[1033] = {name="Deleter",				desc="Deletes the cell in front of it, if it can be deleted.\nUpdates after Forcers."},
	[1034] = {name="Cross Deleter",			desc="2-sided Deleter."},
	[1035] = {name="Bideleter",				desc="2-sided Deleter."},
	[1036] = {name="Trideleter",			desc="3-sided Deleter."},
	[1037] = {name="Tetradeleter",			desc="4-sided Deleter."},
	[1038] = {name="Super Deleter",			desc="Deletes the row in front of it, up until the first cell it cant delete."},
	[1039] = {name="Super Cross Deleter",	desc="2-sided Super Deleter."},
	[1040] = {name="Super Bideleter",		desc="2-sided Super Deleter."},
	[1041] = {name="Super Trideleter",		desc="3-sided Super Deleter."},
	[1042] = {name="Super Tetradeleter",	desc="4-sided Super Deleter."},
	[1043] = {name="Injector",				desc="Like a Convertor, but instead, it transforms the cell in front of it to whatever it holds."},
	[1044] = {name="Skewredirector",		desc="A Redirector that only redirects diagonal neighbors."},
	[1045] = {name="Super Redirector",		desc="Redirects an entire structure."},
	[1046] = {name="Redirect Spinner",		desc="Redirector version of Spinner."},
	[1047] = {name="Redirect Turner",		desc="Redirector version of Turner."},
	[1048] = {name="Skewflipper",			desc="Flipper that only affects diagonal neighbors."},
	[1049] = {name="Diagonal Skewflipper",	desc="Diagonal Flipper that only affects diagonal neighbors."},
	[1050] = {name="Physical Maker",		desc="Physical version of Maker."},
	[1051] = {name="Physical Cross Maker",	desc="Physical version of Cross Maker."},
	[1052] = {name="Physical Bimaker",		desc="Physical version of Bimaker."},
	[1053] = {name="Physical Trimaker",		desc="Physical version of Trimaker."},
	[1054] = {name="Physical Tetramaker",	desc="Physical version of Tetramaker."},
	[1055] = {name="Physical Directional Cross Maker",desc="Physical version of Directional Cross Maker."},
	[1056] = {name="Physical Directional Bimaker",desc="Physical version of Directional Bimaker."},
	[1057] = {name="Physical Directional Trimaker",desc="Physical version of Directional Trimaker."},
	[1058] = {name="Physical Directional Tetramaker",desc="Physical version of Directional Tetramaker."},
	[1059] = {name="Physical Backmaker",		desc="Physical Back version of Maker."},
	[1060] = {name="Physical Cross Backmaker",	desc="Physical Back version of Cross Maker."},
	[1061] = {name="Physical Bibackmaker",		desc="Physical Back version of Bimaker."},
	[1062] = {name="Physical Tribackmaker",		desc="Physical Back version of Trimaker."},
	[1063] = {name="Physical Tetrabackmaker",	desc="Physical Back version of Tetramaker."},
	[1064] = {name="Physical Directional Cross Backmaker",desc="Physical Back version of Directional Cross Maker."},
	[1065] = {name="Physical Directional Bibackmaker",desc="Physical Back version of Directional Bimaker."},
	[1066] = {name="Physical Directional Tribackmaker",desc="Physical Back version of Directional Trimaker."},
	[1067] = {name="Physical Directional Tetrabackmaker",desc="Physical Back version of Directional Tetramaker."},
	[1068] = {name="Backmaker",				desc="Back version of Maker."},
	[1069] = {name="Cross Backmaker",		desc="Back version of Cross Maker."},
	[1070] = {name="Bibackmaker",			desc="Back version of Bimaker."},
	[1071] = {name="Tribackmaker",			desc="Back version of Trimaker."},
	[1072] = {name="Tetrabackmaker",		desc="Back version of Tetramaker."},
	[1073] = {name="Directional Cross Backmaker",desc="Back version of Directional Cross Maker."},
	[1074] = {name="Directional Bibackmaker",desc="Back version of Directional Bimaker."},
	[1075] = {name="Directional Tribackmaker",desc="Back version of Directional Trimaker."},
	[1076] = {name="Directional Tetrabackmaker",desc="Back version of Directional Tetramaker."},
	[1077] = {name="Worm",					desc="Transforms the cell in front of it into itself and disappears."},
	[1078] = {name="CW Worm",				desc="Turns CW when eating a cell."},
	[1079] = {name="CCW Worm",				desc="Turns CCW when eating a cell."},
	[1080] = {name="180 Worm",				desc="Turns 180 when eating a cell."},
	[1081] = {name="Twist CW Worm",			desc="Flips diagonally when eating a cell."},
	[1082] = {name="Twist CCW Worm",		desc="Flips diagonally when eating a cell."},
	[1083] = {name="Partial Convertor",		desc="Like a Convertor, but it can take multiple cells to convert into one."},
	[1084] = {name="Multiplier Diverger",	desc="Multiplies what comes through."},
	[1085] = {name="Divider Diverger",		desc="Takes multiple cells to allow one through."},
	[1086] = {name="CW Slicer",				desc="Only slices to the right."},
	[1087] = {name="CCW Slicer",			desc="Only slices to the left."},
	[1088] = {name="Convert Constructor",	desc="Like a Constructor that only outputs whatever it contains."},
	[1089] = {name="Broken Super Generator",desc="One-use Super Generator."},
	[1090] = {name="Broken Super Replicator",desc="One-use Super Replicator."},
	[1091] = {name="Adjustable Slope",		desc="Slope with adjustable displacement."},
	[1092] = {name="CW Adjustable Slope",	desc="CW Slope with adjustable displacement."},
	[1093] = {name="CCW Adjustable Slope",	desc="CCW Slope with adjustable displacement."},
	[1094] = {name="Random Adjustable Slope",	desc="Random Slope with adjustable displacement."},
	[1095] = {name="Adjustable Gem",		desc="Swaps the cells at an adjustable slope."},
	[1096] = {name="Adjustable Semigem",	desc="Swaps the cells at an adjustable slope."},
	[1097] = {name="Adjustable Quasigem",	desc="Swaps the cells at an adjustable slope."},
	[1098] = {name="Adjustable Hemigem",	desc="Swaps the cells at an adjustable slope."},
	[1099] = {name="Adjustable Henagem",	desc="Swaps the cells at an adjustable slope."},
	[1100] = {name="Time Semirepulsor",		desc="2-sided Time Repulsor."},
	[1101] = {name="Time Quasirepulsor",	desc="3-sided Time Repulsor."},
	[1102] = {name="Time Hemirepulsor",		desc="2-sided Time Repulsor."},
	[1103] = {name="Time Henarepulsor",		desc="1-sided Time Repulsor."},
	[1104] = {name="Time Impulsor",			desc="Impulsor version of Time Repulsor."},
	[1105] = {name="Time Semiimpulsor",		desc="2-sided Time Impulsor."},
	[1106] = {name="Time Quasiimpulsor",	desc="3-sided Time Impulsor."},
	[1107] = {name="Time Hemiimpulsor",		desc="2-sided Time Impulsor."},
	[1108] = {name="Time Henaimpulsor",		desc="1-sided Time Impulsor."},
	[1109] = {name="Flower",				desc="Spreads around cells in a random fashion."},
	[1110] = {name="Dead Flower",			desc="Dead Chorus."},
	[1111] = {name="Epsilon",				desc="Spreads onto cells in a random fashion."},
	[1112] = {name="Dead Epsilon",			desc="Dead Gamma."},
	[1113] = {name="Cyanide",				desc="Spreads onto cells and air in a random fashion."},
	[1114] = {name="Dead Cyanide",			desc="Dead Poison."},
	[1115] = {name="Supragenerator",		desc="Generates an entire colomn."},
	[1116] = {name="Sawblade",				desc="Decorative Phantom, but it can be moved by Sawblade Orbiters."},
	[1117] = {name="Sawblade Orbiter",		desc="Moves sawblades around a square path."},
	[1118] = {name="CW Rotation Zone", 		desc="Rotates the cell below it clockwise."},
	[1119] = {name="CCW Rotation Zone", 	desc="Rotates the cell below it counter-clockwise."},
	[1120] = {name="180 Rotation Zone", 	desc="Rotates the cell below it 180 degrees."},
	[1121] = {name="Random Rotation Zone", 	desc="Rotates the cell below it CW or CCW."},
	[1122] = {name="Redirect Zone", 		desc="Redirects the cell below it."},
	[1123] = {name="Timewarp Zone", 		desc="Sets the space below it back to what it was in the initial state."},
	[1124] = {name="Conveyor Zone", 		desc="Pushes the cell below it."},
	[1125] = {name="Custom Infector", 		desc="Customizable Infector."},
	[1126] = {name="CW Twirler", 			desc="When pushed, it rotates the cell on the other side CW."},
	[1127] = {name="CCW Twirler", 			desc="When pushed, it rotates the cell on the other side CCW."},
	[1128] = {name="180 Twirler", 			desc="When pushed, it rotates the cell on the other side 180."},
	[1129] = {name="Random Twirler", 		desc="When pushed, it rotates the cell on the other side randomly."},
	[1130] = {name="Flip Twirler", 			desc="When pushed, it flips the cell on the other side."},
	[1131] = {name="Diagonal Flip Twirler", desc="When pushed, it flips the cell on the other side."},
	[1132] = {name="Redirect Twirler",		desc="When pushed, it redirects the cell on the other side."},
	[1133] = {name="Pseudo-Proton",			desc="Has a charge of +1 and has weight."},
	[1134] = {name="Pseudo-Antiproton",		desc="Has a charge of -1 and has weight."},
	[1135] = {name="Pseudo-Neutron",		desc="Sticks with Protons using the strong force, has weight."},
	[1136] = {name="Pseudo-Antineutron",	desc="Sticks with Antiprotons using the strong force, has weight."},
	[1137] = {name="Pseudo-Electron",		desc="Has a charge of -1 and no weight."},
	[1138] = {name="Pseudo-Antielectron",	desc="Has a charge of +1 and no weight."},
	[1139] = {name="Pseudo-Muon",			desc="Has a charge of -2 and no weight."},
	[1140] = {name="Pseudo-Antimuon",		desc="Has a charge of +2 and no weight."},
	[1141] = {name="Pseudo-Tau",			desc="Has a charge of -4 and no weight."},
	[1142] = {name="Pseudo-Antitau",		desc="Has a charge of +4 and no weight."},
	[1143] = {name="Pseudo-Graviton",		desc="Attracts all other particles, has no weight."},
	[1144] = {name="Pseudo-Exoticon",		desc="Repels all other particles, has no weight.\nAffected oppositely by gravitons."},
	[1145] = {name="Pseudo-Pion",			desc="Like a Neutron with infinite strong force."},
	[1146] = {name="Pseudo-Antipion",		desc="Like an Antineutron with infinite strong force."},
	[1147] = {name="Pseudo-Strangelet",		desc="Infects neighboring cells, has weight."},
	[1148] = {name="Pseudo-Antistrangelet",	desc="Infects neighboring cells, has weight."},
	[1149] = {name="Pseudo-W Boson",		desc="Splits a Neutron or Antineutron, has no weight."},
	[1150] = {name="Settlestorage",			desc="If it contains something, it will turn into it after a tick passes where it doesn't move."},
	[1151] = {name="Motostorage",			desc="If it contains something, it will turn into it after a tick passes where it gets moved."},
	[1152] = {name="Reshifter",				desc="A Shifter, but when it has nothing to shift, it flips around."},
	[1153] = {name="Cross Reshifter",		desc="Two Reshifters in one."},
	[1154] = {name="Metafungal",			desc="Like a Fungal cell combined with a Metageneratable cell."},
	[1155] = {name="Icicle",				desc="Falls when a cell moves below it. Accelerates as it falls, and deals 1 damage to whatever it hits."},
	[1156] = {name="Snow Wall",				desc="A white snow wall."},
	[1157] = {name="Observer",				desc="If it sees a friendly cell, it will move towards it until it hits a wall, where it will go back. It is solid, but it can crush cells against walls like a Crusher."},
	[1158] = {name="Friendly Observer",		desc="Targets unfriendly cells."},
	[1159] = {name="Springboard",			desc="Bounces Platformer Players with an adjustable amount of speed."},
	[1160] = {name="Crusher",				desc="Can crush cells against walls and is unbreakable on the front."},
	[1161] = {name="Super Crusher",			desc="Crusher + Super Mover."},
	[1162] = {name="Trespasser",			desc="Like a Driller that swaps itself with the last cell in a row of cells."},
	[1163] = {name="Dash Block",			desc="When a Platformer Player touches one of these, it will boost them in the direction that it is facing."},
	[1164] = {name="Activator", 			desc="Freezes the cell in front of it. When a cell enters it's back side, it will stop freezing for one tick."},
	[1165] = {name="Super Ally", 			desc="Ally with infinite HP."},
	[1166] = {name="Super Neutral", 		desc="Neutral with infinite HP."},
	[1167] = {name="Chaser", 				desc="Pathfinds to the nearest friendly cell. If none are found, it will try to push cells out of the way to find some. It only collides with friendly cells. Additionally, it's speed is adjustable in the same manner as an Adjustable Mover, and it's maximum range is adjustable too. Chasers are not tagged by default."},
	[1168] = {name="Super Chaser", 			desc="A Chaser with infinite HP. Unlike a normal Chaser, it will crash into any cell, like an Enemy. It will also destroy every cell that it can if a friendly cell is not in sight."},
	[1169] = {name="Friendly Chaser", 		desc="Chaser that targets unfriendly cells."},
	[1170] = {name="Friendly Super Chaser",	desc="Super Chaser that targets unfriendly cells."},
	[1171] = {name="Ice Wall",				desc="An icy blue wall."},
	[1172] = {name="Fearful Enemy",			desc="An Enemy that runs away from adjacent cells."},
	[1173] = {name="Fearful Ally",			desc="An Ally that runs away from adjacent cells."},
	[1174] = {name="Wool Wall",				desc="A fluffy white wall."},
	[1175] = {name="Crush Repulsor",		desc="Repulsor that can crush cells against walls."},
	[1176] = {name="Crush Semirepulsor",	desc="Semirepulsor that can crush cells against walls."},
	[1177] = {name="Crush Quasirepulsor",	desc="Quasirepulsor that can crush cells against walls."},
	[1178] = {name="Crush Hemirepulsor",	desc="Hemirepulsor that can crush cells against walls."},
	[1179] = {name="Crush Henarepulsor",	desc="Henarepulsor that can crush cells against walls."},
	[1180] = {name="Collectable Key",		desc="A key that cells can collect like a coin.\nCollected keys are shared globally, across all cells, rather than individually like Coins."},
	[1181] = {name="Collectable Key Door",	desc="Is destroyed when a cell touches it after a Collectable Key of the corresponding color has been picked up.\nDoes not remove the key upon destruction."},
	[1182] = {name="Imaginary Weight",		desc="Like a weight, but instead of removing normal bias, it removes an \"imaginary\" bias that only affects the force when it finishes. If the imaginary bias is below 0 when the movement ends, the movement will fail."},
	[1183] = {name="Imaginary Anti-Weight",	desc="Adds 1 to the imaginary bias, or more simply, counteracts the effect of one Imaginary Weight."},
	[1184] = {name="Imaginary Bias",		desc="Bias cell that affects imaginary bias."},
	[1185] = {name="Imaginary Resistance",	desc="If the imaginary bias isn't exactly 0 when the force ends, it stops the force."},
	[1186] = {name="Stone Wall",			desc="A stone grey wall."},
	[1187] = {name="Coil",					desc="Blocks force for as many ticks as the amount of force being applied."},
	[1188] = {name="Adjustable Coil",		desc="Blocks force for an adjustable amount of ticks."},
	[1189] = {name="Capacitor",				desc="Allows force for as many ticks as the amount of force being applied, then becomes immovable until force is no longer applied."},
	[1190] = {name="Adjustable Capacitor",	desc="Allows force for an adjustable amount of ticks."},
	[1191] = {name="Conductance",			desc="The opposite of a Resistance cell; Blocks force if it is exactly 1."},
	[1192] = {name="Super Conductance",		desc="Blocks infinite forces."},
	[1193] = {name="Adjustable Conductance",desc="Conductance that blocks an adjustable amount of force."},
	[1194] = {name="Super Resistance",		desc="Blocks everything except infinite forces."},
	[1195] = {name="Inhibation",			desc="Conductance that acts like Tentative."},
	[1196] = {name="Imaginary Conductance",	desc="If the imaginary bias is 0 when the force ends, it stops the force."},
	[1197] = {name="Inductor",				desc="Only affected by force every Nth tick, where N is the strength of the force being applied to it."},
	[1198] = {name="Adjustable Inductor",	desc="Only affected by force every Nth tick, where N is adjustable."},
	[1199] = {name="Bolter",				desc="Makes cells permenantly locked."},
	[1200] = {name="Script",				desc="Executes raw Lua code, with access to the game's variables, as soon as it eats a cell.\nErrors will not crash the game, but will be reported in the debugger.\nThe text input box is quite crap, so you should copy-paste your script instead of typing it here to make your life easier.\nBe mindful when running other people's scripts! You don't want anything bad to happen."},
	placeable = {name="Placeable",			desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableW = {name="White Placeable",	desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableR = {name="Red Placeable",		desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableO = {name="Orange Placeable",	desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableY = {name="Yellow Placeable",	desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableG = {name="Green Placeable",	desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableC = {name="Cyan Placeable",	desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableB = {name="Blue Placeable",	desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	placeableP = {name="Purple Placeable",	desc="Allows you to drag the cell on top of it to any other Placeable of the same color when in Puzzle Mode."},
	rotatable = {name="Rotatable",			desc="Allows you to rotate the cell on top of it by clicking on it when in Puzzle Mode."},
	rotatable180 = {name="180 Rotatable",	desc="Like a Rotatable, but 180 degrees."},
	hflippable = {name="H Flippable",		desc="Allows you to flip the cell on top of it horizontally by clicking on it when in Puzzle Mode."},
	vflippable = {name="V Flippable",		desc="Allows you to flip the cell on top of it vertically by clicking on it when in Puzzle Mode."},
	duflippable = {name="DU Flippable",		desc="Allows you to flip the cell on top of it diagonally by clicking on it when in Puzzle Mode."},
	ddflippable = {name="DD Flippable",		desc="Allows you to flip the cell on top of it diagonally by clicking on it when in Puzzle Mode."},
	bggrass = {name="Grass BG",				desc="A grassy green background."},
	bgdirt = {name="Dirt BG",				desc="A dirty brown background."},
	bgstone = {name="Stone BG",				desc="A stone grey background."},
	bgcobble = {name="Cobble BG",			desc="A cobblestone background."},
	bgsand = {name="Sand BG",				desc="A sandy yellow background."},
	bgsnow = {name="Snow BG",				desc="A snowy white background."},
	bgice = {name="Ice BG",					desc="An icy blue background."},
	bgmagma = {name="Magma BG",				desc="A magma orange background."},
	bgwood = {name="Wood BG",				desc="A wooden brown background."},
	bgwool = {name="Wool BG",				desc="A fluffy white background."},
	bgplate = {name="Plate BG",				desc="A metal plate background."},
	bgmossystone = {name="Mossy Cobble BG",	desc="A mossy stone background."},
	bgcopper = {name="Copper BG",			desc="A shiny copper background."},
	bgsilver = {name="Silver BG",			desc="A shiny silver background."},
	bggold = {name="Gold BG",				desc="A shiny gold background."},
	bgspace = {name="Space BG",				desc="An outer space background."},
	bgmatrix = {name="Matrix BG",			desc="A green grid background."},
	bgvoid = {name="Void BG",				desc="Removes the default BG."},
	eraser = {name="Eraser",				desc="Erases cells. You can also right-click to use the eraser.", notcell=true},
	paint = {name="Color Paintbrush",		desc="Paints cells with a hex color.", notcell=true},
	invertpaint = {name="Inversion Paintbrush",desc="Makes cell textures purely inverted.", notcell=true},
	invertcolorpaint = {name="Inverted Color Paintbrush",desc="Inverts and colors cells.", notcell=true},
	hsvpaint = {name="HSV Paintbrush",		desc="Changes a cell's Hue, Saturation, and Value.", notcell=true},
	inverthsvpaint = {name="Inverted HSV Paintbrush",desc="Changes a cell's Hue, Saturation, and Value, and inverts it.", notcell=true},
	invispaint = {name="Invisible Paintbrush",desc="Makes cells invisible. #505050trollage commences#x", notcell=true},
	shadowpaint = {name="Shadow Paintbrush",desc="Makes cells completely black and hides effect icons. More preformance-efficient then a colored paint set to black.", notcell=true},
	blendmode = {name="Blending Mode",		desc="Changes the blending mode that a cell is rendered with.\nStacks with paint.\nspoiler alert they donft really look good but hey it's an option", notcell=true},
	timerep_tool = {name="Time Pulse",		desc="Pushes a cell in a direction after some ticks.", notcell=true},
	grav_tool = {name="Gravitize",			desc="Gravitizes a cell.", notcell=true},
	prot_tool = {name="Perpetual Rotate",	desc="Perpetually rotates a cell.", notcell=true},
	armor_tool = {name="Armor",				desc="Permanently protects a cell.", notcell=true},
	bolt_tool = {name="Bolt",				desc="Permanently makes cells unrotatable.", notcell=true},
	coin_tool = {name="Coins",				desc="Sets the coins of a cell.", notcell=true},
	tag_tool = {name="Tag",					desc="Can make cells behave like an Enemy, Ally, or Player in Puzzle mode.", notcell=true},
	spikes_tool = {name="Spikes",			desc="Makes cells collide with other cells like an Enemy.", notcell=true},
	petrify_tool = {name="Petrify",			desc="Makes cells unbreakable.", notcell=true},
	goo_tool = {name="Goo",					desc="Makes cells frozen until moved.", notcell=true},
	compel_tool = {name="Compel",			desc="Applies the effect of a Compeller.", notcell=true},
	entangle_tool = {name="Entangle",		desc="Quantum-entangles cells.", notcell=true},
	input_tool = {name="Input Freeze",		desc="Causes cells to be unable to update unless they are clicked on.", notcell=true},
	permaclamp_tool = {name="Permaclamp",	desc="Makes a cell permanently resist a type of force.", notcell=true},
	ghost_tool = {name="Ghostify",			desc="Makes cells act like Ghost or Ungeneratable cells.", notcell=true},
}

function GetAttribute(id,attribute,...)
	return cellinfo[id] and get(cellinfo[id][attribute],...) or nil
end

function GetAttributeRaw(id,attribute)
	return cellinfo[id] and cellinfo[id][attribute] or nil
end

function MergeIntoInfo(attribute,t)
	for k,v in pairs(t) do
		cellinfo[k] = cellinfo[k] or {name="Placeholder A",desc="Cell info was not set for this id."}
		cellinfo[k][attribute] = v
	end
end

MergeIntoInfo("chunkid",{
	[23]=3,[40]=3,[113]=3,[26]=3,[27]=3,[110]=3,[111]=3,[167]=3,[168]=3,[169]=3,[170]=3,[171]=3,[172]=3,[173]=3,[174]=3,[301]=3,[342]=3,[363]=3,
	[364]=3,[365]=3,[366]=3,[393]=3,[395]=3,[646]=3,[652]=3,[701]=3,[749]=3,[750]=3,[751]=3,[752]=3,[753]=3,[754]=3,[755]=3,[756]=3,[757]=3,
	[758]=3,[759]=3,[760]=3,
	[46]=45,[302]=45,[343]=45,[394]=45,[396]=45,[397]=45,[398]=45,[399]=45,[866]=45,[867]=45,[868]=45,[869]=45,[870]=45,[871]=45,[872]=45,
	[873]=45,[874]=45,[875]=45,[876]=45,[877]=45,
	[56]=15,[80]=15,[315]=15,[316]=15,[445]=15,[446]=15,[478]=15,[479]=15,[489]=15,[490]=15,[491]=15,[492]=15,[658]=15,[659]=15,[660]=15,
	[661]=15,[662]=15,[663]=15,[664]=15,
	[10]=9,[11]=9,[57]=9,[70]=9,[66]=9,[67]=9,[68]=9,[245]=9,[246]=9,[247]=9,[552]=9,[957]=9,[958]=9,[959]=9,[960]=9,[961]=9,[962]=9,[963]=9,
	[994]=9,[995]=9,[996]=9,[997]=9,[998]=9,[999]=9,[1001]=9,[1002]=9,[1003]=9,[1004]=9,[1005]=9,[1006]=9,
	[62]=17,[63]=17,[64]=17,[65]=17,[741]=17,[989]=17,[990]=17,[991]=17,[992]=17,[993]=17,[1044]=17, 
	[89]=30,[90]=30,[640]=30,[654]=30,[655]=30,[656]=30,[713]=30,[1048]=30,[1049]=30,
	[213]=2,[269]=2,[303]=2,[304]=2,[346]=2,[352]=2,[423]=2,[700]=2,[718]=2,[781]=2,[863]=2,[864]=2,[865]=2,[904]=2,[905]=2,[1160]=2,
	[28]=14,[73]=14,[74]=14,[270]=14,[271]=14,[274]=14,[275]=14,[305]=14,[311]=14,[353]=14,[719]=14,[720]=14, 
	[72]=71,[272]=71,[273]=71,[354]=71,[400]=71,
	[59]=58,[60]=58,[61]=58,[75]=58,[76]=58,[77]=58,[78]=58,[276]=58,[277]=58,[278]=58,[279]=58,[280]=58,[281]=58,[282]=58,[283]=58,[355]=58,[1162]=58, 
	[356]=115,[786]=115,[787]=115,[820]=115,[903]=115,[906]=115,[1086]=115,[1087]=115,
	[160]=114,[161]=114,[175]=114,[178]=114,[179]=114,[180]=114,[181]=114,[182]=114,[183]=114,[184]=114,[185]=114,[206]=114,[242]=114,[243]=114,
	[319]=114,[357]=114,[358]=114,[359]=114,[362]=114,[367]=114,[368]=114,[424]=114,[454]=114,[456]=114,[500]=114,[603]=114,[704]=114,[597]=114,
	[598]=114,[599]=114,[600]=114,[792]=114,[793]=114,[794]=114,[795]=114,[800]=114,[801]=114,[802]=114,[803]=114,[821]=114,[822]=114,[823]=114,
	[108]=18,[322]=18,[324]=18,[469]=18,[471]=18,[473]=18,[475]=18,[482]=18,[485]=18,
	[109]=19,[323]=19,[325]=19,[470]=19,[472]=19,[474]=19,[476]=19,[483]=19,[486]=19,
	[450]=449,[451]=449,[452]=449,[484]=449,[487]=449,
	[969]=968,[970]=968,[971]=968,[972]=968,[973]=968,[974]=968,[975]=968,[976]=968,[977]=968,
	[1022]=1021,[1023]=1021,[1024]=1021,[1025]=1021,[1026]=1021,[1027]=1021,[1028]=1021,[1029]=1021,[1030]=1021,[1031]=1021,[1032]=1021,
	[124]=123,[125]=123,[126]=123,[127]=123,[128]=123,[129]=123,[130]=123,[131]=123,[132]=123,[133]=123,[134]=123,[135]=123,[149]=123,[211]=123,
	[212]=123,[369]=123,[371]=123,[373]=123,[375]=123,[377]=123,[379]=123,[567]=123,[604]=123,[808]=123,[809]=123,[810]=123,[811]=123,[812]=123,
	[813]=123,[1109]=123,[1111]=123,[1113]=123,[1125]=123,
	[234]=240,[241]=240,[602]=240,
	[112]=43,[145]=43,[136]=43,[137]=43,[138]=43,[139]=43,[232]=43,[252]=43,[253]=43,[308]=43,[309]=43,[310]=43,[522]=43,[523]=43,[524]=43,[535]=43,[715]=43,
	[588]=43,[619]=43,[647]=43,[648]=43,[649]=43,[650]=43,[651]=43,[736]=43,[745]=43,[788]=43,[789]=43,[790]=43,[791]=43,[824]=43,[825]=43,[896]=43,[935]=43,
	[967]=43,[1199]=43,
	[33]=32,[34]=32,[35]=32,[36]=32,[37]=32,[194]=32,[195]=32,[196]=32,[197]=32,[186]=32,[187]=32,[188]=32,[189]=32,[190]=32,[191]=32,[192]=32,[193]=32,
	[147]=146,[148]=146,[615]=146,[616]=146,[617]=146,
	[107]=106,[254]=106,[255]=106,[256]=106,[257]=106,[258]=106,[259]=106,[260]=106,[261]=106,[262]=106,[263]=106,[264]=106,[265]=106,
	[653]=106,[665]=106,[666]=106,[667]=106,[679]=106,[847]=106,[1152]=106,[1153]=106,
	[155]=44,[250]=44,[251]=44,[317]=44,
	[200]=199,[201]=199,[202]=199,[203]=199,[204]=199,
	[82]=81,[227]=81,[228]=81,
	[238]=237,[267]=237,[268]=237,[505]=237,[506]=237,[507]=237,[508]=237,[509]=237,[510]=237,[511]=237,[512]=237,[536]=237,[537]=237,[538]=237,
	[539]=237,[540]=237,[541]=237,[542]=237,[543]=237,[544]=237,[545]=237,[546]=237,[547]=237,[548]=237,[549]=237,[550]=237,[551]=237,[761]=237,[762]=237,
	[286]=25,[287]=25,[1164]=25,
	[288]=239,[289]=239,[290]=239,[291]=239,[292]=239,[293]=239,[294]=239,[295]=239,[296]=239,[297]=239,[298]=239,[614]=239,[829]=239,[830]=239,[845]=239,[846]=239,
	[307]=306,
	[314]=313,[480]=313,[481]=313,
	[320]=318,[453]=318,[455]=318,[589]=318,[590]=318,[591]=318,[592]=318,[593]=318,[594]=318,[595]=318,[596]=318,[796]=318,[797]=318,[798]=318,[799]=318,
	[804]=318,[805]=318,[806]=318,[807]=318,
	[345]=344,[672]=344,[814]=344,
	[408]=21,[409]=21,[410]=21,[411]=21,[763]=21,[764]=21,[765]=21,[766]=21,[767]=21,[1175]=21,[1176]=21,[1177]=21,[1178]=21,[1179]=21,
	[418]=417,[419]=417,[420]=417,[421]=417,
	[1100]=222,[1101]=222,[1102]=222,[1103]=222,
	[413]=29,[414]=29,[415]=29,[416]=29,[1012]=29,[1013]=29,[1014]=29,[1015]=29,[1016]=29,
	[1105]=1104,[1106]=1104,[1107]=1104,[1108]=1104,
	[404]=403,[405]=403,[406]=403,[407]=403,[498]=403,[499]=403,[501]=403,[502]=403,[503]=403,[504]=403,
	[494]=493,[495]=493,[496]=493,[497]=493,[919]=493,[920]=493,[921]=493,[922]=493,[923]=493,[924]=493,[925]=493,[926]=493,[927]=493,[928]=493,
	[942]=493,[943]=493,[944]=493,[945]=493,[946]=493,[947]=493,[948]=493,[949]=493,[950]=493,[951]=493,[952]=493,[953]=493,[954]=493,[955]=493,[956]=493,
	[1095]=493,[1096]=493,[1097]=493,[1098]=493,[1099]=493,
	[737]=425,[738]=425,[739]=425,[740]=425,[426]=425,[742]=425,[743]=425,[744]=425,
	[437]=436,
	[443]=442,[444]=442,[964]=442,
	[457]=55,[458]=55,[459]=55,[460]=55,[461]=55,[606]=55,[607]=55,[608]=55,[609]=55,[610]=55,[611]=55,[612]=55,[613]=55,[673]=55,[674]=55,[675]=55,
	[769]=55,[770]=55,[771]=55,[772]=55,[773]=55,[774]=55,[775]=55,[776]=55,[777]=55,[778]=55,[779]=55,[780]=55,[1089]=55,
	[1115]=448,
	[467]=465,[468]=465,
	[513]=177,[514]=177,[515]=177,[516]=177,[676]=177,[677]=177,[678]=177,[878]=177,[879]=177,[880]=177,
	[881]=177,[882]=177,[883]=177,[884]=177,[885]=177,[886]=177,[887]=177,[888]=177,[889]=177,[1090]=177,
	[518]=517,[519]=517,[520]=517,[521]=517,
	[525]=266,[826]=266,
	[527]=526,[528]=526,[529]=526,[530]=526,[531]=526,[532]=526,[533]=526,[534]=526,[235]=526,[427]=526,
	[1050]=526,[1051]=526,[1052]=526,[1053]=526,[1054]=526,[1055]=526,[1056]=526,[1057]=526,[1058]=526,
	[1059]=526,[1060]=526,[1061]=526,[1062]=526,[1063]=526,[1064]=526,[1065]=526,[1066]=526,[1067]=526,
	[1068]=526,[1069]=526,[1070]=526,[1071]=526,[1072]=526,[1073]=526,[1074]=526,[1075]=526,[1076]=526,
	[570]=569,[571]=569,[572]=569,[573]=569,[574]=569,[575]=569,[576]=569,[577]=569,[578]=569,[579]=569,[580]=569,[581]=569,[582]=569,
	[605]=568,
	[627]=625,[632]=625,[634]=625,[636]=625,[642]=625,
	[628]=626,[633]=626,[635]=626,[637]=626,
	[630]=629,[657]=629,
	[714]=641,
	[721]=50,[722]=50,[723]=50,[724]=50,
	[725]=435,[726]=435,[727]=435,[728]=435,
	[729]=248,[730]=248,[731]=248,[732]=248,
	[828]=827,[838]=827,[839]=827,
	[834]=833,[835]=833,[836]=833,[837]=833,
	[909]=908,
	[985]=984,[986]=984,[987]=984,[988]=984,
	[1008]=1007,[1009]=1007,[1010]=1007,[1011]=1007,
	[1034]=1033,[1035]=1033,[1036]=1033,[1037]=1033,
	[1039]=1038,[1040]=1038,[1041]=1038,[1042]=1038,
	[1078]=1077,[1079]=1077,[1080]=1077,[1081]=1077,[1082]=1077,
	[1119]=1118,[1120]=1118,[1121]=1118,
	[1134]=1133,[1135]=1133,[1136]=1133,[1137]=1133,[1138]=1133,[1139]=1133,[1140]=1133,[1141]=1133,
	[1142]=1133,[1143]=1133,[1144]=1133,[1145]=1133,[1146]=1133,[1147]=1133,[1148]=1133,[236]=1133,[1149]=1133,
	[1158]=1157,
	[1161]=284,
	[1168]=1167,[1169]=1167,[1170]=1167,
	[1173]=1172,
	[1188]=1187,[1189]=1187,[1190]=1187,
	[1150]="compel",[1151]="compel",
})

function ChunkId(id)
	return GetAttribute(id, "chunkid") or id
end

MergeIntoInfo("isenemy",{
	[13]=true,[24]=true,[163]=true,[164]=true,[244]=true,[299]=true,[326]=true,[360]=true,[361]=true,[827]=true,[828]=true,[838]=true,[839]=true,[1172]=true,
})
function IsEnemy(cell)
	return GetAttribute(cell.id, "isenemy", cell) or cell.vars.tag == 1 and cell.id ~= 0
end

MergeIntoInfo("isally",{
	[768]=true,[1165]=true,[1173]=true,
})
function IsAlly(cell)
	return GetAttribute(cell.id, "isally", cell) or cell.vars.tag == 2 and cell.id ~= 0
end

MergeIntoInfo("isneutral",{
	[239]=true,[288]=true,[289]=true,[290]=true,[291]=true,[292]=true,[293]=true,[294]=true,[295]=true,
	[296]=true,[297]=true,[298]=true,[614]=true,[829]=true,[830]=true,[845]=true,[846]=true,
	[907]=true,[1166]=true,
	[552]=function(c) return c.vars[26] == 1 end,
})
function IsNeutral(cell)
	return GetAttribute(cell.id, "isneutral", cell) or cell.vars.tag == 3 and cell.id ~= 0
end

MergeIntoInfo("isunfriendly",{
	[160]=true,[358]=true,[359]=true,[367]=true,[368]=true,
	[319]=true,[792]=true,[793]=true,[794]=true,[795]=true,
	[318]=true,[589]=true,[590]=true,[591]=true,[592]=true,
	[320]=true,[796]=true,[797]=true,[798]=true,[799]=true,
	[1167]=true,[1168]=true,
	[846]=function(c) return c.vars[1] ~= 846 and c.vars[1] and IsUnfriendly({id=c.vars[1],rot=c.rot,vars=DefaultVars(c.vars[1])}) end,
})
function IsUnfriendly(cell)
	return IsEnemy(cell) or GetAttribute(cell.id, "isunfriendly", cell)
end

MergeIntoInfo("isfriendly",{
	[239]=true,[289]=true,[290]=true,[291]=true,[297]=true,[292]=true,[288]=true,[293]=true,[294]=true,
	[295]=true,[298]=true,[296]=true,[321]=true,[614]=true,[829]=true,[830]=true,[845]=true,
	[456]=true,[597]=true,[598]=true,[599]=true,[600]=true,
	[454]=true,[800]=true,[801]=true,[802]=true,[803]=true,
	[453]=true,[593]=true,[594]=true,[595]=true,[596]=true,
	[455]=true,[804]=true,[805]=true,[806]=true,[807]=true,
	[1169]=true,[1170]=true,
	[552]=function(c) return c.vars[26] == 1 end,
	[846]=function(c) return c.vars[1] ~= 846 and c.vars[1] and IsFriendly({id=c.vars[1],rot=c.rot,vars=DefaultVars(c.vars[1])}) or (not c.vars[1] or c.vars[1] == 846) and true end,
})
function IsFriendly(cell)
	return IsAlly(cell) or GetAttribute(cell.id, "isfriendly", cell)
end

--"will missile crash into anything it heads towards instead of turning away"
MergeIntoInfo("isunsmartmissile",{
	[160]=true,[358]=true,[367]=true,[368]=true,[359]=true,[456]=true,[597]=true,[598]=true,[599]=true,[600]=true,
})
function IsUnsmartMissile(cell)
	return GetAttribute(cell.id, "isunsmartmissile", cell)
end

MergeIntoInfo("isinvisibletoseekers",{
	[735]=true,[815]=true,[816]=true,[817]=true,[819]=true,[1116]=true,[1155]=true,
})
function IsInvisibleToSeekers(cell)
	return GetAttribute(cell.id, "isinvisibletoseekers", cell)
end

MergeIntoInfo("llueaeats",{
	[47]=true,[123]=true,[124]=true,[125]=true,[126]=true,[127]=true,[128]=true,[129]=true,[130]=true,
	[131]=true,[132]=true,[133]=true,[134]=true,[135]=true,[149]=true,[176]=true,[212]=true,[369]=true,
	[371]=true,[373]=true,[161]=true,[369]=true,[370]=true,[371]=true,[372]=true,[373]=true,[374]=true,
	[375]=true,[376]=true,[377]=true,[378]=true,[379]=true,[380]=true,[567]=true,[568]=true,[604]=true,
	[605]=true,[808]=true,[809]=true,[810]=true,[811]=true,[812]=true,[813]=true,[1109]=true,[1110]=true,
	[1111]=true,[1112]=true,[1113]=true,[1114]=true,[1125]=true,[1154]=true,
	[351] = function(c,d,x,y) return c.vars[ToSide(c.rot,d)+1] == 18 end,
	[552] = function(c,d,x,y) return c.vars[ToSide(c.rot,d)+1] == 18 end,
})
function LlueaEats(cell,dir,x,y)
	return GetAttribute(cell.id, "llueaeats", cell,dir,x,y)
end 

MergeIntoInfo("isgear",{
	[18]=true,[108]=true,[322]=true,[324]=true,[469]=true,[471]=true,[473]=true,[475]=true,[482]=true,[485]=true,
	[19]=true,[109]=true,[323]=true,[325]=true,[470]=true,[472]=true,[474]=true,[476]=true,[483]=true,[486]=true,
	[449]=true,[450]=true,[451]=true,[452]=true,[484]=true,[487]=true,
	[968]=true,[969]=true,[970]=true,[971]=true,[972]=true,[973]=true,[974]=true,[975]=true,[976]=true,[977]=true,
	[1021]=true,[1022]=true,[1023]=true,[1024]=true,[1025]=true,[1026]=true,[1027]=true,[1028]=true,[1029]=true,[1030]=true,[1031]=true,[1032]=true,
})
function IsGear(cell,dir,x,y)
	return GetAttribute(cell.id, "isgear", cell,dir,x,y)
end 

function OmnicellIsInverted(cell,dir,x,y)
	return cell.vars[ToSide(cell.rot,dir)+1] == 19
end
MergeIntoInfo("isinverted",{
	[401]=true,
	[351]=OmnicellIsInverted,[552]=OmnicellIsInverted,
})
function IsInverted(cell,dir,x,y)
	return GetAttribute(cell.id, "isinverted", cell,dir,x,y)
end 

MergeIntoInfo("ismulticell",{
	[23]=true,[168]=true,[167]=true,[169]=true,[170]=true,[172]=true,[171]=true,[173]=true,[174]=true,[363]=true,[364]=true,
	[570]=true,[573]=true,[574]=true,[575]=true,[576]=true,[579]=true,[580]=true,[581]=true,[582]=true,
	[238]=true,[536]=true,[537]=true,[538]=true,[539]=true,[540]=true,[541]=true,[542]=true,[543]=true,
	[268]=true,[544]=true,[545]=true,[546]=true,[547]=true,[548]=true,[549]=true,[550]=true,[551]=true,
	[457]=true,[606]=true,[607]=true,[608]=true,[609]=true,[610]=true,[611]=true,[612]=true,[613]=true,
	--one-sided (just for ease of keeping track)
	[46]=true,[397]=true,[398]=true,[399]=true,[513]=true,[514]=true,[515]=true,[516]=true,[235]=true,[427]=true,
	[527]=true,[528]=true,[529]=true,[530]=true,[531]=true,[532]=true,[533]=true,[534]=true,
	[155]=true,[250]=true,[317]=true,[251]=true,[408]=true,[409]=true,[410]=true,[411]=true,
	[413]=true,[414]=true,[415]=true,[416]=true,[518]=true,[519]=true,[520]=true,[521]=true,
	[148]=true,[615]=true,[616]=true,[617]=true,[627]=true,[632]=true,[634]=true,[636]=true,
	[628]=true,[633]=true,[635]=true,[637]=true,[721]=true,[722]=true,[723]=true,[724]=true,
	[725]=true,[726]=true,[727]=true,[728]=true,[729]=true,[730]=true,[731]=true,[732]=true,
	[425]=true,[738]=true,[739]=true,[740]=true,[426]=true,[742]=true,[743]=true,[744]=true,
	[834]=true,[835]=true,[836]=true,[837]=true,[866]=true,[867]=true,[868]=true,[869]=true,
	[870]=true,[871]=true,[872]=true,[873]=true,[874]=true,[875]=true,[876]=true,[877]=true,
	[878]=true,[879]=true,[880]=true,[881]=true,[882]=true,[883]=true,[884]=true,[885]=true,
	[886]=true,[887]=true,[888]=true,[889]=true,[493]=true,[494]=true,[496]=true,[497]=true,
	[764]=true,[765]=true,[766]=true,[767]=true,[919]=true,[920]=true,[922]=true,[923]=true,
	[924]=true,[925]=true,[927]=true,[928]=true,[942]=true,[943]=true,[945]=true,[946]=true,
	[947]=true,[948]=true,[950]=true,[951]=true,[952]=true,[953]=true,[955]=true,[956]=true,
	[985]=true,[986]=true,[987]=true,[988]=true,[1008]=true,[1009]=true,[1010]=true,[1011]=true,
	[1013]=true,[1014]=true,[1015]=true,[1016]=true,
	[1034]=true,[1035]=true,[1036]=true,[1037]=true,[1039]=true,[1040]=true,[1041]=true,[1042]=true,
	[1051]=true,[1052]=true,[1053]=true,[1054]=true,[1055]=true,[1056]=true,[1057]=true,[1058]=true,
	[1060]=true,[1061]=true,[1062]=true,[1063]=true,[1064]=true,[1065]=true,[1066]=true,[1067]=true,
	[1069]=true,[1070]=true,[1071]=true,[1072]=true,[1073]=true,[1074]=true,[1075]=true,[1076]=true,
	[1095]=true,[1096]=true,[1098]=true,[1099]=true,
})
function IsMultiCell(id)
	return GetAttribute(id, "ismulticell")
end 

MergeIntoInfo("istool",{
	paint=true,invertcolorpaint=true,invertpaint=true,hsvpaint=true,inverthsvpaint=true,invispaint=true,shadowpaint=true,blendmode=true,
	timerep_tool=true,grav_tool=true,prot_tool=true,armor_tool=true,bolt_tool=true,coin_tool=true,tag_tool=true,spikes_tool=true,
	petrify_tool=true,goo_tool=true,compel_tool=true,entangle_tool=true,input_tool=true,permaclamp_tool=true,ghost_tool=true,
})
function IsTool(id)
	return GetAttribute(id, "istool")
end

MergeIntoInfo("iscellholder",{
	[165]=true,[166]=true,[175]=true,[198]=true,[211]=true,[212]=true,[235]=true,[341]=true,[362]=true,[425]=true,[426]=true,
	[427]=true,[526]=true,[527]=true,[528]=true,[529]=true,[530]=true,[531]=true,[532]=true,[533]=true,[534]=true,[645]=true,
	[652]=true,[653]=true,[704]=true,[737]=true,[738]=true,[739]=true,[740]=true,[742]=true,[743]=true,[744]=true,[761]=true,
	[762]=true,[821]=true,[822]=true,[823]=true,[831]=true,[905]=true,[918]=true,[1043]=true,
	[1050]=true,[1051]=true,[1052]=true,[1053]=true,[1054]=true,[1055]=true,[1056]=true,[1057]=true,[1058]=true,
	[1059]=true,[1060]=true,[1061]=true,[1062]=true,[1063]=true,[1064]=true,[1065]=true,[1066]=true,[1067]=true,
	[1068]=true,[1069]=true,[1070]=true,[1071]=true,[1072]=true,[1073]=true,[1074]=true,[1075]=true,[1076]=true,
	[1083]=true,[1088]=true,[1150]=true,[1151]=true,[1154]=true,
})
function IsCellHolder(id)
	return GetAttribute(id, "iscellholder")
end

function ClickDraggable(c,b,x,y)
	if b == 1 and not isinitial then
		draggedx,draggedy = x,y
		return true
	end
end
function ClickEnemy(c,b,x,y)
	if b == 1 and not isinitial then
		SetCell(x,y,getempty())
		EmitParticles("player",x,y)
		Play("destroy")
		return true
	end
end
function ClickDoor(c,b,x,y)
	if b == 1 and not isinitial then
		c.id = c.id == 916 and 917 or 916
		return true
	end
end
function ClickFilter(c,b,x,y)
	if b == 1 then
		if chosen.id == 0 then
			if c.vars[1] then
				c.vars[1] = nil
				if isinitial then initiallayers[0][y][x].vars[1] = nil end
				placecells = false
				return true
			end
		elseif GetLayer(chosen.id) == 0 then
			c.vars[1] = chosen.id
			if isinitial then initiallayers[0][y][x].vars[1] = chosen.id end
			placecells = false
			return true
		end
	else
		if c.vars[1] then
			c.vars[1] = nil
			if isinitial then initiallayers[0][y][x].vars[1] = nil end
			placecells = false
			return true
		end
	end
end
function ClickStorage(c,b,x,y)
	if b == 1 and not isinitial then
		if c.vars[1] then
			SetCell(x,y,GetStoredCell(c,false,{c}))
		else
			SetCell(x,y,getempty({c}))
		end
		return true
	end
end
MergeIntoInfo("onclick",{
	[233]=ClickFilter,[601]=ClickFilter,
	[910]=ClickDraggable,[911]=ClickDraggable,[912]=ClickDraggable,[913]=ClickDraggable,[914]=ClickDraggable,
	[915]=ClickEnemy,
	[916]=ClickDoor,[917]=ClickDoor,
	[918]=ClickStorage,
})
function OnClick(cell, btn, x, y)
	local override = GetAttribute(cell.id,"onclick",cell,btn,x,y)
	if override then return override
	elseif cell.vars.input and not isinitial then
		cell.clicked = true
		return true
	end
end

layernames = {
	[-1]="Background",[0]="Foreground",[1]="Above",
}

MergeIntoInfo("layer",{
	placeable=-1,placeableW=-1,placeableR=-1,placeableO=-1,placeableY=-1,
	placeableG=-1,placeableC=-1,placeableB=-1,placeableP=-1,rotatable=-1,
	rotatable180=-1,hflippable=-1,vflippable=-1,duflippable=-1,ddflippable=-1,
	bggrass=-1,bgdirt=-1,bgstone=-1,bgcobble=-1,bgsand=-1,bgsnow=-1,bgice=-1,bgmagma=-1,bgwood=-1,bgwool=-1,
	bgplate=-1,bgmossystone=-1,bgcopper=-1,bgsilver=-1,bggold=-1,bgspace=-1,bgmatrix=-1,bgvoid=-1,
	[553]=1,[554]=1,[555]=1,[556]=1,[557]=1,[558]=1,[559]=1,[560]=1,[561]=1,[562]=1,[564]=1,[565]=1,[566]=1,	
	[684]=1,[685]=1,[686]=1,[687]=1,[688]=1,[689]=1,[690]=1,[691]=1,[692]=1,[693]=1,[706]=1,[707]=1,[708]=1,
	[916]=1,[917]=1,[1118]=1,[1119]=1,[1120]=1,[1121]=1,[1122]=1,[1123]=1,[1124]=1,
})
function GetLayer(id)
	return GetAttribute(id, "layer") or 0
end

overrides = {}	--for mods
function Override(id,...)
	local has = overrides[id]
	if has then
		has(...)
		return true
	end
end

function SetOverride(funcname,id,func)
	overrides[funcname..id] = func
end

--buttons (and cell list) setup

buttons = {}
buttonorder = {}

--note that x and y will flip which direction they go towards depending on alignment (they increase away from the sides that the button is aligned to; if centered, goes right and down)
--[[ priority ranges
0 - 999 = Editor HUD
1000 - 1499 = Cell HUD
1500 - 1999 = Property Menu
2000 - 2999 = Pause Menu
3000+ = Main Menu
]]
function NewButton(x,y,w,h,icon,key,name,desc,onclick,ishold,enabledwhen,align,priority,rot,color,hovercolor,clickcolor,drawfunc,updatefunc)
	local button = {x=x,y=y,w=w,h=h,rot=rot,icon=icon,name=name,desc=desc,onclick=onclick,ishold=ishold,isenabled=(enabledwhen == nil and true or enabledwhen),priority=priority,color=color,hovercolor=hovercolor,clickcolor=clickcolor,drawfunc=drawfunc,editfunc=editfunc}
	button.color = color or {1,1,1,.5}
	button.hovercolor = hovercolor or {1,1,1,1}
	button.clickcolor = clickcolor or {.5,.5,.5,1}
	button.halign = (align == "bottomleft" or align == "left" or align == "topleft") and -1 or (align == "bottomright" or align == "right" or align == "topright") and 1 or 0
	button.valign = (align == "topleft" or align == "top" or align == "topright") and -1 or (align == "bottomleft" or align == "bottom" or align == "bottomright") and 1 or 0
	if not buttons[key] then
		for i=1,#buttonorder+1 do
			if not buttons[buttonorder[i]] or buttons[buttonorder[i]].priority > button.priority then
				table.insert(buttonorder,i,key)
				break
			end
		end
	end
	buttons[key] = button
	return button
end

cat = {}
cat.paints = {name = "Paints",max=4,"paint","invertcolorpaint","invertpaint","invispaint","shadowpaint","hsvpaint","inverthsvpaint","blendmode"}
cat.tool_effects = {name = "Effects",max=4,"timerep_tool","grav_tool","armor_tool","bolt_tool","permaclamp_tool","prot_tool","petrify_tool","goo_tool","compel_tool","spikes_tool","tag_tool","ghost_tool","entangle_tool","input_tool","coin_tool"}

cat.walls = {name = "Walls",max=6,1,41,126,154,229,1088,150,151,152,965,709,710,1046,1117,162,566,564,565,706,707,916,917,351,552}
cat.pushables = {name = "Pushables",max=5,4,5,6,7,8,159,69,157,140,158,214,215,216,217,218,618,620,621,622,623,840,841,842,843,844,910,911,912,913,914}
cat.oppositions = {name = "Oppositions",max=6,696,697,698,699,936,937,52,53,54}
cat.weights = {name = "Weights",max=4,22,103,144,104,1182,1183,668,42,631,638,639,1184,142,143,1194,1185,1191,1195,1192,1196,669,1193,1187,1188,1189,1190,1197,1198,351,552}
cat.sticky = {name = "Sticky",max=5,252,647,648,788,789,649,650,651,790,791,207,231,249}
cat.extensions = {name = "Extensions",max=4,466,464,477}
cat.input = {name = "Input",max=5,910,911,912,913,914,915,916,917,918}
cat.decorative = {name = "Decorative",max=11,116,117,118,119,120,121,122,680,681,682,683,684,685,686,687,688,689,690,691,692,693,708,929,930,1186,931,932,1156,1171,933,934,1174,938,939,940,941}

cat.pushers = {name = "Pushers",max=4,2,28,72,74,59,60,76,78,269,271,273,275,277,279,281,283,213,284,346,304,311,303,400,206,781,700,718,720,863,423,865,864,904,905,1160,1161,352,552}
cat.pullers = {name = "Pullers",max=4,14,28,73,74,61,60,77,78,270,271,274,275,278,279,282,283,305,311,719,720,353,552}
cat.grabbers = {name = "Grabbers",max=4,71,72,73,74,75,76,77,78,272,273,274,275,280,281,282,283,400,354,552}
cat.drillers = {name = "Drillers",max=4,58,59,61,60,75,76,77,78,276,277,278,279,280,281,282,283,1162,355,552}
cat.slicers = {name = "Slicers",max=4,115,269,270,271,272,273,274,275,276,277,278,279,280,281,282,283,1086,1087,906,786,787,356,552}
cat.scissors = {name = "Scissors",max=4,178,179,182,183,180,181,184,185}
cat.missiles = {name = "Missiles",max=5,160,358,359,367,368,319,792,793,794,795,456,597,598,599,600,454,800,801,802,803}
cat.movers_other = {name = "Other",max=8,114,357,161,424,175,821,822,823,362,905,704,820,903,904,306,307,242,243,603,500,1167,1168,1169,1170,552}
cat.players = {name = "Players",max=7,239,829,289,290,291,297,292,288,830,293,294,295,298,296,614,845,846,321,552}
cat.particles = {name = "Particles",max=9,236,1133,1135,1145,1137,1139,1141,1143,1147,1149,1134,1136,1146,1138,1140,1142,1144,1148}

cat.generators = {name = "Generators",max=4,3,23,26,27,168,167,169,170,363,364,110,111,172,171,173,174,40,113,365,366,147,301,166,652,646,701}
cat.physicalgenerators = {name = "Physical Generators",max=10,342,749,750,751,752,673,769,770,771,772,395,753,754,755,756,674,773,774,775,776,393,757,758,759,760,675,777,778,779,780}
cat.supergenerators = {name = "Super Generators",max=4,55,457,458,459,606,607,608,609,460,461,610,611,612,613,1089,1115,448}
cat.replicators = {name = "Replicators",max=10,{45,46,397,398,399,177,513,514,515,516},{343,866,869,872,875,676,878,881,884,887},{396,867,870,873,876,677,879,882,885,888},{394,868,871,874,877,678,880,883,886,889},302,1090,341}
cat.builders = {name = "Builders",max=4,327,328,329,330,331,332,333,334,335,336,337,338,339,340,229,1088}
cat.makers = {name = "Makers",max=9,{526,527,528,529,530,531,532,533,534},{1050,1051,1052,1053,1054,1055,1056,1057,1058},{1059,1060,1061,1062,1063,1064,1065,1066,1067},{1068,1069,1070,1071,1072,1073,1074,1075,1076},235,427}
cat.gates = {name = "Gates",max=5,32,33,34,194,195,35,36,37,196,197}
cat.sentries = {name = "Sentries",max=5,318,589,590,591,592,320,796,797,798,799,453,593,594,595,596,455,804,805,806,807}
cat.generators_other = {name = "Other",max=4,412}

cat.rotators = {name = "Rotators",max=8,{9,10,11,960,66,67,68,961},{994,995,996,997,998,999,1001,1002},{1003,1004,1005,1006,245,246,247,962},{957,958,959,963,442,443,444,964},{150,151,152,965,585,586,587,966},{1126,1127,1128,1129,522,523,524,967},57,70,552}
cat.flippers = {name = "Flippers",max=5,{30,89,90,640,1048},{641,709,711,1130,535},{654,655,656,713,1049},{714,710,712,1131,715}}
cat.redirectors = {name = "Redirectors",max=5,17,62,63,64,65,741,1044,1045,1046,1047,1132,989,990,991,992,993}
cat.orientators = {name = "Orientators",max=4,569,570,571,572,573,574,575,576,577,578,579,580,581,582}
cat.rotators_other = {name = "Other",max=4,105,583,447,462}

cat.repulsors = {name = "Repulsors",max=5,{21,408,409,410,411},{763,764,765,766,767},{50,721,722,723,724},{222,1100,1101,1102,1103},{417,418,419,420,421},{435,725,726,727,728},{984,985,986,987,988},{1175,1176,1177,1178,1179}}
cat.impulsors = {name = "Impulsors",max=5,{29,413,414,415,416},{1012,1013,1014,1015,1016},{248,729,730,731,732},{1104,1105,1106,1107,1108},{1007,1008,1009,1010,1011},{984,985,986,987,988}}
cat.grapulsors = {name = "Grapulsors",max=4,81,82,227,228}
cat.mirrors = {name = "Mirrors",max=5,{15,56,80,315,316},{489,490,491,492,478},{629,630,657,313,314},{445,446,660,658,659},{661,662,663,664,479},480,481}
cat.crystals = {name = "Crystals",max=5,{403,404,405,406,407},{498,499,501,502,503},504}
cat.gems = {name = "Gems",max=5,{493,494,495,496,497},{919,920,921,922,923},{924,925,926,927,928},{942,943,944,945,946},{947,948,949,950,951},{952,953,954,955,956},{1095,1096,1097,1098,1099}}
cat.cyclers = {name = "Cyclers",max=5,{625,627,632,634,636},{626,628,633,635,637},642}
cat.gears = {name = "Gears",max=5,{18,469,473,108,482},{322,471,475,324,485},{19,470,474,109,483},{323,472,476,325,486},{968,969,970,971,972},{973,974,975,976,977},{449,450,484,451,452,487},{1021,1022,1023,1024,1025,1026},{1027,1028,1029,1030,1031,1032}}
cat.intakers = {name = "Intakers",max=5,{44,155,250,317,251},{517,518,519,520,521}}
cat.shifters = {name = "Shifters",max=4,106,107,254,255,256,257,259,258,260,261,262,263,265,264,679,847,653,665,666,667,1152,1153}
cat.forcers_other = {name = "Other",max=5,156}

cat.divergers = {name = "Divergers",max=8,16,31,429,430,38,39,208,209,93,94,83,433,84,85,91,92,431,432,95,96,86,434,87,88,300,210,233,601,488,224,702,703,980,982,981,983,1084,1085,351,552}
cat.forkers = {name = "Forkers",max=6,48,49,97,98,782,784,99,100,101,102,783,785}
cat.spooners = {name = "Spooners",max=4,186,187,188,189,190,191,192,193}
cat.slopes = {name = "Slopes",max=4,381,382,383,978,390,391,392,979,1017,1018,1019,1020,1091,1092,1093,1094}
cat.paraboles = {name = "Paraboles",max=4,384,385,388,389,386,387}
cat.divergers_other = {name = "Other",max=5,221,428,746,747,748,79}

cat.trashes = {name = "Trashes",max=4,12,225,226,205,347,349,694,695,438,439,440,441,348,350,733,734,463,856,890,891,892,893,894,895,436,437,176,300,563,908,909,351,552}
cat.demolishers = {name = "Demolishers",max=4,51,141,670,671,848,849,854,855,850,851,852,853,859,860,861,862,857,858,897,898,899,900,901,902}
cat.enemies = {name = "Enemies",max=4,13,24,163,164,360,361,244,299,827,828,838,839,1172,768,1165,1173,907,1166,915,1000,1167,1168,1169,1170,326,831,351,552}
cat.acids = {name = "Acids",max=4,220,219,717,716,863,423,865,864,351,552}
cat.fire = {name = "Fire",max=4,240,241,602,234,242,243,603}
cat.deleters = {name = "Deleters",max=5,1033,1034,1035,1036,1037,1038,1039,1040,1041,1042}
cat.sappers = {name = "Sappers",max=3,465,467,468}

cat.transformers = {name="Transformers",max=4,237,238,505,506,536,537,538,539,507,508,540,541,542,543,761}
cat.transmutators = {name="Transmutators",max=4,267,268,509,510,544,545,546,547,511,512,548,549,550,551,762}
cat.midases = {name="Midases",max=5,737,738,739,740,425,{742,743,744,426}}
cat.worms = {name="Worms",max=4,1077,1078,1079,1080,1081,1082}
cat.timewarpers = {name="Timewarpers",max=5,146,148,615,616,617,833,834,835,836,837}

cat.generation = {name="Generation",max=4,20,643,644,645}
cat.effects = {name="Effect Givers",max=5,25,286,287,1164,285,43,145,308,309,619,112,1199,136,137,138,139,253,935,310,522,523,524,967,535,715,525,232,588,266,424,252,647,648,788,789,649,650,651,790,791,824,825,826,736,896,745,105,583}
cat.infectious = {name="Infectious",max=6,47,126,176,149,161,211,123,127,128,124,129,130,125,131,132,134,135,133,808,809,810,811,812,813,371,373,369,377,379,375,1111,1113,1109,567,604,1125,1154}
cat.unlocking = {name="Unlocking",max=3,153,584,154,705,706,707,563,564,565}
cat.storage = {name="Storage",max=4,165,362,905,704,175,821,822,823,198,1043,831,645,1154,1150,1151,1083,918}
cat.ai = {name="AI",max=3,206,211,624}
cat.gizmos = {name = "Gizmos",max=5,344,345,672,814,818,815,817,816,1155,1116,1117,1159,1163,1157,1158}
cat.misc_other = {name = "Other",max=4,312,422,402,832,401,351,552}
cat.oneways = {name = "One-ways",max=5,553,554,555,556,557,558,559,560,561,562}
cat.zones = {name = "Zones",max=4,1118,1119,1120,1121,1122,1123,1124}
cat.collectable = {name="Collectable",max=3,223,224,230,1180,1181}

cat.placeables = {name="Placeables",max=3,"placeable","placeableW","placeableR","placeableO","placeableY","placeableG","placeableC","placeableB","placeableP"}
cat.rotatables = {name="Rotatables",max=4,{"rotatable","rotatable180"},{"hflippable","vflippable","duflippable","ddflippable"}}
cat.decorative_bg = {name="Decorative",max=4,"bggrass","bgdirt","bgstone","bgcobble","bgsand","bgsnow","bgice","bgmagma","bgwood","bgwool","bgplate","bgmossystone","bgcopper","bgsilver","bggold","bgspace","bgmatrix","bgvoid"}

cat.truecells = {name="True Cells",max=3,199,200,201,202,203,204}

lists = {}
lists[0] = {name = "Tools", cells = {max=99,"eraser",cat.paints,cat.tool_effects}, desc = "They aren't cells, but they do modify the world.", icon = "eraser"}
lists[1] = {name = "Basic", cells = {max=4,cat.walls,cat.pushables,cat.oppositions,cat.weights,cat.sticky,cat.extensions,cat.input,cat.decorative}, desc = "'Basic' cells.", icon = 4}
lists[2] = {name = "Movers", cells = {max=4,cat.pushers,cat.pullers,cat.grabbers,cat.drillers,cat.slicers,cat.scissors,cat.missiles,cat.movers_other,cat.players,cat.particles}, desc = "Can move on their own, usually with a certain type of force.", icon = 2}
lists[3] = {name = "Generators", cells = {max=4,cat.generators,cat.supergenerators,cat.physicalgenerators,cat.replicators,cat.builders,cat.makers,cat.gates,cat.generators_other}, desc = "Create or duplicate cells.", icon = 3}
lists[4] = {name = "Rotators", cells = {max=3,cat.rotators,cat.flippers,cat.redirectors,cat.orientators,cat.gears,cat.rotators_other}, desc = "Rotate other cells.", icon = 9}
lists[5] = {name = "Forcers", cells = {max=5,cat.repulsors,cat.impulsors,cat.grapulsors,cat.mirrors,cat.crystals,cat.gems,cat.cyclers,cat.gears,cat.intakers,cat.shifters,cat.forcers_other}, desc = "Still cells that generate a force.", icon = 21}
lists[6] = {name = "Divergers", cells  = {max=4,cat.divergers,cat.forkers,cat.spooners,cat.slopes,cat.paraboles,cat.divergers_other}, desc = "Causes whatever comes in to diverge to a different path.", icon = 16}
lists[7] = {name = "Destroyers", cells = {max=4,cat.trashes,cat.demolishers,cat.enemies,cat.missiles,cat.sentries,cat.acids,cat.fire,cat.deleters,cat.intakers,cat.sappers}, desc = "Destroy other cells.", icon = 12}
lists[8] = {name = "Transformers", cells = {max=4,cat.transformers,cat.transmutators,cat.midases,cat.worms,cat.timewarpers}, desc = "Transform cells into other cells.", icon = 237}
lists[9] = {name = "Miscellaneous", cells = {max=4,cat.generation,cat.infectious,cat.effects,cat.unlocking,cat.storage,cat.ai,cat.gizmos,cat.misc_other,cat.oneways,cat.zones,cat.collectable}, desc = "The ones that don't fit into another category.", icon = 20}
lists[10] = {name = "Backgrounds", cells = {max=3,cat.placeables,cat.rotatables,cat.decorative_bg}, desc = "Backgrounds that go behind cells. Usually used for Puzzle Mode.", icon = "placeableW"}
lists[11] = {name = "Cheats", cells = {max=99,cat.truecells,1200}, desc = "Cells that should not be used for making or breaking vaults.\nUse of these cells might cause bugs, so be careful.", icon = 199}

function hudrotation()
	return math.graphiclerp(hudrot,hudrot+((chosen.rot-hudrot+2)%4-2),hudlerp)*math.halfpi
end
lastselects = {}
propertiesopen = 0
function MakePropertyMenu(properties,b)
	propertiesopen = #properties
	local effectivepropamount = 0
	for i=1,#properties do
		effectivepropamount = effectivepropamount + (properties[i].height or 1)
	end
	buttons.propertybg.h = math.min(effectivepropamount,properties.max or 5)*25+30
	buttons.propertybg.w = math.ceil(effectivepropamount/(properties.max or 5))*145+5
	local x,y
	if b.halign == 1 then
		x = 800*winxm-b.x-170
		y = b.y
	else
		x = b.x-buttons.propertybg.w/2+10
		y = b.y+20
	end
	x = math.max(math.min(x,love.graphics.getWidth()-buttons.propertybg.w),0)
	y = math.max(math.min(y,love.graphics.getHeight()-buttons.propertybg.h),0)
	buttons.propertybg.x = x
	buttons.propertybg.y = y
	NewButton(x-25+buttons.propertybg.w,y-25+buttons.propertybg.h,20,20,11,"propertyreset","Reset to Defaults",nil,function() for i=1,#properties do chosen.data[i] = properties[i].default or (properties[i].type == "text" and "" or math.max(0,properties[i][2] or 0)) end end,nil,function() return not puzzle and propertiesopen > 0 end,"bottomleft",1500)
	local effectivei = 1
	for i=1,#properties do
		local bx = math.ceil(effectivei/(properties.max or 5))-1
		local by = (effectivei-1)%(properties.max or 5)+1
		local property = properties[i]
		if property.type == "text" then
			if type(chosen.data[i]) ~= "string" or property.max and string.len(chosen.data[i]) > property.max then
				chosen.data[i] = property.default or ""
			end
			local b = NewButton(x+5+bx*145,y+(math.min(#properties,properties.max or 5)-by+1)*25-20,140,25*(property.height or 1)-5,"pix","propertytype"..i,nil,nil,function() typing = i end,nil,function() return not puzzle and propertiesopen >= i end,"bottomleft",1500,nil,{.15,.15,.15,1},{.15,.15,.15,1},{.15,.15,.15,1})
			NewButton(x+5+bx*145,y+(math.min(#properties,properties.max or 5)-by+1)*25-99999,140,20,"pix","propertysub"..i,nil,nil,function() end,nil,function() return not puzzle and propertiesopen >= i end,"bottomleft",1500)
			NewButton(x-99999,y+(math.min(#properties,properties.max or 5)-by+1)*25-99999,0,0,"pix","propertyadd"..i,nil,nil,function() end,nil,function() return not puzzle and propertiesopen >= i end,"bottomleft",1500)
			b.drawfunc = function(x,y,b)
							love.graphics.setColor(1,1,1,1)
							love.graphics.printf(property[1]..chosen.data[i],x+50*uiscale-b.w/2*uiscale,y-(12.5*(property.height or 1)-7.5)*uiscale,140,"center",0,uiscale,uiscale,50,0)
						end
			effectivei = effectivei + (property.height or 1)
		else
			if type(chosen.data[i]) ~= "number" then
				chosen.data[i] = property.default or 0
			end
			property[2] = property[2] or -999999
			property[3] = property[3] or 999999
			if chosen.data[i] < property[2] or chosen.data[i] > property[3] then
				chosen.data[i] = property.default or math.max(math.min(chosen.data[i],property[3]),property[2])
			end
			local loop = property[2] ~= -999999 and property[3] ~= 999999 and not property.typeable
			if not loop then NewButton(x+30+bx*145,y+(math.min(#properties,properties.max or 5)-by+1)*25-20,90,20,"pix","propertytype"..i,nil,nil,
			function() typing = function(c)
				local oldt = chosen.data[i]; 
				if c == "backspace" then chosen.data[i] = tonumber(string.sub(tostring(chosen.data[i]),1,string.len(tostring(chosen.data[i]))-1)) or 0;
										if property[2] > chosen.data[i] or property[3] < chosen.data[i] then chosen.data[i] = oldt end
				elseif c == "-" then if property[2] <= -chosen.data[i] and property[3] >= -chosen.data[i] then chosen.data[i] = -chosen.data[i] end
				else chosen.data[i] = tonumber(tostring(chosen.data[i])..c)
					if not tonumber(chosen.data[i]) or tonumber(chosen.data[i]) < property[2] or tonumber(chosen.data[i]) > property[3] then chosen.data[i] = oldt end end
			end end,
			nil,function() return not puzzle and propertiesopen >= i end,"bottomleft",1500,nil,{.15,.15,.15,1},{.15,.15,.15,1},{.15,.15,.15,1})
			else
				NewButton(x+5+bx*145,y+(math.min(#properties,properties.max or 5)-by+1)*25-99999,140,20,"pix","propertytype"..i,nil,nil,nil,nil,function() return not puzzle and propertiesopen >= i end,"bottomleft",1500)
			end
			NewButton(x+125+bx*145,y+(math.min(#properties,properties.max or 5)-by+1)*25-20,20,20,"add","propertyadd"..i,nil,nil,function() chosen.data[i] = loop and (chosen.data[i]-property[2]+1)%(property[3]-property[2]+1)+property[2] or math.min(chosen.data[i]+1,property[3]) end,nil,function() return not puzzle and propertiesopen >= i end,"bottomleft",1500)
			local b = NewButton(x+5+bx*145,y+(math.min(#properties,properties.max or 5)-by+1)*25-20,20,20,"subtract","propertysub"..i,nil,nil,function() chosen.data[i] = loop and (chosen.data[i]-property[2]-1)%(property[3]-property[2]+1)+property[2] or math.max(chosen.data[i]-1,property[2]) end,nil,function() return not puzzle and propertiesopen >= i end,"bottomleft",1500)
			b.drawfunc = function(x,y,b)
							love.graphics.setColor(1,1,1,1)
							love.graphics.printf(property[1]..(property.names and property.names[chosen.data[i]] or chosen.data[i]),x+50*uiscale-b.w/2*uiscale,y-20*uiscale+20*uiscale*.5+5*uiscale,140,"center",0,uiscale,uiscale,50,0)
						end
			effectivei = effectivei + 1
		end
	end
end
	
llueanames = {[0]="Push","Grab","Pull","Drill","Slice"}
omnicellnames = {"Pushable","Spirit","Wall","Ghost","Trash","Phantom","Jump Trash",
"Attack Trash","Dodge Trash","Evade Trash","Squish Trash","Demolisher","Enemy","Weight","Anti-Weight","Diverger",
"Super Acid","Fungal","Inversion","CW Rotator","CCW Rotator","180 Rotator","Random Rotator"}
cornernames = {"Pushable","Wall","CW Rotator","CCW Rotator","180 Rotator","Random Rotator"}
name0inf = {[0]="0 (inf)"}
enabledisable = {[0]="Enable",[1]="Disable"}
disableenable = {[0]="Disable",[1]="Enable"}
noyes = {[0]="No",[1]="Yes"}
lifeoptions = {[0]="Die",[1]="Live",[2]="Birth",[3]="Birth+Live"}
function SetSelectedCell(id,b)
	if b and buttons.propertybg.y == b.y+20 and buttons.propertybg.x == math.min(math.max(b.x-buttons.propertybg.w/2+10,0),love.graphics.getWidth()-buttons.propertybg.w) and propertiesopen > 0 then propertiesopen = 0 
	elseif id == 206 and b then MakePropertyMenu({{"Base: ",0,4,names=llueanames}, {"Left: ",0,4,names=llueanames}, {"Right: ",0,4,names=llueanames}},b)
	elseif id == 221 and b then MakePropertyMenu({{"ID: "}, {"Target: "}},b)
	elseif (id == 224 or id == "coin_tool") and b then MakePropertyMenu({{"Coins: ",0}},b)
	elseif (id == 299 or id == 563 or id == 564 or id == 565 or id == 583) and b then MakePropertyMenu({{"ID: "}},b)
	elseif (id == 318 or id == 320 or id == 453 or id == 455 or id == 589 or id == 590 or id == 591 or id == 592 or id == 593 or id == 594 or id == 595 or id == 596
	or id == 796 or id == 797 or id == 798 or id == 799 or id == 804 or id == 805 or id == 806 or id == 807 or id == 1155 or id == 1157 or id == 1158) and b then MakePropertyMenu({{"Range: ",0,names=name0inf}},b)
	elseif id == 351 and b then MakePropertyMenu({{"Right: ",1,19,names=omnicellnames},{"Bottom: ",1,19,names=omnicellnames},{"Left: ",1,19,names=omnicellnames},{"Top: ",1,19,names=omnicellnames},{"HP: ",1}},b)
	elseif id == 552 and b then MakePropertyMenu({{"Right: ",1,23,names=omnicellnames},{"Bottom: ",1,23,names=omnicellnames},{"Left: ",1,23,names=omnicellnames},{"Top: ",1,23,names=omnicellnames},{"HP: ",1}
												,{"Push/Nudge: ",0,2,names={[0]="No","Push","Nudge"}},{"Pull: ",0,1,names=noyes},{"Grab/Shove: ",0,2,names={[0]="No","Grab","Shove"}},{"Drill: ",0,1,names=noyes},{"Slice: ",0,1,names=noyes}
												,{"Speed: ",0,names=name0inf,default=1},{"Delay: ",1},{"Push Max: ",0,names=name0inf},{"Pull Max: ",0,names=name0inf},{"Grab Max: ",0,names=name0inf}
												,{"Time: ",0},{"BR Corner: ",1,6,names=cornernames},{"BL Corner: ",1,6,names=cornernames},{"TL Corner: ",1,6,names=cornernames},{"TR Corner: ",1,6,names=cornernames}
												,{"NeedsFront: ",0,1,names=noyes},{"NeedsRight: ",0,1,names=noyes},{"NeedsBehind: ",0,1,names=noyes},{"NeedsLeft: ",0,1,names=noyes},{"Blocked: ",0,4,names={[0]="Nothing","Rotate CW", "Rotate CCW", "Rotate 180", "Delete"}}
												,{"Controlled: ",0,1,names=noyes},{"Acceleration: ",0}},b)
	elseif (id == 352 or id == 353 or id == 354) and b then MakePropertyMenu({{"Speed: ",1},{"Delay: ",1},{"Time: ",0},{"Max: ",0,names=name0inf}},b)
	elseif (id == 355 or id == 356 or id == 357) and b then MakePropertyMenu({{"Speed: ",1},{"Delay: ",1},{"Time: ",0}},b)
	elseif (id == 1167 or id == 1168 or id == 1169 or id == 1170) and b then MakePropertyMenu({{"Range: ",0,names=name0inf},{"Speed: ",1},{"Delay: ",1},{"Time: ",0}},b)
	elseif id == 402 and b then MakePropertyMenu({{"Contained: ",0}},b)
	elseif id == 412 and b then MakePropertyMenu({{"Recursion: ",0}},b)
	elseif (id == 566) and b then MakePropertyMenu({{"Time: ",0}},b)
	elseif (id == 567) and b then MakePropertyMenu({{"0 Neighbors: ",0,1,names=lifeoptions},{"1 Neighbor: ",0,3,names=lifeoptions},{"2 Neighbors: ",0,3,names=lifeoptions},{"3 Neighbors: ",0,3,names=lifeoptions},{"4 Neighbors: ",0,3,names=lifeoptions}
												,{"5 Neighbors: ",0,3,names=lifeoptions},{"6 Neighbors: ",0,3,names=lifeoptions},{"7 Neighbors: ",0,3,names=lifeoptions},{"8 Neighbors: ",0,3,names=lifeoptions},{"Persistence: ",0}},b)
	elseif (id == 604) and b then MakePropertyMenu({max=4,{"Survive Min: ",0},{"Survive Max: ",0},{"Birth Min: ",1},{"Birth Max: ",0},{"Range: ",1},{"Persistence: ",0},{"Neighbors: ",0,3,names={[0]="[]","<>","X","O"}}},b)
	elseif (id == 614) and b then MakePropertyMenu({{"Jump Strength: ",0,default=2},
													{"Coyote Time: ",0,default=1}},b)
	elseif (id == 222 or id == 1100 or id == 1101 or id == 1102 or id == 1103
		or id == 1104 or id == 1105 or id == 1106 or id == 1107 or id == 1108) and b then MakePropertyMenu({{"Delay: ",1}},b)
	elseif id == 644 and b then MakePropertyMenu({{"Generations: ",2}},b)
	elseif (id == 645 or id == 1154) and b then MakePropertyMenu({{"Generations: ",1}},b)
	elseif id == 668 and b then MakePropertyMenu({{"Numerator: "},{"Denominator: ",1}},b)
	elseif (id == 669 or id == 1193) and b then MakePropertyMenu({{"Numerator: ",1},{"Denominator: ",1}},b)
	elseif (id == 708 or id == 1200) and b then MakePropertyMenu({{"Text: ",type="text",height=5}},b)
	elseif (id == 908 or id == 909) and b then MakePropertyMenu({{"ID: "},{"Enabled: ",0,1,names=noyes}},b)
	elseif (id == 1083 or id == 1084 or id == 1085 or id == 1188 or id == 1190 or id == 1198) and b then MakePropertyMenu({{"Amount: ",1}},b)
	elseif (id == 1091 or id == 1092 or id == 1093 or id == 1094) and b then MakePropertyMenu({{"Run: "},{"Rise: ",0}},b)
	elseif (id == 1095 or id == 1096 or id == 1097 or id == 1098 or id == 1099) and b then MakePropertyMenu({{"Run: ",1},{"Rise: ",1}},b)
	elseif (id == 1117) and b then MakePropertyMenu({{"Speed: "},{"Distance: ",1}},b)
	elseif (id == 1125) and b then MakePropertyMenu({{"Neighbors: ",0,3,names={[0]="Orthogonal","Surrounding","Diagonal","Forward"}},{"Rotation: ",0,3,names={[0]="None","CW","CCW","Random"}},{"Infects Cells: ",0,1,names=noyes},{"Infects Air: ",0,1,names=noyes},{"Spread Chance: ",1,100,default=100,typeable=true}},b)
	elseif (id == 1133 or id == 1134 or id == 1135 or id == 1136 or id == 1137 or id == 1138 or id == 1139 or id == 1140
	or id == 1141 or id == 1142 or id == 1143 or id == 1144 or id == 1145 or id == 1146 or id == 1147 or id == 1148 or id == 236 or id == 1149) and b then MakePropertyMenu({{"X Vel/100: "}, {"Y Vel/100: "}},b)
	elseif (id == 1159 or id == 1163) and b then MakePropertyMenu({{"Speed: ", 1}},b)
	elseif id == 488 and b then MakePropertyMenu({{"",0,11,names={[0]="CW","CCW","180","Flip |","Flip -","Flip \\","Flip /","Random","Redirect Right","Redirect Down", "Redirect Left", "Redirect Up"}}},b)
	elseif (id == 1180 or id == 1181) and b then MakePropertyMenu({{"",1,8,names={"Red","Orange","Yellow","Green","Cyan","Blue","Purple","Magenta"}}},b)
	elseif (id == "paint" or id == "invertcolorpaint") and b then MakePropertyMenu({{"Color: #",2,type="text",default="000000",max=6}},b)
	elseif (id == "hsvpaint" or id == "inverthsvpaint") and b then MakePropertyMenu({{"Hue: ",0,359,typeable=true,loop},{"Saturation: ",0,100,default=100,typeable=true},{"Value: ",0,100,default=100,typeable=true}},b)
	elseif id == "blendmode" and b then MakePropertyMenu({{"",0,6,names={[0]="Normal","Add","Subtract","Multiply","Screen","Lighten","Darken"}}},b)
	elseif id == "timerep_tool" and b then MakePropertyMenu({{"Type: ",0,1,names={[0]="Repulse","Impulse"}},{"Delay: ",0,names={[0]="0 (Disable)"}}},b)
	elseif (id == "armor_tool" or id == "bolt_tool" or id == "spikes_tool" or id == "petrify_tool" or id == "goo_tool" or id == "input_tool") and b then MakePropertyMenu({{"",0,1,names=enabledisable}},b)
	elseif (id == "tag_tool") and b then MakePropertyMenu({{"",0,3,names={[0]="Enemy","Ally","Player","Disable"}}},b)
	elseif (id == "grav_tool") and b then MakePropertyMenu({{"",0,2,names={[0]="Normal","Rotatable","Disable"}}},b)
	elseif id == "prot_tool" and b then MakePropertyMenu({{"",0,8,names={[0]="CW","CCW","180","Flip |","Flip -","Flip \\","Flip /","Random","Disable"}}},b)
	elseif id == "compel_tool" and b then MakePropertyMenu({{"",0,2,names={[0]="Settle","Moto","Disable"}}},b)
	elseif id == "entangle_tool" and b then MakePropertyMenu({{"ID: "},{"",0,1,names=enabledisable}},b)
	elseif id == "permaclamp_tool" and b then MakePropertyMenu({{"",1,6,names={"Push","Pull","Grab","Swap","Scissor","Tunnel"}},{"",0,1,names=enabledisable}},b)
	elseif id == "ghost_tool" and b then MakePropertyMenu({{"",0,2,default=1,names={[0]="Disable","Ghostify","Ungeneratable"}}},b)
	else propertiesopen = 0 end
	if id ~= chosen.id then
		for i=10,2,-1 do
			lastselects[i].onclick = lastselects[i-1].onclick
			lastselects[i].icon = lastselects[i-1].icon
			lastselects[i].name = lastselects[i-1].name
			lastselects[i].desc = lastselects[i-1].desc
		end
		buttons.lastselecttab.icon = function() return GetCellTexture(id) end
		lastselects[1].onclick = function() SetSelectedCell(id,lastselects[1]) end
		lastselects[1].icon = buttons.lastselecttab.icon 
		if cellinfo[id] and not cellinfo[id].idadded and not cellinfo[id].notcell then cellinfo[id].desc = cellinfo[id].desc.."\nID: "..id..(GetLayer(id) ~= 0 and ("\nLayer: "..layernames[GetLayer(id)] or GetLayer(id)) or "") cellinfo[id].idadded = true end
		if cellinfo[id] then
			lastselects[1].name = cellinfo[id].name
			lastselects[1].desc = cellinfo[id].desc
		else
			lastselects[1].name = "Placeholder B"
			lastselects[1].desc = "This ID ("..tostring(id)..") doesn't exist in the version of CelLua you are using."
		end
	end
	chosen.id = id == "eraser" and 0 or id
end

function ToggleSubList(i,j)
	local list = lists[i]
	if openedsubtab ~= -1 then
		local cell = list.cells[openedsubtab]
		for k=1,#cell do
			local subcell = cell[k]
			if type(subcell) == "table" then
				for l=1,#subcell do
					local b = buttons["list"..i.."sublist"..openedsubtab.."cell"..subcell[l]]
					ip.MoveObjTo(b,i*50+16,openedsubtab*20+34,.2,"backin",function(b) b.isenabled = false end)
				end
			else
				local b = buttons["list"..i.."sublist"..openedsubtab.."cell"..subcell]
				ip.MoveObjTo(b,i*50+16,openedsubtab*20+34,.2,"backin",function(b) b.isenabled = false end)
			end
		end
	end
	if openedsubtab ~= j then
		local cell = list.cells[j]
		for k=1,#cell do
			local subcell = cell[k]
			if type(subcell) == "table" then
				for l=1,#subcell do
					local b = buttons["list"..i.."sublist"..j.."cell"..subcell[l]]
					local x,y = b.openx,b.openy
					local f = function() return not mainmenu end
					b.isenabled = f
					ip.MoveObjTo(b,i*50+16+x*20,j*20+34+y*20,.2,"backout",function(b) b.isenabled = f end,function(b) b.isenabled = f end)
				end
			else
				local b = buttons["list"..i.."sublist"..j.."cell"..subcell]
				local x,y = b.openx,b.openy
				local f = function() return not mainmenu end
				b.isenabled = f
				ip.MoveObjTo(b,i*50+16+x*20,j*20+34+y*20,.2,"backout",function(b) b.isenabled = f end,function(b) b.isenabled = f end)
			end
		end
		openedsubtab = j
	else
		openedsubtab = -1
	end
	propertiesopen = 0
end

function ToggleList(i)
	if openedtab == -2 then
		for j=1,10 do
			local b = buttons["lastselect"..j]
			ip.MoveObjTo(b,b.x,-20,.33,"backin",function(b) b.isenabled = false end)
		end
	elseif openedtab ~= -1 then
		local list = lists[openedtab]
		for j=1,#list.cells do
			local cell = list.cells[j]
			if type(cell) == "table" and #cell > 1 then
				if openedsubtab == j then ToggleSubList(openedtab,j) end
				local b = buttons["list"..openedtab.."sublist"..j]
				ip.MoveObjTo(b,b.x,-20,.33,"backin",function(b) b.isenabled = false end)
			else
				cell = type(cell) == "table" and cell[1] or cell
				local b = buttons["list"..openedtab.."cell"..cell]
				ip.MoveObjTo(b,b.x,-20,.33,"backin",function(b) b.isenabled = false end)
			end
		end
	end
	if openedtab ~= i then
		local f = function() return not mainmenu end
		if i == -2 then
			for j=1,10 do
				local b = buttons["lastselect"..j]
				b.isenabled = f
				ip.MoveObjTo(b,b.x,j*20+34,.33,"backout",function(b) b.isenabled = f end,function(b) b.isenabled = f end)
			end
		else
			local list = lists[i]
			for j=1,#list.cells do
				local cell = list.cells[j]
				if type(cell) == "table" and #cell > 1 then
					if openedsubtab == j then ToggleSubList(i,j) end
					local b = buttons["list"..i.."sublist"..j]
					b.isenabled = f
					ip.MoveObjTo(b,b.x,j*20+34,.33,"backout",function(b) b.isenabled = f end,function(b) b.isenabled = f end)
				else
					cell = type(cell) == "table" and cell[1] or cell
					local b = buttons["list"..i.."cell"..cell]
					b.isenabled = f
					ip.MoveObjTo(b,b.x,j*20+34,.33,"backout",function(b) b.isenabled = f end,function(b) b.isenabled = f end)
				end
			end
		end
		openedtab = i
	else
		openedtab = -1
	end
	openedsubtab = -1
	propertiesopen = 0
end

function ToggleHud(val)
	if not val then
		if openedtab then
			ToggleList(openedtab)
		end
	end
	if val then
		for i=0,#lists do 
			local b = buttons["list"..i]
			b.isenabled = function() return not mainmenu end
			ip.MoveObjTo(b,b.x,6,.2,"easeout",function(b) b.isenabled = function() return not mainmenu end end)
		end
		buttons.lastselecttab.isenabled = function() return not mainmenu end
		ip.MoveObjTo(buttons.lastselecttab,buttons.lastselecttab.x,6,.2,"easeout",function(b) b.isenabled = function() return not mainmenu end end)
		buttons.menubar.isenabled = function() return not mainmenu end
		ip.MoveObjTo(buttons.menubar,buttons.menubar.x,0,.2,"easeout",function(b) b.isenabled = function() return not mainmenu end end)
	else
		for i=0,#lists do 
			local b = buttons["list"..i]
			ip.MoveObjTo(b,b.x,-54,.2,"easein",function(b) b.isenabled = false end)
		end
		ip.MoveObjTo(buttons.lastselecttab,buttons.lastselecttab.x,-54,.2,"easein",function(b) b.isenabled = false end)
		ip.MoveObjTo(buttons.menubar,buttons.menubar.x,-60,.2,"easein",function(b) b.isenabled = false end)
	end
end

jx,jy = 0,0
function HandleJoystick()
	jx,jy = love.mouse.getX()-love.graphics.getWidth()+90*uiscale,love.mouse.getY()-love.graphics.getHeight()+120*uiscale
	if jx*jx+jy*jy > 50*50*uiscale*uiscale then
		jx,jy = 0,0
	end
	if freezecam then
		held = math.floor((math.atan2(jy,jx)+(math.pi*.25))*2/math.pi)%4
		if held == 0 then heldhori = 0
		elseif held == 1 then heldvert = 1
		elseif held == 2 then heldhori = 2
		elseif held == 3 then heldvert = 3 end
	else
		cam.tarx,cam.tary = cam.tarx+jx*delta*30/uiscale,cam.tary+jy*delta*30/uiscale
	end
end

if love._os == "Android" or love._os == "iOS" then
	NewButton(70,175,40,40,"action","action",nil,nil,function() actionpressed = true end,nil,function() return moreui and not mainmenu end,"bottomright",0)
	joystick = NewButton(40,70,100,100,"joystickbg","joystick",nil,nil,HandleJoystick,true,function() return moreui and not mainmenu end,"bottomright",0,nil,{1,1,1,1},{1,1,1,1},{1,1,1,1})
	joystick.drawfunc = function() if moreui and not mainmenu then
		local texture = GetTex("joystick").normal
		local texsize = GetTex("joystick").size
		love.graphics.draw(texture,love.graphics.getWidth()+jx-90*uiscale,love.graphics.getHeight()+jy-120*uiscale,0,uiscale*52/texsize.w,uiscale*52/texsize.h,texsize.w2,texsize.h2)
	end end
end

function CreateCategories()
	for i=0,#lists do 
		local list = lists[i]
		for j=1,#list.cells do
			local cell = list.cells[j]
			local x,y = 0,0
			if type(cell) == "table" and #cell > 1 then
				for k=1,#cell do
					local subcell = cell[k]
					if type(subcell) == "table" then
						if x > 0 then
							x,y = 0,y+1
						end
						for l=1,#subcell do
							local subcell = subcell[l]
							cellinfo[subcell] = cellinfo[subcell] or {name="Placeholder A",desc="Cell info was not set for this id."}
							if not cellinfo[subcell].idadded and not cellinfo[subcell].notcell then cellinfo[subcell].desc = (cellinfo[subcell].desc or "").."\nID: "..subcell..(GetLayer(subcell) ~= 0 and ("\nLayer: "..layernames[GetLayer(subcell)] or GetLayer(subcell)) or "") cellinfo[subcell].idadded = true end
							local b = NewButton(i*50+16,j*20+34,20,20,function() return GetCellTexture(subcell) end,"list"..i.."sublist"..j.."cell"..subcell,function() return GetAttribute(subcell,"name") end,function() return GetAttribute(subcell,"desc") end,function(b) SetSelectedCell(subcell,b) end,false,false,"bottomleft",1000, i ~= 0 and hudrotation)
							b.openx,b.openy = l,y
						end
						x,y = 0,y+1
					else
						local m = cell.max or list.cells.max
						x = x + 1
						cellinfo[subcell] = cellinfo[subcell] or {name="Placeholder A",desc="Cell info was not set for this id."}
						if not cellinfo[subcell].idadded and not cellinfo[subcell].notcell then cellinfo[subcell].desc = (cellinfo[subcell].desc or "").."\nID: "..subcell..(GetLayer(subcell) ~= 0 and ("\nLayer: "..layernames[GetLayer(subcell)] or GetLayer(subcell)) or "") cellinfo[subcell].idadded = true end
						local b = NewButton(i*50+16,j*20+34,20,20,function() return GetCellTexture(subcell) end,"list"..i.."sublist"..j.."cell"..subcell,function() return GetAttribute(subcell,"name") end,function() return GetAttribute(subcell,"desc") end,function(b) SetSelectedCell(subcell,b) end,false,false,"bottomleft",1000, i ~= 0 and hudrotation)
						b.openx,b.openy = x,y
						if x >= m then
							x,y = 0,y+1
						end
					end
				end
				NewButton(i*50+16,-20,20,20,function() return GetCellTexture((type(cell[1]) == "table" and cell[1][1] or cell[1])) end,"list"..i.."sublist"..j,cell.name,nil,function() if openedtab == i then ToggleSubList(i,j) end end,false,false,"bottomleft",1000, i ~= 0 and hudrotation)
			else
				cell = type(cell) == "table" and (type(cell[1]) == "table" and cell[1][1] or cell[1]) or cell
				cellinfo[cell] = cellinfo[cell] or {name="Placeholder A",desc="Cell info was not set for this id."}
				if not cellinfo[cell].idadded and not cellinfo[cell].notcell then cellinfo[cell].desc = cellinfo[cell].desc.."\nID: "..cell..(GetLayer(cell) ~= 0 and ("\nLayer: "..layernames[GetLayer(cell)] or GetLayer(cell)) or "") cellinfo[cell].idadded = true end
				local b = NewButton(i*50+16,-20,20,20,function() return GetCellTexture(cell) end,"list"..i.."cell"..cell,function() return GetAttribute(cell,"name") end,function() return GetAttribute(cell,"desc") end,function(b) if openedsubtab ~= -1 then ToggleSubList(i,openedsubtab) end; SetSelectedCell(cell,b) end,false,false,"bottomleft",1000, i ~= 0 and hudrotation)
				b.openx,b.openy = x,y
			end
		end
	end
	for i=1,10 do
		table.insert(lastselects,NewButton(16,i*20+34,20,20,"eraser","lastselect"..i,cellinfo["eraser"].name,cellinfo["eraser"].desc,function(b) if openedsubtab ~= -1 then ToggleSubList(i,openedsubtab) end; SetSelectedCell("eraser") end,false,false,"bottomright",1000, hudrotation))
	end
	NewButton(0,-60,function() return winxm*850/uiscale end,54,"menubar","menubar",nil,nil,function() end,nil,false,"bottom",1000,nil,{1,1,1,1},{1,1,1,1},{1,1,1,1})
	NewButton(6,-54,40,40,"eraser","lastselecttab","Last Selections",nil,function() ToggleList(-2) end,false,false,"bottomright",1000, hudrotation)
	for i=0,#lists do 
		local list = lists[i]
		NewButton(i*50+6,-54,40,40,list.icon,"list"..i,list.name,list.desc,function() ToggleList(i) end,false,false,"bottomleft",1000, i ~= 0 and hudrotation)
	end

	local pbg = NewButton(0,0,150,30,"pix","propertybg",nil,nil,function() end,nil,function() return not puzzle and propertiesopen > 0 end,"bottomleft",1500,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	pbg.drawfunc = function(x,y,b)
		love.graphics.setColor(textcolor)
		love.graphics.print("Properties",x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,uiscale,uiscale)
	end
end
--miscellaneous setup
love.keyboard.setKeyRepeat(true)
love.graphics.setBackgroundColor(.125,.125,.125)
bgcolor = {.375,.375,.375,.25}
voidcolor = {.125,.125,.125}

fireworkparticles = {}
function EmitFireworks(x,y)
	if #fireworkparticles < 1000 then
		for i=math.random(0,8),359,9 do
			local p = {}
			p.life = .75+math.random()*(i%18 < 9 and -.2 or .2)
			p.x = x
			p.y = y
			p.vx = math.cos(math.rad(i))*(i%18 < 9 and .15 or .08)
			p.vy = math.sin(math.rad(i))*(i%18 < 9 and .15 or .08)
			local hue = math.random()*math.pi*2
			p.color = {(math.sin(hue))+0.5,(math.sin(hue+math.pi*2/3))+0.5,(math.sin(hue+math.pi*4/3))+0.5,1}
			table.insert(fireworkparticles,p)
		end
		for i=1,50 do
			local p = {}
			p.life = .2+math.random()*.4
			p.x = x
			p.y = y
			local ang = math.random()*math.pi*2
			local dist = math.random()*.3
			p.vx = math.cos(ang)*dist
			p.vy = math.sin(ang)*dist
			local hue = math.random()*math.pi*2
			p.color = {(math.sin(hue))+0.5,(math.sin(hue+math.pi*2/3))+0.5,(math.sin(hue+math.pi*4/3))+0.5,1}
			table.insert(fireworkparticles,p)
		end
	end
end

particles = {}
function NewParticles(texture, id)
	local part = love.graphics.newParticleSystem(GetTex(texture).normal)
	part:setSizes(4,0)
	part:setSpread(math.pi*2)
	part:setSpeed(0,200)
	part:setParticleLifetime(0.5,1)
	part:setEmissionArea("uniform",10,10)
	part:setSizeVariation(1)
	part:setLinearDamping(1)
	part:setBufferSize(1000)
	particles[id] = part
	return part
end

function EmitParticles(id,x,y,amount)
	if fancy and particles[id] then
		particles[id]:setPosition(x*cellsize-cellsize/2,y*cellsize-cellsize/2)
		particles[id]:emit(amount or 50)
	end
end

function LoadDefaultParticles()
	table.insert(truequeue, function()
		local enemyparticles = NewParticles("pix", "enemy")
		enemyparticles:setColors(1,0,0,1,.5,0,0,1)
		local sparkleparticles = NewParticles("sparkle", "sparkle")
		sparkleparticles:setColors(1,0,.75,1,.5,0,.25,1)
		sparkleparticles:setSizes(1,0)
		local stallerparticles = NewParticles("pix", "staller")
		stallerparticles:setColors(.5,.75,.25,1,.15,.5,0,1)
		local bulkparticles = NewParticles("pix", "bulk")
		bulkparticles:setColors(1,.75,0,1,.5,.25,0,1)
		local swivelparticles = NewParticles("pix", "swivel")
		swivelparticles:setColors(.25,.5,1,1,0.1,0.1,.75,1)
		local coinparticles = NewParticles("sparkle", "coin")
		coinparticles:setColors(1,.75,.25,1,0.5,0.25,0,1)
		coinparticles:setSizes(1,0)
		local quantumparticles = NewParticles("pix", "quantum")
		quantumparticles:setColors(.75,0,1,1,.375,0,.5,1)
		local superparticles = NewParticles("pix", "super")
		superparticles:setColors(.1,0,0,1,0,0,0,1)
		local friendlysuperparticles = NewParticles("pix", "friendlysuper")
		friendlysuperparticles:setColors(0,.1,0,1,0,0,0,1)
		local neutralsuperparticles = NewParticles("pix", "neutralsuper")
		neutralsuperparticles:setColors(0,0,.1,1,0,0,0,1)
		local explosiveparticles = NewParticles("pix", "explosive")
		explosiveparticles:setColors(1,.5,.5,1,.75,.2,.2,1)
		local friendlyexplosiveparticles = NewParticles("pix", "friendlyexplosive")
		friendlyexplosiveparticles:setColors(.5,1,.5,1,.2,.75,.2,1)
		local angryparticles = NewParticles("pix", "angry")
		angryparticles:setColors(1,0,.75,1,.5,0,.25,1)
		local playerparticles = NewParticles("pix", "player")
		playerparticles:setColors(.6,.6,.6,1,.3,.3,.3,1)
		local greysparkleparticles = NewParticles("sparkle", "greysparkle")
		greysparkleparticles:setColors(.75,.75,.75,1,.5,.5,.5,1)
		greysparkleparticles:setSizes(1,0)
		local smokeparticles = NewParticles("smoke", "smoke")
		smokeparticles:setColors(.75,.75,.75,1,.5,.5,.5,0)
		smokeparticles:setSizes(1,0)
		smokeparticles:setSpeed(0,25)
		menuparticles = love.graphics.newParticleSystem(GetTex(2).normal)
		menuparticles:setSizes(80/math.max(GetTex(2).size.w,GetTex(2).size.h))
		menuparticles:setSpeed(300,1200)
		menuparticles:setParticleLifetime(1,2)
		menuparticles:setEmissionArea("uniform",3000,3000)
		menuparticles:setBufferSize(1000)
		menuparticles:setColors(1,1,1,0,1,1,1,.25,1,1,1,0)
	end)
end

function AsSavedString(val)
	if type(val) == "number" then
		return "#"..val.."\n"
	elseif type(val) == "string" then
		return "\""..val.."\n"
	elseif val == true then
		return "T\n"
	elseif val == false then
		return "F\n"
	elseif type(val) == "table" then
		local s = "{\n"
		for k,v in sortedpairs(val) do
			if v ~= "__parent" and v ~= "__name" then
				s = s..AsSavedString(k)..AsSavedString(v)
			end
		end
		return s.."}\n"
	end
end

function GetValFromLine(pre,val)
	if pre == "#" then
		return tonumber(val)
	elseif pre == "\"" then
		return val
	elseif pre == "T" then
		return true
	elseif pre == "F" then
		return false
	end
end

function SaveVar(name,val)
	savedqueue[name] = val
	return val
end

function GetSaved(name)
	return savedqueue[name]
end

function WriteSavedVars()
	local s = ""
	for k,v in sortedpairs(savedqueue) do
		s = s..k.."\n"..AsSavedString(v)
	end
	love.filesystem.write("save.txt",s)
end

function ReadSavedVars()
	savedqueue = {	--fallbacks
		settings = {
			debug = false,
			fancy = true,
			fancywm = true,
			rendertext = true,
			moreui = true,
			popups = true,
			playercam = true;
			volume = .5,
			sfxvolume = .5,
			musicspeed = 1,
			uiscale = 1,
			music = 1,
			texturepack = "testerpack",
			window_width = 800,
			window_height = 600,
			fullscreen = love._os == "Android" or love._os == "iOS",
		},
		completed = {},
		secrets = {},
		favorites = {},
	}
	if love.filesystem.getInfo("save.txt") then
		local num = 0
		local r = false
		local stack = {savedqueue}
		local name = nil
		for line in love.filesystem.lines("save.txt") do
			num = num + 1
			local pre = line:sub(1,1)
			local data = line:sub(2,#line)
			if num%2 == 0 then
				if pre ~= "{" then
					stack[#stack][name] = GetValFromLine(pre,data)
				else
					stack[#stack][name] = type(stack[#stack][name]) == "table" and stack[#stack][name] or {}
					table.insert(stack,stack[#stack][name])
				end
			else
				if pre == "}" then
					num = num - 1
					table.remove(stack)
				else
					name = #stack == 1 and line or GetValFromLine(pre,data)
				end
			end
		end
	end
	settings = GetSaved("settings")
	dodebug = settings.debug
	fancy = settings.fancy
	fancywm = settings.fancywm
	rendertext = settings.rendertext
	moreui = settings.moreui
	popups = settings.popups
	playercam = settings.playercam
	uiscale = settings.uiscale
	newuiscale = uiscale
	SetVolume(settings.volume)
	SetSFXVolume(settings.sfxvolume)
	SetMusicSpeed(settings.musicspeed)
	SetPack(settings.texturepack)
	SetFavorites(GetSaved("favorites"))
end

function SetVolume(v)
	settings.volume = v
	volume = v
	for k,m in pairs(music) do
		m.audio:setVolume(m.mult*v)
	end
end

function SetSFXVolume(v)
	settings.sfxvolume = v
	sfxvolume = v
	for k,m in pairs(sounds) do
		m.audio:setVolume(m.mult*v)
	end
end

function SetMusicSpeed(s)
	settings.musicspeed = s
	musicspeed = s
	for k,m in pairs(music) do
		m.audio:setPitch(s)
	end
end


music = {}
function NewMusic(path,mult)
	mult = mult or 1
	local m = love.audio.newSource("audio/"..path, "stream")
	m:setLooping(true)
	m:setVolume(settings.volume*mult)
	m:setPitch(settings.musicspeed)
	music[#music+1] = {audio=m,mult=mult,name=path}
end

sounds = {}
function NewSFX(path,name,mult)
	mult = mult or 1
	local sfx = love.audio.newSource("audio/"..path, "static")
	sfx:setVolume(settings.sfxvolume*mult)
	sounds[name] = {audio=sfx,mult=mult}
end
	
function LoadAudio()
	NewMusic("scattered cells.ogg")
	NewMusic("stepping stones.ogg")
	NewMusic("seen sights.ogg")
	NewMusic("sovereign silence.ogg")
	NewMusic("scarlet synthbeat.ogg")
	NewSFX("beep.wav", "beep")
	NewSFX("destroy.ogg", "destroy")
	NewSFX("unlock.ogg", "unlock")
	NewSFX("move.ogg", "move", 4)
	NewSFX("rotate.ogg", "rotate", .5)
	NewSFX("infect.ogg", "infect", 3)
	NewSFX("coin.ogg", "coin", .5)
	NewSFX("laser.ogg", "laser", 2)
	NewSFX("shoot.ogg", "shoot", 2)
end

--everything else

function AllChunkIds(cell)
	local ids = {}
	table.insert(ids,ChunkId(cell.id))
	if cell.id ~= 0 then table.insert(ids,"all") end
	if IsEnemy(cell) or IsAlly(cell) or IsNeutral(cell) then table.insert(ids,"tagged") end
	if cell.vars.timerepulseright or cell.vars.timerepulseleft or cell.vars.timerepulseup or cell.vars.timerepulsedown then table.insert(ids,"timerep") end
	if cell.vars.timeimpulseright or cell.vars.timeimpulseleft or cell.vars.timeimpulseup or cell.vars.timeimpulsedown then table.insert(ids,"timeimp") end
	if cell.vars.gravdir then table.insert(ids,"gravity") end
	if cell.vars.perpetualrot then table.insert(ids,"perpetualrotate") end
	if cell.vars.compelled or cell.vars.gooey then table.insert(ids,"compel") end
	if cell.vars.input then table.insert(ids,"input") end
	if cell.vars.entangled then table.insert(ids,299) end
	if cell.id == 242 or cell.id == 243 or cell.id == 603 then table.insert(ids,240) end
	if cell.id == 552 and cell.vars[6] == 2 and cell.vars[26] ~= 1 then table.insert(ids,114) end
	if cell.id == 552 and cell.vars[6] == 1 and cell.vars[26] ~= 1 then table.insert(ids,2) end
	if cell.id == 552 and cell.vars[7] == 1 and cell.vars[26] ~= 1 then table.insert(ids,14) end
	if cell.id == 552 and cell.vars[8] ~= 0 and cell.vars[26] ~= 1 then table.insert(ids,71) end
	if cell.id == 552 and cell.vars[9] == 1 and cell.vars[26] ~= 1 then table.insert(ids,58) end
	if cell.id == 552 and cell.vars[26] ~= 1 then table.insert(ids,115) end
	if cell.id == 552 and cell.vars[26] == 1 then table.insert(ids,239) end
	if cell.id == 642 then table.insert(ids,626) end
	if cell.id == 657 then table.insert(ids,15) end
	if cell.id == 1147 or cell.id == 1148 then table.insert(ids,240) end
	return ids
end

function DefaultVars(id,norng)	--Default variables.
	if id == 206 then return {0,0,0,tickcount+200}
	elseif id == 211 then return {[3]=250,[4]=25}
	elseif id == 212 then return {[3]=250,[4]=0}
	elseif id == 221 or id == 1133 or id == 1134 or id == 1135 or id == 1136 or id == 1137 or id == 1138 or id == 1139 or id == 1140 or id == 1141
		or id == 1142 or id == 1143 or id == 1144 or id == 1145 or id == 1146 or id == 1147 or id == 1148 or id == 236 or id == 1149 then return {0,0}
	elseif id == 224 or id == 299 or id == 318 or id == 320 or id == 453 or id == 455 or id == 488 or id == 564 or id == 565 or id == 568
		or id == 583 or id == 589 or id == 590 or id == 591 or id == 592 or id == 593 or id == 594 or id == 595 or id == 596 or id == 605
		or id == 796 or id == 797 or id == 798 or id == 799 or id == 804 or id == 805 or id == 806 or id == 807 or id == 908 or id == 909
		or id == 1155 or id == 1157 or id == 1158 or id == 1187 or id == 1189 or id == 1197 then return {0}
	elseif id == 351 then return {1,1,1,1,1}
	elseif id == 352 or id == 353 or id == 354 then return {1,1,0,0}
	elseif id == 355 or id == 356 or id == 357 then return {1,1,0}
	elseif id == 1167 or id == 1168 or id == 1169 or id == 1170 then return {0,1,1,0}
	elseif id == 500 then return norng and {1,0} or {math.random(1,8),math.random(0,7)}
	elseif id == 552 then return {1,1,1,1,1,0,0,0,0,0,1,1,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0}	--the the
	elseif id == 563 then return {0,switches[0]}
	elseif id == 566 or id == 1091 or id == 1092 or id == 1093 or id == 1094 then return {1,0}
	elseif id == 1095 or id == 1096 or id == 1097 or id == 1098 or id == 1099 then return {2,1}
	elseif id == 567 then return {0,0,0,0,0,0,0,0,0,0}
	elseif id == 604 then return {0,0,0,0,0,0}
	elseif id == 614 then return {2,0,0}
	elseif id == 644 or id == 1159 or id == 1163 then return {2}
	elseif id == 645 or id == 1154 then return {nil,nil,1}
	elseif id == 624 then return norng and {} or GetRandomRutziceGene()
	elseif id == 668 or id == 669 or id == 1193 then return {0,1}
	elseif id == 708 then return {"?"}
	elseif id == 1200 then return {"GetCell(scriptx,scripty).testvar = 'no data'"}
	elseif id == 1083 then return {nil,nil,1,1}
	elseif id == 222 or id == 1084 or id == 1100 or id == 1101 or id == 1102 or id == 1103
		or id == 1104 or id == 1105 or id == 1106 or id == 1107 or id == 1108 or id == 1180 or id == 1181 then return {1}
	elseif id == 1085 or id == 1117 or id == 1188 or id == 1190 or id == 1198 then return {0,1}
	elseif id == 1125 then return {0,0,0,0,100}
	else return {} end
end

function GetStoredCell(cell,upd,eaten)
	local vars = DefaultVars(cell.vars[1])
	vars.paint = cell.vars.paint
	vars.blending = cell.vars.blending
	return {id=cell.vars[1],rot=cell.vars[2],lastvars={cell.lastvars[1],cell.lastvars[2],0},updated=upd,vars=vars,eatencells=eaten}
end

chunks = {}
maxchunksize = 1

function ResetChunks(width,height)
	maxchunksize = math.floor(math.log(math.max(width,height)-1,2))
	for z=0,depth-1 do
		chunks[z] = {}
		chunks[z].all = {}
		for i=1,maxchunksize do
			local invsize = 1/2^i
			chunks[z][i] = {}
			for y=0,(height-1)*invsize do
				chunks[z][i][y] = {}
				for x=0,(width-1)*invsize do
					chunks[z][i][y][x] = {}
				end
			end
		end
	end
end

function SetChunk(x,y,z,cell,nowrap)
	z = z or 0
	if not nowrap and layers[0][0][0].id == 428 then x=(x-1)%(width-2)+1 y=(y-1)%(height-2)+1 end
	local ids = AllChunkIds(cell)
	for j=1,#ids do
		for i=1,maxchunksize do
			local invsize = 1/2^i
			local chunk = chunks[z][i][math.floor(y*invsize)][math.floor(x*invsize)]
			if chunk[ids[j]] then
				break
			end
			chunk[ids[j]] = true
		end
		chunks[z].all[ids[j]] = true
	end
end

function SetChunkId(x,y,id,z,nowrap)
	z = z or 0
	if not nowrap and layers[0][0][0].id == 428 then x=(x-1)%(width-2)+1 y=(y-1)%(height-2)+1 end
	for i=1,maxchunksize do
		local invsize = 1/2^i
		local chunk = chunks[z][i][math.floor(y*invsize)][math.floor(x*invsize)]
		if chunk[id] then
			break
		end
		chunk[id] = true
	end
	chunks[z].all[id] = true
end

function GetChunk(x,y,z,id)
	local s = 1
	for i=1,maxchunksize do
		local invsize = 1/2^i
		local chunk = chunks[z][i][math.floor(y*invsize)][math.floor(x*invsize)]
		if chunk[id] then
			return s
		else
			s = invsize
		end
	end
	return s
end

function ResetPortals()
	portals = {}
	reverseportals = {}
	switches = {}
	collectedkeys = {}
	totalenemies = 0
	totalallies = 0
	totalplayers = 0
	for x=1,width-2 do
		for y=1,height-2 do
			if richtexts[x+y*width] then
				richtexts[x+y*width].text:release()
				richtexts[x+y*width] = nil
			end
			local cell = layers[0][y][x]
			local above = layers[1][y][x]
			if cell.id == 221 then
				portals[cell.vars[1]] = portals[cell.vars[1]] or {}
				reverseportals[cell.vars[2]] = reverseportals[cell.vars[2]] or {}
				table.insert(portals[cell.vars[1]],{x,y})
				table.insert(reverseportals[cell.vars[2]],{x,y})
			elseif cell.id == 563 and cell.vars[2] then
				switches[cell.vars[1]] = true
			--[[elseif cell.id == 299 and cell.vars[1] and loadedcode == "K3" then
				for cx = math.floor(x*.04),math.floor(x*.04)+19 do
					for cy = math.floor(y*.04),math.floor(y*.04)+19 do
						
					end
				end]]
			end
			if IsEnemy(cell) then
				totalenemies = totalenemies + 1
			end
			if IsAlly(cell) then
				totalallies = totalallies + 1
			end
			if IsNeutral(cell) then
				totalplayers = totalplayers + 1
			end
			if above.id == 708 then
				richtexts[x+y*width] = SetRichText(richtexts[x+y*width] or love.graphics.newText(font),above.vars[1])
			end
		end
	end
end

function SortByLarger()
	if chosen.data[2] > chosen.data[1] then return {2,1}
	else return {1,2} end
end
function NilIfZero()
	return {chosen.data[1] ~= 0 and 1 or nil}
end
function VictorySwitchVars()
	return {chosen.data[1],chosen.data[2] == 1 and 2 or nil}
end
--table = direct map from chosen.data to cell.vars ({2,1} = {chosen.data[2],chosen.data[1]})
--number = amount of variables, ordered linearly like an array (3 = {1,2,3} = {chosen.data[1],chosen.data[2],chosen.data[3]})
--note that these will be placed "on top" of defaultvars
MergeIntoInfo("placedvars",{
	[222]=1,[224]=1,[299]=1,[318]=1,[320]=1,[453]=1,[455]=1,[488]=1,[563]=1,[564]=1,[565]=1,
	[566]=1,[583]=1,[589]=1,[590]=1,[591]=1,[592]=1,[593]=1,[594]=1,[595]=1,[596]=1,[614]=1,
	[644]=1,[708]=1,[796]=1,[797]=1,[798]=1,[799]=1,[804]=1,[805]=1,[806]=1,[807]=1,[1084]=1,
	[1100]=1,[1101]=1,[1102]=1,[1103]=1,[1104]=1,[1105]=1,[1106]=1,[1107]=1,[1108]=1,[1155]=1,
	[1157]=1,[1158]=1,[1159]=1,[1163]=1,[1180]=1,[1181]=1,[1200]=1,
	[221]=2,[236]=2,[668]=2,[669]=2,[1091]=2,[1092]=2,[1093]=2,[1094]=2,[1117]=2,[1193]=2,
	[1133]=2,[1134]=2,[1135]=2,[1136]=2,[1137]=2,[1138]=2,[1139]=2,[1140]=2,[1141]=2,[1142]=2,
	[1143]=2,[1144]=2,[1145]=2,[1146]=2,[1147]=2,[1148]=2,[1149]=2,
	[206]=3,[355]=3,[356]=3,[357]=3,
	[352]=4,[353]=4,[354]=4,[1167]=4,[1168]=4,[1169]=4,[1170]=4,
	[351]=5,[1125]=5,
	[604]=7,
	[567]=10,
	[552]=27,
	[1085]={[2]=1},[1188]={[2]=1},[1190]={[2]=1},[1198]={[2]=1},
	[645]={[3]=1},[1154]={[3]=1},[1083]={[3]=1},
	[1095]=SortByLarger,[1096]=SortByLarger,[1097]=SortByLarger,[1098]=SortByLarger,[1099]=SortByLarger,
	[402]=NilIfZero,[412]=NilIfZero,
	[908]=VictorySwitchVars,[909]=VictorySwitchVars,
})

function GetPlacedCell(cell,norng)
	if not cell.vars then
		local id = cell.id
		cell.vars = DefaultVars(id,norng)
		local placedvars = GetAttribute(id,"placedvars")
		if placedvars then
			if type(placedvars) == "number" then
				for i=1,placedvars do
					cell.vars[i] = chosen.data[i] or cell.vars[i]
				end
			else
				for k,v in pairs(placedvars) do
					cell.vars[k] = chosen.data[v] or cell.vars[k]
				end
			end
		end
		if cell.id == 563 then
			cell.vars[2] = switches[cell.vars[1]]
		end
	end
	return cell
end

function HandleCopy(cell)
	if (chosen.id == "colorpicker") then
		if not cell.vars[1] then
			chosen.id = "paint"
			chosen.data[1] = "000000"
		elseif type(cell.vars[1]) == "number" then
			if cell.vars[1] > 0 then
				SetSelectedCell("paint")
				chosen.data[1] = cell.vars[1]
			else
				SetSelectedCell("invertcolorpaint")
				chosen.data[1] = -cell.vars[1]
			end
		elseif cell.vars[1]:sub(1,1) == "H" then
			SetSelectedCell("hsvpaint")
			chosen.data[1] = tonumber(cell.vars.paint:sub(2,string.find(cell.vars.paint,"S")-1))
			chosen.data[2] = tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"S")+1,string.find(cell.vars.paint,"V")-1))
			chosen.data[3] = tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"V")+1,#cell.vars.paint))
		elseif cell.vars[1]:sub(1,1) == "h" then
			SetSelectedCell("inverthsvpaint")
			chosen.data[1] = tonumber(cell.vars.paint:sub(2,string.find(cell.vars.paint,"s")-1))
			chosen.data[2] = tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"s")+1,string.find(cell.vars.paint,"v")-1))
			chosen.data[3] = tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"v")+1,#cell.vars.paint))
		elseif cell.vars == "i" then
			SetSelectedCell("invertpaint")
		elseif cell.vars == "I" then
			SetSelectedCell("invispaint")
		elseif cell.vars == "s" then
			SetSelectedCell("shadowpaint")
		end
		return true
	else
		local placedvars = GetAttribute(cell.id,"placedvars")
		if placedvars then
			if type(placedvars) == "number" then
				for i=1,placedvars do
					chosen.data[i] = cell.vars[i]
				end
			else
				for k,v in pairs(placedvars) do
					chosen.data[v] = cell.vars[k]
				end
			end
		end
	end
end

function PlaceCell(x,y,cell,z)
	z = z or 0
	if cell == GetCell(x,y,z) or x > 0 and x < width-1 and y > 0 and y < height-1 then
		GetPlacedCell(cell)
		local was = layers[z][y][x]
		if cell.id == 221 or was.id == 221 then
			ResetPortals()
		end
		if cell.id == 563 then
			switches[cell.vars[1]] = cell.vars[2] and true
		end
		if was.id == 708 and richtexts[x+y*width] then
			richtexts[x+y*width].text:release()
			richtexts[x+y*width] = nil
		end
		if cell.id == 708 then
			if cell.vars[1] == "" then return true end
			richtexts[x+y*width] = SetRichText(love.graphics.newText(font),cell.vars[1] or "",math.huge)
		end
		if isinitial and IsEnemy(was) then
			totalenemies = totalenemies - 1
		end
		if isinitial and IsEnemy(cell) then
			totalenemies = totalenemies + 1
		end
		if isinitial and IsAlly(was) then
			totalallies = totalallies - 1
		end
		if isinitial and IsAlly(cell) then
			totalallies = totalallies + 1
		end
		if isinitial and IsNeutral(was) then
			totalplayers = totalplayers - 1
		end
		if isinitial and IsNeutral(cell) then
			totalplayers = totalplayers + 1
		end
		cell.lastvars = {x,y,0}	
		layers[z][y][x] = cell	
		if isinitial then	
			initiallayers[z][y][x].id = cell.id	
			initiallayers[z][y][x].rot = cell.rot	
			initiallayers[z][y][x].vars = table.copy(cell.vars)	
			initiallayers[z][y][x].lastvars = {x,y,0}	
		end
		SetChunk(x,y,z,cell)
		return true
	end
end

function SetCell(x,y,cell,z)
	z = z or 0
	if layers[0][0][0].id == 428 then x=(x-1)%(width-2)+1 y=(y-1)%(height-2)+1 end
	if x > 0 and x < width-1 and y > 0 and y < height-1 and z >= 0 and z < depth then
		local was = layers[z][y][x].id
		layers[z][y][x] = cell
		if layers[z][y][x].id == 221 or was == 221 then
			ResetPortals()
		end
		SetChunk(x,y,z,cell)
	end
end

function GetCell(x,y,z,nowrap)
	z = z or 0
	if layers[0][0][0].id == 428 and not nowrap then x=(x-1)%(width-2)+1 y=(y-1)%(height-2)+1 end
	return (x >= 0 and x < width and y >= 0 and y < height and z >= 0 and z < depth) and layers[z][y][x] or getempty()
end

function GetData(x,y)
	if layers[0][0][0].id == 428 then x=(x-1)%(width-2)+1 y=(y-1)%(height-2)+1 end
	return (x >= 0 and x < width and y >= 0 and y < height) and stilldata[y][x] or {}
end

function GetPlaceable(x,y)
	return (x >= 0 and x < width and y >= 0 and y < height) and placeables[y][x]
end

function SetPlaceable(x,y,v)
	if (x >= 0 and x < width and y >= 0 and y < height) then placeables[y][x] = v end
end

function CopyCell(x,y,z)
	return table.copy(GetCell(x,y,z))
end

function ClearWorld()
	selection.on = false
	isinitial = true
	winscreen = false
	TogglePause(true)
	layers = {}
	initiallayers = {}
	stilldata = {}
	placeables = {}
	width = newwidth+2
	height = newheight+2
	ResetChunks(width,height)
	for z=0,depth-1 do
		layers[z] = {}
		initiallayers[z] = {}
		for y=0,height-1 do
			layers[z][y] = {}
			initiallayers[z][y] = {}
			stilldata[y] = {}
			placeables[y] = {}
			for x=0,width-1 do
				if (x == 0 or x == width-1 or y == 0 or y == height-1) and z == 0 then
					layers[z][y][x] = {id=bordercells[border],rot=0,lastvars={x,y,0},vars={},firstx=x,firsty=y}
					initiallayers[z][y][x] = {id=bordercells[border],rot=0,lastvars={x,y,0},vars={},firstx=x,firsty=y}
					stilldata[y][x] = {}
				else
					layers[z][y][x] = z == 0 and {id=0,rot=0,lastvars={x,y,0},vars={},firstx=x,firsty=y} or getempty()
					initiallayers[z][y][x] = getempty()
					stilldata[y][x] = {}
				end
				if x > 0 and x < width-1 and y > 0 and y < height-1 then
				end
			end
		end
	end
	subtick = 0
	tickcount = 0
	ResetPortals()
end

function RefreshWorld()
	selection.on = false
	isinitial = true
	winscreen = false
	TogglePause(true)
	local borderchange = initiallayers[0][0][0].id ~= bordercells[border]	
	layers = {}	
	stilldata = {}	
	ResetChunks(newwidth+2,newheight+2)
	for z=0,depth-1 do	
		layers[z] = {}	
		for y=0,math.max(height-1,newheight+1) do	
			if y >= height then	
				layers[z][y] = {}	
				initiallayers[z][y] = {}	
				stilldata[y] = {}	
				placeables[y] = {}	
			end	
			if y > newheight+1 then	
				initiallayers[z][y] = nil	
				placeables[y] = nil	
			else	
				layers[z][y] = {}	
				stilldata[y] = {}	
				for x=0,math.max(width-1,newwidth+1) do	
					if (x == 0 or x == newwidth+1 or (y == 0 or y == newheight+1) and x <= newwidth+1) and z == 0 then	
						local p = x <= width-1 and y <= height-1 and initiallayers[z][y][x].vars.paint or nil	
						layers[z][y][x] = {id=bordercells[border],rot=0,lastvars={x,y,0},vars={paint=p},firstx=x,firsty=y}	
						initiallayers[z][y][x] = {id=bordercells[border],rot=0,lastvars={x,y,0},vars={paint=p},firstx=x,firsty=y}
						stilldata[y][x] = {}
					elseif x > newwidth+1 then
						initiallayers[z][y][x] = nil
						placeables[y][x] = nil
					elseif x >= width-1 or y >= height-1 then
						layers[z][y][x] = getempty()
						initiallayers[z][y][x] = getempty()
						stilldata[y][x] = {}
					else
						layers[z][y][x] = table.copy(initiallayers[z][y][x])
						stilldata[y][x] = {}
						SetChunk(x,y,z,initiallayers[z][y][x],true)
					end
				end
			end
		end
	end
	width = newwidth+2
	height = newheight+2
	subtick = 0
	subtickco = nil
	currentsst = nil
	forcespread = {}
	tickcount = 0
	overallcount = 0
	ResetPortals()
end

b74cheatsheet = {}	--i dont know why, but for some reason i have to seperate the cheatsheets even though they use the exact same characters
for i=0,9 do b74cheatsheet[tostring(i)] = i end
for i=0,25 do b74cheatsheet[string.char(string.byte("a")+i)] = i+10 end
for i=0,25 do b74cheatsheet[string.char(string.byte("A")+i)] = i+36 end
b74cheatsheet["!"] = 62 b74cheatsheet["$"] = 63 b74cheatsheet["%"] = 64 b74cheatsheet["&"] = 65 b74cheatsheet["+"] = 66
b74cheatsheet["-"] = 67 b74cheatsheet["."] = 68 b74cheatsheet["="] = 69 b74cheatsheet["?"] = 70 b74cheatsheet["^"] = 71
b74cheatsheet["{"] = 72 b74cheatsheet["}"] = 73
cheatsheet = {}
for i=0,9 do cheatsheet[tostring(i)] = i end
for i=0,25 do cheatsheet[string.char(string.byte("a")+i)] = i+10 end
for i=0,25 do cheatsheet[string.char(string.byte("A")+i)] = i+36 end
cheatsheet["!"] = 62 cheatsheet["$"] = 63 cheatsheet["%"] = 64 cheatsheet["&"] = 65 cheatsheet["+"] = 66
cheatsheet["-"] = 67 cheatsheet["."] = 68 cheatsheet["="] = 69 cheatsheet["?"] = 70 cheatsheet["^"] = 71
cheatsheet["{"] = 72 cheatsheet["}"] = 73 cheatsheet["/"] = 74 cheatsheet["#"] = 75 cheatsheet["_"] = 76
cheatsheet["*"] = 77 cheatsheet["'"] = 78 cheatsheet[":"] = 79 cheatsheet[","] = 80 cheatsheet["@"] = 81
cheatsheet["~"] = 82 cheatsheet["|"] = 83
for k,v in pairs(cheatsheet) do
	cheatsheet[v] = k				--basically "invert" table
end

function unbase74(origvalue)
	local result = 0
	local iter = 0
	local chars = string.len(origvalue)
	for i=chars,1,-1 do
		iter = iter + 1
		local mult = 74^(iter-1)
		result = result + b74cheatsheet[string.sub(origvalue,i,i)] * mult
	end
	return result
end

function unbase84(origvalue)
	local neg = false
	if string.sub(origvalue,1,1) == ">" then
		neg = true
		origvalue = string.sub(origvalue,2,#origvalue)
	end
	local result = 0
	local iter = 0
	local chars = string.len(origvalue)
	for i=chars,1,-1 do
		iter = iter + 1
		local mult = 84^(iter-1)
		--if not cheatsheet[string.sub(origvalue,i,i)] then error(string.sub(origvalue,i,i)) end
		result = result + cheatsheet[string.sub(origvalue,i,i)] * mult
	end
	return result*(neg and -1 or 1)
end

function base84(origvalue)
	local result = ""
	local iter = 0
	local neg = false
	if origvalue == 0 then return 0
	elseif origvalue < 0 then origvalue = -origvalue; neg = true end
	while true do
		iter = iter + 1
		local lowermult = 84^(iter-1)
		local mult = 84^(iter)
		if lowermult > origvalue then
			break
		else
			result = cheatsheet[math.floor(origvalue/lowermult)%84] .. result
		end
	end
	if neg then result = ">"..result end
	return result
end

V3Cells = {}
V3Cells["0"] = {3,0,false} V3Cells["i"] = {3,1,false} V3Cells["A"] = {3,2,false} V3Cells["S"] = {3,3,false}
V3Cells["1"] = {3,0,true} V3Cells["j"] = {3,1,true} V3Cells["B"] = {3,2,true} V3Cells["T"] = {3,3,true} 
V3Cells["2"] = {9,0,false} V3Cells["k"] = {9,1,false} V3Cells["C"] = {9,2,false} V3Cells["U"] = {9,3,false}
V3Cells["3"] = {9,0,true} V3Cells["l"] = {9,1,true} V3Cells["D"] = {9,2,true} V3Cells["V"] = {9,3,true} 
V3Cells["4"] = {10,0,false} V3Cells["m"] = {10,1,false} V3Cells["E"] = {10,2,false} V3Cells["W"] = {10,3,false}
V3Cells["5"] = {10,0,true} V3Cells["n"] = {10,1,true} V3Cells["F"] = {10,2,true} V3Cells["X"] = {10,3,true} 
V3Cells["6"] = {2,0,false} V3Cells["o"] = {2,1,false} V3Cells["G"] = {2,2,false} V3Cells["Y"] = {2,3,false}
V3Cells["7"] = {2,0,true} V3Cells["p"] = {2,1,true} V3Cells["H"] = {2,2,true} V3Cells["Z"] = {2,3,true} 
V3Cells["8"] = {5,0,false} V3Cells["q"] = {5,1,false} V3Cells["I"] = {5,2,false} V3Cells["!"] = {5,3,false}
V3Cells["9"] = {5,0,true} V3Cells["r"] = {5,1,true} V3Cells["J"] = {5,2,true} V3Cells["$"] = {5,3,true} 
V3Cells["a"] = {4,0,false} V3Cells["s"] = {4,1,false} V3Cells["K"] = {4,2,false} V3Cells["%"] = {4,3,false}
V3Cells["b"] = {4,0,true} V3Cells["t"] = {4,1,true} V3Cells["L"] = {4,2,true} V3Cells["&"] = {4,3,true} 
V3Cells["c"] = {1,0,false} V3Cells["u"] = {1,1,false} V3Cells["M"] = {1,2,false} V3Cells["+"] = {1,3,false}
V3Cells["d"] = {1,0,true} V3Cells["v"] = {1,1,true} V3Cells["N"] = {1,2,true} V3Cells["-"] = {1,3,true} 
V3Cells["e"] = {13,0,false} V3Cells["w"] = {13,1,false} V3Cells["O"] = {13,2,false} V3Cells["."] = {13,3,false}
V3Cells["f"] = {13,0,true} V3Cells["x"] = {13,1,true} V3Cells["P"] = {13,2,true} V3Cells["="] = {13,3,true} 
V3Cells["g"] = {12,0,false} V3Cells["y"] = {12,1,false} V3Cells["Q"] = {12,2,false} V3Cells["?"] = {12,3,false}
V3Cells["h"] = {12,0,true} V3Cells["z"] = {12,1,true} V3Cells["R"] = {12,2,true} V3Cells["^"] = {12,3,true} 
V3Cells["{"] = {0,0,false} V3Cells["}"] = {0,0,true} V3Cells[":"] = {0,0,false}

function NumToCell(num,hasplaceables)
	if hasplaceables then
		local id = (math.floor(num/8))
		if id == 0 then id = 1 elseif id == 1 then id = 0 end
		return id, math.floor(num*.5)%4, num%2==1		--id, rot, placeable
	else
		local id = (math.floor(num/4))
		if id == 0 then id = 1 elseif id == 1 then id = 0 end
		return id, num%4
	end
end

symmetries = {
	[0]=1,[1]=1,[4]=1,[9]=1,[10]=1,[11]=1,[12]=1,[13]=1,[18]=1,[19]=1,[20]=1,[21]=1,[22]=1,[24]=1,
	[25]=1,[29]=1,[39]=1,[41]=1,[43]=1,[47]=1,[50]=1,[51]=1,[56]=1,[62]=1,[63]=1,[64]=1,[65]=1,[79]=1,
	[80]=1,[81]=1,[82]=1,[104]=1,[105]=1,[108]=1,[109]=1,[112]=1,[116]=1,[123]=1,[124]=1,[125]=1,[126]=1,[127]=1,[128]=1,
	[129]=1,[130]=1,[131]=1,[132]=1,[133]=1,[133]=1,[134]=1,[135]=1,[136]=1,[137]=1,[138]=1,[139]=1,[141]=1,[142]=1,[144]=1,
	[145]=1,[149]=1,[150]=1,[151]=1,[152]=1,[153]=1,[154]=1,[162]=1,[163]=1,[165]=1,[176]=1,[203]=1,[204]=1,[205]=1,[211]=1,
	[214]=1,[219]=1,[220]=1,[222]=1,[223]=1,[224]=1,[231]=1,[235]=1,[239]=1,[240]=1,[241]=1,[245]=1,[246]=1,[247]=1,[248]=1,
	[251]=1,[252]=1,[266]=1,[253]=1,[285]=1,[286]=1,[288]=1,[289]=1,[290]=1,[291]=1,[292]=1,[293]=1,[294]=1,[295]=1,[296]=1,
	[297]=1,[298]=1,[308]=1,[309]=1,[310]=1,[316]=1,[317]=1,[321]=1,[322]=1,[323]=1,[324]=1,[325]=1,[326]=1,[347]=1,[348]=1,
	[349]=1,[350]=1,[360]=1,[361]=1,[364]=1,[382]=1,[383]=1,[388]=1,[389]=1,[403]=1,[417]=1,[422]=1,[425]=1,[426]=1,[427]=1,
	[428]=1,[429]=1,[430]=1,[431]=1,[432]=1,[435]=1,[437]=1,[438]=1,[439]=1,[440]=1,[441]=1,[442]=1,[443]=1,[444]=1,[446]=1,
	[449]=1,[450]=1,[451]=1,[452]=1,[493]=1,[498]=1,[504]=1,[557]=1,[562]=1,[566]=1,[583]=1,[584]=1,[585]=1,[586]=1,[587]=1,
	[618]=1,[617]=1,[619]=1,[645]=1,[649]=1,[670]=1,[671]=1,[694]=1,[695]=1,[716]=1,[717]=1,[733]=1,[734]=1,[736]=1,[746]=1,
	[808]=1,[809]=1,[810]=1,[811]=1,[812]=1,[813]=1,[827]=1,[828]=1,[838]=1,[839]=1,[896]=1,[935]=1,[965]=1,[966]=1,[978]=1,
	[979]=1,[989]=1,[1172]=1,[1173]=1,[1180]=1,[1181]=1,[1199]=1,

	[5]=2,[15]=2,[30]=2,[31]=2,[38]=2,[66]=2,[67]=2,[68]=2,[69]=2,[70]=2,[84]=2,[85]=2,[87]=2,[88]=2,[89]=2,[90]=2,[92]=2,
	[202]=2,[207]=2,[210]=2,[215]=2,[225]=2,[226]=2,[233]=2,[249]=2,[250]=2,[287]=2,[315]=2,[363]=2,[381]=2,[385]=2,[387]=2,
	[391]=2,[392]=2,[404]=2,[408]=2,[413]=2,[436]=2,[445]=2,[478]=2,[479]=2,[489]=2,[490]=2,[491]=2,[492]=2,[494]=2,[499]=2,
	[555]=2,[560]=2,[601]=2,[615]=2,[647]=2,[650]=2,
}

function EncodeData(data)	
	if type(data) == "number" then	
		local code = base84(data)	
		if string.len(code) > 2 then	
			code = ")"..#code..code	
		elseif string.len(code) > 1 then	
			code = "("..code	
		end	
		return code	
	elseif type(data) == "string" then	
		return "<"..string.gsub(string.gsub(data,"\\","\\\\"),"<","\\<").."<"	
	elseif type(data) == "boolean" and data then	
		return "1"	
	end	
end	

function EncodeCell(x,y)	
	local cell = type(x) == "number" and initiallayers[0][y][x] or x	
	local code = ""	
	local id = cell.id	
	local rot = cell.rot	
	if symmetries[id] == 1 then	
		rot = 0	
	elseif symmetries[id] == 2 then	
		rot = rot%2	
	end	
	if type(id) == "number" then	
		code = EncodeData(id*4+rot)	
	elseif type(id) == "string" then	
		code = "<"..id.."<"..rot	
	end	
	if cell.vars then	
		for k,v in pairs(cell.vars) do	
			code = code.."["..EncodeData(k)..EncodeData(v)	
		end	
	end	
	if type(x) == "number" then	
		local p = GetPlaceable(x,y)	
		if p then	
			code = "]"..EncodeData(p)..code	
		end	
	end	
	return code	
end

function DecodeV3(code)
	loadedcode = "V3"
	local currentspot = 0
	local currentcharacter = 3 --start right after V3;
	local storedstring = ""
	TogglePause(true)
	isinitial = true
	title,subtitle = "","" 
	if selection.on then ToggleSelection() end
	if pasting then TogglePasting() end
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter)
		end
	end
	width = unbase74(storedstring)+2
	storedstring = ""
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	height = unbase74(storedstring)+2
	newwidth = width-2
	newheight = height-2
	border = 2
	ClearWorld()
	storedstring = ""
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ")" then							--basic repeat
			local howmany = unbase74(string.sub(code,currentcharacter+1,currentcharacter+1))
			local howmuch = unbase74(string.sub(code,currentcharacter+2,currentcharacter+2))
			local curcell = 0
			local startspot = currentspot
			for i=1,howmuch do
				if curcell == 0 then
					curcell = howmany
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor(height-1-(currentspot)/(width-2))
				PlaceCell(x,y,CopyCell((startspot-curcell-1)%(width-2)+1,math.floor(height-1-(startspot-curcell)/(width-2))))
				SetPlaceable(x,y,GetPlaceable((startspot-curcell-1)%(width-2)+1,math.floor(height-1-(startspot-curcell)/(width-2))))
			end
			currentcharacter = currentcharacter + 2
		elseif string.sub(code,currentcharacter,currentcharacter) == "(" then						--advanced repeat
			local howmany = ""
			local howmuch = ""
			local simplemuch = false
			while true do
				currentcharacter = currentcharacter + 1
				if string.sub(code,currentcharacter,currentcharacter) == "(" then
					break
				elseif string.sub(code,currentcharacter,currentcharacter) == ")" then
					simplemuch = true
					break
				else
					howmany = howmany..string.sub(code,currentcharacter,currentcharacter)
				end
			end
			howmany = unbase74(howmany)
			if simplemuch then
				currentcharacter = currentcharacter + 1
				howmuch = unbase74(string.sub(code,currentcharacter,currentcharacter))
			else
				while true do
					currentcharacter = currentcharacter + 1
					if string.sub(code,currentcharacter,currentcharacter) == ")" then
						break
					else
						howmuch = howmuch..string.sub(code,currentcharacter,currentcharacter)
					end
				end
				howmuch = unbase74(howmuch)
			end
			local curcell = 0
			local startspot = currentspot
			for i=1,howmuch do
				if curcell == 0 then
					curcell = howmany
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor(height-1-(currentspot)/(width-2))
				PlaceCell(x,y,CopyCell((startspot-curcell-1)%(width-2)+1,math.floor(height-1-(startspot-curcell)/(width-2))))
				SetPlaceable(x,y,GetPlaceable((startspot-curcell-1)%(width-2)+1,math.floor(height-1-(startspot-curcell)/(width-2))))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else																						--one cell
			currentspot = currentspot + 1
			local cell = V3Cells[string.sub(code,currentcharacter,currentcharacter)]
			local x,y = (currentspot-1)%(width-2)+1,math.floor(height-1-(currentspot)/(width-2))
			PlaceCell(x,y,{id=cell[1],rot=cell[2],lastvars={x,y,0},vars=DefaultVars(cell[1])})
			if cell[3] then
				SetPlaceable(x,y,"placeable")
			end
		end
	end	
	Play("beep")
end

function DecodeK1(code)
	loadedcode = "K1"
	local currentspot = 0
	local currentcharacter = 3 --start right after K1;
	local storedstring = ""
	TogglePause(true)
	isinitial = true
	title,subtitle = "","" 
	if selection.on then ToggleSelection() end
	if pasting then TogglePasting() end
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	width = unbase84(storedstring)+2
	storedstring = ""
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	height = unbase84(storedstring)+2
	local hasplaceables
	if string.sub(code,currentcharacter+1,currentcharacter+1) == "0" then
		hasplaceables = false
	else
		hasplaceables = true
	end
	newwidth = width-2
	newheight = height-2
	border = 1
	currentcharacter = currentcharacter + 2
	ClearWorld()
	while currentspot <= (width-2)*(height-2) do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == "<" then						--duplicate the last 6 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*6
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*6
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 6
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == ">" then						--duplicate the last 5 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*5
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*5
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 5
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == "[" then						--duplicate the last 4 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*4
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*4
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 4
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == "]" then						--duplicate the last 3 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*3
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*3
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 3
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == ")" then						--duplicate the last 2 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*2
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*2
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 2
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else																						--one cell
			local celltype,cellrot,place
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				celltype,cellrot,place = NumToCell(unbase84(string.sub(code,currentcharacter+1,currentcharacter+2)),hasplaceables)
				currentcharacter = currentcharacter + 2
			else
				celltype,cellrot,place = NumToCell(unbase84(string.sub(code,currentcharacter,currentcharacter)),hasplaceables)
			end
			currentspot = currentspot + 1
			local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
			PlaceCell(x,y,{id=celltype,rot=cellrot,lastvars={x,y,0},vars=DefaultVars(celltype)})
			if place then
				SetPlaceable(x,y,"placeable")
			end
		end  
	end	
	Play("beep")
end

function DecodeK2(code)
	loadedcode = "K2"
	local currentspot = 0
	local currentcharacter = 3 --start right after K2;
	local storedstring = ""
	TogglePause(true)
	isinitial = true
	title,subtitle = "","" 
	if selection.on then ToggleSelection() end
	if pasting then TogglePasting() end
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	width = unbase84(storedstring)+2
	storedstring = ""
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	height = unbase84(storedstring)+2
	local hasplaceables
	if unbase84(string.sub(code,currentcharacter+1,currentcharacter+1))%2 == 0 then
		hasplaceables = false
	else
		hasplaceables = true
	end
	newwidth = width-2
	newheight = height-2
	border = math.floor(unbase84(string.sub(code,currentcharacter+1,currentcharacter+1))*.5)+1
	currentcharacter = currentcharacter + 2
	ClearWorld()
	while currentspot <= (width-2)*(height-2) do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == "<" then							--duplicate arbitrary amount of cells
			local howmany = 0
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmany = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))
				currentcharacter = currentcharacter + 2
			else
				howmany = unbase84(string.sub(code,currentcharacter,currentcharacter))
			end
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*howmany
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*howmany
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = howmany
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == ">" then						--duplicate the last 5 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*5
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*5
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 5
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == "[" then						--duplicate the last 4 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*4
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*4
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 4
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == "]" then						--duplicate the last 3 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*3
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*3
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 3
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == ")" then						--duplicate the last 2 cells X times
			local howmuch = 0
			currentcharacter = currentcharacter + 1
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				howmuch = unbase84(string.sub(code,currentcharacter+1,currentcharacter+2))*2
				currentcharacter = currentcharacter + 2
			else
				howmuch = unbase84(string.sub(code,currentcharacter,currentcharacter))*2
			end
			local startspot = currentspot
			local curcell = 1
			for i=1,howmuch do
				if curcell == 1 then
					curcell = 2
				else
					curcell = curcell - 1
				end
				currentspot = currentspot + 1
				local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
				PlaceCell(x,y,CopyCell((startspot-curcell)%(width-2)+1,math.floor((startspot-curcell)/(width-2)+1)))
			end
		elseif string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else																						--one cell
			local celltype,cellrot,place
			if string.sub(code,currentcharacter,currentcharacter) == "(" then
				celltype,cellrot,place = NumToCell(unbase84(string.sub(code,currentcharacter+1,currentcharacter+2)),hasplaceables)
				currentcharacter = currentcharacter + 2
			else
				celltype,cellrot,place = NumToCell(unbase84(string.sub(code,currentcharacter,currentcharacter)),hasplaceables)
			end
			currentspot = currentspot + 1
			local x,y = (currentspot-1)%(width-2)+1,math.floor((currentspot-1)/(width-2)+1)
			PlaceCell(x,y,{id=celltype,rot=cellrot,lastvars={x,y,0},vars=DefaultVars(celltype)})
			if place then
				SetPlaceable(x,y,"placeable")
			end
		end  
	end	
	Play("beep")
end

function DecodeK3(code,stamp)
	loadedcode = "K3"
	local currentspot = 0
	local currentcharacter = 3 --start right after K3;
	local storedstring = ""
	if not stamp then
		TogglePause(true)
		isinitial = true
		title,subtitle = "","" 
		if selection.on then ToggleSelection() end
		if pasting then TogglePasting() end
	end
	if string.sub(code,currentcharacter,currentcharacter) == ":" then
		while true do
			currentcharacter = currentcharacter + 1
			local character = string.sub(code,currentcharacter,currentcharacter)
			if character == ";" or character == ":" then
				break
			elseif not stamp then
				title = title..character
			end
		end
		if string.sub(code,currentcharacter,currentcharacter) == ":" then
			while true do
				currentcharacter = currentcharacter + 1
				local character = string.sub(code,currentcharacter,currentcharacter)
				if character == ";" then
					break
				elseif not stamp then
					subtitle = subtitle..character
				end
			end
		end
	end
	if not stamp then
		SetRichText(lvltitle,title,1000,"center")
		SetRichText(lvldesc,subtitle,300,"center")
	end
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	local awidth,aheight
	if stamp then
		awidth = unbase84(storedstring)+2
	else
		width = unbase84(storedstring)+2
	end
	storedstring = ""
	while true do
		currentcharacter = currentcharacter + 1
		if string.sub(code,currentcharacter,currentcharacter) == ";" then
			break
		else
			storedstring = storedstring..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	if stamp then
		aheight = unbase84(storedstring)+2
	else
		height = unbase84(storedstring)+2
	end
	if not stamp then
		newwidth = width-2
		newheight = height-2
	end
	local width = awidth and awidth or width
	local height = aheight and aheight or height
	local array
	if stamp then
		array = {}
		for z=0,depth-1 do
			array[z] = {}
			for y=0,aheight-3 do
				array[z][y] = {}
				for x=0,awidth-3 do
					array[z][y][x] = getempty()
				end
			end
		end
		array[-1] = {}
		for y=0,aheight-2 do
			array[-1][y] = {}
		end
	end
	if not stamp then
		border = unbase84(string.sub(code,currentcharacter+1,currentcharacter+1))+1
	end
	currentcharacter = currentcharacter + 2
	if not stamp then
		ClearWorld()
	end
	if string.sub(code,currentcharacter,currentcharacter) == ":" then
		local paint = ""	
		while true do	
			currentcharacter = currentcharacter + 1	
			local character = string.sub(code,currentcharacter,currentcharacter)	
			if character == ";" then	
				break	
			else	
				paint = paint..character	
			end	
		end	
		if not stamp then
			paint = love.data.decompress("string","zlib",love.data.decode("string","base64",paint))	
			local paintchar = 0	
			local pos = 0	
			while paintchar <= #paint do	
				paintchar = paintchar + 1	
				local character = string.sub(paint,paintchar,paintchar)	
				local p	
				if character == "<" then	
					p = ""	
					paintchar = paintchar + 1	
					local backslash
					character = string.sub(paint,paintchar,paintchar)	
					while character ~= "<" or backslash do	
						if character == "\\" and not backslash then
							backslash = true
						else
							p = p..character
							backslash = false
						end
						paintchar = paintchar + 1	
						character = string.sub(paint,paintchar,paintchar)	
					end	
				else	
					if character == "(" then	
						character = string.sub(paint,paintchar+1,paintchar+2)	
						paintchar = paintchar + 2	
					elseif character == ")" then	
						local num = unbase84(string.sub(paint,paintchar+1,paintchar+1))	
						character = string.sub(paint,paintchar+2,paintchar+1+num)	
						paintchar = paintchar + 1+num	
					end	
					p = unbase84(character)	
				end	
				if p ~= 0 then	
					local x,y = pos%width,math.floor(pos/width)	
					GetCell(x,y).vars.paint = p	
					PlaceCell(x,y,GetCell(x,y))	
				end	
				if pos < width or width*height-pos <= width or pos%width == width-1 then	
					pos = pos + 1	
				else	
					pos = pos + width - 1	
				end	
			end	
		end	
	end
	local data = ""
	while true do
		currentcharacter = currentcharacter + 1
		local c = string.sub(code,currentcharacter,currentcharacter)
		if c == ";" or c == "" then
			break
		else
			data = data..string.sub(code,currentcharacter,currentcharacter) 
		end
	end
	local celltext = love.data.decompress("string","zlib",love.data.decode("string","base64",data))
	local currentcell = 0
	currentcharacter = 1
	local z,zset = 0,false
	while currentcharacter <= #celltext do
		local character = string.sub(celltext,currentcharacter,currentcharacter)
		if character == "\\" then
			currentcell = currentcell - 1
			currentcharacter = currentcharacter + 1
			character = string.sub(celltext,currentcharacter,currentcharacter)
			z,zset = unbase84(character),true
		elseif character == "]" then
			currentcharacter = currentcharacter + 1
			character = string.sub(celltext,currentcharacter,currentcharacter)
			local p
			if character == "<" then
				p = ""
				currentcharacter = currentcharacter + 1
				local backslash
				character = string.sub(celltext,currentcharacter,currentcharacter)
				while character ~= "<" or backslash do	
					if character == "\\" and not backslash then
						backslash = true
					else
						p = p..character
						backslash = false
					end
					currentcharacter = currentcharacter + 1
					character = string.sub(celltext,currentcharacter,currentcharacter)
				end
			else
				if character == "(" then
					character = string.sub(celltext,currentcharacter+1,currentcharacter+2)
					currentcharacter = currentcharacter + 2
				elseif character == ")" then
					local num = unbase84(string.sub(celltext,currentcharacter+1,currentcharacter+1))
					character = string.sub(celltext,currentcharacter+2,currentcharacter+1+num)
					currentcharacter = currentcharacter + 1+num
				end
				p = unbase84(character)
			end
			local x,y = currentcell%(width-2)+1,math.floor(currentcell/(width-2))+1
			if not stamp then
				SetPlaceable(x,y,p)
			end
		elseif character == "[" then
			currentcell = currentcell - 1
			currentcharacter = currentcharacter + 1
			character = string.sub(celltext,currentcharacter,currentcharacter)
			local k
			if character == "<" then
				k = ""
				currentcharacter = currentcharacter + 1
				local backslash
				character = string.sub(celltext,currentcharacter,currentcharacter)
				while character ~= "<" or backslash do
					if character == "\\" and not backslash then
						backslash = true
					else
						k = k..character
						backslash = false
					end
					currentcharacter = currentcharacter + 1
					character = string.sub(celltext,currentcharacter,currentcharacter)
				end
			else
				if character == "(" then
					character = string.sub(celltext,currentcharacter+1,currentcharacter+2)
					currentcharacter = currentcharacter + 2
				elseif character == ")" then
					local num = unbase84(string.sub(celltext,currentcharacter+1,currentcharacter+1))
					character = string.sub(celltext,currentcharacter+2,currentcharacter+1+num)
					currentcharacter = currentcharacter + 1+num
				end
				k = unbase84(character)
			end
			currentcharacter = currentcharacter + 1
			character = string.sub(celltext,currentcharacter,currentcharacter)
			local v
			if character == "<" then
				v = ""
				currentcharacter = currentcharacter + 1
				local backslash
				character = string.sub(celltext,currentcharacter,currentcharacter)
				while character ~= "<" or backslash do
					if character == "\\" and not backslash then
						backslash = true
					else
						v = v..character
						backslash = false
					end
					currentcharacter = currentcharacter + 1
					character = string.sub(celltext,currentcharacter,currentcharacter)
				end
			else
				if character == "(" then
					character = string.sub(celltext,currentcharacter+1,currentcharacter+2)
					currentcharacter = currentcharacter + 2
				elseif character == ")" then
					local num = unbase84(string.sub(celltext,currentcharacter+1,currentcharacter+1))
					character = string.sub(celltext,currentcharacter+2,currentcharacter+1+num)
					currentcharacter = currentcharacter + 1+num
				end
				v = unbase84(character)
			end
			local x,y = currentcell%(width-2)+1,math.floor(currentcell/(width-2))+1
			if stamp then
				array[z][y-1][x-1].vars[k] = v
			else
				initiallayers[z][y][x].vars[k] = v
				layers[z][y][x].vars[k] = v
			end
			currentcell = currentcell + 1
		else
			z = zset and z or 0
			zset = false
			local x,y = currentcell%(width-2)+1,math.floor(currentcell/(width-2))+1
			if character == "<" then
				local cell = ""
				currentcharacter = currentcharacter + 1
				character = string.sub(celltext,currentcharacter,currentcharacter)
				while character ~= "<" or backslash do
					if character == "\\" and not backslash then
						backslash = true
					else
						cell = cell..character
						backslash = false
					end
					currentcharacter = currentcharacter + 1
					character = string.sub(celltext,currentcharacter,currentcharacter)
				end
				currentcharacter = currentcharacter + 1
				character = string.sub(celltext,currentcharacter,currentcharacter)
				PlaceCell(x,y,{id=cell,rot=tonumber(character),lastvars={x,y,0},vars=DefaultVars(cell)})
			else
				if character == "(" then
					character = string.sub(celltext,currentcharacter+1,currentcharacter+2)
					currentcharacter = currentcharacter + 2
				elseif character == ")" then
					local num = unbase84(string.sub(celltext,currentcharacter+1,currentcharacter+1))
					character = string.sub(celltext,currentcharacter+2,currentcharacter+1+num)
					currentcharacter = currentcharacter + 1+num
				end
				local cell = unbase84(character)
				if stamp then
					array[z][y-1][x-1] = {id=math.floor(cell/4),rot=cell%4,lastvars={x,y,0},vars=DefaultVars(math.floor(cell/4))}
				else
					PlaceCell(x,y,{id=math.floor(cell/4),rot=cell%4,lastvars={x,y,0},vars=DefaultVars(math.floor(cell/4))},z)
				end
			end
			currentcell = currentcell + 1
		end
		currentcharacter = currentcharacter + 1
	end
	if stamp then
		return array
	else
		ResetPortals()
		Play("beep")
	end
end

function LoadError()
	Play("destroy")
	title = "#ff0000ERROR"
	subtitle = "#ff0000Something went wrong while loading the level. Sorry!"
	SetRichText(lvltitle,title,1000,"center")
	SetRichText(lvldesc,subtitle,300,"center")
	return false
end

function LoadWorld(txt)
	txt = txt or love.system.getClipboardText()
	while string.len(txt) > 0 do
		if string.sub(txt,1,2) == "V3" then
			if not pcall(DecodeV3,txt) then return LoadError() end
			return true
		elseif string.sub(txt,1,2) == "K1" then
			if not pcall(DecodeK1,txt) then return LoadError() end
			return true
		elseif string.sub(txt,1,2) == "K2" then
			if not pcall(DecodeK2,txt) then return LoadError() end
			return true
		elseif string.sub(txt,1,2) == "K3" then
			if not pcall(DecodeK3,txt) then return LoadError() end
			return true
		end
		txt = string.sub(txt,2)
	end
	Play("destroy")
	return false
end

function NextLevel()
	if level then
		level = level+1
		if level > (plvl and #plevels or #levels) then
			ToMenu("back")
			puzzle = true
			inmenu = false
			level = nil
			Play("beep")
		else
			puzzle = true
			DecodeK3((plvl and plevels or levels)[level][2])
			ToMenu(false)
		end
	else
		RefreshWorld()
	end
end

function GetBorderPaint()	
	local borderpaint,haspaint = "",false	
	for cx=0,width-1 do	
		if GetCell(cx,0).vars.paint then	
			haspaint = true	
			borderpaint = borderpaint..EncodeData(GetCell(cx,0).vars.paint)	
		else	
			borderpaint = borderpaint.."0"	
		end	
	end	
	for cy=1,height-2 do	
		if GetCell(0,cy).vars.paint then	
			haspaint = true	
			borderpaint = borderpaint..EncodeData(GetCell(0,cy).vars.paint)	
		else	
			borderpaint = borderpaint.."0"	
		end	
		if GetCell(width-1,cy).vars.paint then	
			haspaint = true	
			borderpaint = borderpaint..EncodeData(GetCell(width-1,cy).vars.paint)	
		else	
			borderpaint = borderpaint.."0"	
		end	
	end	
	for cx=0,width-1 do	
		if GetCell(cx,height-1).vars.paint then	
			haspaint = true	
			borderpaint = borderpaint..EncodeData(GetCell(cx,height-1).vars.paint)	
		else	
			borderpaint = borderpaint.."0"	
		end	
	end	
	if haspaint then	
		return ":"..love.data.encode("string","base64",love.data.compress("string","zlib",borderpaint,9))	
	else	
		return ""	
	end	
end	

function SaveWorld()
	local currentcell = 0
	local result = "K3:"..title..":"..subtitle..";"
	result = result..base84(width-2)..";"..base84(height-2)..";"	
	result = result..base84(border-1)..GetBorderPaint()..";"
	local cellcode = ""
	local cellcodes = {}
	for y=1,height-2 do
		cellcodes[y] = ""
		for x=1,width-2 do
			for z=0,depth-1 do
				local c = initiallayers[z][y][x]
				if c.id ~= 0 or z == 0 then
					local c = EncodeCell(z == 0 and x or c,y)
					cellcodes[y] = cellcodes[y]..(z ~= 0 and "\\"..cheatsheet[z] or "")..c	--please tell me we wont have more than 84 layers
				end
			end
		end
	end
	for i=1,#cellcodes do
		cellcode = cellcode..cellcodes[i]	--apparently this somehow makes it faster?? not complaining though
	end
	cellcode = love.data.encode("string","base64",love.data.compress("string","zlib",cellcode,9))
	result = result..cellcode..";"
	love.system.setClipboardText(result)
	Play("beep")
end

function SetInitial()
	for z=0,depth-1 do
		for y=0,height-1 do
			for x=0,width-1 do
				initiallayers[z][y][x] = {}
				initiallayers[z][y][x].id = layers[z][y][x].id
				initiallayers[z][y][x].rot = layers[z][y][x].rot
				initiallayers[z][y][x].lastvars = {x,y,0}
				initiallayers[z][y][x].vars = table.copy(layers[z][y][x].vars)
			end
		end
	end
	isinitial = true
	ResetPortals()
end

function TogglePause(v)
	if winscreen or level and not paused and not isinitial then return end
	if paused ~= v then
		if not v and draggedcell then
			local cx = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
			local cy = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
			if GetPlaceable(cx,cy) == GetPlaceable(draggedcell.lastvars[1],draggedcell.lastvars[2]) then
				PlaceCell(draggedcell.lastvars[1],draggedcell.lastvars[2],GetCell(cx,cy))
				PlaceCell(cx,cy,draggedcell)
			else
				PlaceCell(draggedcell.lastvars[1],draggedcell.lastvars[2],draggedcell)
			end
			draggedcell = nil
		end
		paused = v
		isinitial = isinitial and paused
		buttons.playbtn.icon = paused and 2 or 5
		buttons.playbtn.rot = paused and 0 or math.halfpi
		buttons.playbtn.name = paused and "Unpause (Space)" or "Pause (Space)"
	end
end

function RotateCW()
	if pasting then
		local oldcopied = table.copy(copied)
		copied = {}
		for z=0,#oldcopied do
			copied[z] = {}
			for y=0,#oldcopied[0][0] do
				copied[z][y] = {}
				for x=0,#oldcopied[0] do
					copied[z][y][x] = oldcopied[z][#oldcopied[0]-x][y]
					RotateCellRaw(copied[z][y][x],1)
					copied[z][y][x].lastvars[3] = 0
				end
			end
		end
		copied[-1] = {}
		for y=0,#oldcopied[0][0] do
			copied[-1][y] = {}
			for x=0,#oldcopied[0] do
				copied[-1][y][x] = oldcopied[-1][#oldcopied[0]-x][y]
			end
		end
	else
		hudrot,hudlerp = chosen.rot,0
		chosen.rot = (chosen.rot+1)%4
	end
end

function RotateCCW()
	if pasting then
		local oldcopied = table.copy(copied)
		copied = {}
		for z=0,#oldcopied do
			copied[z] = {}
			for y=0,#oldcopied[0][0] do
				copied[z][y] = {}
				for x=0,#oldcopied[0] do
					copied[z][y][x] = oldcopied[z][x][#oldcopied[0][0]-y]
					RotateCellRaw(copied[z][y][x],-1)
					copied[z][y][x].lastvars[3] = 0
				end
			end
		end
		copied[-1] = {}
		for y=0,#oldcopied[0][0] do
			copied[-1][y] = {}
			for x=0,#oldcopied[0] do
				copied[-1][y][x] = oldcopied[-1][x][#oldcopied[0][0]-y]
			end
		end
	else
		hudrot,hudlerp = chosen.rot,0
		chosen.rot = (chosen.rot-1)%4
	end
end

function FlipH()
	if pasting then
		local oldcopied = table.copy(copied)
		copied = {}
		for z=0,#oldcopied do
			copied[z] = {}
			for y=0,#oldcopied[0] do
				copied[z][y] = {}
				for x=0,#oldcopied[0][0] do
					copied[z][y][x] = oldcopied[z][y][#oldcopied[0][0]-x]
					FlipCellRaw(copied[z][y][x],0)
				end
			end
		end
		copied[-1] = {}
		for y=0,#oldcopied[0] do
			copied[-1][y] = {}
			for x=0,#oldcopied[0][0] do
				copied[-1][y][x] = oldcopied[-1][y][#oldcopied[0][0]-x]
				if copied[-1][y][x] == "duflippable" then copied[-1][y][x] = "ddflippable"
				elseif copied[-1][y][x] == "ddflippable" then copied[-1][y][x] = "duflippable" end
			end
		end
	else
		hudrot,hudlerp = chosen.rot,0
		chosen.rot = (-chosen.rot+2)%4
	end
end

function FlipV()
	if pasting then
		local oldcopied = table.copy(copied)
		copied = {}
		for z=0,#oldcopied do
			copied[z] = {}
			for y=0,#oldcopied[0] do
				copied[z][y] = {}
				for x=0,#oldcopied[0][0] do
					copied[z][y][x] = oldcopied[z][#oldcopied[0]-y][x]
					FlipCellRaw(copied[z][y][x],1)
				end
			end
		end
		copied[-1] = {}
		for y=0,#oldcopied[0] do
			copied[-1][y] = {}
			for x=0,#oldcopied[0][0] do
				copied[-1][y][x] = oldcopied[-1][#oldcopied[0]-y][x]
				if copied[-1][y][x] == "duflippable" then copied[-1][y][x] = "ddflippable"
				elseif copied[-1][y][x] == "ddflippable" then copied[-1][y][x] = "duflippable" end
			end
		end
	else
		hudrot,hudlerp = chosen.rot,0
		chosen.rot = (-chosen.rot)%4
	end
end

function FlipDU()
	if pasting then
		local oldcopied = table.copy(copied)
		copied = {}
		for z=0,#oldcopied do
			copied[z] = {}
			for y=0,#oldcopied[0][0] do
				copied[z][y] = {}
				for x=0,#oldcopied[0] do
					copied[z][y][x] = oldcopied[z][x][y]
					FlipCellRaw(copied[z][y][x],1.5)
				end
			end
		end
		copied[-1] = {}
		for y=0,#oldcopied[0][0] do
			copied[-1][y] = {}
			for x=0,#oldcopied[0] do
				copied[-1][y][x] = oldcopied[-1][x][y]
				if copied[-1][y][x] == "hflippable" then copied[-1][y][x] = "vflippable"
				elseif copied[-1][y][x] == "vflippable" then copied[-1][y][x] = "hflippable" end
			end
		end
	else
		hudrot,hudlerp = chosen.rot,0
	end
end

function FlipDD()
	if pasting then
		local oldcopied = table.copy(copied)
		copied = {}
		for z=0,#oldcopied do
			copied[z] = {}
			for y=0,#oldcopied[0][0] do
				copied[z][y] = {}
				for x=0,#oldcopied[0] do
					copied[z][y][x] = oldcopied[z][#oldcopied[0]-x][#oldcopied[0][0]-y]
					FlipCellRaw(copied[z][y][x],.5)
				end
			end
		end
		copied[-1] = {}
		for y=0,#oldcopied[0][0] do
			copied[-1][y] = {}
			for x=0,#oldcopied[0] do
				copied[-1][y][x] = oldcopied[-1][#oldcopied[0]-x][#oldcopied[0][0]-y]
				if copied[-1][y][x] == "hflippable" then copied[-1][y][x] = "vflippable"
				elseif copied[-1][y][x] == "vflippable" then copied[-1][y][x] = "hflippable" end
			end
		end
	else
		hudrot,hudlerp = chosen.rot,0
	end
end

function Scatter()
	if pasting then
		for y=0,#copied[0] do
			for x=0,#copied[0][0] do
				local cx,cy = math.random(0,#copied[0][0]),math.random(0,#copied[0])
				for z=-1,#copied do
					local old = copied[z][cy][cx]
					copied[z][cy][cx] = copied[z][y][x]
					copied[z][y][x] = old
				end
			end
		end
	end
end

function Undo()
	if #undocells > 0 then
		layers = undocells[1]
		placeables = undocells[1].background
		chunks = undocells[1].chunks
		isinitial = undocells[1].isinitial
		width = undocells[1].width
		height = undocells[1].height
		newwidth,newheight = width-2,height-2
		if isinitial then
			initiallayers = table.copy(undocells[1])
		end
		table.remove(undocells,1)
	end
end

function ChangeZoom(y)
	cam.zoomlevel = math.min(math.max(cam.zoomlevel + y,1),#zoomlevels)
	cam.tarx = cam.tarx*(zoomlevels[cam.zoomlevel]/cam.tarzoom)
	cam.tary = cam.tary*(zoomlevels[cam.zoomlevel]/cam.tarzoom)
	cam.tarzoom = zoomlevels[cam.zoomlevel]
end

function ToggleSelection()
	selection.on = not selection.on
	selection.x = 0
	selection.y = 0
	selection.w = 0
	selection.h = 0
	SetEnabledColors(buttons.select,selection.on)
	if selection.on then
		if pasting then TogglePasting() end
		if filling then ToggleFill() end
	end
end

function TogglePasting()
	if not pasting and copied[0] and not puzzle or pasting then 
		pasting = not pasting
	end
	SetEnabledColors(buttons.paste,pasting)
	if pasting then
		if selection.on then ToggleSelection() end
		if filling then ToggleFill() end
	end
end

function ToggleFill()
	filling = not filling
	SetEnabledColors(buttons.fill,filling)
	if filling then
		if pasting then TogglePasting() end
		if selection.on then ToggleSelection() end
	end
end

function CopySelection()
	if not selection.on or selection.w == 0 or selection.h == 0 then return end
	copied = {}
	for z=0,depth-1 do
		copied[z] = {}
		for y=0,selection.h-1 do
			copied[z][y] = {}
			for x=0,selection.w-1 do
				copied[z][y][x] = CopyCell(x+selection.x,y+selection.y,z)
			end
		end
	end
	copied[-1] = {}
	for y=0,selection.h-1 do
		copied[-1][y] = {}
		for x=0,selection.w-1 do
			copied[-1][y][x] = GetPlaceable(x+selection.x,y+selection.y)
		end
	end
	ToggleSelection()
end

function CutSelection()
	if not selection.on or selection.w == 0 or selection.h == 0 then return end
	for z=0,depth-1 do
		copied[z] = {}
		for y=0,selection.h-1 do
			copied[z][y] = {}
			for x=0,selection.w-1 do
				copied[z][y][x] = CopyCell(x+selection.x,y+selection.y,z)
				PlaceCell(x+selection.x,y+selection.y,getempty(),z)
			end
		end
	end
	copied[-1] = {}
	for y=0,selection.h-1 do
		copied[-1][y] = {}
		for x=0,selection.w-1 do
			copied[-1][y][x] = GetPlaceable(x+selection.x,y+selection.y)
			SetPlaceable(x+selection.x,y+selection.y)
		end
	end
	ToggleSelection()
end

function DeleteSelection()
	if not selection.on or selection.w == 0 or selection.h == 0 then return end
	for z=0,depth-1 do
		for y=0,selection.h-1 do
			for x=0,selection.w-1 do
				PlaceCell(x+selection.x,y+selection.y,getempty(),z)
			end
		end
	end
	for y=0,selection.h-1 do
		for x=0,selection.w-1 do
			SetPlaceable(x+selection.x,y+selection.y)
		end
	end
	ToggleSelection()
end
stamps = {}
stamppage = 0
stampimgs = {}
function CreateStamp()
	if not selection.on or selection.w == 0 or selection.h == 0 then Play("destroy") return end
	local result = "K3;"..base84(selection.w)..";"..base84(selection.h)..";0;"
	local cellcode = ""
	local cellcodes = {}
	for y=0,selection.h-1 do
		cellcodes[y+1] = ""
		for x=0,selection.w-1 do
			for z=0,depth-1 do
				local c = GetCell(selection.x+x,selection.y+y,z)
				if c.id ~= 0 or z == 0 then
					local c = EncodeCell(c)
					cellcodes[y+1] = cellcodes[y+1]..(z ~= 0 and "\\"..cheatsheet[z] or "")..c
				end
			end
		end
	end
	for i=1,#cellcodes do
		cellcode = cellcode..cellcodes[i]
	end
	cellcode = love.data.encode("string","base64",love.data.compress("string","zlib",cellcode,9))
	result = result..cellcode..";"
	local t = os.time()
	if not love.filesystem.getInfo("stamps") then
		love.filesystem.createDirectory("stamps")
	end
	local name = string.format("%x",t)
	while love.filesystem.getInfo("stamps/"..name..".txt") do
		t = t + 1
	end
	love.filesystem.write("stamps/"..name..".txt",result)
	MakeStampThumbnail(result,1)
	table.insert(stamps,1,{data=result,name=name})
	ToggleSelection()
	Play("beep") 
end

function RemoveStamp(i)
	local name = stamps[i].name
	if love.filesystem.getInfo("stamps") then
		love.filesystem.remove("stamps/"..stamps[i].name..".txt")
	end
	table.remove(stamps,i)
end

function StampMenu()
	stamppage = 0
	ToMenu("stamps")
	Play("beep")
end

function MakeStampThumbnail(data,i)
	local array = DecodeK3(data,true)
	local w,h = cellsize*(#array[0][0]+1),cellsize*(#array[0]+1)
	local size = math.max(w*3/4,h)
	local canv = love.graphics.newCanvas(size*4/3,size)
	love.graphics.setCanvas(canv)
	love.graphics.setColor(love.graphics.getBackgroundColor())
	love.graphics.rectangle("fill",0,0,canv:getWidth(),canv:getHeight())
	love.graphics.setColor(1,1,1,1)
	local camera = cam
	cam = {x=400*winxm-math.max((size-w*3/4)*4/3,0)/2,y=300*winym-math.max(size-h,0)/2,zoom=cellsize}
	for z=0,#array do
		for y=0,#array[0] do
			for x=0,#array[0][0] do
				DrawCell(array[z][y][x],x,y,false,1)
				if array[z][y][x].id == 0 and z == 0 then
					local texture = GetTex(0).normal
					local texsize = GetTex(0).size
					love.graphics.draw(texture,(x+.5)*cam.zoom-cam.x+400*winxm,(y+.5)*cam.zoom-cam.y+300*winym,0,math.ceil(cam.zoom)/texsize.w,math.ceil(cam.zoom)/texsize.h,texsize.w2,texsize.h2)
				end
			end
		end
	end
	love.graphics.setCanvas()
	cam = camera
	local d = canv:newImageData()
	table.insert(stampimgs,i,love.graphics.newImage(d))
	canv:release()
	d:release()
end

function ReloadStamps()
	for i=1,#stamps do
		UnloadTex("stamp_"..stamps[i].name)
	end
	stamps = {}
	local names = {}
	if love.filesystem.getInfo("stamps") then
		local files = love.filesystem.getDirectoryItems("stamps")
		for i=1,#files do
			local num = 1
			while names[num] and tonumber(names[num],16) > tonumber(files[i]:sub(1,-5),16) do
				num = num + 1
			end
			table.insert(names,num,files[i]:sub(1,-5))
		end
	end
	for i=1,#names do
		local data = love.filesystem.read("stamps/"..names[i]..".txt")
		MakeStampThumbnail(data,i)
		stamps[i] = {name=names[i],data=data}
	end
end

function NextStampPage()
	if stamppage-1 < #stamps/12 then
		stamppage = stamppage + 1
	end
end
function LastStampPage()
	if stamppage > 0 then
		stamppage = stamppage - 1
	end
end

function ChangeEditMode()
	if chosen.mode == "All" then
		chosen.mode = "Or"
		buttons.editmode.icon = "edit_or"
	elseif chosen.mode == "Or" then
		chosen.mode = "And"
		buttons.editmode.icon = "edit_and"
	else
		chosen.mode = "All"
		buttons.editmode.icon = "edit_all"
	end
	SetEnabledColors(buttons.editmode,chosen.mode ~= "All")
end

function ChangeEditShape()
	if chosen.shape == "Square" then
		chosen.shape = "Circle"
		buttons.editshape.icon = "shape_circle"
	else
		chosen.shape = "Square"
		buttons.editshape.icon = "shape_square"
	end
end

function ToggleRandRot()
	chosen.randrot = not chosen.randrot
	SetEnabledColors(buttons.randrot,chosen.randrot)
end

function ResetCam()
	cam.x,cam.y,cam.tarx,cam.tary,cam.zoom,cam.tarzoom,cam.zoomlevel = 0,0,0,0,cellsize,cellsize,defaultzoom
end

function SetEnabledColors(b,on,menu)
	if menu then
		if on then
			b.color = {.25,.5,.25,1}
			b.hovercolor = {.33,.75,.33,1}
			b.clickcolor = {.125,.25,.125,1}
		else
			b.color = {.5,.5,.5,1}
			b.hovercolor = {.75,.75,.75,1}
			b.clickcolor = {.25,.25,.25,1}
		end
	else
		if on then
			b.color = {.5,1,.5,.5}
			b.hovercolor = {.5,1,.5,1}
			b.clickcolor = {.25,.5,.25,1}
		else
			b.color = {1,1,1,.5}
			b.hovercolor = {1,1,1,1}
			b.clickcolor = {.5,.5,.5,1}
		end
	end
end

function ToMenu(screen)
	propertiesopen = 0
	if screen == "back" then
		mainmenu = menustack[#menustack]
		menustack[#menustack] = nil
		Resplash()
	elseif screen ~= mainmenu then
		table.insert(menustack,mainmenu)
		mainmenu = screen
	end
end

function MenuRect(x,y,w,h,inclr,outclr)
	love.graphics.setColor(inclr or {.5,.5,.5,.5})
	love.graphics.rectangle("fill",x,y,w,h,5,5)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(outclr or {.5,.5,.5,1})
	love.graphics.rectangle("line",x,y,w,h,5,5)
end

local function recursivelyDelete(item) -- modified from https://love2d.org/wiki/love.filesystem.remove
	if love.filesystem.getInfo(item, "directory") then
		for _,v in ipairs(love.filesystem.getDirectoryItems(item)) do
			recursivelyDelete(item.."/"..v)
			love.filesystem.remove(item.."/"..v)
		end
	elseif love.filesystem.getInfo(item) then
		love.filesystem.remove(item)
	end
end

function CreateMenu()
	bactive = function() return inmenu and not winscreen and not mainmenu and not wikimenu end
	optionbactive = function() return (inmenu and not winscreen and not mainmenu or mainmenu == "options") and not wikimenu end
	strictbactive = function() return inmenu and not level and not mainmenu and not wikimenu end
	stricterbactive = function() return inmenu and not puzzle and not mainmenu and not wikimenu end
	stampactive = function() return inmenu == "stamps" and not mainmenu and not wikimenu end
	wactive = function() return winscreen and not mainmenu and not wikimenu end
	mble = function() return moreui and not mainmenu end
	mbleandnopuz = function() return moreui and not puzzle and not mainmenu end
	mbleandnolvl = function() return moreui and not level and not mainmenu end
	titlemenu = function() return mainmenu == "title" end
	puzzlemenu = function() return mainmenu == "puzzles" end
	exitbtn = function() return mainmenu and mainmenu ~= "title" end
	searchbar = function() return mainmenu == "search" end
	secretbar = function() return mainmenu == "secret" end
	wmexport = function() return not inmenu and not winscreen and not mainmenu and wikimenu == "export" end
	NewButton(20,20,40,40,"menu","menu","Menu",nil,function() inmenu = not inmenu and not winscreen end,false,function() return not mainmenu end,"topleft",0)
	NewButton(70,20,40,40,"zoomin","zoomin","Zoom In",nil,function() ChangeZoom(1) end,false,mble,"topleft",0)
	NewButton(120,20,40,40,"zoomout","zoomout","Zoom Out",nil,function() ChangeZoom(-1) end,false,mble,"topleft",0)
	NewButton(170,20,40,40,"eraser","erase","Eraser",nil,function() SetSelectedCell("eraser") end,false,mbleandnopuz,"topleft",0)
	NewButton(220,20,40,40,"brushup","brushup","Increase Brush Size",nil,function() chosen.size = chosen.size + 1 end,false,mbleandnopuz,"topleft",0)
	NewButton(270,20,40,40,"exportimage","exportimage","Export Selection as Image",nil,function()
		inmenu = false
		wikimenu = not wikimenu and "export"
	end,false,mbleandnopuz,"topleft",0)
	NewButton(20,70,40,40,"select","select","Select (Tab)",nil,ToggleSelection,false,mbleandnopuz,"topleft",0)
	NewButton(70,70,40,40,"copy","copy","Copy Selected (Ctrl+C)",nil,CopySelection,false,mbleandnopuz,"topleft",0)
	NewButton(120,70,40,40,"cut","cut","Cut Selected (Ctrl+X)",nil,CutSelection,false,mbleandnopuz,"topleft",0)
	NewButton(170,70,40,40,"delete","remove","Delete Selected (Backspace)",nil,DeleteSelection,false,mbleandnopuz,"topleft",0)
	NewButton(220,70,40,40,"brushdown","brushdown","Decrease Brush Size",nil,function() chosen.size = math.max(1,chosen.size - 1) end,false,mbleandnopuz,"topleft",0)
	NewButton(20,120,40,40,10,"rotateccw","Rotate CCW (Q)",nil,RotateCCW,false,mbleandnopuz,"topleft",0)
	NewButton(70,120,40,40,9,"rotatecw","Rotate CW (E)",nil,RotateCW,false,mbleandnopuz,"topleft",0)
	NewButton(120,120,40,40,"paste","paste","Paste (Ctrl+V)",nil,TogglePasting,false,function() return moreui and not puzzle and not mainmenu end,"topleft",0)
	NewButton(170,120,40,40,"fill","fill","Fill",nil,ToggleFill,false,function() return moreui and not puzzle and not mainmenu end,"topleft",0)
	NewButton(220,120,40,40,"scatter","scatter","Scatter Copied",nil,Scatter,false,mbleandnopuz,"topleft",0)
	NewButton(20,170,40,40,30,"fliph","Flip Horizontally (Ctrl+Q)",nil,FlipH,false,mbleandnopuz,"topleft",0)
	NewButton(70,170,40,40,30,"flipv","Flip Vertically (Ctrl+E)",nil,FlipV,false,mbleandnopuz,"topleft",0,math.halfpi)
	NewButton(120,170,40,40,654,"flipdu","Flip Diagonally",nil,FlipDU,false,mbleandnopuz,"topleft",0)
	NewButton(170,170,40,40,654,"flipdd","Flip Diagonally",nil,FlipDD,false,mbleandnopuz,"topleft",0,math.halfpi)
	NewButton(220,170,40,40,"randrot","randrot","Random Rotation",nil,ToggleRandRot,false,mbleandnopuz,"topleft",0)
	NewButton(20,220,40,40,"addstamp","newstampbtn","New Stamp (Ctrl+K)",nil,CreateStamp,false,mbleandnopuz,"topleft",0)
	NewButton(70,220,40,40,"stamp","stampsbtn","Stamps (K)",nil,StampMenu,false,mbleandnopuz,"topleft",0)
	NewButton(120,220,40,40,"edit_all","editmode","Brush Mode",function() return "Current: "..chosen.mode end,ChangeEditMode,false,mbleandnopuz,"topleft",0)
	NewButton(170,220,40,40,"shape_square","editshape","Brush Shape",function() return "Current: "..chosen.shape end,ChangeEditShape,false,mbleandnopuz,"topleft",0)
	NewButton(220,220,40,40,"search","search","Search (Ctrl+F)",nil,function() ToMenu("search"); typing = searchtypefunc; Play("beep") end,false,mbleandnopuz,"topleft",0)
	NewButton(20,20,40,40,2,"playbtn","Unpause (Space)",nil,function() TogglePause(not paused) end,false,function() return moreui and not mainmenu and (paused or not level) end,"topright",0)
	NewButton(70,20,40,40,114,"stepbtn","Step (F)",nil,function() DoTick(true) TogglePause(true) end,false,mbleandnolvl,"topright",0)
	NewButton(120,20,40,40,14,"undobtn","Undo (Ctrl+Z)",nil,Undo,false,function() return moreui and not mainmenu and #undocells > 0 and not puzzle end,"topright",0,math.pi)
	NewButton(20,function() return level and 20 or 70 end,40,40,11,"resetlvl","Reset (Ctrl+R)",nil,function() RefreshWorld(); Play("beep") end,false,function() return not isinitial and moreui and not mainmenu end,"topright",0)
	NewButton(function() return moreui and 70 or 20 end,function() return moreui and 70 or 20 end,40,40,146,"setinitial","Set Initial","Sets the initial state to the current state.",SetInitial,false,function() return not isinitial and not puzzle and not mainmenu end,"topright",0)
	local menubg = NewButton(0,-10,400,320,"px","menubg",nil,nil,function() end,false,function() return (inmenu or winscreen or wikimenu) and not mainmenu end,"center",1999,nil,{1,1,1,0},{1,1,1,0},{1,1,1,0})
	menubg.drawfunc = function(x,y,b)
		MenuRect(x-200*uiscale,y-160*uiscale,400*uiscale,320*uiscale)
	end
	NewButton(-150,100,40,40,2,"closemenu","Close Menu",nil,function() inmenu = false Play("beep") end,false,bactive,"center",2000)
	NewButton(-100,100,40,40,11,"resetlvlmenu","Reset Level","Also resizes the world to the values specified above in Sandbox Mode.",function() RefreshWorld(); Play("beep") end,false,bactive,"center",2000)
	NewButton(-50,100,40,40,9,"resetpuzzlemenu","Reset Puzzle","Resets the puzzle to how it was in the beginning.",function() level = level - 1; NextLevel() end,false,function() return level and inmenu and not mainmenu end,"center",2000)
	NewButton(-50,100,40,40,12,"clearlvl","Clear Level","Also resizes the world to the values specified above.",function() title,subtitle = "",""; ClearWorld() Play("beep") end,false,strictbactive,"center",2000)
	NewButton(0,100,40,40,3,"savelvl","Save Level","Saves to clipboard.\nNote: Saves the#ffff80 initial#x state, not the current state.\nFormat: K3",SaveWorld,false,strictbactive,"center",2000, -math.halfpi)
	NewButton(50,100,40,40,"pencil","loadlvl","Load & Edit Level","Fetches from clipboard.\nLoads V3 and K1-K3 codes.",function() LoadWorld(); ToggleHud(true); puzzle = false end,false,strictbactive,"center",2000)
	NewButton(100,100,40,40,"puzzle","puzzleloadlvl","Load Level as Puzzle","Fetches from clipboard.\nLoads V3 and K1-K3 codes.",function() LoadWorld(); ToggleHud(false); puzzle = true; SetSelectedCell("eraser") end,false,strictbactive,"center",2000)
	NewButton(150,100,40,40,"delete","tomainmenu","Back to Main Menu",nil,function() ToMenu("back"); ToggleHud(false); puzzle = true; inmenu = false; Play("beep") end,false,bactive,"center",2000,nil,{1,.5,.5,.5},{1,.5,.5,1},{.5,.25,.25,1})
	NewButton(0,-127,300,10,"pix","delayslider",nil,nil,function() delay =  math.round((love.mouse.getX()/uiscale-centerx/uiscale+150)/3)*.01 end,true,strictbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(0,-105,300,10,"pix","tpuslider",nil,nil,function() tpu = math.round((love.mouse.getX()/uiscale-centerx/uiscale+150+33.3333333)/33.3333333) end,true,strictbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(0,-83,300,10,"pix","borderslider",nil,nil,function() if not puzzle then border = math.round((love.mouse.getX()/uiscale-centerx/uiscale+150+300/(#bordercells-1))/(300/(#bordercells-1))) end end,true,stricterbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(0,-61,300,10,"pix","volumeslider",nil,nil,function() SetVolume(math.round((love.mouse.getX()/uiscale-centerx/uiscale+150)/15)*.05) end,true,optionbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(0,-39,300,10,"pix","sfxvolumeslider",nil,nil,function() SetSFXVolume(math.round((love.mouse.getX()/uiscale-centerx/uiscale+150)/15)*.05) end,true,optionbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(0,-17,300,10,"pix","musicspeedslider",nil,nil,function() SetMusicSpeed(math.round((love.mouse.getX()/uiscale-centerx/uiscale+250)/10)*.05) end,true,optionbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(0,5,300,10,"pix","uiscaleslider",nil,nil,function() newuiscale = math.round((love.mouse.getX()/uiscale-centerx/uiscale+250)/10)*.05 end,true,optionbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	local b = NewButton(0,25,20,20,"debug","debugbtn","Debug mode",nil,function(b) settings.debug = not dodebug; dodebug = settings.debug; SetEnabledColors(b,dodebug,true) end,false,optionbactive,"center",2000,nil,{.5,.5,.5,1},{.75,.75,.75,1},{.25,.25,.25,1})
	SetEnabledColors(b,dodebug,true)
	NewButton(-25,25,20,20,function(b) return "subtick"..subticking end,"subtickbtn","Subticking",function(b) return "Controls how ticks are displayed.\nCurrently: "..({[0] = "Full ticks", "Subticks", "Subsubticks (individual cells)", "Force propagation"})[subticking] end,function(b) subticking = (subticking + 1) % 4 SetEnabledColors(b,subticking > 0,true) end,false,optionbactive,"center",2000,nil,{.5,.5,.5,1},{.75,.75,.75,1},{.25,.25,.25,1})
	local b = NewButton(25,25,20,20,"fancy","fancybtn","Fancy Graphics",nil,function(b) settings.fancy = not fancy; fancy = settings.fancy; SetEnabledColors(b,fancy,true) end,false,optionbactive,"center",2000,nil,{.25,.5,.25,1},{.33,.75,.33,1},{.125,.25,.125,1})
	SetEnabledColors(b,fancy,true)
	local b = NewButton(12.5,25,20,20,"fancy","fancybtnwmexport","Fancy Graphics","Toggle whether or not to export as if #rFancy Graphics#x is enabled",function(b) settings.fancywm = not fancywm; fancywm = settings.fancywm; SetEnabledColors(b,fancywm,true) end,false,wmexport,"center",2000,nil,{.25,.5,.25,1},{.33,.75,.33,1},{.125,.25,.125,1})
	SetEnabledColors(b,fancywm,true)
	local b = NewButton(-12.5,25,20,20,"rendertext","rendertextbtn","Render Text","Toggle whether or not to render text shown on cells, like #ffff00Coin#x counts",function(b) settings.rendertext = not rendertext; rendertext = settings.rendertext; SetEnabledColors(b,rendertext,true) end,false,wmexport,"center",2000,nil,{.25,.5,.25,1},{.33,.75,.33,1},{.125,.25,.125,1})
	SetEnabledColors(b,rendertext,true)
	local b = NewButton(-50,25,20,20,"bigui","moreuibtn","Minimalist UI",nil,function(b) settings.moreui = not moreui; moreui = settings.moreui; SetEnabledColors(b,not moreui,true) end,false,optionbactive,"center",2000,nil,{.5,.5,.5,1},{.75,.75,.75,1},{.25,.25,.25,1})
	SetEnabledColors(b,not moreui,true)
	local b = NewButton(50,25,20,20,"playercam","playercam","Player-Centered Camera",nil,function(b) settings.playercam = not playercam; playercam = settings.playercam; SetEnabledColors(b,playercam,true) end,false,optionbactive,"center",2000,nil,{.25,.5,.25,1},{.33,.75,.33,1},{.125,.25,.125,1})
	SetEnabledColors(b,playercam,true)
	local b = NewButton(-75,25,20,20,"popups","popups","Show Pop-up Info",nil,function(b) settings.popups = not popups; popups = settings.popups; SetEnabledColors(b,popups,true) end,false,optionbactive,"center",2000,nil,{.25,.5,.25,1},{.33,.75,.33,1},{.125,.25,.125,1})
	SetEnabledColors(b,popups,true)
	NewButton(75,25,20,20,"music","musicbtn","Change Music",function() return "Currently Playing: "..music[settings.music].name end,function(b) settings.music = settings.music%#music+1; PlayMusic(settings.music) end,false,optionbactive,"center",2000,nil,{.5,.5,.5,1},{.75,.75,.75,1},{.25,.25,.25,1})
	NewButton(-75,62,50,25,"pix","widthbtn",nil,nil,function() if not puzzle then typing = "width" end end,false,stricterbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(75,62,50,25,"pix","heightbtn",nil,nil,function() if not puzzle then typing = "height" end end,false,stricterbactive,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(80,80,60,60,2,"nextlvlwin","Next Level",nil,function() NextLevel() Play("beep") winscreen = false end,false,function() return wactive() and winscreen ~= -1 end,"center",2000)
	NewButton(0,80,60,60,11,"replaylvlwin",function() return winscreen == 1 and "Replay Solution" or "Reset Level" end,nil,RefreshWorld,false,wactive,"center",2000)
	NewButton(-80,80,60,60,"delete","exitlvlwin","Back to Main Menu",nil,function() ToMenu("back"); ToggleHud(false); puzzle = true; inmenu = false; winscreen = false; Play("beep") end,false,wactive,"center",2000,nil,{1,.5,.5,.5},{1,.5,.5,1},{.5,.25,.25,1})
	NewButton(-80,100,60,60,"puzzle","puzzlescreen","Puzzles",nil,function() ToMenu("puzzles"); delay = .2; tpu = 1; Play("beep") end,false,titlemenu,"center",3000)
	NewButton(0,70,40,40,583,"texturesbtn","Texture Packs",nil,function() ToMenu("packs"); packscroll = 0; Play("beep") end,false,function() return mainmenu == "options" end,"center",3000)
	NewButton(235,-40,60,60,121,"packscrollup",nil,nil,function() packscroll = math.max(packscroll - 3, 0); end,true,function() return mainmenu == "packs" end,"center",3000,-math.halfpi)
	NewButton(235,40,60,60,121,"packscrolldown",nil,nil,function() packscroll = math.min(packscroll + 3, maxpackscroll); end,true,function() return mainmenu == "packs" end,"center",3000,math.halfpi)
	NewButton(-235,0,60,60,"folder","texfolderbtn","Open Texture Pack Folder",nil,function() love.system.openURL("file://"..love.filesystem.getSaveDirectory().."/texturepacks") end,false,function() return mainmenu == "packs" end,"center",3000)
	NewButton(0,100,60,60,105,"optionsbtn","Options",nil,function() ToMenu("options"); Play("beep") end,false,titlemenu,"center",3000)
	NewButton(80,100,60,60,2,"startgamebtn","Sandbox",nil,function() ToMenu(false); newwidth = 100; newheight = 100; border = 2; delay = .2; tpu = 1; title,subtitle = "",""; ClearWorld(); ToggleHud(true); puzzle = false; level = nil ResetCam() Play("beep") end,false,titlemenu,"center",3000)
	NewButton(20,20,40,40,"delete","backtomain","Go Back",nil,function() ToMenu("back") Play("beep") end,false,exitbtn,"topleft",3001)
	NewButton(20,20,40,40,"delete","closegame","Quit Game",nil,function() love.event.quit() end,false,function() return mainmenu == "title" end,"topright",3001,nil,{1,.5,.5,.5},{1,.5,.5,1},{.5,.25,.25,1})
	NewButton(0,-100,150,75,"pix","logosecret",nil,nil,function() ToMenu("secret"); typedcode = ""; Play("beep") end,false,titlemenu,"center",3000,nil,{0,0,0,0},{0,0,0,0},{0,0,0,0})
	NewButton(0,100,40,40,3,"savelvl","Save Level","Saves to clipboard.\nNote: Saves the#ffff80 initial#x state, not the current state.\nFormat: K3",SaveWorld,false,strictbactive,"center",2000, -math.halfpi)
	NewButton(-75,62,50,25,"pix","cellsizebtn",nil,nil,function() if not puzzle then typing = "cellsize" end end,false,wmexport,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(75,62,50,25,"pix","paddingtbtn",nil,nil,function() if not puzzle then typing = "padding" end end,false,wmexport,"center",2000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	NewButton(-30,100,40,40,3,"exportconfirm","Export Image","Exports your selection as an image in your save directory and opens it\nNote: If the image is larger than "..graphicsmax.."x"..graphicsmax.." or you have no selection, exporting will fail",ExportImage,false,wmexport,"center",2000,math.halfpi)
	NewButton(270,70,40,40,"countcells","countcellsbtn","Count Cells",nil,UpdateCount,false,mbleandnopuz,"topleft",0)
	NewButton(270,120,40,40,"recordvideo","recordvideobtn","Record video","Takes a video data file from your clipboard and records each frame as an image into your save directory. See CelLua Machine Wiki Mod\\#Recording.",function()
		local ds = love.system.getClipboardText()
		local data, data2, data3
		local succ, err = pcall(function()
			data, data2, data3 = quanta.parse(ds)
		end)
		if not succ or not data or #data == 0 then Play("destroy") return end
		local sceneboard = (data2.board or {})[1]
		local sceneanimation = (data2.animation or {})[1]
		if not sceneboard or not sceneanimation then Play("destroy") return end
		if type(sceneboard.level) ~= "string"
		or type(sceneboard.camera) ~= "table"
		or type(sceneboard.camera[1]) ~= "number"
		or type(sceneboard.camera[2]) ~= "number"
		or type(sceneboard.cellsize) ~= "number"
		or sceneboard.cellsize < 1
		or sceneboard.cellsize > 1000 -- please don't do this
		or type(sceneboard.capture) ~= "table"
		or type(sceneboard.capture[1]) ~= "number"
		or type(sceneboard.capture[2]) ~= "number"
		or sceneboard.capture[1] < 1
		or sceneboard.capture[2] < 1
		or type(sceneanimation.defaultspeed) ~= "number"
		or type(sceneanimation.fps) ~= "number"
		or type(sceneanimation.ticks) ~= "table"
		or #sceneanimation.ticks < 3
		or #sceneanimation.ticks % 2 ~= 1
		or (type(sceneanimation.camera) ~= "table" and type(sceneanimation.camera) ~= "nil")
		or (type(sceneanimation.camera) == "table" and #sceneanimation.camera ~= #sceneanimation.ticks)
		or (type(sceneanimation.trackplayer) ~= "table" and type(sceneanimation.trackplayer) ~= "nil")
		or (type(sceneanimation.trackplayer) == "table" and (
			type(sceneanimation.trackplayer[1]) ~= "number" and (type(sceneanimation.trackplayer[1]) ~= "string" or not sceneanimation.trackplayer[1]:match("%d+%-%d+"))
		) and (
			type(sceneanimation.trackplayer[2]) ~= "number" and (type(sceneanimation.trackplayer[2]) ~= "string" or not sceneanimation.trackplayer[2]:match("%d+%-%d+"))
		))
		then Play("destroy") return end
		if not LoadWorld(sceneboard.level) then return end
		RefreshWorld()
		recording = true
		recorddata = {
			scene = sceneboard,
			animation = sceneanimation,
			canvas = love.graphics.newCanvas(sceneboard.capture[1] * sceneboard.cellsize, sceneboard.capture[2] * sceneboard.cellsize),
			current = 1,
			timer = 0,
			next = 0,
			frame = 1
		}
		recorddata.animation.usinginput = not not recorddata.animation.input
		recorddata.animation.input = recorddata.animation.input or ""
		recorddata.animation.ltime = 0
		cam.x = sceneboard.camera[1] * sceneboard.cellsize
		cam.y = sceneboard.camera[2] * sceneboard.cellsize
		cam.zoom = sceneboard.cellsize
		cam.tarx = cam.x * sceneboard.cellsize
		cam.tary = cam.y * sceneboard.cellsize
		cam.tarzoom = cam.zoom
		subticking = ({
			ticks = 0,
			subticks = 1,
			subsubticks = 2,
			cells = 2,
			forces = 3,
			subsubsubticks = 3,
			propagation = 3
		})[recorddata.animation.mode or "ticks"] or 0
		TogglePause(false)
		Play("unlock")
		recursivelyDelete("recording")
		love.filesystem.createDirectory("recording")
		-- ::rth:: --
	end,false,mbleandnopuz,"topleft",0)
	NewButton(270,170,40,40,"recordinput","recordinputbtn","Record Input","Records your input as you play. Toggle this off to copy what was recorded.",function(b)
		recordinginput = not recordinginput
		if not recordinginput then
			love.system.setClipboardText(inputrecording)
		end
		SetEnabledColors(b,recordinginput,true)
	end,false,mbleandnopuz,"topleft",0)
	NewButton(-205,50,40,40,"copy","copycount","Copy as Wikitext",nil,function()
		local a = ""
		for _,v in ipairs(cellcounts) do
			a = a.."* {{Cell|"..cellinfo[v[1]].name.."}} x"..v[2].."\n"
		end
		love.system.setClipboardText(a:sub(1, -2))
	end,false,function() return mainmenu == "cellcount" end,"top",0)

	secrettypefunc = function(key)
		if key == "backspace" then
			if utf8.len(typedcode) > 0 then
				typedcode = typedcode:sub(1,utf8.offset(typedcode,-1)-1)
			end
		elseif utf8.len(typedcode) < 23 then
			typedcode = typedcode..key
			typedcode = typedcode:sub(1,math.min(utf8.offset(typedcode,24) or #typedcode))
		end
	end
	local b = NewButton(-20,0,400,40,"pix","secretbar",nil,nil,function() typing = secrettypefunc end,false,secretbar,"center",3000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	b.drawfunc = function(x,y,b)
		love.graphics.setColor(1,1,1,1)
		love.graphics.printf(">"..typedcode..(typing == secrettypefunc and "_" or ""),x+10*uiscale,y+2*uiscale,380,"left",0,2*uiscale,2*uiscale,380/4,5)
	end
	NewButton(210,0,40,40,"checkon","confirmsecret",nil,nil,function() if HandleSecret(typedcode) then Play("unlock") else Play("destroy") end; typedcode = "" end,false,secretbar,"center",3000)
	
	searchtypefunc = function(key)
		if key == "backspace" then
			if utf8.len(searched) > 0 then
				searched = searched:sub(1,utf8.offset(searched,-1)-1)
				UpdateSearch()
			end
		elseif utf8.len(searched) < 23 then
			searched = searched..key
			searched = searched:sub(1,math.min(utf8.offset(searched,24) or #searched))
			UpdateSearch()
		end
	end
	UpdateSearch()
	local b = NewButton(-205,50,400,40,"pix","searchbar",nil,nil,function() typing = searchtypefunc end,false,searchbar,"top",3000,nil,{.25,.25,.25,1},{.25,.25,.25,1},{.25,.25,.25,1})
	b.drawfunc = function(x,y,b)
		love.graphics.setColor(1,1,1,1)
		love.graphics.printf("Prefix with \" to match exactly\nPrefix with / to use Lua patterns\nPrefix with # to search by ID",20,y+2*uiscale,math.abs(20 - (x+10*uiscale+20))/1.5,"left",0,1.5*uiscale,1.5*uiscale,0,0)
		love.graphics.printf("Search: "..searched..(typing == searchtypefunc and "_" or ""),x+10*uiscale,y+2*uiscale,380,"left",0,2*uiscale,2*uiscale,380/4,5)
		love.graphics.printf("Favorites",x+410*uiscale,y+2*uiscale,380,"left",0,2*uiscale,2*uiscale,380/4,5)
	end
	for i=1,12 do
		local b = NewButton(((i-1)%4-1)*150-75,math.floor((i-1)/4-1)*120,120,90,"X","stamp"..i,nil,nil,function() ToMenu("back"); copied = DecodeK3(stamps[i+stamppage*12].data,true); pasting = true end,false,function() return mainmenu == "stamps" and stamppage*12+i <= #stamps end,"center",3000,nil,{1,1,1,1},{1,1,1,1},{1,1,1,1})
		b.predrawfunc = function(x,y,b)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.rectangle("fill",x-62*uiscale,y-47*uiscale,124*uiscale,94*uiscale)
			love.graphics.setColor(1,1,1,1)
		end
		b.drawfunc = function(x,y,b)
			love.graphics.setColor(1,1,1,1)
			local img = stampimgs[i+stamppage*12]
			love.graphics.draw(img,x-b.w/2*uiscale,y-b.h/2*uiscale,0,b.w*uiscale/img:getWidth(),b.h*uiscale/img:getHeight())
			love.graphics.printf(stamps[i+stamppage*12].name,x-25*uiscale,y+55*uiscale,999,"left",0,uiscale,uiscale)
		end
		NewButton(((i-1)%4-1)*150-25,math.floor((i-1)/4-1)*120-35,20,20,"delete","deletestamp"..i,nil,nil,function() RemoveStamp(i+stamppage*12) end,false,function() return mainmenu == "stamps" and stamppage*12+i <= #stamps end,"center",3000,nil,{1,.5,.5,.5},{1,.5,.5,1},{.5,.25,.25,1})
	end
	NewButton(325,0,40,40,121,"stampnext",nil,nil,NextStampPage,false,function() return mainmenu == "stamps" and stamppage < #stamps/12-1 end,"center",3000)
	NewButton(-325,0,40,40,121,"stamplast",nil,nil,LastStampPage,false,function() return mainmenu == "stamps" and stamppage > 0 end,"center",3000,math.pi)
end

difficulties = {
	[1] = "#00c0ffEasier",
	[2] = "#00ff00Easy",
	[3] = "#ffff00Medium",
	[4] = "#ff8000Hard",
	[5] = "#ff0000Harder",
	[6] = "#ff0080Extreme",
	[7] = "#0080ff_000000Easier Super",
	[8] = "#00ff00_000000Easy Super",
	[9] = "#ffff00_000000Medium Super",
	[10] = "#ff8000_000000Hard Super",
	[11] = "#ff0000_000000Harder Super",
	[12] = "#ff0080_000000Extreme Super",
}

levels = {
	{1,"K3:First Steps:Welcome to #ffff00CelLua Machine#x! Click and drag cells that are on top of a + background, known as a Placeable, to move them. The #0080ffMover#x will constantly move forwards when the simulation is played. The #ff0000Enemy#x will die on contact, and must be killed to proceed. You can start the simulation with the blue button in the top right, or the space key, and restart it with the purple button that appears thereafter.;7;5;0;eNqLtSnISUxOTUzKSbUxiDHUqIiMNrRRNjCwMEhLU1BQ8M0vSy2yiUVWhMIBAZyyFmhK4canpYH0AY13zUvNrbTBYwS6bYHEKzUgRSkAOTtWbQ==;"},
	{1,"K3:The Pushables:The majority of cell types can be pushed by other cells. These #ffe000yellow#x cells indicate which directions they can be pushed with their lines.;a;9;0;eNqLtSnISUxOTUzKSbUxiKWUAwI4ZS2QOenEmhgYSI5LLIl3owWlvi4g043Z+N2IAgKxsKAAALmGl1Y=;"},
	{1,"K3:Building Blocks:The #00ff00Generator#x cell will clone the cell behind it and push it out the front.;5;9;0;eNqLtSnISUxOTUzKSbUxiKUPx5K6RhsYxBhqVERGG9ooGxikpRkYeObZJKMJKYCAf2kJSDUaCARCMAAAsd9WYg==;"},
	{1,"K3:Spinning Cells:Rotator cells will rotate nearby cells either clockwise or counter-clockwise, depending on what type of rotator it is. #ff8000Orange#x#x clockwise, #00ffffcyan#x counter-clockwise.;a;c;0:eNozMAADG08bZGSAjpEAkjC6LjAAAARaEqI=;eNqLtSnISUxOTUzKSbUxiCWDYxJrk5Relp+ZAhLHz8JhhCWRMpTbRD8/Ud0mMDBBKMfKMsAAMYYaFZHRhjbKaWkWQK5zuI2jgYErXNTAIA0IFEDAGSiHqd8EDEAs4oMExjIxCAwkSxsQAACyJdrk;"},
	{1,"K3:Garbage Collector:#c000ffTrash cells#x will delete any cells that go into them.;b;c;0;eNozMDCItSnISUxOTUzKSbVB4VgSKQMBOBXj1kmSMZbEWWCAD+SAAG6mBZQZiKbAFwRQTQIAg+Zh9g==;"},
	{1,"K3:Double-Cross:#00ff00Cross Generators#x act like two generators combined.;8;8;0;eNoLDMQODAwMTEyQ6FibgpzE5NTEpJxUmzRkjgEyR8PQwsAATbUBTk46frXJKDJgtQBUCzn3;"},
	{2,"K3:Chirality:Watch what happens to the #ff8000Rotator#x cell when it's next to the #80ff00Flipper#x cell!;9;8;0:eNqz8bSxASMDELCB8XAhA0wAAA5WDw8=;eNqLtUlKL8vPTLExiIWzTGJtCnISk1MTk3JSQeIIjiWKjEksFs2xI89AExMTAwMoCQGBgQYGjhDKwEDD0BFEAQBbankE;"},
	{2,"K3:Pulling Your Weight:#ff00ffPullers#x will attempt to pull every cell behind them. They cannot push.;a;a;0:eNozMMAGbDxtsGFkBFUJALQ/Des=;eNqLtSnISUxOTUzKSbUxiCWOAwHIQhY4FacjcxwxdeLmhBKwkzTXmoAA1Iyk9LL8zBQbAiwaqw6krUsAvnacnw==;"},
	{2,"K3:Turnaround:The #c040ffpurple rotator#x rotates cells 180 degrees.;9;7;0;eNozMECAQINYm4KcxOTUxKScVBtHiCCykCtEyAJJTxJIG5oyT2yaIAAAlAseWQ==;"},
	{2,"K3:Advancing Forwards:#c080ffAdvancers#x can both push and pull.;9;9;0;eNozMEAFgQZ4QKxNQU5icmpiUk6qDQpHw7AMlVuMohS/ZjwcQrYWk6sVn+shWgEsWFio;"},
	{2,"K3:Around The World:Something's different about the border this time...;b;b;b;eNqLtSnISUxOTUzKSbUxiCWDY2IAAsQpTqWOMbg5YQSMsSTJU2DSxBEEIEwIgEtBFRgEBgbiZ4IAAHrmcYc=;"},
	{2,"K3:Diversion:#e04040Divergers#x will divert whatever comes in according to the arrow on it.;a;a;0;eNozMIADCwgVa1OQk5icmpiUk2qjbYACkKXUULmquFVqowvoGqCBQOzmowsh2wEA2/MxtQ==;"},
	{2,"K3:Green Grabby Guys:#80ff80Grabbers#x will hold onto a row of cells perpendicular to it's direction. Also, cells on one color of Placeable cannot be put onto a different color!;f;9;0;eNozMACCQBAwwAJibQpyEpNTE5NyUm2I5RjkgABNtWsYVyBzLbAZgCQWZEM8LxxsM0EjNIyr8BlJnCEGBI1AA4h4AgAXPJAW;"},
	{2,"K3:Round The Corner:Remember that pullers cannot push!;7;8;0;eNozMDAIBAIDdMoECIBUrE1BTmJyamJSTqoNsRyitSXi0xaKU1saebahWg0APXVTug==;"},
	{3,"K3:Open The Gate;e;9;0:eNqz8bSxASMDZADiQ8VgTCRMJILqBgBZQxb5;eNqLtUlKL8vPTLExiIWzTGJtCnISk1MTk3JSbSyQOQbInHQUGRDIMUAyBYd5BjgNd8RmngkC5JjgNsgADnLwOD8FlypcZgXicTqyKiRgANKDGQbUZpkEBpoAAMhTkEo=;"},
	{3,"K3:Strength Increasing:#c02020Strong enemies#x take 2 hits to kill.;f;5;0:eNqz8bSxgSEDCLBBEsJEBgiFqAAAjxYQwA==;eNqLtUlKL8vPTLExiMXCMom1KchJTE5NTMpJDQJJIPHS8Mih8Uxi8dpCOsuEeLvx8FzJcJcJEBgYaBgmG5DnK7j1qBwLFBkIMAEDZIlEnPrTIFpwypPFAQDCG7nL;"},
	{3,"K3:Collision;8;e;0;eNozMIi1KchJTE5NTMpJtSGWAwJU12dJDfvCMPShAg3DZFSBQEw1SEYE2eDjpaPKkaTXgGp6kwjodcRvLwAttak3;"},
	{3,"K3:Change of Sides:Here, you'll have to move the #ff0000enemies#x so that the #0080ffmovers#x can destroy all of them!;a;a;0;eNpzNDCItSnISUxOTUzKSbUhlmNg4OqIqlPDMBmn8kAMva64zcZnEFDOwBHdZtxWoRsFcTUEuDpaQBiJYBZIAsJKSkJjGQChqwEQAgBAcl/T;"},
	{3,"K3:Rotatables:You can click on cells that are on top of an #ffc080orange background#x (outlined with orange) to rotate them.;e;b;0;eNozMICCGEONishoQxsFBQXnnMzkbIWSfIWi/JLEklRFGwMUEGsDFk9Mykm10TB0w+CjAQsDCyDC0OfqiMZH10eUPehmEHALkW4g1zUahskoeqB8ABCTY18=;"},
	{3,"K3:Cycles:These generators will generate at an #ffff00angle#x. The lighter grey walls are un-generatable walls.;c;c;0:eNqz8bSxgSEDMLBBEsFEBkiAGJXIIgB0bRmd;eNqlUjEOwyAQ+w5DBiPdyBd4AgMQWlUlSae+PyZdQpWQSEhInHXGZwzOhOd3eY0G7qASUTqKiGuy2pVYoFMBSEoPFxq0SSK2vfge2PtkH5MPOZlzoPRc9QBLofGP874nVgwwMi4WN4/sQcCDF7Bo2Z1qmOv5JSjZZ3GRGvn02vc+UjLrU/h9tDZrBXNG4SM=;"},
	{3,"K3:Pipe Dream:That's a lot of Divergers! Only #ffc080orange-outlined#x ones can be rotated. Just try to follow the arrows!;a;6;0;eNqLtSnISUxOTUzKSbUxMIi1KcovSSwB8zQM3TQMqyEkmjgqtxqkD48pKFwTR5ChJmhqXNG0oJpoYQBxCJq1aEagm2LiYRCI6i4Mt7gQ8Bq6M93w+9QV3UUmhnidDAwHQ3QTCXoTzY8YMeZqYAAASrScBg==;"},
	{3,"K3:Tetromino;f;9;0:eNozMMABbDxtSEI4NAEABf0WNw==;eNqLtSnISUxOTUzKSbUxiMXJQQKByBIWOLVYIOkIxK0Kuy2BgYEmYABkQxixNknpZfmZKSDtxLHAeknXNpgtQgqsIJRwROelDzL3JA2AeyLwuY4M9wAAOpwTZQ==;"},
	{4,"K3:Deployed;c;7;0:eNqz8bQxQAY2QD4axkQwlVgRAAP4EzU=;eNozMYCAWJuCnMTk1MSknFQbYjkmhPSGI3OykTmWJiTZm47MSfQF6jOBAbAZSell+ZkpNiZwlgElLBMk24JQHIKFR0urA/FYHUhtqwGIfLJf;"},
	{4,"K3:Crossed Paths;9;9;0;eNqLtSnISUxOTUzKSbUxiMXJMTAw0TBMNjFBFnRE5qQjczQMi4E6DIA6gCiWaBsMUM0fKMXpqIqT8Ck2MHDFHSYYJleR4gwgAABjGoqI;"},
	{4,"K3:Repulsive:#2020e0Repulsors#x will push the cells around it away from it.;b;5;0;eNqLtSnISUxOTUzKSbUxiCWKY4EiAwImJkQqxs0BAQ1DAxPilDviN8ggEEUomwSvGPiS43pkTjrIGyYmviYAJ0V2bQ==;"},
	{4,"K3:Reflection:Mirror cells will swap the two cells adjacent to them according to the arrows.;a;a;0;eNqLtSnISUxOTUzKSbUxiCWOAwHIQpZk68TNSUHT6Ui0TvLtRNcZSW87XQnoTMRrp4mJCZmuzSHbnzkGgQCQqcVT;"},
	{4,"K3:Weighing Your Options:The weight cell requires an extra mover to be pushed!;c;a;0:eNqz8bSxgSEDOEDhQPjEI7h6AM9PFXc=;eNqLtUlKL8vPTLExibYpSMzMK7Gx8bSJJVrQJN0EiFQN1EyAIAWEDJI1TJxibQpyEpNTE5NyUm0McHIcUWTSkXhBKAqDUCWdQJJF+SWJJWCNaiYahrZE2oHHwkBUHqqFgcgWauO10IBYCw3wWWhAvIVJ1LdQTcOwWtsEBgxsTWIpSyV0EzQxGDJOxe5+DUOTIe6DQOzuBwDa9oG9;"},
	{5,"K3:Round Another Corner;8;d;0:eNozMMAKbDxt4BgDAAAQawpU;eNozMDCItSnISUxOTUzKSbVB4SQicyxwKjMwwGNGKTLHkmgzUKwOx6nNkmh3oHDSyfMLkZxwoBkmIACiY22S0svyM1NASvCxaKkW6hZMoGGYbGAAAINurAU=;"},
	{5,"K3:Redirection:#00ff80Redirectors#x will force cells to face the same way it is facing!;e;e;2;eNqLtSnISUxOTUzKSbUxiCWdkxRLoQEDwrGl1ABL2rnNfiACRI9i02CAum40yMkGghwqx4pBDtDYnBxyEnISXlMDA3NyKI5Ze9JMJTNcMUOAYo4labFFScqyHPAiRI9O9hCZLuOGZDk8MDEHAHEPdt0=;"},
	{5,"K3:Precision:#00e000Ally#x cells cause the player to fail when they get destroyed. Kill the enemies without hitting any #00e000Allies#x!;y;c;0:eNqz8bSxQUUGeAFIATZFMHEbEs0DAPU4GxE=;eNqLtUlKL8vPTLExiCWSZaLh6Et1FEu6MwyAINAABlBZJmBggAf4ggE+FbE2BTmJyamJSTmpNigcV2SOBU5lqByybELh5FDZJiJd7khlP2Ujc5KJc0MyZTFJODWQmfwMcKTB2MGRqQAFGhnE;"},
	{5,"K3:Safecracking:The rotator with #ffff00yellow sides#x will only rotate cells next to the sides that #c080ffaren't yellow#x.;g;b;0;eNqLtSnISUxOTUzKSbUxiCWDgwSI05FORbNId1c+GWZpGOeAzckGghwquSwHaFQOWYGEzAmFmJWjYZicQzWX5RDvy1CcMo4wX2Zno4i70iWNoXAs6JHGAKrkHI4=;"},
	{6,"K3:Chilled Out:#80ffffFreezers#x will prevent the four cells around it from functioning.;9;a;0:eNozMMAHbDxtkNlABADhSAmU;eNqLtSnISUxOTUzKSbUxiMXFScQpYwACyAKOyBwNwxJkbihOY0LRjUmPJcph6XjdYoDqFtxmRmC4xQQEQIxAA0IAog6oMtYmKb0sPzPFxgTBirYpSMzMK7Gx8bQBAL8ydqM=;"},
	{6,"K3:The Box;e;e;0;eNqLtSnISUxOTUzKSbUxiB3lDAzHxMTEAAiAFFm605PTgcAk3YQSu1PI0W1hkI7MD7LRcPRF4Rvg46FqxmONJ4oMup2ovEB8PKJtROE40sNGV7L96IrKI8+PBiZplKVBE1AaTKUsDZJn9yiH2hwAWlghiw==;"},
}

plevels = {
	{1,"K3:Control:The #0080ffPlayer cell#x can be controlled while the simulation is running! It has the ability to push cells. If it dies, you'll have to restart.;a;a;0;eNoziDHUqIiMNrRxLCrKLy/WUQh3DHbRUcgvUsjKrywuyUzOVijJV8jNL0tVtDGAA42kcgMMYAIEvtlAAOblgAWgLCgogCuF0oFAViSqGABHsyQA;"},
	{1,"K3:Locked Away:#ff40c0Key#x cells can open #c04080Door#x cells when pushed into them.;a;a;b;eNozMPA1gAAN83w428TEBEyAKDCASYBYQIVQKYQCMEsjqRzOhhpZDESBJhCjgAAA8bMXLw==;"},
	{1,"K3:Reverse Sokoban:This type of #0080ffPlayer#x can only #ff00ffpull#x cells. Careful not to get stuck!;7;4;0:eNozMAADG08bIAJRUB5UBCpgYAAAtCEI2A==;eNozMAACk1ibpPSy/MwUGxDPIN0EBIB0OkIcwTLRSFE1MAkEANWREJg=;"},
	{2,"K3:Defense:Protect the #00e000Allies#x by moving the #ffe000Semi#c000fftrashes#x!;h;k;0:eNqz8bSxQUIGKAAkQAwmEgAAI9gXIA==;eNqLtUlKL8vPTLExiMXLMtFI9Iw2NIw2MiSPYWLh6GgSS6xlBhAAogPJ0WQwqonumkxAAEXAE13AgHQBy2QDdEPBacoAlKZgEq5AgGI9hK2RVJ4OBBqJahAE5iSVQ+U1HH0xEVgGAILR394=;"},
	{2,"K3:Stop Running:The #ffc000Fearful Enemy#x will run away from any cells adjacent to it. Find a way to catch it!;5;5;b;eNozMAABjaRyAwTQCNEDkkkGBgBcdAYu;"},
	{2,"K3:Gearbox:The #c08040Gear#x cells will rotate the cells around themselves.;c;c;0;eNozMDDQMDRBQwZAoJFUbmBQDeHHg8QCwaLY1GIKYkXxEKraAEwYxBOpjVjTIa6FObnagIpmVyNCAs4iiAAeA0PV;"},
	{2,"K3:Gravity:This #0080ffPlayer#x falls due to gravity, and can jump!\nThe 2 means it's initial velocity when it jumps is 2 cells/tick.\nDont fall into those #c0c0c0spikes#x!;P;a;0:eNozMCAEbDxtgAiTjaICHRODkExENRRD2gCLUjgPANw2KuM=;eNozMMALNJztTWJtktLL8jNTbAwQLBOQJG4ZIgB5xgbSwlgTExOaGItNBovRJjBHmBByJW4VpDvcBM3XuIzVKMmJNjSKNiI1XIhSCAVIviPSWLyBQR0WEcabEB/MJhRbRpFfNJzjIMiEWIWYyIQMk00IGkC0UQAigVkE;"},
	{2,"K3:Springing Into Action:#00ff00Springboards#x will bounce you if you push against one of the green sides! The number represents how hard it bounces you back.;M;i;0:eNqz8bSxoR4ywATE6kTGcJ14MRE2YFNCjOMARVtBuA==;eNrtlU0PgiAcxr8KneLQAZRT8+YnaPPS0LYKpqyElvb27Zs1m5hYGq2DPXMOZTz4/z0CkbeKj0owD0WDaBEYxBS7pjuqikQDg/MCHXrWH5EBzJDJlDygP+2HhDTp4aK90LpMIt2T/I2nXg2ZoU6CQUIxbuLRgPE+oNjz3iGoebXXqyvE8Dyn2AsU2HC+A5lg/LS8ZCBVKZf5IZ2Eobz1JGrLhIyBkEDk4wwwsefrXCg58uwEUWVhxN/T03DUFHnY+o9ap9LCrQddPNmYxeru0GP92PqqYdQI8y3FDnUQdcuV/t2aob+oXeSDsb182ltXmsNjng==;"},
	{2,"K3:Raceway Rush:#ffe000Dash Blocks#x will propel you in their direction when you touch one of their sides. Just like a Springboard, the number represents how fast it does so.;V;s;0:eNozMCAX2HjaYMPURQZ4MMlmobidzggA/ixVTg==;eNrTcLbVIB0ZEAVMDMgE5GsMJFcjFBgYaIRURRsaGWBjEGNOrE1Sell+ZoqNAemsoWq7RkglUBF+EmoShQ4k33qygsmEhq42Ic+AIe12SBajgrs0nOPwIyzWYk05FLsECRCXR2kXK4PLThMaW6cRUg7O3fhIujmGjAxhQmGyw/QtSAyltCYmiHAHGr39RG0WWmBQyW0mOEoVE1RAY8uJbS+N2kuj+oUYZEJyW4VazscFgPaX5ADtiTYyiDamVeCNskiMKXrUYaOsQRbxo9E6Gq2jrKESrfhq+dEAojcLAEiTYf4=;"},
	{2,"K3:Rivalry:The #ff0000Chaser#x is a cell that will constantly chase you around. In this level, the #ff0000Chaser#x is slower than you, so you can avoid it. Get all the #ffe000coins#x and kill the #ff0000enemy#x!;d;b;0:eNozMEACNp42QGSAjuGSWESRNQIAd7oQjQ==;eNozMAACjcRAEGVgEmuTlF6Wn5liY4AEyBSFGQq1wMQESCWVQ7ghvtGGBtFGhtHGRtEmYPnQaEPTQGSDTCh3AcJjYBpJBgD3nj7G;"},
	{2,"K3:Defense 2:Same goal as Defense 1, but now you control a row of #80ff80friendly Sentries#x that you can activate by pressing on them!;g;k;0:eNqz8bSxQUIGyADEpzZGBwBt3Rz7;eNqLtUlKL8vPTLExiMXLMtFI9Iw2NIw2MiSJYWLh6GgSS6wdBmAAogLJ0GMwqmdUDz31mIAAMt8TjW+AxtcwD0pGmGWikRMQbWgQbZOZV1BaYmNIRS7MOeB8aADKhxqOvmjIxBUIANezNkM=;"},
	{3,"K3:Defrosting;a;7;0:eNqz8bQxAAEbJBqGUThAjIYMYBoAFIQPoA==;eNoz0UgqNzAwMTExAJIGIOBoAOGbaJjnm4BYIDZYLNAAxMoBMgMNNMyLDRI1DNNNDCBKwGpMAJ3eEPo=;"},
	{3,"K3:Double Team:Here, you control two #0080ffPlayers#x at once. Dont let the top one hit an #00e000Ally#x!;b;k;0:eNqz8bSxASMDCLCB8fEjA+IBAGDrFXE=;eNqLtUlKL8vPTLExiIWzTEw0HH0hyMQkFosCbCyQHgONpHIDkC6SNJmQrsWANC2E/GOCAAYIAOTABIH+AnLgEgZgGbACA4i4SSCUCTbCBKbIAKYSyjRAYxpgiEKEDKBWw5RASAC+PHT0;"},
	{3,"K3:Firing Range:#e00000Sentries#x will shoot dangerous #ff4000Missiles#x at the #0080ffPlayer#x once they get close enough. The lighter #ff8080Turrets#x will shoot homing #ff8080Seeker#x missiles. The range of the Sentries have been marked with Red Placeables as a warning.;Y;7;2;eNozMICCWJuCnMTk1MSknNQgGwN8or7IALc67AbiNhlTPVbLUQU10lKiDY1pK0aeH1GliOdppCVHG5qQqxuro3yxiFLCJcpIUnycS6GPgUAjqZyYZEWvWKFTkOMQCqQwn9HC9QOUOkgqheiVS4kq2NKwFE7UFaN/4U1JzQEASd8kUg==;"},
	{3,"K3:Slider Puzzle:#c0c0c0Input Sliders#x can be dragged around with your cursor! They can only be dragged along one axis, as you might expect.;6;5;0:eNqz8bSx8bQxMDCwATMgbDQAAJcMB7Y=;eNozMQk0MTHR8KjQ8CgHIwijwgDGhwihoXJUEsoAAEJ+FlM=;"},
	{3,"K3:The Hallway:Watch out for the #e0a080Chainsaws#x! They will destroy the #0080ffPlayer#x upon touch.;G;7;0;eNoz0XC2RUYmJiaeGFjDWUsjLSXa0AAPwwTdIA1nPQMwAHKgpIZ5CFYeKtBwtofrBfPTnUBklTG6smpMPRpJ5RA+yOwqQ7DuKpBmI410Z2zaA1Ht00gv16hCdw9MDMVGNH3OcSikhnkQGg/Dj8AAikNG2EM+LQ0cyFZ4GBgGAQCenWkY;"},
	{3,"K3:Buzzing Saws:#c0c0c0Sawblades#x are deadly, just like #e0a080Chainsaws#x. However, they can orbit in trickier ways, so watch out!;E;d;0:eNqz8bSxIREZ4AIgOWSMLkgjhLCdSAQAuig6lA==;eNrtVk8LgjAU/zrvEryN33F179BBr6NDFogYlSD19ZtbybIRCS4l3OnNTd/v39StyvLruTgo3k6yAofHSHig1WVXnGql1irGxS5dSnMthJaC0v2oxHsYlnQ4gMQSwGiWteNdVQMOC6pLLaSWXFUM+Nut6AY+w/cFHlmzmG8StM91JjU3g+qjbcJmCwKNP4PuXzFlt05g7IRWrqF14rEqDaDyycqxjOfEaxgaaZKgmBEzGXDVNwxTP1TDkHfi/zXZnwhqUuOdpGY2yzLc58OGdJZiwB+o2C/4b6s7x5Zwvg==;"},
	{3,"K3:Ka-ching!:In this level, you'll have to find out how to get to the #ffe000Coins#x to progress!;E;k;0:eNqz8bSxIYQMYACLOJoKEB8rRgNYlBBygA0RLqUEAQCVZD94;eNrlVLFuwjAQ/ZxanS70TchVh0wMHRiYUpBSUBESahkQDPx8ndgxvuAkF2S1lXqyosvF9/zu7jlL/b49fe02mpY/4EHlz3aR9yBMRqEP5e7zqPVM+6Aq51Af6yIj+4yCgZwlL8eYg0btv2Xq/GpCCPeYrypf+cXz5UdRYCp/bE61dVehh5pCkDKXozewU7q1sBjGXpWLIpt0FAHOtI2N6Fw5PvUIhPeDvdgpMIms7P5+dfRV3iLpNCxENAycAqId9fppGvVi3dqB088lnsY04TjR9W5dK6mUUo3riYbNp4cIBKA3yRTZzvfvU7v4IbY6tHBvg9VOqZDj1DvmdMeFZ9ylWay0EWRMSweAa6WP79IAqjruzb0uJrLeofOi/G4Q4wc1/LcXjA/+T59QdOmmm44TBO1K2Pm/VX/qIf837xsloTj+;"},
	{4,"K3:Hide and Seek:You can't outrun the #ff0000Chasers#x this time. They move twice as fast as you. Hide. When you're ready, press the #0080ffMover#x with the cursor icon to activate it and flip the #ff8000Switch#x, and see if you survive long enough to outlast the timer.;O;e;0:eNqz8bSxASMD4oENTA8eZADDeHUYkAkAJ+wm6g==;eNqVVMFuwjAM/ZgdqHZgTvEBTd0n7DBpt1BNQpMQlwETg8O0f1/sOLXrFqGkpUpi5/nl5YW+2+4uh/1nB/3QQ+B22ITm9BsD9ZuwpNEij9D8Jqk0K+nPNIP9TIn6HgIeCfMvYSIaCubJLUdkeBdUMpvwUhgTwKmUmuy1ZC6YB5aAKYQosKCc0iI0DTJL/CakB0IS1I+8Owu3jt3+6/hz7lJ4yfQozjWSzNN3ftYnobAUsRx7q4Yk3dgHyBmIZE/sgZT3/pp6sW3jKsQUVX+goNkNq8SDniydO3SKFCBXAEVp54mREaG4w1YDaxHWdHtNX2toBZ0g5qNQitobb4/ZzRvQVRJ38FfdgT5PDUaLKu6QN9roIikDJ5zxvSysqAlG8rF6xjJDnmQ8lsLD3bt3lavbGuy/VkV7+wdOW0vf;"},
}

local d = os.date("%B")
if d == "December" or true then
	table.insert(plevels, {symbol="❄",6,"K3:#a0e0ff❄ Frostbite Hall ❄;1j;a;h;eNrtWclOw0AM/RsULmiyVPSQD4ADp1ZcQg9AUamEWhAVlfh6BKJbkvF4nSRSb44m9njs52cnMyufFp+r9bZMpsVsJzsV6diiT9baKa1S8cvx/MXseeJkyIVuktdvuRZA0qPPpsPDTCkNi9u9vKjK98flalOWN+nYTbLRfepcuV++Oyxn49Ekd4NZpuStiBp+y3Lvq19ANnSIglVEFgyIcmvoRCiFgH3rgK0FWG/Atfq1Xs7rEl3Dq9vwn6TtzHTJMEDsfWLnIU0+NjvUXBavF9Pv4OKxZw0Ze8aGDkIb0Dm2uXx+4TdZWPlvG6tlfE8HMxBj/GAXF0efdnwsAP1cKa7aAAJiE1ByfUWxCL/XKLnMh0+SMeb2WN0AcALIRye1LhGzCpB/+FC7kQwRofYsHVIZqilxitB1TDwCqvGx9Wn+4+NHYyI27ttDkgKwEcSUHGsxuvSpJ1QQSHjkPiPCCpORi2VJo5CoQIqBwhkmywCo64Rq2n9x/C/Bj0VH3V7bimUr5LC2FTr8JNgywv9+KJ1ss5x3Rjje6ceCdeLzpe8DauBDDD6o4TGmOJOJmExCdpqjIn9g8ZEIjlDMOJSTMNIMzcO8t9EiujKHGMQGCqLcvE/QHlxqUzj82B3b1KY/RVPEgPeLfKLyjrXPAIiM/sHodVrO3nkIa/KPs87nF9Mrg/P402MGqlNJDAqC+5cWGenfFfBmH89Z2yNRmPxcHyQn0ccwONLGJIO4eW2thc1blWZV5qq8XxxEIHUixgmPaNqyaGAC1pNeoitblS0jkE2tVfYtfpdxAIhXb0CSIUejaIFvyrZ6dsbFMCTkJdnWAGZ6R5SQD0GOQc4/uJmGTg==;"})
end

function CreateLevelMenu()
	local xamnt = math.ceil(math.sqrt(#levels+#plevels)*4/3)	-- *4/3 so the layout will stay more rectangular to fit the screen better
	local xoff = 25*(xamnt-1)
	local yoff = 25*math.floor((#levels-1)/xamnt)+25*math.floor((#plevels-1)/xamnt)+25
	local function getrenderfunc(i,name,interactive,symbol)
		return function(x,y,b)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf(symbol or i+1,x+2*uiscale,y+2*uiscale,100,"center",0,2*uiscale,2*uiscale,50,5)
			love.graphics.setColor(GetSaved("completed")[name] and {0,1,0,1} or {1,1,1,1})
			love.graphics.printf(symbol or i+1,x,y,100,"center",0,2*uiscale,2*uiscale,50,5)
			if i == 1 then
				love.graphics.setColor(textcolor[1],textcolor[2],textcolor[3],1)
				love.graphics.printf(interactive and "Interactive Puzzles" or "Normal Puzzles",centerx,y-30*uiscale,100,"center",0,2*uiscale,2*uiscale,50,5)
			end
		end
	end
	for i=0,#levels-1 do
		local name
		local currentcharacter = 3 --start right after K3
		if string.sub(levels[i+1][2],currentcharacter,currentcharacter) == ":" then
			name = ""
			while true do
				currentcharacter = currentcharacter + 1
				local character = string.sub(levels[i+1][2],currentcharacter,currentcharacter)
				if character == ";" or character == ":" then
					break
				else
					name = name..character
				end
			end
		end
		local b = NewButton(50*(i%xamnt)-xoff,50*math.floor(i/xamnt)-yoff,40,40,"difficulty"..levels[i+1][1],"topuzzle"..i+1,name,"Difficulty: "..difficulties[levels[i+1][1]],function() plvl = false; level = i; NextLevel() ResetCam() Play("beep") end,false,puzzlemenu,"center",3000)
		b.drawfunc = getrenderfunc(i,name,false,levels[i+1].symbol)
	end
	xoff = 25*(xamnt-1)
	yoff = 50*math.floor((#levels-1)/xamnt)-yoff+60
	for i=0,#plevels-1 do
		local name
		local currentcharacter = 3 --start right after K3
		if string.sub(plevels[i+1][2],currentcharacter,currentcharacter) == ":" then
			name = ""
			while true do
				currentcharacter = currentcharacter + 1
				local character = string.sub(plevels[i+1][2],currentcharacter,currentcharacter)
				if character == ";" or character == ":" then
					break
				else
					name = name..character
				end
			end
		end
		local b = NewButton(50*(i%xamnt)-xoff,50*math.floor(i/xamnt)+yoff,40,40,"difficulty"..plevels[i+1][1],"toplayerpuzzle"..i+1,name,"Difficulty: "..difficulties[plevels[i+1][1]],function() plvl = true; level = i; NextLevel() ResetCam() Play("beep") end,false,puzzlemenu,"center",3000)
		b.drawfunc = getrenderfunc(i,name,true,plevels[i+1].symbol)
	end
end

function AddFavorite(cell)
	favorites = GetSaved("favorites")
	for i=1,#favorites do
		if favorites[i] == cell then
			return
		end
	end
	if #favorites < 10 then
		table.insert(favorites,cell)
		SetFavorites()
	end
end

function SetFavorites()
	for i=1,10 do
		if buttons["favorite"..i] then
			buttons["favorite"..i].isenabled = false
			buttons["deletefavorite"..i].isenabled = false
		end
	end
	favorites = GetSaved("favorites")
	for i=1,#favorites do
		local cell = favorites[i]
		local b = NewButton(205,function() return 50+i*60 end,400,50,GetCellTexture(cell),"favorite"..i,nil,nil,function() SetSelectedCell(cell) ToMenu("back") Play("beep") end,nil,function() return mainmenu == "search" end,"top",3000,nil,{1,1,1,0},{1,1,1,0},{1,1,1,0})
		b.drawfunc = function(x,y,b)
		if y < 600*winym+200 and y > -200 then
			MenuRect(x-b.w*uiscale/2,y-b.h*uiscale/2,400*uiscale,50*uiscale)
			love.graphics.setColor(1,1,1)
			local tex = GetTex(GetCellTexture(cell))
			love.graphics.draw(tex.normal,x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,40/tex.size.w*uiscale,40/tex.size.h*uiscale)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf(cellinfo[cell].name,x-(b.w/2-55)*uiscale,y-(b.h/2-11)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			love.graphics.setColor(1,1,1)
			love.graphics.printf(cellinfo[cell].name,x-(b.w/2-54)*uiscale,y-(b.h/2-10)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			love.graphics.draw(tex.normal,x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,40/tex.size.w*uiscale,40/tex.size.h*uiscale)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf("ID: "..cell,x-(b.w/2-55)*uiscale,y-(b.h/2-30)*uiscale,280,"left",0,uiscale,uiscale)
			love.graphics.setColor(1,1,1)
			love.graphics.printf("ID: "..cell,x-(b.w/2-54)*uiscale,y-(b.h/2-29)*uiscale,280,"left",0,uiscale,uiscale)
		end
	end
	NewButton(380,function() return 55+i*60 end,40,40,"delete","deletefavorite"..i,nil,nil,function() table.remove(favorites,i) SetFavorites() end,nil,function() return mainmenu == "search" end,"top",3001)
	end
end

function MakeSearchResult(cell,index)
	local b = NewButton(-205,function() return 50+index*60 end,400,50,"pix","searchresult"..index,nil,nil,function() SetSelectedCell(cell) ToMenu("back") Play("beep") end,nil,function() return mainmenu == "search" end,"top",3000,nil,{1,1,1,0},{1,1,1,0},{1,1,1,0})
	b.drawfunc = function(x,y,b)
		if y < 600*winym+200 and y > -200 then
			MenuRect(x-b.w*uiscale/2,y-b.h*uiscale/2,400*uiscale,50*uiscale)
			love.graphics.setColor(1,1,1)
			local tex = GetTex(GetCellTexture(cell))
			love.graphics.draw(tex.normal,x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,40/tex.size.w*uiscale,40/tex.size.h*uiscale)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf(cellinfo[cell].name,x-(b.w/2-55)*uiscale,y-(b.h/2-11)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			love.graphics.setColor(1,1,1)
			love.graphics.printf(cellinfo[cell].name,x-(b.w/2-54)*uiscale,y-(b.h/2-10)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			love.graphics.draw(tex.normal,x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,40/tex.size.w*uiscale,40/tex.size.h*uiscale)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf("ID: "..cell,x-(b.w/2-55)*uiscale,y-(b.h/2-30)*uiscale,280,"left",0,uiscale,uiscale)
			love.graphics.setColor(1,1,1)
			love.graphics.printf("ID: "..cell,x-(b.w/2-54)*uiscale,y-(b.h/2-29)*uiscale,280,"left",0,uiscale,uiscale)
		end
	end
	NewButton(-30,function() return 55+index*60 end,40,40,"favorite","searchresultfav"..index,nil,nil,function() AddFavorite(cell) end,nil,function() return mainmenu == "search" end,"top",3001)
end

function EscapePattern(str)
	return str:gsub("[%[%]%%%+%-%*%?%(%)%^%$%.]", "%%%0")
end

function UpdateSearch()
	local results = {}
	for i=1,30 do
		if buttons["searchresult"..i] then
			buttons["searchresult"..i].isenabled = false
			buttons["searchresultfav"..i].isenabled = false
		end
	end
	for k,v in sortedpairs(cellinfo) do
		--if not v.notcell then
			if #results >= 30 then break end
			local match
			local success = pcall(function() match = string.match(v.name, searched:sub(2)) end)
			if string.find(string.lower(v.name), EscapePattern(string.lower(searched))) and not searched:match("^[/\"#]")
			or string.match(v.name, "^"..EscapePattern(searched:sub(2))) and searched:match("^\"")
			or success and match and searched:match("^/")
			or tostring(k) == searched:sub(2) and searched:match("#") then
				table.insert(results, k)
			end
		--end
	end
	for i=1,#results do
		MakeSearchResult(results[i],i)
	end
end

function MakeCellCountResult(cell,count,index)
	local b = NewButton(-205,function() return 50+index*60 end,400,50,"pix","cellcountresult"..index,nil,nil,nil,nil,function() return mainmenu == "cellcount" end,"top",3000,nil,{1,1,1,0},{1,1,1,0},{1,1,1,0})
	b.drawfunc = function(x,y,b)
		if y < 600*winym+200 and y > -200 then
			MenuRect(x-b.w*uiscale/2,y-b.h*uiscale/2,400*uiscale,50*uiscale)
			love.graphics.setColor(1,1,1)
			local tex = GetTex(GetCellTexture(cell))
			love.graphics.draw(tex.normal,x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,40/tex.size.w*uiscale,40/tex.size.h*uiscale)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf(cellinfo[cell].name,x-(b.w/2-55)*uiscale,y-(b.h/2-11)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			love.graphics.setColor(1,1,1)
			love.graphics.printf(cellinfo[cell].name,x-(b.w/2-54)*uiscale,y-(b.h/2-10)*uiscale,280,"left",0,uiscale*2,uiscale*2)
			love.graphics.draw(tex.normal,x-(b.w/2-5)*uiscale,y-(b.h/2-5)*uiscale,0,40/tex.size.w*uiscale,40/tex.size.h*uiscale)
			love.graphics.setColor(0,0,0,.5)
			love.graphics.printf("x"..count,x-(b.w/2-55)*uiscale,y-(b.h/2-30)*uiscale,280,"left",0,uiscale*1.5,uiscale*1.5)
			love.graphics.setColor(1,1,1)
			love.graphics.printf("x"..count,x-(b.w/2-54)*uiscale,y-(b.h/2-29)*uiscale,280,"left",0,uiscale*1.5,uiscale*1.5)
		end
	end
	--NewButton(-30,function() return 55+index*60 end,40,40,"favorite","searchresultfav"..index,nil,nil,function() AddFavorite(cell) end,nil,function() return mainmenu == "cellcount" end,"top",3001)
end

function UpdateCount()
	if selection.w <= 0 or selection.h <= 0 then Play("destroy") return end
	local counts = {}
	for i=0, selection.w * selection.h - 1 do
		local x, y = i % selection.w + selection.x, math.floor(i / selection.w) + selection.y
		local pt = getempty()
		pt.id=GetPlaceable(x,y) or 0
		if pt.id ~= 0 then counts[pt.id] = (counts[pt.id] or 0) + 1 end
		love.graphics.setShader()
		local tex0 = GetCell(x, y, 0)
		if tex0.id ~= 0 then counts[tex0.id] = (counts[tex0.id] or 0) + 1 end
		local tex1 = GetCell(x, y, 1)
		if tex1.id ~= 0 then counts[tex1.id] = (counts[tex1.id] or 0) + 1 end
	end
	cellcounts = {}
	for i,v in pairs(counts) do
		table.insert(cellcounts, {i, v})
	end
	table.sort(cellcounts, function(a, b)
		local res
		pcall(function() res = a[1] < b[1] end)
		if res == nil then return tostring(a[1]) < tostring(b[1]) end
		return res
	end)
	Play("beep")
	ToMenu("cellcount")

	for i=1,30 do
		if buttons["cellcountresult"..i] then
			buttons["cellcountresult"..i].isenabled = false
		end
	end
	for i,v in ipairs(cellcounts) do
		MakeCellCountResult(v[1],v[2],i)
	end
end

function ExportImage()
	local newpadding = newpadding / 100
	local cwidth, cheight = newcellsize*selection.w - newpadding*newcellsize*2, newcellsize*selection.h - newpadding*newcellsize*2
	if cwidth <= 0 or cwidth > graphicsmax or cheight <= 0 or cheight > graphicsmax then Play("destroy") return end
	inmenu = false
	wikimenu = nil
	local canvas = love.graphics.newCanvas(cwidth, cheight)
	local pr, pg, pb, pa = love.graphics.getColor()
	local shader = love.graphics.getShader()
	local previous = love.graphics.getCanvas()
	local camera = cam
	love.graphics.setCanvas(canvas)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader()
	fancy = fancywm
	rendercelltext = rendertext
	for i=0, selection.w * selection.h - 1 do
		local x, y = i % selection.w + selection.x, math.floor(i / selection.w) + selection.y
		local pt = getempty()
		local cx, cy = (x - selection.x) * newcellsize + newcellsize/2 - newpadding*newcellsize, (y - selection.y) * newcellsize + newcellsize/2 - newpadding*newcellsize
		pt.id=GetPlaceable(x,y) or 0
		DrawAbsoluteCell(pt, cx, cy, 0, 1, newcellsize/20)
		love.graphics.setShader()
		local tex0 = GetCell(x, y, 0)
		DrawAbsoluteCell(tex0, cx, cy, 0, 1, newcellsize/20)
		local tex1 = GetCell(x, y, 1)
		DrawAbsoluteCell(tex1, cx, cy, 0, 1, newcellsize/20)
	end

	love.graphics.setCanvas(previous)
	love.graphics.setColor(pr, pg, pb, pa)
	love.graphics.setShader(shader)
	fancy = settings.fancy
	rendercelltext = true
	Play("beep")
	canvas:newImageData():encode("png", "export.png")
	love.system.openURL("file://"..love.filesystem.getSaveDirectory().."/export.png")
end

queue = {}
executing = {}
frozen = {}

function AddChannel(c)
	queue[c] = {}
	executing[c] = false
	frozen[c] = false
end

function Queue(c,func)
	table.insert(queue[c],func)
end

function QueueLast(c,func)
	table.insert(queue[c],1,func)
end

--we could probably use coroutines to do this but i dont know them so im doing the easy way
function ExecuteQueue(c)
	if executing[c] == false and frozen[c] == false then
		executing[c] = true
		local q = queue[c]
		while q[1] do
			local n = #q
			local f = q[n]
			f()
			while q[n] ~= f do
				n = n + 1
			end
			table.remove(q,n)
		end
		executing[c] = false
	end
end

--unfreezing will execute the queue automatically, if you dont want that just set frozen[c] to false manually
function FreezeQueue(c,val)
	frozen[c] = val
	if val == false then ExecuteQueue(c) end
end

AddChannel("postnudge")
AddChannel("postpush")
AddChannel("postpull")
AddChannel("postgrab")
AddChannel("swap")
AddChannel("rotate")
AddChannel("redirect")
AddChannel("flip")
AddChannel("effect")
AddChannel("damage")
AddChannel("anchor")
AddChannel("hypergen")
AddChannel("superrotate")
AddChannel("superflip")
AddChannel("superredirect")
AddChannel("fill")

function ToSide(rot,dir)	--laziness (converts rotation of cell & direction of force -> the side that the force is being applied to)
	return (dir-rot+2)%4
end

function GetNoNeighbors()
	return {}
end

function GetNeighbors(x,y)	--4 neighbors
	return {[0]={x+1,y},{x,y+1},{x-1,y},{x,y-1}}
end

function GetSurrounding(x,y)	--8 neighbors
	return {[0]={x+1,y},[0.5]={x+1,y+1},[1]={x,y+1},[1.5]={x-1,y+1},[2]={x-1,y},[2.5]={x-1,y-1},[3]={x,y-1},[3.5]={x+1,y-1}}
end

function GetDiagonals(x,y)	--4 diagonal neighbors
	return {[0.5]={x+1,y+1},[1.5]={x-1,y+1},[2.5]={x-1,y-1},[3.5]={x+1,y-1}}
end

function GetArea(x,y,s)	--not ordered by angle
	local t = {}
	for cx=x-s,x+s do
		for cy=y-s,y+s do
			table.insert(t,{cx,cy})
		end
	end
	return t
end

function InvertLasts(cell,dir,x,y,vars)
	local newvars = table.copy(vars)
	newvars.lastcell,newvars.lastdir,newvars.lastx,newvars.lasty,newvars.islast = cell,dir,x,y,(not vars.islast)
	return vars.lastcell,(dir+2)%4,vars.lastx,vars.lasty,newvars
end

function ToughOnTopBottom(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side%2 ~= 0
end

function ToughOnTopBottomRight(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side ~= 2
end

function ToughOnTopRight(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side ~= 1 and side ~= 2
end

function ToughOnRight(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side ~= 1 and side ~= 2 and side ~= 3
end

function ToughOnCorners(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side%1 ~= 0
end

function OneWayUnbreakable(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side > 3 or side < 1
end

function CrossWayUnbreakable(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side > 2 and side < 1
end

function BiWayUnbreakable(cell,dir)
	local side = ToSide(cell.rot,dir)
	return (side > 3 or side < 1) or side > 1 and side < 3
end

function TriWayUnbreakable(cell,dir)
	local side = ToSide(cell.rot,dir)
	return side ~= 2
end

function TrashUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype ~= "rotate" and vars.forcetype ~= "flip" and vars.forcetype ~= "redirect"
end

function RedirectorUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "redirect"
end

function FireUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "infect" or vars.forcetype == "burn"
end

function GravitizerUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "gravitize"
end

function PerpetualRotUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "perpetualrotate"
end

function MidasUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "transform"
end

function StickyUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "stick"
end

function CompelUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "compel"
end

function GooerUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "goo"
end

function LlueaUnbreakable(cell,dir,x,y,vars)
	return vars.forcetype == "infect"
end

MergeIntoInfo("isunbreakable",{
	[1]=true,[41]=true,[126]=true,[150]=true,[151]=true,[152]=true,[162]=true,[163]=true,[165]=true,[199]=true,[200]=true,[201]=true,
	[202]=true,[203]=true,[204]=true,[229]=true,[224]=true,[235]=true,[427]=true,[428]=true,[709]=true,[710]=true,[733]=true,[734]=true,
	[735]=true,[746]=true,[747]=true,[748]=true,[815]=true,[816]=true,[817]=true,[818]=true,[819]=true,[861]=true,[862]=true,[929]=true,
	[930]=true,[931]=true,[932]=true,[933]=true,[934]=true,[938]=true,[939]=true,[940]=true,[941]=true,[965]=true,[1046]=true,[1088]=true,
	[1116]=true,[1117]=true,[1156]=true,[1157]=true,[1158]=true,[1163]=true,[1171]=true,[1174]=true,[1181]=true,[1186]=true,
	[69]=ToughOnTopBottom,[213]=ToughOnTopBottom,[1155]=ToughOnTopBottom,[1159]=ToughOnTopBottom,
	[140]=ToughOnTopRight,
	[157]=ToughOnTopBottomRight,
	[158]=ToughOnRight,
	[159]=ToughOnCorners,
	[12]=TrashUnbreakable,[51]=TrashUnbreakable,[141]=TrashUnbreakable,[176]=TrashUnbreakable,[205]=TrashUnbreakable,[221]=TrashUnbreakable,
	[344]=TrashUnbreakable,[345]=TrashUnbreakable,[347]=TrashUnbreakable,[349]=TrashUnbreakable,[436]=TrashUnbreakable,[437]=TrashUnbreakable,
	[438]=TrashUnbreakable,[439]=TrashUnbreakable,[440]=TrashUnbreakable,[441]=TrashUnbreakable,[463]=TrashUnbreakable,[563]=TrashUnbreakable,
	[670]=TrashUnbreakable,[671]=TrashUnbreakable,[672]=TrashUnbreakable,[694]=TrashUnbreakable,[695]=TrashUnbreakable,[814]=TrashUnbreakable,
	[848]=TrashUnbreakable,[849]=TrashUnbreakable,[850]=TrashUnbreakable,[851]=TrashUnbreakable,[852]=TrashUnbreakable,[853]=TrashUnbreakable,
	[854]=TrashUnbreakable,[855]=TrashUnbreakable,[856]=TrashUnbreakable,[857]=TrashUnbreakable,[858]=TrashUnbreakable,[890]=TrashUnbreakable,
	[891]=TrashUnbreakable,[892]=TrashUnbreakable,[893]=TrashUnbreakable,[894]=TrashUnbreakable,[895]=TrashUnbreakable,[897]=TrashUnbreakable,
	[898]=TrashUnbreakable,[899]=TrashUnbreakable,[900]=TrashUnbreakable,[901]=TrashUnbreakable,[902]=TrashUnbreakable,[908]=TrashUnbreakable,
	[909]=TrashUnbreakable,[1200]=TrashUnbreakable,
	[17]=RedirectorUnbreakable,[62]=RedirectorUnbreakable,[63]=RedirectorUnbreakable,[64]=RedirectorUnbreakable,[65]=RedirectorUnbreakable,[741]=RedirectorUnbreakable,
	[1044]=RedirectorUnbreakable,[1045]=RedirectorUnbreakable,[1046]=RedirectorUnbreakable,[1047]=RedirectorUnbreakable,[1132]=RedirectorUnbreakable,[989]=RedirectorUnbreakable,
	[990]=RedirectorUnbreakable,[991]=RedirectorUnbreakable,[992]=RedirectorUnbreakable,[993]=RedirectorUnbreakable,
	[234]=FireUnbreakable,[240]=FireUnbreakable,[241]=FireUnbreakable,[242]=FireUnbreakable,[243]=FireUnbreakable,[602]=FireUnbreakable,[603]=FireUnbreakable,
	[232]=GravitizerUnbreakable,[266]=GravitizerUnbreakable,[424]=GravitizerUnbreakable,[588]=GravitizerUnbreakable,
	[522]=PerpetualRotUnbreakable,[523]=PerpetualRotUnbreakable,[524]=PerpetualRotUnbreakable,
	[525]=PerpetualRotUnbreakable,[535]=PerpetualRotUnbreakable,[715]=PerpetualRotUnbreakable,[967]=PerpetualRotUnbreakable,
	[425]=MidasUnbreakable,[737]=MidasUnbreakable,[738]=MidasUnbreakable,[739]=MidasUnbreakable,[740]=MidasUnbreakable,
	[426]=MidasUnbreakable,[742]=MidasUnbreakable,[743]=MidasUnbreakable,[744]=MidasUnbreakable,
	[252]=StickyUnbreakable,[647]=StickyUnbreakable,[648]=StickyUnbreakable,[788]=StickyUnbreakable,[789]=StickyUnbreakable,
	[649]=StickyUnbreakable,[650]=StickyUnbreakable,[651]=StickyUnbreakable,[790]=StickyUnbreakable,[791]=StickyUnbreakable,
	[824]=CompelUnbreakable,[825]=CompelUnbreakable,[826]=CompelUnbreakable,
	[896]=GooerUnbreakable,
	[206]=LlueaUnbreakable,[1147]=LlueaUnbreakable,[1148]=LlueaUnbreakable,
	[154]=function(cell,dir,x,y,vars) return vars.lastcell.id ~= 153 and vars.lastcell.id ~= 584 end,
	[225]=function(cell,dir,x,y,vars) return ToSide(cell.rot,dir)%2 ~= 0 or vars.forcetype ~= "rotate" and vars.forcetype ~= "flip" and vars.forcetype ~= "redirect"end,
	[226]=function(cell,dir,x,y,vars) return ToSide(cell.rot,dir)%2 == 0 and vars.forcetype ~= "rotate" and vars.forcetype ~= "flip" and vars.forcetype ~= "redirect" end,
	[300]=function(cell,dir,x,y,vars) return ToSide(cell.rot,dir) == 0 and vars.forcetype ~= "rotate" and vars.forcetype ~= "flip" and vars.forcetype ~= "redirect" end,
	[699]=function(cell,dir,x,y,vars) return vars.forcetype == "swap" end,
	[936]=function(cell,dir,x,y,vars) return vars.forcetype == "scissor" end,
	[937]=function(cell,dir,x,y,vars) return vars.forcetype == "tunnel" end,
	[552]=function(cell,dir,x,y,vars)
		local side = ToSide(cell.rot,dir)
		return cell.vars[side+1] == 3 or cell.vars[side+1] == 4 or (cell.vars[side+1] == 5 or cell.vars[side+1] == 6 or cell.vars[side+1] == 7 or cell.vars[side+1] == 8 or cell.vars[side+1] == 9 or cell.vars[side+1] == 10 or cell.vars[side+1] == 12) and vars.forcetype ~= "rotate" and vars.forcetype ~= "flip" and vars.forcetype ~= "redirect" or side%1 ~= 0
	end,
	[351]=function(cell,dir,x,y,vars)
		local side = ToSide(cell.rot,dir)
		return cell.vars[side+1] == 3 or cell.vars[side+1] == 4 or (cell.vars[side+1] == 5 or cell.vars[side+1] == 6 or cell.vars[side+1] == 7 or cell.vars[side+1] == 8 or cell.vars[side+1] == 9 or cell.vars[side+1] == 10 or cell.vars[side+1] == 12) and vars.forcetype ~= "rotate" and vars.forcetype ~= "flip" and vars.forcetype ~= "redirect" or cell.vars[math.floor(side)+17] == 2 and side%1 ~= 0
	end,
	[553]=OneWayUnbreakable,[558]=OneWayUnbreakable,[1160]=OneWayUnbreakable,[1161]=OneWayUnbreakable,
	[554]=CrossWayUnbreakable,[559]=CrossWayUnbreakable,
	[555]=BiWayUnbreakable,[560]=BiWayUnbreakable,
	[556]=TriWayUnbreakable,[561]=TriWayUnbreakable,
	[557]=true,[562]=true,
	[564]=function(cell,dir,x,y,vars) return not switches[cell.vars[1]] end,
	[565]=function(cell,dir,x,y,vars) return switches[cell.vars[1]] end,
	[566]=function(cell,dir,x,y,vars) return cell.vars[2] == 0 end,
	[706]=true,[916]=true,
})

function IsUnbreakable(cell,dir,x,y,vars)
	vars = vars or {}
	vars.lastcell = vars.lastcell or getempty()
	vars.lastx,vars.lasty = vars.lastx or x,vars.lasty or y
	return GetAttribute(cell.id,"isunbreakable",cell,dir,x,y,vars) or cell.vars.petrified
	or (cell.locked or cell.vars.bolted) and (vars.forcetype == "rotate" or vars.forcetype == "redirect" or vars.forcetype == "flip")
	or (cell.swapclamped or cell.vars.swappermaclamped) and vars.forcetype == "swap"
	or (cell.scissorclamped or cell.vars.scissorpermaclamped) and vars.forcetype == "scissor"
	or (cell.tunnelclamped or cell.vars.tunnelpermaclamped) and vars.forcetype == "tunnel"
	or (cell.protected or cell.vars.armored) and (vars.forcetype == "destroy" or vars.forcetype == "infect" or vars.forcetype == "burn" or vars.forcetype == "transform")
	or GetLayer(cell.id) == 0 and GetAttribute(GetCell(x,y,1).id,"isunbreakable",GetCell(x,y,1),dir,x,y,vars)
end

MergeIntoInfo("isnonexistant",{	
	[0]=true,[116]=true,[117]=true,[118]=true,[119]=true,[120]=true,[121]=true,[122]=true,[223]=true,	
	[680]=true,[681]=true,[682]=true,[683]=true,[819]=true,[1180]=true,
})

function IsNonexistant(cell,dir,x,y)	--act like empty space
	local above = GetCell(x,y,1)
	local aboveside = ToSide(above.rot,dir)
	if (above.id == 553 or above.id == 558) and (aboveside > 3 or aboveside < 1) or (above.id == 554 or above.id == 559) and (aboveside > 2 or aboveside < 1)
	or (above.id == 555 or above.id == 560) and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3)
	or (above.id == 556 or above.id == 561) and aboveside ~= 2 or (above.id == 557 or above.id == 562)
	or above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 566 and above.vars[2] == 0 or above.id == 706 or above.id == 916 then
		return false
	end
	return GetAttribute(cell.id,"isnonexistant",cell,dir,x,y)
end

function SemiDestroys(cell,dir,x,y,vars)
	return ToSide(cell.rot,dir)%2 == 0
end

function QuasiDestroys(cell,dir,x,y,vars)
	return ToSide(cell.rot,dir) == 0
end

function ConvertorDestroys(cell,dir,x,y,vars)
	return ToSide(cell.rot,dir) == 2
end

function StorageDestroys(cell,dir,x,y,vars)
	return not cell.vars[1]
end

function FilterDestroys(cell,dir,x,y,vars)
	return vars.forcetype == "push" or vars.forcetype == "nudge"
end

function SquishDestroys(cell,dir,x,y,vars)
	return vars.forcetype == "push"
end

function ForkerDestroys(cell,dir,x,y,vars)
	return ToSide(cell.rot,dir) == 2 and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function BiforkerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 2 or side == 1) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function ParaforkerDestroys(cell,dir,x,y,vars)
	return ToSide(cell.rot,dir)%2 == 0 and (vars.forcetype == "push" or vars.forcetype == "nudge")
end

function SpoonerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 1 or side == 3) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function TrispoonerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 1 or side == 2 or side == 3) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function CWSpoonerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 2 or side == 1) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function CCWSpoonerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 3 or side == 2) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end

function IntakerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 0) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function CrossIntakerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 0 or side == 3) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function BiIntakerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 0 or side == 2) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end
function TriIntakerDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 0 or side == 1 or side == 3) and (vars.forcetype == "push" or vars.forcetype == "nudge")
end

function GateDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return (side == 1 or side == 3)
end

function OmnicellDestroys(cell,dir,x,y,vars)
	local side = ToSide(cell.rot,dir)
	return cell.vars[side+1] == 5 or cell.vars[side+1] == 6 or cell.vars[side+1] == 7 or cell.vars[side+1] == 8 or cell.vars[side+1] == 9 or cell.vars[side+1] == 10 or cell.vars[side+1] == 11 and vars.forcetype == "push" or cell.vars[side+1] == 12
end

MergeIntoInfo("isdestroyer",{	
	[12]=true,[51]=true,[141]=true,[165]=true,[176]=true,[205]=true,[344]=true,[345]=true,[347]=true,
	[349]=true,[436]=true,[437]=true,[438]=true,[439]=true,[440]=true,[441]=true,[463]=true,[563]=true,
	[670]=true,[671]=true,[672]=true,[694]=true,[695]=true,[735]=true,[814]=true,[816]=true,[819]=true,
	[848]=true,[849]=true,[850]=true,[851]=true,[852]=true,[853]=true,[854]=true,[855]=true,[856]=true,
	[857]=true,[858]=true,[890]=true,[891]=true,[892]=true,[893]=true,[894]=true,[895]=true,[897]=true,
	[898]=true,[899]=true,[900]=true,[901]=true,[902]=true,[908]=true,[909]=true,[1116]=true,[1200]=true,
	[225]=SemiDestroys,[226]=SemiDestroys,[300]=QuasiDestroys,[815]=QuasiDestroys,[817]=QuasiDestroys,
	[175]=StorageDestroys,[362]=StorageDestroys,[645]=StorageDestroys,[704]=StorageDestroys,[821]=StorageDestroys,
	[822]=StorageDestroys,[823]=StorageDestroys,[831]=StorageDestroys,[905]=StorageDestroys,[1150]=StorageDestroys,
	[1151]=StorageDestroys,[1154]=StorageDestroys,
	[198]=ConvertorDestroys,[1043]=ConvertorDestroys,[1083]=ConvertorDestroys,[1164]=ConvertorDestroys,
	[233]=FilterDestroys,[601]=FilterDestroys,
	[348]=SquishDestroys,[350]=SquishDestroys,[859]=SquishDestroys,[860]=SquishDestroys,
	[48]=ForkerDestroys,[49]=ForkerDestroys,[97]=ForkerDestroys,[98]=ForkerDestroys,[99]=ForkerDestroys,[100]=ForkerDestroys,[101]=ForkerDestroys,
	[102]=ForkerDestroys,[782]=BiforkerDestroys,[783]=BiforkerDestroys,[784]=ParaforkerDestroys,[785]=ParaforkerDestroys,[1084]=ForkerDestroys,
	[186]=SpoonerDestroys,[187]=TrispoonerDestroys,[188]=CWSpoonerDestroys,[189]=CCWSpoonerDestroys,
	[190]=SpoonerDestroys,[191]=TrispoonerDestroys,[192]=CWSpoonerDestroys,[193]=CCWSpoonerDestroys,
	[44]=IntakerDestroys,[155]=CrossIntakerDestroys,[250]=BiIntakerDestroys,[317]=TriIntakerDestroys,[251]=FilterDestroys,
	[517]=IntakerDestroys,[518]=CrossIntakerDestroys,[519]=BiIntakerDestroys,[520]=TriIntakerDestroys,[521]=FilterDestroys,
	[32]=GateDestroys,[33]=GateDestroys,[34]=GateDestroys,[35]=GateDestroys,[36]=GateDestroys,
	[37]=GateDestroys,[194]=GateDestroys,[195]=GateDestroys,[196]=GateDestroys,[197]=GateDestroys,
	[351]=OmnicellDestroys,[552]=OmnicellDestroys,
	[558]=OneWayUnbreakable,
	[559]=CrossWayUnbreakable,
	[560]=BiWayUnbreakable,
	[561]=TriWayUnbreakable,
	[154]=function(cell,dir,x,y,vars)
		return vars.lastcell.id == 153 or vars.lastcell.id == 584
	end,
})

function IsDestroyer(cell,dir,x,y,vars)
	local id = cell.id
	local rot = cell.rot
	local side = ToSide(rot,dir)
	local above = GetCell(x,y,1)
	local aboveside = ToSide(above.rot,dir)
	vars = vars or {}
	vars.lastcell = vars.lastcell or getempty()
	vars.lastx,vars.lasty = vars.lastx or x,vars.lasty or y
	local pushing = vars.forcetype == "push" or vars.forcetype == "nudge"
	if ((CausesCollision(cell,dir,x,y,vars) or (CausesCollision(InvertLasts(cell,dir,x,y,vars)) and vars.forcetype ~= "swap"))
	and not IsUnbreakable(cell,dir,x,y,{forcetype="destroy",lastcell=vars.lastcell}) and not IsNonexistant(cell,dir,x,y,vars))
	and not IsUnbreakable(vars.lastcell,(dir+2)%4,vars.lastx,vars.lasty,{lastx=x,lasty=y,lastdir=dir,lastcell=cell,forcetype="destroy"}) then
		return "collide"
	elseif GetAttribute(cell.id,"isdestroyer",cell,dir,x,y,vars)
	or GetLayer(cell.id) == 0 and GetAttribute(GetCell(x,y,1).id,"isdestroyer",GetCell(x,y,1),dir,x,y,vars) then
		return "destroy"
	end
end

function IsTransparent(cell,dir,x,y,vars)
	return (IsNonexistant(cell,dir,x,y) or IsDestroyer(cell,dir,x,y,vars))
end

function returnnil()
	return nil
end

MergeIntoInfo("togenerate",{
	[20]=getempty,
	[41]=returnnil,[205]=returnnil,[214]=returnnil,[215]=returnnil,[216]=returnnil,[217]=returnnil,[218]=returnnil,[349]=returnnil,[350]=returnnil,
	[439]=returnnil,[441]=returnnil,[670]=returnnil,[671]=returnnil,[735]=returnnil,[819]=returnnil,[856]=returnnil,[891]=returnnil,[1116]=returnnil,
	[351]=function(cell,dir,x,y)
		local side = ToSide(cell.rot,dir)
		if cell.vars[side+1] == 2 or cell.vars[side+1] == 4 or cell.vars[side+1] == 6 then
			return nil
		end
		return cell
	end,
	[552]=function(cell,dir,x,y)
		local side = ToSide(cell.rot,dir)
		if cell.vars[side+1] == 2 or cell.vars[side+1] == 4 or cell.vars[side+1] == 6 then
			return nil
		end
		return cell
	end,
	[643]=function(cell,dir,x,y)
		cell.id = 20
		return cell
	end,
	[644]=function(cell,dir,x,y)
		if cell.vars[1] > 2 then
			cell.vars[1] = cell.vars[1]-1
		elseif cell.vars[1] == 2 then
			cell.id = 643
			cell.vars[1] = nil
		elseif cell.vars[1] == 1 then
			cell.id = 20
			cell.vars[1] = nil
		else
			return getempty()
		end
		return cell
	end,
	[645]=function(cell,dir,x,y)
		if cell.vars[3] > 1 then
			cell.vars[3] = cell.vars[3]-1
		else
			if cell.vars[1] then
				return GetStoredCell(cell)
			else
				return getempty()
			end
		end
		return cell
	end,
})	

function ToGenerate(cell,dir,x,y)
	local above = GetCell(x,y,1)
	local aboveside = ToSide(above.rot,dir)
	if (above.id == 553 or above.id == 558) and (aboveside > 3 or aboveside < 1) or (above.id == 554 or above.id == 559) and (aboveside > 2 or aboveside < 1)
	or (above.id == 555 or above.id == 560) and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3)
	or (above.id == 556 or above.id == 561) and aboveside ~= 2 or (above.id == 557 or above.id == 562)
	or above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 566 and above.vars[2] == 0 or above.id == 706 or above.id == 916 then
		return nil
	end
	if cell.vars.ghostified == 1 then
		return nil
	elseif cell.vars.ghostified == 2 then
		return getempty()
	end
	local genfunc = GetAttributeRaw(cell.id,"togenerate")
	if genfunc then
		return genfunc(cell,dir,x,y)
	else
		if IsNonexistant(cell,dir,x,y) then
			return nil
		end
		return cell
	end
end

function StopsOptimize(cell,dir,x,y,vars)
	local id = cell.id
	return IsTransparent(cell,dir,x,y,vars) or id == 126 or id == 150 or id == 151 or id == 152 or id == 162 or id == 163 or id == 312 or id == 401 or id == 402 or id == 566 or id == 709 or id == 710
	or id == 423 or id == 863 or id == 864 or id == 865 or id == 965  or id == 1046 
	or (id == 219 or id == 220 or id == 327 or id == 328 or id == 329 or id == 330 or id == 331 or id == 332 or id == 333 or id == 334 or id == 335 or id == 336 or id == 716 or id == 717
	or id == 337 or id == 338 or id == 339 or id == 340 or id == 701) and cell.rot == dir
	or (id == 351 or id == 552) and (cell.vars[ToSide(cell.rot,dir)+1] == 19 or cell.vars[ToSide(cell.rot,dir+2)+1] == 17)
end

function OmnicellCollides(cell,dir,x,y,vars)
	return cell.vars[ToSide(cell.rot,dir)+1] == 13
end

function CrackerCollides(cell,dir,x,y,vars)
	return cell.vars[1] and cell.updatekey ~= updatekey
end

function FragilePlayerCollides(cell,dir,x,y,vars)
	return not vars.islast
end

function ParticleCollides(cell,dir,x,y,vars)
	return vars.lastcell.id == cell.id + 1 
end
function AntiparticleCollides(cell,dir,x,y,vars)
	return vars.lastcell.id == cell.id - 1 
end

function CollidesWithFriendly(cell,dir,x,y,vars)
	return IsFriendly(vars.lastcell)
end
function CollidesWithUnfriendly(cell,dir,x,y,vars)
	return IsUnfriendly(vars.lastcell)
end

MergeIntoInfo("causescollision",{
	[13]=true,[24]=true,[160]=true,[164]=true,[244]=true,[299]=true,[318]=true,[319]=true,[320]=true,[358]=true,[359]=true,[360]=true,[361]=true,[367]=true,
	[368]=true,[453]=true,[454]=true,[455]=true,[456]=true,[589]=true,[590]=true,[591]=true,[592]=true,[593]=true,[594]=true,[595]=true,[596]=true,[597]=true,
	[598]=true,[599]=true,[600]=true,[768]=true,[792]=true,[793]=true,[794]=true,[795]=true,[796]=true,[797]=true,[798]=true,[799]=true,[800]=true,[801]=true,
	[802]=true,[803]=true,[804]=true,[805]=true,[806]=true,[807]=true,[827]=true,[828]=true,[838]=true,[839]=true,[907]=true,[915]=true,[1000]=true,[1165]=true,
	[1166]=true,[1168]=true,[1170]=true,[1172]=true,[1173]=true,
	[288]=FragilePlayerCollides,[293]=FragilePlayerCollides,[294]=FragilePlayerCollides,[295]=FragilePlayerCollides,[296]=FragilePlayerCollides,[298]=FragilePlayerCollides,[830]=FragilePlayerCollides,
	[351]=OmnicellCollides,[552]=OmnicellCollides,
	[831]=CrackerCollides,
	[1133]=ParticleCollides,[1135]=ParticleCollides,[1137]=ParticleCollides,[1139]=ParticleCollides,
	[1141]=ParticleCollides,[1143]=ParticleCollides,[1145]=ParticleCollides,[1147]=ParticleCollides,
	[1134]=AntiparticleCollides,[1136]=AntiparticleCollides,[1138]=AntiparticleCollides,[1140]=AntiparticleCollides,
	[1142]=AntiparticleCollides,[1144]=AntiparticleCollides,[1146]=AntiparticleCollides,[1148]=AntiparticleCollides,
	[1167]=CollidesWithFriendly,[1169]=CollidesWithUnfriendly,
	[1155] = function(cell,dir,x,y,vars)
		return dir == (cell.rot+2)%4
	end,
})

function CausesCollision(cell,dir,x,y,vars)
	local id = cell.id
	return GetAttribute(cell.id,"causescollision",cell,dir,x,y,vars)
	or IsAcid(cell,dir,x,y,vars) and vars.islast and not IsAcid(InvertLasts(cell,dir,x,y,vars))
	or cell.vars.spiked
end

function OmnicellIsAcid(cell,dir,x,y,vars)
	return cell.vars[ToSide(cell.rot,dir)+1] == 17
end

MergeIntoInfo("isacid",{
	[219]=true,[220]=true,[423]=true,[863]=true,
	[351]=OmnicellIsAcid,[552]=OmnicellIsAcid,
})

function IsAcid(cell,dir,x,y,vars)
	local id = cell.id
	return GetAttribute(cell.id,"isacid",cell,dir,x,y,vars)
end

function HealthIsRotation(cell)
	return cell.rot+1
end

function OmnicellHealth(cell)
	return cell.vars[5]
end

function SpringHealth(cell)
	return (cell.vars[1] or 0)+1
end

function StoredHealth(cell,dir,x,y)
	return 1 +(cell.vars[1] and GetHP(GetStoredCell(cell),dir,x,y,vars) or 0)
end

MergeIntoInfo("health",{
	[24]=2,[358]=2,[589]=2,[593]=2,[597]=2,[792]=2,[796]=2,[800]=2,[804]=2,
	[244]=math.huge,[359]=math.huge,[590]=math.huge,[594]=math.huge,[598]=math.huge,[793]=math.huge,[797]=math.huge,
	[801]=math.huge,[805]=math.huge,[832]=math.huge,[838]=math.huge,[839]=math.huge,[840]=math.huge,[841]=math.huge,
	[842]=math.huge,[843]=math.huge,[844]=math.huge,[219]=math.huge,[423]=math.huge,[716]=math.huge,[864]=math.huge,
	[1165]=math.huge,[1166]=math.huge,[1168]=math.huge,[1170]=math.huge,
	[164]=HealthIsRotation,
	[351]=OmnicellHealth,[552]=OmnicellHealth,
	[402]=SpringHealth,
	[831]=StoredHealth,
})

function GetHP(cell,dir,x,y)
	return GetAttribute(cell.id,"health",cell,dir,x,y) or 1
end

function GetDamageBasic(particles)
	return function(cell,dmg,dir,x,y,vars)
		if dmg > 0 then
			cell.id = 0
			cell.vars = {}
		end
		EmitParticles(particles,x,y)
	end
end
function GetDamageStrong(weakid, particles)
	return function(cell,dmg,dir,x,y,vars)
		if dmg > 1 then
			cell.id = 0
			cell.vars = {}
		elseif dmg > 0 then
			cell.id = weakid
		end
		EmitParticles(particles,x,y)
	end
end
function GetDamageSuper(particles)
	return function(cell,dmg,dir,x,y,vars)
		if dmg == math.huge then
			cell.id = 0
			cell.vars = {}
		end
		EmitParticles(particles,x,y)
	end
end
function DamageOmnicell(cell,dmg,dir,x,y,vars)
	if dmg >= cell.vars[5] then
		cell.id = 0
		cell.vars = {}
	else
		cell.vars[5] = cell.vars[5] - dmg
	end
	if cell.vars[ToSide(cell.rot,dir)+1] == 12 and fancy then EmitParticles("enemy",x,y) end
end
function GetDamageExplosive(neighborfunc,particles)
	return function(cell,dmg,dir,x,y,vars)
		if dmg > 0 then
			cell.id = 0
			cell.vars = {}
			local x,y = x,y
			if vars.lastcell == cell then
				x,y = vars.lastx,vars.lasty
				if not IsUnbreakable(GetCell(x,y),(dir+2)%4,x,y,{forcetype="destroy",lastcell=cell}) then
					Queue("damage", function() DamageCell(GetCell(x,y),(dir+2)%4,k,x,y,vars) end)
				end
			end
			local neighbors = neighborfunc(x,y)
			for k,v in pairs(neighbors) do
				local c = GetCell(v[1],v[2])
				if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
					Queue("damage", function() DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars) end)
				end
			end
		end
		if fancy then
			EmitParticles(particles,x,y)
		end
	end
end

MergeIntoInfo("handledamage",{
	[13]=GetDamageBasic("enemy"),[160]=GetDamageBasic("enemy"),[318]=GetDamageBasic("enemy"),[319]=GetDamageBasic("enemy"),
	[320]=GetDamageBasic("enemy"),[1167]=GetDamageBasic("enemy"),
	[288]=GetDamageBasic("player"),[293]=GetDamageBasic("player"),[294]=GetDamageBasic("player"),[295]=GetDamageBasic("player"),
	[296]=GetDamageBasic("player"),[298]=GetDamageBasic("player"),[830]=GetDamageBasic("player"),[915]=GetDamageBasic("player"),
	[453]=GetDamageBasic("staller"),[454]=GetDamageBasic("staller"),[455]=GetDamageBasic("staller"),[456]=GetDamageBasic("staller"),
	[768]=GetDamageBasic("staller"),[220]=GetDamageBasic("staller"),[863]=GetDamageBasic("staller"),[1169]=GetDamageBasic("staller"),
	[827]=GetDamageBasic("angry"),[828]=GetDamageBasic("angry"),
	[717]=GetDamageBasic("bulk"),[865]=GetDamageBasic("bulk"),[1172]=GetDamageBasic("bulk"),
	[907]=GetDamageBasic("swivel"),[1155]=GetDamageBasic("swivel"),[1173]=GetDamageBasic("swivel"),
	[24]=GetDamageStrong(13,"enemy"),[358]=GetDamageStrong(160,"enemy"),[589]=GetDamageStrong(318,"enemy"),
	[792]=GetDamageStrong(319,"enemy"),[796]=GetDamageStrong(320,"enemy"),[593]=GetDamageStrong(453,"staller"),
	[597]=GetDamageStrong(456,"staller"),[800]=GetDamageStrong(454,"staller"),[804]=GetDamageStrong(455,"staller"),
	[244]=GetDamageSuper("super"),[359]=GetDamageSuper("super"),[590]=GetDamageSuper("super"),[793]=GetDamageSuper("super"),[1168]=GetDamageSuper("super"),
	[838]=GetDamageSuper("super"),[839]=GetDamageSuper("super"),[1165]=GetDamageSuper("friendlysuper"),[1170]=GetDamageSuper("friendlysuper"),[1166]=GetDamageSuper("neutralsuper"),
	[219]=GetDamageSuper("staller"),[423]=GetDamageSuper("staller"),
	[716]=GetDamageSuper("bulk"),[864]=GetDamageSuper("bulk"),
	[594]=GetDamageSuper("friendlysuper"),[598]=GetDamageSuper("friendlysuper"),[801]=GetDamageSuper("friendlysuper"),[805]=GetDamageSuper("friendlysuper"),
	[832]=GetDamageSuper(),[840]=GetDamageSuper(),[841]=GetDamageSuper(),[842]=GetDamageSuper(),[843]=GetDamageSuper(),[844]=GetDamageSuper(),
	[351]=DamageOmnicell,[552]=DamageOmnicell,
	[360]=GetDamageExplosive(GetNeighbors,"explosive"),[367]=GetDamageExplosive(GetNeighbors,"explosive"),
	[591]=GetDamageExplosive(GetNeighbors,"explosive"),[794]=GetDamageExplosive(GetNeighbors,"explosive"),
	[798]=GetDamageExplosive(GetNeighbors,"explosive"),
	[595]=GetDamageExplosive(GetNeighbors,"friendlyexplosive"),[599]=GetDamageExplosive(GetNeighbors,"friendlyexplosive"),
	[802]=GetDamageExplosive(GetNeighbors,"friendlyexplosive"),[806]=GetDamageExplosive(GetNeighbors,"friendlyexplosive"),
	[361]=GetDamageExplosive(GetSurrounding,"explosive"),[368]=GetDamageExplosive(GetSurrounding,"explosive"),
	[592]=GetDamageExplosive(GetSurrounding,"explosive"),[795]=GetDamageExplosive(GetSurrounding,"explosive"),
	[799]=GetDamageExplosive(GetSurrounding,"explosive"),
	[595]=GetDamageExplosive(GetSurrounding,"friendlyexplosive"),[600]=GetDamageExplosive(GetSurrounding,"friendlyexplosive"),
	[803]=GetDamageExplosive(GetSurrounding,"friendlyexplosive"),[807]=GetDamageExplosive(GetSurrounding,"friendlyexplosive"),
	[164]=function(cell,dmg,dir,x,y,vars)
		if dmg >= cell.rot+1 then
			cell.id = 0
			cell.vars = {}
		else
			cell.rot = cell.rot-dmg
			cell.lastvars[3] = cell.lastvars[3]-dmg
		end
		EmitParticles("swivel",x,y)
	end,
	[299]=function(cell,dmg,dir,x,y,vars)
		if dmg > 0 then
			DoQuantumEnemy(cell,vars)
		end
	end,
	[402]=function(cell,dmg,dir,x,y,vars)
		if dmg >= (cell.vars[1] or 0)+1 then
			cell.id = 0
			cell.vars = {}
		else
			cell.vars[1] = (cell.vars[1] or 0) - dmg
		end
	end,
	[831]=function(cell,dmg,dir,x,y,vars)
		if dmg > 0 then
			dmg = dmg
			cell.id,cell.rot,cell.updated,cell.vars = cell.vars[1],cell.vars[2],true,DefaultVars(cell.vars[1])
			if dmg > 1 then
				DamageCell(cell,dmg-1,dir,x,y,vars)
			end
		end
		EmitParticles("bulk",x,y)
	end,
	[1000]=function(cell,dmg,dir,x,y,vars)
		if dmg > 0 then
			cell.id = 0 
			cell.vars = {}
		end
		if fancy then EmitFireworks(x,y) end
		Play("shoot")
	end,
})

function DamageCell(cell,dmg,dir,x,y,vars)
	local id = cell.id
	if cell.vars.spiked and fancy then
		EmitParticles("enemy",x,y)
	end
	local damagefunc = cellinfo[id].handledamage
	if damagefunc then
		damagefunc(cell,dmg,dir,x,y,vars)
	else
		if dmg > 0 then
			cell.id = 0
			cell.vars = {}
		end
	end
	ExecuteQueue("damage")
end

function StepForward(x,y,dir,mult)
	mult = (mult or 1)*(dir%1 == .5 and 2 or 1)
	--return x-(math.min(dir,-dir+4)-1)*mult,y-(math.max(-dir,dir-2))*mult
	return x-(math.min(dir,-dir+4)-1)*mult,y-(math.max((-dir-1)%-4+1,(dir+1)%4-3))*mult
end
StepForwards = StepForward

function StepRight(x,y,dir,mult)
	mult = (mult or 1)*(dir%1 == .5 and 2 or 1)
	return x+(math.max((-dir-1)%-4+1,(dir+1)%4-3))*mult,y-(math.min(dir,-dir+4)-1)*mult
end
StepRightwards = StepRight
StepClockwise = StepRight
StepCW = StepRight

function StepBack(x,y,dir,mult)
	mult = (mult or 1)*(dir%1 == .5 and 2 or 1)
	return x+(math.min(dir,-dir+4)-1)*mult,y+(math.max((-dir-1)%-4+1,(dir+1)%4-3))*mult
end
StepBackwards = StepBack
Step180 = StepBack

function StepLeft(x,y,dir,mult)
	mult = (mult or 1)*(dir%1 == .5 and 2 or 1)
	return x-(math.max((-dir-1)%-4+1,(dir+1)%4-3))*mult,y+(math.min(dir,-dir+4)-1)*mult
end
StepLeftwards = StepLeft
StepCounterClockwise = StepLeft
StepCCW = StepLeft

function HandleNext(cell,x,y,dir,vars,reversed)
	local id = cell.id
	local side = ToSide(cell.rot,dir)
	local continue = true
	if id == 16 or id == 91 then
		if side == 0 then
			if id == 16 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
		elseif side == 1 then
			if id == 16 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
		else continue = false end
	elseif id == 31 or id == 92 then
		if side == 0 or side == 2 then
			if id == 31 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
		elseif side == 1 or side == 3 then
			if id == 31 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
		else continue = false end
	elseif id == 38 then
		if side == 1 or side == 3 then continue = false end
	elseif id == 210 then
		if side == 1 or side == 3 then continue = false
		else FlipCellRaw(vars.lastcell,(cell.rot+1)%4) end
	elseif id == 93 or id == 95 then
		if reversed then
			if side ~= 0 then continue = false end
		else
			if side == 1 then
				if id == 93 then RotateCellRaw(vars.lastcell,1) end
				dir = (dir + 1)%4
			elseif side ~= 2 then continue = false end
		end
	elseif id == 94 or id == 96 then
		if reversed then
			if side ~= 0 then continue = false end
		else
			if side == 3 then
				if id == 94 then RotateCellRaw(vars.lastcell,-1) end
				dir = (dir - 1)%4
			elseif side ~= 2 then continue = false end
		end
	elseif id == 83 or id == 86 then
		if reversed then
			if side ~= 2 then continue = false end
		else
			if side == 1 then
				if id == 83 then RotateCellRaw(vars.lastcell,1) end
				dir = (dir + 1)%4
			elseif side == 3 then
				if id == 83 then RotateCellRaw(vars.lastcell,-1) end
				dir = (dir - 1)%4
			elseif side == 0 then continue = false end
		end
	elseif id == 433 or id == 434 then
		if reversed then
			if side ~= 2 then continue = false
			else
				dir = (dir - 1)%4
				if id == 433 then RotateCellRaw(vars.lastcell,-1) end
			end
		else
			if side == 1 then
				if id == 433 then RotateCellRaw(vars.lastcell,1) end
				dir = (dir + 1)%4
			elseif side == 3 then
				if id == 433 then RotateCellRaw(vars.lastcell,-1) end
				dir = (dir - 1)%4
			else continue = false end
		end
	elseif id == 84 or id == 87 then
		if side == 1 or side == 3 then
			if reversed then continue = false end
			if id == 84 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
		end
	elseif id == 85 or id == 88 then
		if side == 1 or side == 3 then
			if reversed then continue = false end
			if id == 85 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
		end
	elseif id == 208 or id == 300 or id == 1084 and reversed then
		if side ~= 0 and reversed or side ~= 2 and not reversed or side == 1 or side == 3 then
			continue = false
		end
	elseif id == 209 then
		if side ~= 0 and side ~= 3 and reversed or side ~= 2 and side ~= 1 and not reversed then
			continue = false
		end
	elseif (id == 48 or id == 99) and reversed then
		if side == 1 then
			if id == 48 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
		elseif side == 3 then
			if id == 48 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
		else continue = false end
	elseif (id == 49 or id == 100) and reversed then
		if side == 1 then
			if id == 49 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
		elseif side == 3 then
			if id == 49 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
		elseif side == 2 then continue = false end
	elseif (id == 97 or id == 101) and reversed then
		if side == 1 then
			if id == 97 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
		elseif side ~= 0 then continue = false end
	elseif (id == 98 or id == 102) and reversed then
		if side == 3 then
			if id == 98 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
		elseif side ~= 0 then continue = false end
	elseif (id == 782 or id == 783) and reversed then
		if side ~= 0 and side ~= 3 then continue = false end
	elseif (id == 784 or id == 785) and reversed then
		if side == 1 or side == 3 then
			if id == 784 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
		else continue = false end
	elseif (id == 186 or id == 190) and reversed then
		if side == 0 then
			if id == 186 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
		else continue = false end
	elseif (id == 187 or id == 188 or id == 189 or id == 191 or id == 192 or id == 193) and reversed then
		if side ~= 0 then continue = false end
	elseif id == 221 then
		if not reversed then
			local options = portals[cell.vars[2]] or {}
			if #options ~= 0 then
				x,y = unpack(options[math.random(#options)])	--apparently this function exists
				local cell2 = GetCell(x,y)
				local change = cell2.rot-cell.rot
				dir = (dir+change)%4
				if fancy then table.safeinsert(cell,"eatencells",table.copy(vars.lastcell)) end
				RotateCellRaw(vars.lastcell,change)
				vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
				vars.lastcell.lastvars[1] = x
				vars.lastcell.lastvars[2] = y
			end
		else
			local options = reverseportals[cell.vars[1]] or {}
			if #options ~= 0 then
				x,y = unpack(options[math.random(#options)])
				local cell2 = GetCell(x,y)
				local change = cell2.rot-cell.rot
				dir = (dir+change)%4
				if fancy then table.safeinsert(cell,"eatencells",table.copy(vars.lastcell)) end
				RotateCellRaw(vars.lastcell,change)
				vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
				vars.lastcell.lastvars[1] = x
				vars.lastcell.lastvars[2] = y
			end
		end
	elseif id == 224 and vars.lastcell.vars.coins and vars.lastcell.vars.coins >= cell.vars[1] then
		vars.lastcell.vars.coins = vars.lastcell.vars.coins-cell.vars[1]
		if vars.lastcell.vars.coins <= 0 then
			vars.lastcell.vars.coins = nil
		end
	elseif id == 233 then
		if vars.lastcell.id == cell.vars[1] or side == 1 or side == 3 then
			continue = false
		end
	elseif id == 601 then
		if vars.lastcell.id ~= cell.vars[1] or side == 1 or side == 3 then
			continue = false
		end
	elseif (id == 351 or id == 552) then
		if not reversed and cell.vars[side+1] ~= 16 or reversed and cell.vars[(side+2)%4+1] ~= 16 then
			continue = false
		end
	elseif id == 381 then
		if cell.rot == 0 or cell.rot == 2 then
			if dir == 0 or dir == 1 then x=x-1 y=y-1				
			else x=x+1 y=y+1 end	
		else
			if dir == 0 or dir == 3 then x=x-1 y=y+1				
			else x=x+1 y=y-1 end	
		end		
	elseif id == 383 and not reversed or id == 382 and reversed or id == 978 and math.random() < .5 then
		if dir == 0 or dir == 1 then x=x-1
		else x=x+1 end
		if dir == 2 or dir == 1 then y=y-1
		else y=y+1 end	
	elseif id == 382 and not reversed or id == 383 and reversed or id == 978 then
		if dir == 0 or dir == 3 then x=x-1
		else x=x+1 end
		if dir == 0 or dir == 1 then y=y-1
		else y=y+1 end
	elseif id == 390 then
		if cell.rot == 0 or cell.rot == 2 then
			if dir == 0 then x=x-2 y=y-1
			elseif dir == 1 then x=x-1 y=y-2
			elseif dir == 2 then x=x+2 y=y+1
			else x=x+1 y=y+2 end	
		else
			if dir == 0 then x=x-2 y=y+1				
			elseif dir == 1 then x=x+1 y=y-2
			elseif dir == 2 then x=x+2 y=y-1
			else x=x-1 y=y+2 end	
		end		
	elseif id == 392 and not reversed or id == 391 and reversed or id == 979 and math.random() < .5 then
		if dir == 0 then x=x-2 y=y+1				
		elseif dir == 1 then x=x-1 y=y-2
		elseif dir == 2 then x=x+2 y=y-1
		else x=x+1 y=y+2 end		
	elseif id == 391 and not reversed or id == 392 and reversed or id == 979 then
		if dir == 0 then x=x-2 y=y-1				
		elseif dir == 1 then x=x+1 y=y-2
		elseif dir == 2 then x=x+2 y=y+1
		else x=x-1 y=y+2 end		
	elseif id == 1017 then
		if cell.rot == 0 or cell.rot == 2 then
			if dir == 0 then y=y-1
			elseif dir == 1 then x=x-1
			elseif dir == 2 then y=y+1
			else x=x+1 end	
		else
			if dir == 0 then y=y+1				
			elseif dir == 1 then x=x+1
			elseif dir == 2 then y=y-1
			else x=x-1 end	
		end		
	elseif id == 1019 and not reversed or id == 1018 and reversed or id == 1020 and math.random() < .5 then
		if dir == 0 then y=y+1				
		elseif dir == 1 then x=x-1 
		elseif dir == 2 then y=y-1
		else x=x+1 end		
	elseif id == 1018 and not reversed or id == 1019 and reversed or id == 1020 then
		if dir == 0 then y=y-1				
		elseif dir == 1 then x=x+1
		elseif dir == 2 then y=y+1
		else x=x-1 end		
	elseif id == 1091 then
		if cell.rot == 0 or cell.rot == 2 then
			if dir == 0 then x=x+cell.vars[1]-1 y=y-cell.vars[2]
			elseif dir == 1 then x=x-cell.vars[2] y=y+cell.vars[1]-1
			elseif dir == 2 then x=x-cell.vars[1]+1 y=y+cell.vars[2]
			else x=x+cell.vars[2] y=y-cell.vars[1]+1 end	
		else
			if dir == 0 then x=x+cell.vars[1]-1 y=y+cell.vars[2]
			elseif dir == 1 then x=x+cell.vars[2] y=y+cell.vars[1]-1
			elseif dir == 2 then x=x-cell.vars[1]+1 y=y-cell.vars[2]
			else x=x-cell.vars[2] y=y-cell.vars[1]+1 end	
		end		
	elseif id == 1093 and not reversed or id == 1092 and reversed or id == 1094 and math.random() < .5 then
		if dir == 0 then x=x+cell.vars[1]-1 y=y+cell.vars[2]
		elseif dir == 1 then x=x-cell.vars[2] y=y+cell.vars[1]-1
		elseif dir == 2 then x=x-cell.vars[1]+1 y=y-cell.vars[2]
		else x=x+cell.vars[2] y=y-cell.vars[1]+1 end		
	elseif id == 1092 and not reversed or id == 1093 and reversed or id == 1094 then
		if dir == 0 then x=x+cell.vars[1]-1 y=y-cell.vars[2]
		elseif dir == 1 then x=x+cell.vars[2] y=y+cell.vars[1]-1
		elseif dir == 2 then x=x-cell.vars[1]+1 y=y+cell.vars[2]
		else x=x-cell.vars[2] y=y-cell.vars[1]+1 end	
	elseif id == 384 or id == 386 then
		if side == 0 then dir = (dir-1)%4
		elseif side == 1 then dir = (dir+1)%4 end
		continue = false
	elseif id == 385 or id == 387 then
		if side == 0 or side == 2 then dir = (dir-1)%4
		elseif side == 1 or side == 3 then dir = (dir+1)%4 end
		continue = false
	elseif id == 388 and not reversed or id == 389 and reversed then
		dir = (dir+1)%4
		continue = false
	elseif id == 389 and not reversed or id == 388 and reversed then
		dir = (dir-1)%4
		continue = false
	elseif (id == 429 or id == 431) and not reversed or (id == 430 or id == 432) and reversed then
		dir = (dir+1)%4
		if id < 431 then
			RotateCellRaw(vars.lastcell,1)
		end
	elseif (id == 429 or id == 431) and reversed or (id == 430 or id == 432) and not reversed then
		dir = (dir-1)%4
		if id < 431 then
			RotateCellRaw(vars.lastcell,-1)
		end
	elseif id == 488 and side%2 == 0 then
		if vars.lastcell.id ~= 0 then
			if cell.vars[1] == 0 then
				RotateCellRaw(vars.lastcell,1)
			elseif cell.vars[1] == 1 then
				RotateCellRaw(vars.lastcell,-1)
			elseif cell.vars[1] == 2 then
				RotateCellRaw(vars.lastcell,2)
			elseif cell.vars[1] == 3 then
				FlipCellRaw(vars.lastcell,cell.rot)
			elseif cell.vars[1] == 4 then
				FlipCellRaw(vars.lastcell,cell.rot+1)
			elseif cell.vars[1] == 5 then
				FlipCellRaw(vars.lastcell,cell.rot+.5)
			elseif cell.vars[1] == 6 then
				FlipCellRaw(vars.lastcell,cell.rot+1.5)
			elseif cell.vars[1] == 7 then
				RotateCellRaw(vars.lastcell,math.randomsign())
			elseif cell.vars[1] == 8 then
				RotateCellRaw(vars.lastcell,cell.rot-vars.lastcell.rot)
			elseif cell.vars[1] == 9 then
				RotateCellRaw(vars.lastcell,cell.rot-vars.lastcell.rot+1)
			elseif cell.vars[1] == 10 then
				RotateCellRaw(vars.lastcell,cell.rot-vars.lastcell.rot+2)
			elseif cell.vars[1] == 11 then
				RotateCellRaw(vars.lastcell,cell.rot-vars.lastcell.rot+3)
			end
		end
	elseif id == 702 or id == 703 then
		if side%2 == 0 then
			if id == 702 then RotateCellRaw(vars.lastcell,-1) end
			dir = (dir - 1)%4
			if vars.lastcell.id ~= 0 then RotateCellRaw(cell,-1) end
		elseif side%2 == 1 then
			if id == 702 then RotateCellRaw(vars.lastcell,1) end
			dir = (dir + 1)%4
			if vars.lastcell.id ~= 0 then RotateCellRaw(cell,1) end
		else continue = false end
	elseif id == 980 or id == 981 then
		r = math.random(-1,1)
		if r ~= 0 then
			if id == 980 then RotateCellRaw(vars.lastcell,r) end
			dir = (dir + r)%4
		end
	elseif id == 982 or id == 983 then
		if side == 2 then
			r = math.randomsign()
			if id == 982 then RotateCellRaw(vars.lastcell,r) end
			dir = (dir + r)%4
		elseif side ~= 0 then
			r = side == 3 and math.random(0,1) or math.random(-1,0)
			if r ~= 0 then
				if id == 982 then RotateCellRaw(vars.lastcell,r) end
				dir = (dir + r)%4
			end
		end
	elseif id == 1085 then
		if side == 0 then
			continue = reversed
		elseif side == 2 and not reversed then
			if cell.vars[1] < cell.vars[2]-1 then
				cell.vars[1] = cell.vars[1] + 1
				vars.forcedestroy = true
			else
				cell.vars[1] = 0
			end
		else
			continue = false
		end
	elseif id == 428 or id == 747 and side == 0 or id == 748 and (side == 3 or side == 0) then
		repeat
			x,y = StepBack(x,y,dir)
		until GetCell(x,y).id == 428 or GetCell(x,y).id == 747 and GetCell(x,y).rot == dir or GetCell(x,y).id == 748 and (GetCell(x,y).rot == dir or GetCell(x,y).rot == (dir+1)%4) or x < 1 or x > width-2 or y < 1 or y > height-2
		vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
		vars.lastcell.lastvars[1] = x
		vars.lastcell.lastvars[2] = y
	elseif id == 746 or id == 747 and side == 2 or id == 748 and (side == 1 or side == 2) then
		local ox,oy = x,y
		repeat
			x,y = StepForward(x,y,dir)
			if x < 1 or x > width-2 or y < 1 or y > height-2 then
				x,y = ox,oy
				return
			end
		until GetCell(x,y).id == 746 or GetCell(x,y).id == 747 and GetCell(x,y).rot == (dir+2)%4 or GetCell(x,y).id == 748 and (GetCell(x,y).rot == (dir+2)%4 or GetCell(x,y).rot == (dir+3)%4)
		vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
		vars.lastcell.lastvars[1] = x
		vars.lastcell.lastvars[2] = y
	elseif id ~= 39 and (not IsNonexistant(cell,dir,x,y) or
	(dir%2 == 0) and (GetCell(x,y-1).id ~= 79 and GetCell(x,y+1).id ~= 79) or
	(dir%2 == 0.5) and (GetCell(x-1,y-1).id ~= 79 and GetCell(x+1,y+1).id ~= 79) or
	(dir%2 == 1) and (GetCell(x-1,y).id ~= 79 and GetCell(x+1,y).id ~= 79) or
	(dir%2 == 1.5) and (GetCell(x-1,y+1).id ~= 79 and GetCell(x+1,y-1).id ~= 79)) then continue = false
	end
	return continue,x,y,dir
end

function NextCell(x,y,dir,vars,reversed,checkfirst)	--i know it's a weirdly named function
	vars = vars or {lastcell=getempty()}
	vars = vars.id and {lastcell=vars} or vars
	local firstloop,data = true
	while true do
		if checkfirst or not firstloop then
			if not vars.layer or vars.layer == 0 then
				local above = GetCell(x,y,1)
				local aboveside = ToSide(above.rot,dir)
				if (above.id == 553 or above.id == 558) and (aboveside > 3 or aboveside < 1) or (above.id == 554 or above.id == 559) and (aboveside > 2 or aboveside < 1)
				or (above.id == 555 or above.id == 560) and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3)
				or (above.id == 556 or above.id == 561) and aboveside ~= 2 or (above.id == 557 or above.id == 562)
				or above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 566 and above.vars[2] == 0 or above.id == 706 or above.id == 916 then
					goto stop
				end
			end
			local continue,newx,newy,newdir = HandleNext(GetCell(x,y,vars.layer),x,y,dir,vars,reversed)
			x,y,dir = newx or x,newy or y,newdir or dir
			if not continue then goto stop end
		end
		::redo::
		x,y = StepForward(x,y,dir)
		if layers[0][0][0].id == 428 then
			x = math.max(math.min(x,width-1),0)
			y = math.max(math.min(y,height-1),0)
			if x > width-2 then
				repeat 
					x = x-1
				until layers[0][y][x].id == 428
				vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
				vars.lastcell.lastvars[1] = x
				x = x + 1
			elseif x < 1 then
				repeat 
					x = x+1
				until layers[0][y][x].id == 428
				vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
				vars.lastcell.lastvars[1] = x
				x = x - 1
			end
			if y > height-2 then
				repeat 
					y = y-1
				until layers[0][y][x].id == 428
				vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
				vars.lastcell.lastvars[2] = y
				y = y + 1
			elseif y < 1 then
				repeat 
					y = y+1
				until layers[0][y][x].id == 428
				vars.lastcell.lastvars = table.copy(vars.lastcell.lastvars)
				vars.lastcell.lastvars[2] = y
				y = y - 1
			end
		end
		data = GetData(x,y)
		if data.updatekey == updatekey and data.crosses >= 5 then
			return
		else
			data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
		end
		data.updatekey = updatekey
		firstloop = false
		goto loop
		::stop::
		if firstloop then goto redo
		else break end
		::loop::
	end
	return x,y,dir,vars.lastcell
end

function FindAnchored(x,y,dir,t,ut,forced)
	--[[if cells[0][0] == 428 then
		x = x < 1 and width-2 or x > width-2 and 1 or x
		y = y < 1 and height-2 or y > height-2 and 1 or y
	end]]
	--GetCell(x,y).testvar = "found"
	if not IsNonexistant(GetCell(x,y),dir,x,y) and GetCell(x,y).supdatekey ~= supdatekey and (not IsUnbreakable(GetCell(x,y),dir,x,y,{forcetype="swap",lastcell=cell}) or forced) then
		t[x+y*width] = GetCell(x,y)
		ut[x+y*width] = CopyCell(x,y)
		t[x+y*width].supdatekey = supdatekey
		t[x+y*width].testvar = "a"
		SetCell(x,y,getempty())
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			Queue("anchor",function() FindAnchored(v[1],v[2],k,t,ut) end)
		end
	end
	ExecuteQueue("anchor")
	return t,ut
end

function DoAnchor(x,y,rot) 
	local anchored,undocells = FindAnchored(x,y,0,{},{},true)
	local undo = false
	for k,v in pairs(anchored) do
		--if v.id == 447 and v ~= cell then undo = true; end
		if (cx~=x or cy~=y) and not v.locked and not v.vars.bolted and anchored[x+y*width].id ~= 462 then
			if rot == "fh" then FlipCellRaw(v,0)
			elseif rot == "fv" then FlipCellRaw(v,1)
			elseif rot == "fd0" then FlipCellRaw(v,1.5)
			elseif rot == "fd1" then FlipCellRaw(v,0.5)
			else RotateCellRaw(v,rot) end
		end
		local cx,cy = k%width-x,math.floor(k/width)-y
		local ocx,ocy = cx,cy
		if rot == "fh" then cx = -cx
		elseif rot == "fv" then cy = -cy
		elseif rot == "fd0" then cx,cy = cy,cx
		elseif rot == "fd1" then cx,cy = -cy,-cx
		elseif rot%4 == 1 then cx,cy = -cy,ocx
		elseif rot%4 == 2 then cx,cy = -cx,-cy
		elseif rot%4 == 3 then cx,cy = cy,-ocx end
		local cx,cy = cx+x,cy+y
		undocells[cx+cy*width] = undocells[cx+cy*width] or GetCell(cx,cy)
		local angle
		if rot == "fh" then angle = cx > x and 0 or 2
		elseif rot == "fv" then angle = cy > y and 1 or 3
		elseif rot == "fd0" then angle = (cy-cx > 0 and 3.5 or 1.5)
		elseif rot == "fd1" then angle = (cy+cx > 0 and 2.5 or 0.5)
		else angle = math.angleTo4(cx-x,cy-y)+rot end
		if not NudgeCellTo(v,cx,cy,angle,{lastx=ocx,last=ocy,undocells=undocells}) then undo = true; break; end
	end
	if undo then
		for k,v in pairs(undocells) do
			SetCell(k%width,math.floor(k/width),v)
		end
	end
	supdatekey = supdatekey + 1
end

function DoTransmitter(cell,x,y,func,neighborfunc,nval,queuekey,dirindex,...)
	cell.updatekey = updatekey
	local neighbors = neighborfunc(x,y,nval)
	local vars = {...}
	for k,v in pairs(neighbors) do
		vars[dirindex] = k
		Queue(queuekey, function() func(v[1],v[2],unpack(vars)) end)
	end
end

function DoWirelessTransmitter(cell,x,y,func,neighborfunc,nval,queuekey,dirindex,...)
	local vars = {...}
	vars[dirindex] = 0
	if supdatekey ~= cell.supdatekey then
		Queue(queuekey, function() supdatekey = supdatekey+1 end)
		Queue(queuekey, function() RunOn(function(c) return c.id == 583 and c.vars[1] == cell.vars[1] end,
		function(x,y,c) c.supdatekey = supdatekey; func(x,y,unpack(vars)) end,
		"rightup",
		583)() end)
		Queue(queuekey, function() updatekey = updatekey+1 end)
	end
	local neighbors = neighborfunc(x,y,nval)
	for k,v in pairs(neighbors) do
		vars[dirindex] = k
		if GetCell(v[1],v[2]).id ~= 583 or GetCell(v[1],v[2]).vars[1] ~= cell.vars[1] then
			Queue(queuekey, function() func(v[1],v[2],unpack(vars)) end)
		end
	end
	cell.updatekey = updatekey
	cell.supdatekey = supdatekey
end

function RotateCellRaw(c,rot,force)
	if not force then rot = (rot+2)%4-2 end
	c.rot = (c.rot+rot)%4
	c.lastvars[3] = c.lastvars[3]+rot
	if c.vars.gravdir and c.vars.gravdir >= 4 then c.vars.gravdir = (c.vars.gravdir+rot)%4+4 end
	if IsCellHolder(c.id) and c.vars[2] then c.vars[2] = (c.vars[2]+rot)%4 end
	if c.vars.perpetualrot then
		if c.vars.perpetualrot == 3 then
			if rot == 1 or rot == -1 then
				c.vars.perpetualrot = 4
			end
		elseif c.vars.perpetualrot == 4 then
			if rot == 1 or rot == -1 then
				c.vars.perpetualrot = 3
			end
		elseif c.vars.perpetualrot == 5 then
			if rot == 1 or rot == -1 then
				c.vars.perpetualrot = 6
			end
		elseif c.vars.perpetualrot == 6 then
			if rot == 1 or rot == -1 then
				c.vars.perpetualrot = 5
			end
		end
	end
end

function RotateCell(x,y,rot,dir,large,forced)
	local cell = GetCell(x,y)
	if not forced and IsUnbreakable(cell,dir,x,y,{forcetype="rotate"}) then return end
	local success = false
	if cell.id == 105 and updatekey ~= cell.updatekey then
		RotateCellRaw(cell,rot)
		DoTransmitter(cell,x,y,RotateCell,large and GetSurrounding or GetNeighbors,nil,"rotate",2,rot,nil,large)
		success = true
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		RotateCellRaw(cell,rot)
		DoWirelessTransmitter(cell,x,y,RotateCell,large and GetSurrounding or GetNeighbors,nil,"rotate",2,rot,nil,large)
		success = true
	elseif IsInverted(cell,dir,x,y) then
		RotateCellRaw(cell,-rot)
		success = true
	elseif cell.id == 447 or cell.id == 462 then
		if cell.id == 462 then RotateCellRaw(cell,rot) end
		QueueLast("rotate", function() if GetCell(x,y) == cell then DoAnchor(x,y,rot) end end)
		success = true
	elseif not IsNonexistant(cell,dir,x,y) then
		RotateCellRaw(cell,rot)
		success = true
	end
	if success then Play("rotate") end
	ExecuteQueue("rotate")
	return success
end

function RotateCellTo(x,y,rot,dir,large,forced)
	local cell = GetCell(x,y)
	if not forced and IsUnbreakable(cell,dir,x,y,{forcetype="redirect"}) then return end
	local success = false
	local totalrot = rot-cell.rot
	if cell.id == 105 and updatekey ~= cell.updatekey then
		RotateCellRaw(cell,totalrot)
		DoTransmitter(cell,x,y,RotateCellTo,large and GetSurrounding or GetNeighbors,nil,"redirect",2,rot,nil,large)
		success = true
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		RotateCellRaw(cell,totalrot)
		DoWirelessTransmitter(cell,x,y,RotateCellTo,large and GetSurrounding or GetNeighbors,nil,"redirect",2,rot,nil,large)
		success = true
	elseif IsInverted(cell,dir,x,y) then
		RotateCellRaw(cell,totalrot+2)
		success = true
	elseif cell.id == 447 or cell.id == 462 then
		if cell.id == 462 then RotateCellRaw(cell,totalrot) end
		QueueLast("redirect", function() if GetCell(x,y).id == cell.id then DoAnchor(x,y,(totalrot)%4) end end)
		success = true
	elseif not IsNonexistant(cell,dir,x,y) then
		RotateCellRaw(cell,totalrot)
		success = true
	end
	if success then Play("rotate") end
	ExecuteQueue("redirect")
	return success
end

flipids = {
	[9]=10,[10]=9,[18]=19,[19]=18,[26]=27,[27]=26,[64]=65,[65]=64,[66]=67,[67]=66,[81]=82,[82]=81,[84]=85,[85]=84,
	[87]=88,[88]=87,[93]=94,[94]=93,[95]=96,[96]=95,[97]=98,[98]=97,[101]=102,[102]=101,[108]=109,[109]=108,
	[110]=111,[111]=110,[150]=151,[151]=150,[169]=170,[170]=169,[173]=174,[174]=173,[183]=182,[182]=183,
	[185]=184,[184]=185,[188]=189,[189]=188,[192]=193,[193]=192,[245]=246,[246]=245,[254]=255,[255]=254,
	[258]=259,[259]=258,[260]=261,[261]=260,[264]=265,[265]=264,[306]=307,[307]=306,[323]=322,[322]=323,
	[325]=324,[324]=325,[329]=330,[330]=329,[333]=334,[334]=333,[335]=336,[336]=335,[339]=340,[340]=339,
	[344]=345,[345]=344,[369]=375,[375]=369,[370]=376,[376]=370,[371]=377,[377]=371,[372]=378,[378]=372,
	[373]=379,[379]=373,[374]=380,[380]=374,[382]=383,[383]=382,[388]=389,[389]=388,[429]=430,[430]=429,
	[431]=432,[432]=431,[438]=440,[440]=438,[439]=441,[441]=439,[850]=852,[852]=850,[851]=853,[853]=851,
	[442]=443,[443]=442,[458]=459,[459]=458,[460]=461,[461]=460,[469]=470,[470]=469,[471]=472,[472]=471,
	[473]=474,[474]=473,[475]=476,[476]=475,[482]=483,[483]=482,[486]=483,[486]=485,[489]=490,[490]=489,
	[505]=506,[506]=505,[507]=508,[508]=507,[509]=510,[510]=509,[511]=512,[512]=511,[522]=523,[523]=522,
	[585]=586,[586]=585,[608]=609,[609]=608,[612]=613,[613]=612,[625]=626,[626]=625,[627]=628,[628]=627,
	[632]=633,[633]=632,[634]=635,[635]=634,[636]=637,[637]=636,[655]=656,[656]=655,[661]=662,[662]=661,
	[749]=750,[750]=749,[751]=752,[752]=751,[753]=754,[754]=753,[755]=756,[756]=755,[757]=758,[758]=757,
	[759]=760,[760]=759,[769]=770,[770]=769,[771]=772,[772]=771,[773]=774,[774]=773,[775]=776,[776]=775,
	[777]=778,[778]=777,[779]=780,[780]=779,[786]=787,[787]=786,[892]=894,[894]=892,[893]=895,[895]=893,
	[899]=901,[901]=899,[900]=902,[902]=900,[957]=958,[958]=957,[994]=995,[995]=994,[998]=999,[999]=998,
	[1003]=1004,[1004]=1003,[1018]=1019,[1019]=1018,[1078]=1079,[1079]=1078,[1081]=1082,[1082]=1081,[1086]=1087,
	[1087]=1086,[1118]=1119,[1119]=1118,[1126]=1127,[1127]=1126,
}
flipsymmetry = {
	[6]=1,[8]=1,[2]=1,[14]=1,[17]=1,[121]=1,
	[28]=1,[52]=1,[54]=1,[58]=1,[59]=1,[60]=1,[61]=1,[71]=1,[72]=1,[73]=1,[74]=1,
	[75]=1,[76]=1,[77]=1,[78]=1,[3]=1,[26]=1,[27]=1,[110]=1,[111]=1,[40]=1,[44 ]=1,
	[55]=1,[113]=1,[45]=1,[32]=1,[33]=1,[34]=1,[35]=1,[36]=1,[37]=1,[93]=1,[94]=1,
	[83]=1,[95]=1,[96]=1,[86]=1,[48]=1,[49]=1,[97]=1,[98]=1,[99]=1,[106]=1,[100]=1,
	[101]=1,[102]=1,[42]=1,[114]=1,[115]=1,[146]=1,[147]=1,[156]=1,[157]=1,[158]=1,
	[160]=1,[161]=1,[166]=1,[167]=1,[168]=1,[169]=1,[170]=1,[171]=1,[172]=1,[173]=1,
	[174]=1,[175]=1,[177]=1,[178]=1,[179]=1,[180]=1,[181]=1,[182]=1,[183]=1,[184]=1,
	[185]=1,[186]=1,[187]=1,[188]=1,[189]=1,[190]=1,[191]=1,[192]=1,[193]=1,[194]=1,
	[195]=1,[196]=1,[197]=1,[198]=1,[199]=1,[200]=1,[201]=1,[206]=1,[208]=1,[212]=1,
	[213]=1,[227]=1,[229]=1,[230]=1,[232]=1,[237]=1,[242]=1,[243]=1,[254]=1,[255]=1,
	[256]=1,[257]=1,[258]=1,[259]=1,[260]=1,[261]=1,[262]=1,[263]=1,[264]=1,[265]=1,
	[268]=1,[269]=1,[270]=1,[271]=1,[272]=1,[273]=1,[274]=1,[275]=1,[276]=1,[277]=1,
	[278]=1,[279]=1,[280]=1,[281]=1,[282]=1,[283]=1,[284]=1,[300]=1,[301]=1,[302]=1,
	[304]=1,[305]=1,[311]=1,[318]=1,[319]=1,[320]=1,[327]=1,[328]=1,[329]=1,[330]=1,
	[331]=1,[332]=1,[333]=1,[334]=1,[335]=1,[336]=1,[337]=1,[338]=1,[339]=1,[340]=1,
	[341]=1,[342]=1,[343]=1,[344]=1,[345]=1,[735]=1,[346]=1,[352]=1,[353]=1,[354]=1,
	[355]=1,[356]=1,[357]=1,[358]=1,[359]=1,[362]=1,[365]=1,[366]=1,[367]=1,[368]=1,
	[369]=1,[371]=1,[373]=1,[375]=1,[377]=1,[379]=1,[393]=1,[394]=1,[395]=1,[396]=1,
	[397]=1,[398]=1,[399]=1,[400]=1,[405]=1,[407]=1,[409]=1,[411]=1,[412]=1,[414]=1,
	[416]=1,[423]=1,[424]=1,[433]=1,[434]=1,[448]=1,[453]=1,[454]=1,[455]=1,[458]=1,
	[459]=1,[460]=1,[461]=1,[463]=1,[496]=1,[502]=1,[505]=1,[506]=1,[507]=1,[508]=1,
	[509]=1,[510]=1,[511]=1,[512]=1,[526]=1,[529]=1,[533]=1,[553]=1,[556]=1,[558]=1,
	[561]=1,[588]=1,[589]=1,[590]=1,[591]=1,[592]=1,[593]=1,[594]=1,[595]=1,[596]=1,
	[597]=1,[598]=1,[599]=1,[600]=1,[606]=1,[607]=1,[608]=1,[609]=1,[610]=1,[611]=1,
	[612]=1,[613]=1,[615]=1,[616]=1,[617]=1,[625]=1,[626]=1,[631]=1,[634]=1,[635]=1,
	[638]=1,[639]=1,[646]=1,[648]=1,[651]=1,[652]=1,[653]=1,[665]=1,[666]=1,[667]=1,
	[672]=1,[673]=1,[674]=1,[675]=1,[676]=1,[677]=1,[678]=1,[679]=1,[701]=1,[704]=1,
	[718]=1,[719]=1,[720]=1,[722]=1,[724]=1,[726]=1,[728]=1,[730]=1,[732]=1,[737]=1,
	[740]=1,[741]=1,[744]=1,[747]=1,[749]=1,[750]=1,[751]=1,[752]=1,[753]=1,[754]=1,
	[755]=1,[756]=1,[757]=1,[758]=1,[759]=1,[760]=1,[761]=1,[762]=1,[765]=1,[767]=1,
	[786]=1,[787]=1,[789]=1,[791]=1,[792]=1,[793]=1,[794]=1,[795]=1,[796]=1,[797]=1,
	[798]=1,[799]=1,[800]=1,[801]=1,[802]=1,[803]=1,[804]=1,[805]=1,[806]=1,[807]=1,
	[814]=1,[820]=1,[821]=1,[822]=1,[823]=1,[842]=1,[844]=1,[847]=1,[856]=1,[863]=1,
	[864]=1,[865]=1,[872]=1,[873]=1,[874]=1,[884]=1,[885]=1,[886]=1,[903]=1,[904]=1,
	[905]=1,[906]=1,[912]=1,[914]=1,[874]=1,[884]=1,[986]=1,[988]=1,[991]=1,[993]=1,
	[994]=1,[995]=1,[996]=1,[997]=1,[1003]=1,[1004]=1,[1005]=1,[1006]=1,[1014]=1,
	[1016]=1,[1033]=1,[1036]=1,[1038]=1,[1041]=1,[1043]=1,[1044]=1,[1045]=1,[1046]=1,
	[1047]=1,[1077]=1,[1078]=1,[1079]=1,[1080]=1,[1081]=1,[1082]=1,[1083]=1,[1084]=1,
	[1085]=1,[1086]=1,[1087]=1,[1088]=1,[1089]=1,[1090]=1,[1101]=1,[1103]=1,[1106]=1,
	[1108]=1,[1109]=1,[1110]=1,[1111]=1,[1112]=1,[1113]=1,[1114]=1,[1115]=1,[1122]=1,
	[1124]=1,[1125]=1,[1132]=1,[1152]=1,[1160]=1,[1161]=1,[1162]=1,[1164]=1,
	
	[7]=2,[23]=2,[46]=2,[53]=2,[57]=2,[107]=2,[122]=2,[140]=2,[148]=2,[155]=2,[209]=2,
	[228]=2,[238]=2,[268]=2,[407]=2,[410]=2,[415]=2,[457]=2,[492]=2,[527]=2,[531]=2,
	[554]=2,[559]=2,[627]=2,[628]=2,[723]=2,[727]=2,[731]=2,[738]=2,[742]=2,[748]=2,
	[766]=2,[782]=2,[783]=2,[788]=2,[790]=2,[843]=2,[866]=2,[867]=2,[868]=2,[878]=2,
	[879]=2,[880]=2,[913]=2,[987]=2,[992]=2,[998]=2,[999]=2,[1001]=2,[1002]=2,[1015]=2,
	[1034]=2,[1039]=2,[1102]=2,[1106]=2,[1153]=2,
	
	[16]=3,[91]=3,[92]=3,[381]=3,[384]=3,[385]=3,[386]=3,[387]=3,[390]=3,
	[495]=3,[497]=3,[499]=3,[501]=3,[503]=3,[629]=3,[657]=3,[921]=3,[923]=3,
	
	[642]=4,
	
	[5]=5,[15]=5,[30]=5,[38]=5,[89]=5,[90]=5,[66]=5,[67]=5,[68]=5,[69]=5,[207]=5,[210]=5,
	[215]=5,[225]=5,[226]=5,[250]=5,[287]=5,[313]=5,[404]=5,[408]=5,[413]=5,[418]=5,
	[445]=5,[478]=5,[479]=5,[480]=5,[488]=5,[489]=5,[490]=5,[491]=5,[519]=5,[528]=5,
	[532]=5,[535]=5,[555]=5,[560]=5,[620]=5,[640]=5,[641]=5,[647]=5,[650]=5,[709]=5,
	[711]=5,[721]=5,[725]=5,[729]=5,[739]=5,[743]=5,[764]=5,[784]=5,[785]=5,[841]=5,
	[881]=5,[882]=5,[883]=5,[869]=5,[870]=5,[871]=5,[911]=5,[985]=5,[990]=5,[1013]=5,
	[1035]=5,[1040]=5,[1048]=5,[1100]=5,[1105]=5,[1130]=5,
	
	[31]=3,[70]=6,[315]=6,[492]=6,[494]=3,[630]=6,[657]=6,[654]=6,[655]=6,[656]=6,[702]=6,
	[703]=6,[710]=6,[712]=6,[713]=6,[714]=6,[715]=6,[920]=6,[1017]=6,[1049]=6,[1131]=6,
}
function FlipCellRaw(cell,rot)
	--convert cell id to flipped variant (i.e. clockwise to counter-clockwise)
	cell.id = flipids[cell.id] or cell.id
	--symmetric across the - axis
	local id = cell.id
	rot = rot%2
	local fs = get(flipsymmetry[id])
	if fs == 1 then
		if rot == 0 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot)-cell.rot)%4-2
			cell.rot = (-cell.rot+2)%4
		elseif rot == 1 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+2)-cell.rot)%4-2
			cell.rot = (-cell.rot)%4
		elseif rot == 1.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+3)-cell.rot)%4-2
			cell.rot = (-cell.rot+1)%4
		elseif rot == 0.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+1)-cell.rot)%4-2
			cell.rot = (-cell.rot+3)%4
		end
	--symmetric across the / axis
	elseif fs == 2 then
		if rot == 0 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+1)-cell.rot)%4-2
			cell.rot = (-cell.rot+3)%4
		elseif rot == 1 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+3)-cell.rot)%4-2
			cell.rot = (-cell.rot+1)%4
		elseif rot == 1.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot)-cell.rot)%4-2
			cell.rot = (-cell.rot+2)%4
		elseif rot == 0.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+2)-cell.rot)%4-2
			cell.rot = (-cell.rot)%4
		end
	--symmetric across the \ axis
	elseif fs == 3 then
		if rot == 0 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+3)-cell.rot)%4-2
			cell.rot = (-cell.rot+1)%4
		elseif rot == 1 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+1)-cell.rot)%4-2
			cell.rot = (-cell.rot+3)%4
		elseif rot == 1.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+2)-cell.rot)%4-2
			cell.rot = (-cell.rot)%4
		elseif rot == 0.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot)-cell.rot)%4-2
			cell.rot = (-cell.rot+2)%4
		end
	--symmetric across the | axis
	elseif fs == 4 then
		if rot == 0 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+2)-cell.rot)%4-2
			cell.rot = (-cell.rot)%4
		elseif rot == 1 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot)-cell.rot)%4-2
			cell.rot = (-cell.rot+2)%4
		elseif rot == 1.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+1)-cell.rot)%4-2
			cell.rot = (-cell.rot+3)%4
		elseif rot == 0.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+3)-cell.rot)%4-2
			cell.rot = (-cell.rot+1)%4
		end
	--symmetric across the + axises
	elseif fs == 5 then
		if rot == 1.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+3)-cell.rot)%4-2
			cell.rot = (-cell.rot+1)%4
		elseif rot == 0.5 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+1)-cell.rot)%4-2
			cell.rot = (-cell.rot+3)%4
		end
	--symmetric across the X axises
	elseif fs == 6 then
		if rot == 0 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+3)-cell.rot)%4-2
			cell.rot = (-cell.rot+1)%4
		elseif rot == 1 then
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+1)-cell.rot)%4-2
			cell.rot = (-cell.rot+3)%4
		end
	--the special bois
	elseif id == 351 then
		if rot == cell.rot%2 then
			local old = cell.vars[1]
			cell.vars[1] = cell.vars[3]
			cell.vars[3] = old
		elseif rot == (cell.rot+.5)%2 then
			local old = cell.vars[1]
			cell.vars[1] = cell.vars[4]
			cell.vars[4] = old
			old = cell.vars[2]
			cell.vars[2] = cell.vars[3]
			cell.vars[3] = old
		elseif rot == (cell.rot+1.5)%2 then
			local old = cell.vars[1]
			cell.vars[1] = cell.vars[2]
			cell.vars[2] = old
			old = cell.vars[4]
			cell.vars[4] = cell.vars[3]
			cell.vars[3] = old
		else
			local old = cell.vars[2]
			cell.vars[2] = cell.vars[4]
			cell.vars[4] = old
		end
	elseif id == 552 then
		if rot == 0 then
			local old = cell.vars[2]
			cell.vars[2] = cell.vars[4]
			cell.vars[4] = old
			old = cell.vars[17]
			cell.vars[17] = cell.vars[20]
			cell.vars[20] = old
			old = cell.vars[19]
			cell.vars[19] = cell.vars[18]
			cell.vars[18] = old
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot)-cell.rot)%4-2
			cell.rot = (-cell.rot+2)%4
		elseif rot == 1.5 then
			local old = cell.vars[4]
			cell.vars[4] = cell.vars[2]
			cell.vars[2] = old
			old = cell.vars[17]
			cell.vars[17] = cell.vars[20]
			cell.vars[20] = old
			old = cell.vars[19]
			cell.vars[19] = cell.vars[18]
			cell.vars[18] = old
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+3)-cell.rot)%4-2
			cell.rot = (-cell.rot+1)%4
		elseif rot == 0.5 then
			local old = cell.vars[2]
			cell.vars[2] = cell.vars[4]
			cell.vars[4] = old
			old = cell.vars[17]
			cell.vars[17] = cell.vars[20]
			cell.vars[20] = old
			old = cell.vars[19]
			cell.vars[19] = cell.vars[18]
			cell.vars[18] = old
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+1)-cell.rot)%4-2
			cell.rot = (-cell.rot+3)%4
		else
			local old = cell.vars[2]
			cell.vars[2] = cell.vars[4]
			cell.vars[4] = old
			old = cell.vars[17]
			cell.vars[17] = cell.vars[20]
			cell.vars[20] = old
			old = cell.vars[19]
			cell.vars[19] = cell.vars[18]
			cell.vars[18] = old
			cell.lastvars[3] = cell.lastvars[3]+((-cell.rot+2)-cell.rot)%4-2
			cell.rot = (-cell.rot)%4
		end
	elseif id == 488 then
		if cell.vars[1] == 0 then
			cell.vars[1] = 1
		elseif cell.vars[1] == 3 then
			if rot == .5 or rot == 1.5 then
				cell.vars[1] = 4
			end
		elseif cell.vars[1] == 4 then
			if rot == .5 or rot == 1.5 then
				cell.vars[1] = 3
			end
		elseif cell.vars[1] == 5 then
			if rot == 0 or rot == 1 then
				cell.vars[1] = 6
			end
		elseif cell.vars[1] == 6 then
			if rot == 0 or rot == 1 then
				cell.vars[1] = 5
			end
		elseif cell.vars[1] == 8 then
			if rot == 0 then
				cell.vars[1] = 10
			elseif rot == .5 then
				cell.vars[1] = 11
			elseif rot == 1.5 then
				cell.vars[1] = 9
			end
		elseif cell.vars[1] == 9 then
			if rot == .5 then
				cell.vars[1] = 8
			elseif rot == 1 then
				cell.vars[1] = 11
			elseif rot == 1.5 then
				cell.vars[1] = 10
			end
		elseif cell.vars[1] == 10 then
			if rot == .5 then
				cell.vars[1] = 8
			elseif rot == 1 then
				cell.vars[1] = 11
			elseif rot == 1.5 then
				cell.vars[1] = 10
			end
		end
	end
	if cell.vars.perpetualrot then
		if cell.vars.perpetualrot == 1 then
			cell.vars.perpetualrot = -1
		elseif cell.vars.perpetualrot == -1 then
			cell.vars.perpetualrot = 1
		elseif cell.vars.perpetualrot == 3 then
			if rot == .5 or rot == 1.5 then
				cell.vars.perpetualrot = 4
			end
		elseif cell.vars.perpetualrot == 4 then
			if rot == .5 or rot == 1.5 then
				cell.vars.perpetualrot = 3
			end
		elseif cell.vars.perpetualrot == 5 then
			if rot == 0 or rot == 1 then
				cell.vars.perpetualrot = 6
			end
		elseif cell.vars.perpetualrot == 6 then
			if rot == 0 or rot == 1 then
				cell.vars.perpetualrot = 5
			end
		end
	end
	if cell.vars.gravdir and cell.vars.gravdir > 4 then
		cell.vars.gravdir = (-cell.vars.gravdir+(rot*2+2))%4+4
	end
	if IsCellHolder(cell.id) and cell.vars[1] then
		local incell = GetStoredCell(cell)
		FlipCellRaw(incell,rot)
		cell.vars[1] = incell.id
		cell.vars[2] = incell.rot
	end
end

function FlipCell(x,y,rot,dir,large,forced)
	local cell = GetCell(x,y)
	if not forced and IsUnbreakable(cell,dir,x,y,{forcetype="flip"}) then return end
	local success = false
	rot = rot%2
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,FlipCell,large and GetSurrounding or GetNeighbors,nil,"flip",2,rot,nil)
		success = true
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,FlipCell,large and GetSurrounding or GetNeighbors,nil,"flip",2,rot,nil)
		success = true
	elseif cell.id == 447 or cell.id == 462 then
		QueueLast("flip", function() if GetCell(x,y).id == cell.id then DoAnchor(x,y,rot == 0 and "fh" or rot == 1.5 and "fd0" or rot == 0.5 and "fd1" or "fv") end end)
		success = true
	elseif not IsNonexistant(cell,dir,x,y) then
		FlipCellRaw(cell,rot)
		SetChunk(x,y,0,cell)
		Play("rotate")
		success = true
	end
	ExecuteQueue("flip")
	return success
end

function FreezeCell(x,y,dir,large)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) or IsUnbreakable(cell,dir,x,y,{forcetype="freeze"}) or cell.thawed then return end
	cell.updated = true
	cell.frozen = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,FreezeCell,large and GetSurrounding or GetNeighbors,nil,"effect",1,nil,large or false)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,FreezeCell,large and GetSurrounding or GetNeighbors,nil,"effect",1,nil,large or false)
	elseif IsInverted(cell,dir,x,y) then
		cell.frozen = nil
		cell.thawed = true
	end
	ExecuteQueue("effect")
end

function ThawCell(x,y,dir)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) then return end
	cell.thawed = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,ThawCell,large and GetSurrounding or GetNeighbors,nil,"effect",1)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,ThawCell,large and GetSurrounding or GetNeighbors,nil,"effect",1)
	elseif IsInverted(cell,dir,x,y) then
		cell.frozen = true
		cell.thawed = nil
	end
	ExecuteQueue("effect")
end

function ProtectCell(x,y,dir,size)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) then return end
	cell.protected = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,ProtectCell,size == -1 and GetNeighbors or size == 1 and GetArea or GetSurrounding,1,"effect",1,nil,size)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,ProtectCell,size == -1 and GetNeighbors or size == 1 and GetArea or GetSurrounding,1,"effect",1,nil,size)
	elseif IsInverted(cell,dir,x,y) then
		cell.protected = nil
	end
	ExecuteQueue("effect")
end

function ArmorCell(x,y,dir)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) then return end
	cell.vars.armored = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,ArmorCell,GetSurrounding,nil,"effect",1)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,ArmorCell,GetSurrounding,nil,"effect",1)
	elseif IsInverted(cell,dir,x,y) then
		cell.vars.armored = nil
	end
	ExecuteQueue("effect")
end

function BoltCell(x,y,dir)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) then return end
	cell.vars.bolted = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,BoltCell,GetNeighbors,nil,"effect",1)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,BoltCell,GetNeighbors,nil,"effect",1)
	elseif IsInverted(cell,dir,x,y) then
		cell.vars.bolted = nil
	end
	ExecuteQueue("effect")
end

function PetrifyCell(x,y,dir)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) then return end
	cell.vars.petrified = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,PetrifyCell,GetNeighbors,nil,"effect",1)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,PetrifyCell,GetNeighbors,nil,"effect",1)
	elseif IsInverted(cell,dir,x,y) then
		cell.vars.petrified = nil
	end
	ExecuteQueue("effect")
end

function GooCell(x,y,dir)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) or IsUnbreakable(cell,dir,x,y,{forcetype="goo"}) then return end
	cell.vars.gooey = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,GooCell,GetNeighbors,nil,"effect",1)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,GooCell,GetNeighbors,nil,"effect",1)
	elseif IsInverted(cell,dir,x,y) then
		cell.vars.gooey = nil
	end
	SetChunkId(x,y,"compel")
	ExecuteQueue("effect")
end

function PaintCell(x,y,dir,paint,blending)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) then return end
	cell.vars.paint = paint
	cell.vars.blending = blending
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,PaintCell,GetNeighbors,nil,"effect",1,nil,paint,blending)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,PaintCell,GetNeighbors,nil,"effect",1,nil,paint,blending)
	elseif IsInverted(cell,dir,x,y) then
		cell.vars.paint = nil
		cell.vars.blending = nil
	end
	ExecuteQueue("effect")
end

function DoBasicEffect(x,y,dir,var,forcetype,val)
	val = val == nil and true or val
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) or forcetype and IsUnbreakable(cell,dir,x,y,{forcetype=forcetype}) then return end
	cell[var] = true
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,DoBasicEffect,GetNeighbors,nil,"effect",1,nil,var,forcetype,val)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,DoBasicEffect,GetNeighbors,nil,"effect",1,nil,var,forcetype,val)
	elseif IsInverted(cell,dir,x,y) then
		cell[var] = nil
	end
	ExecuteQueue("effect")
end

function GravitizeCell(x,y,dir,gdir)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) or IsUnbreakable(cell,dir,x,y,{forcetype="gravitize"}) then return end
	if cell.id == 105 and updatekey ~= cell.updatekey then
		cell.vars.gravdir = gdir or nil
		DoTransmitter(cell,x,y,GravitizeCell,GetNeighbors,nil,"effect",1,nil,gdir or nil)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		cell.vars.gravdir = gdir or nil
		DoWirelessTransmitter(cell,x,y,GravitizeCell,GetNeighbors,nil,"effect",1,nil,gdir or nil)
	elseif IsInverted(cell,dir,x,y) then
		cell.vars.gravdir = (gdir+2)%4
	else
		cell.vars.gravdir = gdir or nil
	end
	SetChunkId(x,y,"gravity")
	ExecuteQueue("effect")
end

function StickCell(x,y,dir,stype)
	local cell = GetCell(x,y)
	if type(cell.sticky) == "number" and cell.sticky < stype or IsNonexistant(cell,dir,x,y) or IsUnbreakable(cell,dir,x,y,{forcetype="stick"}) then return end
	cell.sticky = stype
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,StickCell,GetNeighbors,nil,"effect",1,nil,stype)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,StickCell,GetNeighbors,nil,"effect",1,nil,stype)
	elseif IsInverted(cell,dir,x,y) then
		cell.sticky = nil
	end
	ExecuteQueue("effect")
end

function PerpetualRotateCell(x,y,dir,prot)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) or IsUnbreakable(cell,dir,x,y,{forcetype="perpetualrotate"}) then return end
	if cell.id == 105 and updatekey ~= cell.updatekey then
		cell.vars.perpetualrot = prot or nil
		DoTransmitter(cell,x,y,PerpetualRotateCell,GetNeighbors,nil,"effect",1,nil,prot)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		cell.vars.perpetualrot = prot or nil
		DoWirelessTransmitter(cell,x,y,PerpetualRotateCell,GetNeighbors,nil,"effect",1,nil,prot)
	elseif IsInverted(cell,dir,x,y) then
		if prot == 1 then prot = -1
		elseif prot == -1 then prot = 1
		elseif prot == 3 then prot = 4
		elseif prot == 4 then prot = 3
		elseif prot == 5 then prot = 6
		elseif prot == 6 then prot = 5 end
		cell.vars.perpetualrot = (-prot+1)%4-1
	else
		cell.vars.perpetualrot = prot or nil
	end
	SetChunkId(x,y,"perpetualrotate")
	ExecuteQueue("effect")
end

function CompelCell(x,y,dir,cval)
	local cell = GetCell(x,y)
	if IsNonexistant(cell,dir,x,y) or IsUnbreakable(cell,dir,x,y,{forcetype="compel"}) then return end
	cell.vars.compelled = cval
	if cell.id == 105 and updatekey ~= cell.updatekey then
		DoTransmitter(cell,x,y,CompelCell,GetNeighbors,nil,"effect",1,nil,cval)
	elseif cell.id == 583 and updatekey ~= cell.updatekey then
		DoWirelessTransmitter(cell,x,y,CompelCell,GetNeighbors,nil,"effect",1,nil,cval)
	elseif IsInverted(cell,dir,x,y) then
		if cval == 1 then cval = 2
		elseif cval == 2 then cval = 1
		end
		cell.vars.compelled = cval
	end
	SetChunkId(x,y,"compel")
	ExecuteQueue("effect")
end

function DoQuantumEnemy(cell,vars)
	RunOn(function(c) return (c.id == 299 and c.vars[1] == cell.vars[1] or c.vars.entangled == cell.vars[1]) and not c.protected and not c.vars.armored end,
	function(x,y,c)
		if vars.undocells then vars.undocells[x+y*width] = vars.undocells[x+y*width] or c end
		SetCell(x,y,getempty())
		EmitParticles("quantum",x,y)
	end,
	"rightup",
	299)
end

function ExecuteScriptCell(cell)
	local success,err = pcall(loadstring(cell.vars[1]))
	if not success then
		DEBUG(err)
	end
end

function HandleNudge(cell,dir,x,y,vars)
	local id = cell.id
	local rot = cell.rot
	local side = ToSide(rot,dir)
	local lid = vars.lastcell.id
	local lrot = vars.lastcell.rot
	if ChunkId(lid) == 1133 then
		if dir == 0 then vars.lastcell.vars[1] = math.ceil(vars.lastcell.vars[1]/100)*100 + 100 elseif dir == 2 then vars.lastcell.vars[1] = math.floor(vars.lastcell.vars[1]/100)*100 - 100
		elseif dir == 1 then vars.lastcell.vars[2] = math.ceil(vars.lastcell.vars[2]/100)*100 + 100 elseif dir == 3 then vars.lastcell.vars[2] = math.floor(vars.lastcell.vars[2]/100)*100 - 100 end
	end
	if vars.active == "replace" then
		if id == 223 then
			vars.lastcell.vars.coins = (vars.lastcell.vars.coins or 0)+1
			EmitParticles("coin",x,y,25)
			Play("coin")
		elseif id == 1180 then
			collectedkeys[cell.vars[1]] = true
			EmitParticles("greysparkle",x,y,25)
			Play("coin")
		end
	elseif vars.active == "collide" then
		if vars.undocells then vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell) end
		local dmg = math.min(GetHP(InvertLasts(cell,dir,x,y,vars)),GetHP(cell,dir,x,y,vars))
		DamageCell(vars.lastcell,dmg,(dir+2)%4,x,y,vars)
		DamageCell(cell,dmg,dir,x,y,vars)
		if IsNonexistant(cell,dir,x,y,vars) then SetCell(x,y,vars.lastcell) end
		Play("destroy")
	elseif vars.active == "destroy" then
		if ((id == 48 or id == 99) and side == 2 or (id == 784 or id == 785) and (side%2 == 0)) and cell.updatekey ~= updatekey then
			cell.updatekey = updatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,(dir-1)%4,newvars)
			if cx then
				if id == 48 or id == 784 then RotateCellRaw(lastcell,-1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,(dir+1)%4,newvars)
			if cx then
				if id == 48 or id == 784 then RotateCellRaw(lastcell,1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
		elseif (id == 49 or id == 100) and side == 2 and cell.updatekey ~= updatekey then
			cell.updatekey = updatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,dir,newvars)
			if cx then
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,(dir-1)%4,newvars)
			if cx then
				if id == 49 then RotateCellRaw(lastcell,-1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,(dir+1)%4,newvars)
			if cx then
				if id == 49 then RotateCellRaw(lastcell,1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
		elseif (id == 97 or id == 101) and side == 2 and cell.updatekey ~= updatekey then
			cell.updatekey = updatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,dir,newvars)
			if cx then
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,(dir+1)%4,newvars)
			if cx then
				if id == 97 then RotateCellRaw(lastcell,1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
		elseif (id == 98 or id == 102) and side == 2 and cell.updatekey ~= updatekey then
			cell.updatekey = updatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,dir,newvars)
			if cx then
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,(dir-1)%4,newvars)
			if cx then
				if id == 98 then RotateCellRaw(lastcell,-1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
		elseif (id == 782 or id == 783) and (side == 2 or side == 1) and cell.updatekey ~= updatekey then
			cell.updatekey = updatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,side == 2 and dir or (dir+1)%4,newvars)
			if cx then
				if side == 1 and id == 782 then RotateCellRaw(lastcell,1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
			local newvars = table.copy(vars)
			local cx,cy,cdir,lastcell = NextCell(x,y,side == 2 and (dir-1)%4 or dir,newvars)
			if cx then
				if side == 2 and id == 782 then RotateCellRaw(lastcell,-1) end
				Queue("postnudge",function() NudgeCellTo(lastcell,cx,cy,cdir,newvars) end)
			end
		elseif id == 1084 and side == 2 and cell.supdatekey ~= supdatekey then
			for i=1,cell.vars[1] do
				local newvars = table.copy(vars)
				local cx,cy,cdir,newcell = NextCell(x,y,dir,newvars)
				updatekey = updatekey + 1
				if cx then
					newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = 1,newcell,nil,true
					Queue("postnudge",function() cell.supdatekey = supdatekey; PushCell(cx,cy,cdir,newvars); if not vars.supdated then supdatekey = supdatekey + 1 end end)
				end
			end
		elseif id == 154 and lid == 153 then
			if vars.undocells then vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell) end
			cell.eatencells = {table.copy(cell),vars.lastcell}
			cell.id = 0
			EmitParticles("sparkle",x,y)
			Play("unlock")
			Play("destroy")
		elseif id == 154 and lid == 584 then
			if vars.undocells then vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell) end
			cell.eatencells = {table.copy(cell),vars.lastcell}
			SetCell(x,y,vars.lastcell)
			EmitParticles("sparkle",x,y)
			Play("unlock")
			Play("destroy")
		elseif id == 165 or (id == 175 or id == 362 or id == 704 or id == 821 or id == 822 or id == 823 or id == 831 or id == 905) and not cell.vars[1] then
			cell.updatekey = updatekey
			if cell.vars[1] then
				local cx,cy = StepForward(x,y,dir)
				if cell.supdatekey ~= supdatekey or cell.scrosses ~= 5 then
					cell.scrosses = (cell.supdatekey == supdatekey and cell.scrosses or 0) + 1
					cell.supdatekey = supdatekey
					PushCell(cx,cy,dir,{force=1,replacecell=GetStoredCell(cell,true)})
				end
				cell.vars = {}
				supdatekey = supdatekey + 1
			end
			if not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
			end
		elseif (id == 645 or id == 1150 or id == 1151 or id == 1154) and not cell.vars[1] then
			if lid ~= 0 then
				cell.vars[1] = lid
				cell.vars[2] = lrot
				cell.updated = true
			end
		elseif id == 198 and side == 2 then
			if cell.vars[1] then
				local cx,cy = StepForward(x,y,dir)
				local rc = GetStoredCell(cell,true)
				PushCell(cx,cy,dir,{force=1,replacecell=rc,undocells=vars.undocells})
			elseif not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
			end
		elseif id == 1083 and side == 2 then
			if cell.vars[1] then
				if cell.vars[4] < cell.vars[3] then
					cell.vars[4] = cell.vars[4] + 1
				else
					cell.vars[4] = 1
					local cx,cy = StepForward(x,y,dir)
					local rc = GetStoredCell(cell,true)
					PushCell(cx,cy,dir,{force=1,replacecell=rc,undocells=vars.undocells})
				end
			elseif not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
			end
		elseif id == 1043 and side == 2 then
			if cell.vars[1] then
				local cx,cy,cdir = NextCell(x,y,dir)
				local cell2 = GetCell(cx,cy)
				if not IsNonexistant(cell2,cdir,cx,cy) and not IsUnbreakable(cell2,cdir,cx,cy,{forcetype="transform",lastcell=cell}) then
					newcell = GetStoredCell(cell)
					newcell.lastvars = {cx,cy,0}
					newcell.eatencells = {cell2}
					SetCell(cx,cy,newcell)
				end
			elseif not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
			end
		elseif id == 1164 and side == 2 then
			if not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = 1
			end
		elseif id == 233 or id == 601 then
			table.safeinsert(cell,"eatencells",vars.lastcell)
			if side == 1 or side == 3 then cell.vars[1] = lid end
		elseif id == 12 or id == 225 or id == 226 or id == 300 or id == 44 or id == 155 or id == 250 or id == 251 or id == 317 or id == 344 or id == 345 or id == 672 or id == 735 or id == 814
		or id == 436 or id == 437 or id == 517 or id == 518 or id == 519 or id == 520 or id == 521 or id == 815 or id == 816 or id == 817 or id == 819 or id == 1116 then
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			Play("destroy")
		elseif id == 205 or id == 351 and cell.vars[side+1] == 6 then
			table.safeinsert(cell,"eatencells",vars.lastcell)
		elseif id == 347 or id == 349 or (id == 351 or id == 552) and (cell.vars[side+1] == 7 or cell.vars[side+1] == 8 or cell.vars[side+1] == 9 or cell.vars[side+1] == 10) or id == 438 or id == 439 or id == 440 or id == 441 or id == 463 or id == 694 or id == 695 or id == 856 then
			local cdir = (id == 347 or id == 349 or (id == 351 or id == 552) and cell.vars[side+1] == 7) and dir
			or (id == 694 or id == 695 or (id == 351 or id == 552) and cell.vars[side+1] == 8) and (dir+2)%4
			or (id == 438 or id == 439 or (id == 351 or id == 552) and cell.vars[side+1] == 9) and (dir-1)%4
			or (id == 440 or id == 441 or (id == 351 or id == 552) and cell.vars[side+1] == 10) and (dir+1)%4
			or (id == 463 or id == 856) and cell.rot
			table.safeinsert(cell,"eatencells",vars.lastcell)
			if (id == 351 or id == 552) then
				local neighbors = GetNeighbors(x,y)
				for k,v in pairs(neighbors) do
					local c = GetCell(v[1],v[2])
					if cell.vars[(k-cell.rot)%4+1] == 12 and not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
						if vars.undocells then vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2])) end
						DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
					end
				end
			end
			Queue("postnudge",function() PushCell(x,y,cdir,{force=1,skipfirst=true}) end)
			if id ~= 349 and id ~= 439 and id ~= 441 and id ~= 856 then Play("destroy") end
		elseif id == 563 then
			table.safeinsert(cell,"eatencells",vars.lastcell)
			if not vars.checkonly then
				switches[cell.vars[1]] = not switches[cell.vars[1]] and true or nil
				cell.vars[2] = switches[cell.vars[1]]
				Play("destroy")
			end
		elseif id == 51 or id == 670 or id == 848 or id == 850 or id == 852 or id == 854 or id == 857 then
			local cdir = id == 848 and dir or id == 850 and (dir-1)%4 or id == 852 and (dir+1)%4 or id == 854 and (dir+2)%4 or id == 857 and cell.rot or nil
			local neighbors = GetNeighbors(x,y)
			for k,v in pairs(neighbors) do
				local c = GetCell(v[1],v[2])
				if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
					DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if cdir then Queue("postnudge",function() PushCell(x,y,cdir,{force=1,skipfirst=true}) end) end
			if id ~= 670 then Play("destroy") end
		elseif id == 141 or id == 671 or id == 849 or id == 851 or id == 853 or id == 855 or id == 858 then
			local cdir = id == 849 and dir or id == 851 and (dir-1)%4 or id == 853 and (dir+1)%4 or id == 855 and (dir+2)%4 or id == 858 and cell.rot or nil
			local neighbors = GetSurrounding(x,y)
			for k,v in pairs(neighbors) do
				local c = GetCell(v[1],v[2])
				if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
					DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if cdir then Queue("postnudge",function() PushCell(x,y,cdir,{force=1,skipfirst=true}) end) end
			if id ~= 671 then Play("destroy") end
		elseif (id == 351 or id == 552) and (cell.vars[side+1] == 5 or cell.vars[side+1] == 6 or cell.vars[side+1] == 12) then
			local neighbors = GetNeighbors(x,y)
			if id == 351 or id == 552 then
				for k,v in pairs(neighbors) do
					local c = GetCell(v[1],v[2])
					if cell.vars[(k-cell.rot)%4+1] == 12 and not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
						if vars.undocells then vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2])) end
						DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
					end
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if cell.vars[side+1] ~= 8 then Play("destroy") end
		elseif id == 176 then
			if not IsUnbreakable(GetCell(vars.lastx,vars.lasty),(vars.lastdir+2)%4,vars.lastx,vars.lasty,{forcetype="infect",lastcell=cell}) then
				SetCell(vars.lastx,vars.lasty,table.copy(cell))
				Play("destroy")
				Play("infect")
				if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			end
		elseif id == 890 or id == 891 or id == 892 or id == 893 or id == 894 or id == 895 then
			if id == 890 or id == 892 or id == 894 then Play("destroy") end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			local cdir = (id == 892 or id == 893) and (dir+1)%4 or (id == 894 or id == 895) and (dir-1)%4 or dir 
			local cx,cy = StepForward(x,y,cdir)
			Queue("postnudge",function() PushCell(cx,cy,cdir,{force=1}) end)
		elseif id == 897 or id == 898 or id == 899 or id == 900 or id == 901 or id == 902 then
			Play("destroy")
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			local cdir = (id == 899 or id == 900) and (dir+1)%4 or (id == 901 or id == 902) and (dir-1)%4 or dir 
			local cx,cy = StepForward(x,y,cdir)
			Queue("postnudge",function()
				PushCell(cx,cy,cdir,{force=1})
				local neighbors = ((id == 898 or id == 900 or id == 902) and GetSurrounding or GetNeighbors)(x,y)
				for k,v in pairs(neighbors) do
					local c = GetCell(v[1],v[2])
					if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
						vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
						DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
					end
				end
			end)
		elseif id == 908 or id == 909 then
			Play("destroy")
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			cell.vars[2] = not cell.vars[2] and true or nil
		elseif id == 32 or id == 33 or id == 34 or id == 35 or id == 36 or id == 37 or id == 194 or id == 195 or id == 196 or id == 197 then
			if side == 3 then
				cell.inl = true
				if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			elseif side == 1 then
				cell.inr = true
				if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			end
		elseif id == 186 or id == 187 or id == 188 or id == 189 or id == 190 or id == 191 or id == 192 or id == 193 then
			if not cell.output then
				cell.output = vars.lastcell
				if side == 1 and id < 190 then RotateCellRaw(cell.output,1)
				elseif side == 3 and id < 190 then RotateCellRaw(cell.output,-1) end
			end
		elseif id == 1200 then
			if not vars.checkonly then
				scriptx,scripty=x,y
				ExecuteScriptCell(cell)
			end
		end
	else
		if (lid == 178 or lid == 179 or lid == 180 or lid == 181
		or lid == 182 or lid == 183 or lid == 184 or lid == 185) and lrot == dir and not IsUnbreakable(cell,dir,x,y,{forcetype="scissor",lastcell=vars.lastcell}) and not IsNonexistant(cell,dir,x,y,vars) then
			SetCell(vars.lastx,vars.lasty,getempty())
			SetCell(x,y,vars.lastcell)
			if vars.lastcell.supdatekey ~= supdatekey then
				vars.lastcell.supdatekey = supdatekey
				local cx,cy,cdir = x,y,dir
				if lid ~= 178 and lid ~= 180 then
					cx,cy = StepBack(cx,cy,cdir)
					PushCell(cx,cy,cdir,{force=1,replacecell=table.copy(cell)})
				end
				cx,cy,cdir = x,y,dir
				if lid ~= 183 and lid ~= 185 then
					cdir = (cdir - 1)%4
					if lid == 178 or lid == 179 or lid == 182 then RotateCellRaw(cell,1) end
					cx,cy = StepForward(cx,cy,cdir)
					PushCell(cx,cy,cdir,{force=1,replacecell=table.copy(cell)})
					if lid == 178 or lid == 179 or lid  == 182 then RotateCellRaw(cell,-1) end
				end
				cx,cy,cdir = x,y,dir
				if lid ~= 182 and lid ~= 184 then
					cdir = (cdir + 1)%4
					if lid == 178 or lid == 179 or lid == 183 then RotateCellRaw(cell,-1) end
					cx,cy = StepForward(cx,cy,cdir)
					PushCell(cx,cy,cdir,{force=1,replacecell=table.copy(cell)})
				end
				supdatekey = supdatekey + 1
			end
		elseif id == 126 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="infect",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				vars.undocells[vars.lastx+vars.lasty*width] = CopyCell(x,y)
			else
				SetCell(vars.lastx,vars.lasty,CopyCell(x,y))
			end
			Play("infect")
		elseif id == 150 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],1)
			else
				RotateCellRaw(vars.lastcell,1)
			end
			Play("rotate")
		elseif id == 151 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],-1)
			else
				RotateCellRaw(vars.lastcell,-1)
			end
			Play("rotate")
		elseif id == 152 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],2)
			else
				RotateCellRaw(vars.lastcell,2)
			end
			Play("rotate")
		elseif id == 965 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],math.randomsign())
			else
				RotateCellRaw(vars.lastcell,math.randomsign())
			end
			Play("rotate")
		elseif id == 709 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				FlipCellRaw(vars.undocells[vars.lastx+vars.lasty*width],rot)
			else
				FlipCellRaw(vars.lastcell,rot)
			end
			Play("rotate")
		elseif id == 710 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				FlipCellRaw(vars.undocells[vars.lastx+vars.lasty*width],rot-.5)
			else
				FlipCellRaw(vars.lastcell,rot-.5)
			end
			Play("rotate")
		elseif id == 1046 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells and vars.undocells[vars.lastx+vars.lasty*width] ~= vars.lastcell then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],rot-vars.undocells[vars.lastx+vars.lasty*width].rot)
			else
				RotateCellRaw(vars.lastcell,rot-lrot)
			end
			Play("rotate")
		elseif id == 162 then
			SetCell(x,y,getempty())
			if vars.undocells then
				vars.undocells[x+y*width] = getempty()
			end
			EmitParticles("staller",x,y)
			Play("destroy")
		elseif id == 163 and not cell.protected and not cell.vars.armored and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="destroy",lastcell=cell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			DamageCell(vars.lastcell,1,(dir+2)%4,x,y,vars)
			SetCell(x,y,getempty())
			if vars.undocells then
				vars.undocells[x+y*width] = getempty()
				if vars.undocells[vars.lastx+vars.lasty*width] then vars.undocells[vars.lastx+vars.lasty*width] = table.copy(vars.lastcell) end
			end
			EmitParticles("bulk",x,y)
			Play("destroy")
		elseif id == 1181 and collectedkeys[cell.vars[1]] then
			SetCell(x,y,getempty())
			if vars.undocells then
				vars.undocells[x+y*width] = getempty()
			end
			EmitParticles("greysparkle",x,y)
			Play("unlock")
			Play("destroy")
		elseif id == 733 or id == 734 or id == 861 or id == 862 then
			SetCell(vars.lastx,vars.lasty,getempty())
			if id == 861 or id == 862 then
				local neighbors = (id == 861 and GetNeighbors or GetSurrounding)(x,y)
				for k,v in pairs(neighbors) do
					local c = GetCell(v[1],v[2])
					if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
						DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
					end
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if id ~= 734 then Play("destroy") end
		elseif id == 229 and side == 2 then
			local cx,cy = StepForward(x,y,dir)
			local gen = table.copy(vars.lastcell)
			gen.lastvars = {x,y,0}
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				PushCell(cx,cy,dir,{replacecell=gen,force=1,noupdate=true})
			end
		elseif id == 1088 and side == 2 then
			local cx,cy = StepForward(x,y,dir)
			if cell.vars[1] then
				PushCell(cx,cy,dir,{replacecell=GetStoredCell(cell),force=1,noupdate=true})
			end
		elseif (id == 327 or id == 331 or id == 332 or id == 333 or id == 334 or id == 337 or id == 338 or id == 339 or id == 340) and side == 2 or id == 328 and (side == 2 or side == 1) then
			local gen = table.copy(vars.lastcell)
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				if id ~= 331 and id ~= 337 then
					gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
					local cx,cy = StepForward(x,y,dir)
					PushCell(cx,cy,dir,{replacecell=table.copy(gen),force=1,noupdate=true})
				end
				if id < 335 then gen.rot = (gen.rot-1)%4 end
				if id ~= 327 and id ~= 333 and id ~= 339 and id ~= 328 then
					gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
					local cx,cy = StepLeft(x,y,dir)
					PushCell(cx,cy,(dir-1)%4,{replacecell=table.copy(gen),force=1,noupdate=true,repeats=0})
				end
				if id < 335 then gen.rot = (gen.rot+2)%4 end
				if id ~= 327 and id ~= 334 and id ~= 340 and id ~= 328 then
					gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
					local cx,cy = StepRight(x,y,dir)
					PushCell(cx,cy,(dir+1)%4,{replacecell=table.copy(gen),force=1,noupdate=true})
				end
			end
			vars.optimizegen = false
		elseif (id == 329 or id == 335) and side == 1 then
			local cx,cy = StepRight(x,y,dir)
			local gen = table.copy(vars.lastcell)
			if id == 329 then gen.rot = (gen.rot+1)%4 end 
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
				PushCell(cx,cy,(dir+1)%4,{replacecell=gen,force=1,noupdate=true})
			end
		elseif (id == 330 or id == 336) and side == 3 then
			local cx,cy = StepLeft(x,y,dir)
			local gen = table.copy(vars.lastcell)
			if id == 330 then gen.rot = (gen.rot-1)%4 end 
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
				PushCell(cx,cy,(dir-1)%4,{replacecell=gen,force=1,noupdate=true})
			end
		elseif id == 464 then
			Queue("postnudge",function() PullCell(x,y,dir,{force = 1}) end)
		elseif id == 466 then
			Queue("postnudge",function() PushCell(vars.lastx,vars.lasty,vars.lastdir,{force = 1}) end)
		elseif id == 477 then
			Queue("postnudge",function() if GrabCell(x,y,dir,{force = 1}) then NudgeCell(vars.lastx,vars.lasty,vars.lastdir) end end)
		end
	end
end

function HandlePush(force,cell,dir,x,y,vars)
	local id = cell.id
	local rot = cell.rot
	local side = ToSide(rot,dir)
	local lid = vars.lastcell.id
	local lrot = vars.lastcell.rot
	force = force + (cell.vars.gravdir and (cell.vars.gravdir%4 == dir and 1 or cell.vars.gravdir%4 == (dir+2)%4 and -1 or 0) or 0)
	if not vars.skipfirst or vars.repeats > 0 then
		vars.lastcell = vars.lastcell or getempty()
		vars.lastx,vars.lasty = vars.lastx or x,vars.lasty or y
		vars.firstx,vars.firsty = vars.firstx or vars.lastx,vars.firsty or vars.lasty
		if not vars.layer then
			local above = GetCell(x,y,1)
			local aboveside = ToSide(above.rot,dir)
			if ((above.id == 553) and (aboveside > 3 or aboveside < 1) or above.id == 554 and (aboveside > 2 or aboveside < 1)
			or above.id == 555 and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3) or above.id == 556 and aboveside ~= 2 or above.id == 557) and vars.repeats > 0
			or above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 916 then
				vars.destroying = false
				return 0
			elseif ((above.id == 558) and (aboveside > 3 or aboveside < 1) or above.id == 559 and (aboveside > 2 or aboveside < 1)
			or above.id == 560 and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3) or above.id == 561 and aboveside ~= 2 or above.id == 562) and vars.repeats > 0 then
				vars.destroying = true
				if fancy then table.safeinsert(above,"eatencells",vars.lastcell) end
				Play("destroy")
				return force
			elseif above.id == 566 and above.vars[2] == 0 then
				above.vars[2] = above.vars[1]+1
				EmitParticles("staller",x,y)
				return 0
			elseif above.id == 706 then
				if lid == 705 then
					above.id = 707
					vars.destroying = true
					vars.ended = true
					EmitParticles("quantum",x,y)
					Play("unlock")
					return force
				else
					vars.destroying = false
					return 0
				end
			elseif above.id == 707 and lid == 705 then
				above.id = 706
				vars.destroying = true
				vars.ended = true
				Play("unlock")
				EmitParticles("quantum",x,y)
				return force
			end
		end
		if lid == 1126 then
			if not IsUnbreakable(cell,dir,x,y,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
				RotateCellRaw(cell,1)
			end
		elseif lid == 1127 then
			if not IsUnbreakable(cell,dir,x,y,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
				RotateCellRaw(cell,-1)
			end
		elseif lid == 1128 then
			if not IsUnbreakable(cell,dir,x,y,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
				RotateCellRaw(cell,-2)
			end
		elseif lid == 1129 then
			if not IsUnbreakable(cell,dir,x,y,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
				RotateCellRaw(cell,math.randomsign())
			end
		elseif lid == 1130 then
			if not IsUnbreakable(cell,dir,x,y,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
				FlipCellRaw(cell,lrot)
			end
		elseif lid == 1131 then
			if not IsUnbreakable(cell,dir,x,y,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
				FlipCellRaw(cell,lrot-.5)
			end
		elseif lid == 1132 then
			if not IsUnbreakable(cell,dir,x,y,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
				RotateCellRaw(cell,lrot-rot)
			end
		end
		id = cell.id
		rot = cell.rot
		side = ToSide(rot,dir)
		if vars.destroying == "collide" then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			local dmg = math.min(GetHP(InvertLasts(cell,dir,x,y,vars)),GetHP(cell,dir,x,y,vars))
			DamageCell(vars.lastcell,dmg,(dir+2)%4,x,y,vars)
			DamageCell(cell,dmg,dir,x,y,vars)
			if IsNonexistant(cell,dir,x,y,vars) then SetCell(x,y,vars.lastcell) end
			vars.ended = true
			Play("destroy")
		elseif ((id == 48 or id == 99) and side == 2 or (id == 784 or id == 785) and side%2 == 0) and cell.supdatekey ~= supdatekey then
			cell.supdatekey = supdatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,(dir-1)%4,newvars)
			if id == 48 or id == 784 then RotateCellRaw(newcell,-1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) if not vars.supdated then supdatekey = supdatekey + 1 end end)
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,(dir+1)%4,newvars)
			if id == 48 or id == 784 then RotateCellRaw(newcell,1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) end)
		elseif (id == 49 or id == 100) and side == 2 and cell.supdatekey ~= supdatekey then
			cell.supdatekey = supdatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,(dir-1)%4,newvars)
			if id == 49 then RotateCellRaw(newcell,-1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) if not vars.supdated then supdatekey = supdatekey + 1 end end)
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,(dir+1)%4,newvars)
			if id == 49 then RotateCellRaw(newcell,1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) end)
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,dir,newvars)
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) end)
		elseif (id == 97 or id == 101) and side == 2 and cell.supdatekey ~= supdatekey then
			cell.supdatekey = supdatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,(dir+1)%4,newvars)
			if id == 97 then RotateCellRaw(newcell,1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) if not vars.supdated then supdatekey = supdatekey + 1 end end)
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,dir,newvars)
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) end)
		elseif (id == 98 or id == 102) and side == 2 and cell.supdatekey ~= supdatekey then
			cell.supdatekey = supdatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,(dir-1)%4,newvars)
			if id == 98 then RotateCellRaw(newcell,-1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) if not vars.supdated then supdatekey = supdatekey + 1 end end)
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,dir,newvars)
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) end)
		elseif (id == 782 or id == 783) and (side == 2 or side == 1) and cell.supdatekey ~= supdatekey then
			cell.supdatekey = supdatekey
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,side == 2 and (dir-1)%4 or dir,newvars)
			if id == 782 and side == 2 then RotateCellRaw(newcell,-1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) if not vars.supdated then supdatekey = supdatekey + 1 end end)
			local newvars = table.copy(vars)
			local cx,cy,cdir,newcell = NextCell(x,y,side == 2 and dir or (dir+1)%4,newvars)
			if id == 782 and side == 1 then RotateCellRaw(newcell,1) end
			newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
			Queue("postpush",function() PushCell(cx,cy,cdir,newvars) end)
		elseif id == 1084 and side == 2 and cell.supdatekey ~= supdatekey then
			for i=1,cell.vars[1] do
				local newvars = table.copy(vars)
				local cx,cy,cdir,newcell = NextCell(x,y,dir,newvars)
				updatekey = updatekey + 1
				if cx then
					newvars.force,newvars.replacecell,newvars.undocells,newvars.supdated = force,newcell,nil,true
					Queue("postpush",function() cell.supdatekey = supdatekey; PushCell(cx,cy,cdir,newvars); if not vars.supdated then supdatekey = supdatekey + 1 end end)
				end
			end
		elseif (lid == 716 or lid == 717 or lid == 864 or lid == 865) and not IsUnbreakable(cell,x,y,dir,{forcetype="destroy",lastcell=vars.lastcell}) then
			local v = table.copy(vars)
			v.force = force
			v.undocells = nil
			v.replacecell = nil
			v.repeats = 0
			vars.ended = true
			vars.destroying = not PushCell(x,y,dir,v)
			if vars.destroying then
				vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
				local dmg = math.min(GetHP(InvertLasts(cell,dir,x,y,vars)),GetHP(cell,dir,x,y,vars))
				DamageCell(vars.lastcell,dmg,(dir+2)%4,x,y,vars)
				DamageCell(cell,dmg,dir,x,y,vars)
				if IsNonexistant(cell,dir,x,y,vars) then SetCell(x,y,vars.lastcell) end
				Play("destroy")
			else
				SetCell(x,y,vars.lastcell)
			end
		elseif (lid == 178 or lid == 179 or lid == 180 or lid == 181
		or lid == 182 or lid == 183 or lid == 184 or lid == 185) and lrot == dir and not IsUnbreakable(cell,dir,x,y,{forcetype="scissor",lastcell=vars.lastcell}) and not IsNonexistant(cell,dir,x,y,vars) then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			SetCell(x,y,vars.lastcell)
			if vars.lastcell.supdatekey ~= supdatekey then
				vars.lastcell.supdatekey = supdatekey
				local cx,cy,cdir = x,y,(dir+2)%4
				if lid ~= 178 and lid ~= 180 then
					cx,cy = StepForward(cx,cy,cdir)
					Queue("postpush",function() PushCell(cx,cy,cdir,{force=1,replacecell=cell}) end)
				end
				local cx,cy,cdir = x,y,(dir+3)%4
				local cell2 = table.copy(cell)
				if lid ~= 183 and lid ~= 185 then
					if lid == 178 or lid == 179 or lid == 182 then RotateCellRaw(cell2,1) end
					cx,cy = StepForward(cx,cy,cdir)
					Queue("postpush",function() PushCell(cx,cy,cdir,{force=1,replacecell=cell2}) if lid == 182 or lid == 184 then supdatekey = supdatekey + 1 end end)
				end
				local cx,cy,cdir = x,y,(dir+1)%4
				local cell2 = table.copy(cell)
				if lid ~= 182 and lid ~= 184 then
					if lid == 178 or lid == 179 or lid == 183 then RotateCellRaw(cell2,-1) end
					cx,cy = StepForward(cx,cy,cdir)
					Queue("postpush",function() PushCell(cx,cy,cdir,{force=1,replacecell=cell2}) supdatekey = supdatekey + 1 end)
				end
				vars.ended = true
			end
		elseif id == 402 and lid == 402 and rot%2 == lrot%2 and rot%2 == dir%2 and not vars.sprung then
			local lastx,lasty = vars.lastx,vars.lasty
			local vars2 = table.copy(vars)
			vars2.undocells = nil
			Queue("postpush",function()
				if vars.stopped then
					SetCell(lastx,lasty,getempty())
					GetCell(x,y).vars[1] = (GetCell(x,y).vars[1] or 0) + (vars2.lastcell.vars[1] or 0) + 1
					PushCell(vars.firstx,vars.firsty,vars.firstdir,vars2)
				end
			end)
			vars.sprung = true
			vars.optimizegen = false
		elseif cell.pushclamped or cell.vars.pushpermaclamped or id == 696 or cell.vars.petrified then
			return 0
		elseif id == 42 and side == 0 or id == 22 or (id == 351 or id == 552) and cell.vars[side+1] == 14 then
			force = force-1
		elseif id == 42 and side == 2 or id == 104 or (id == 351 or id == 552) and cell.vars[side+1] == 15 then
			force = force+1
		elseif id == 1182 or id == 1183 or id == 1184 and side%2 == 0 then
			if vars.iforce then
				vars.iforce = id == 1182 and vars.iforce-1 or id == 1183 and vars.iforce+1 or id == 1184 and vars.iforce+side-1 
			else
				vars.iforce = id == 1182 and -1 or id == 1183 and 1 or id == 1184 and side-1
				Queue("postpush",function()
					if vars.iforce < 0 then
						for k,v in pairs(vars.undocells) do
							SetCell(k%width,math.floor(k/width),v)
						end
						vars.forcefalse = true
					end
				end)
			end
		elseif ChunkId(cell.id) == 1133 then
			if vars.particlepush and ChunkId(vars.startcell.id) == 1133 then
				if masses[cell.id] == masses[vars.startcell.id] then
					cell.vars[1] = math.round(math.lerp(cell.vars[1],vars.startcell.vars[1],.5))
					vars.startcell.vars[1] = cell.vars[1] 
					cell.vars[2] = math.round(math.lerp(cell.vars[2],vars.startcell.vars[2],.5))
					vars.startcell.vars[2] = cell.vars[2] 
					cell.updated = true
					return 0
				elseif masses[cell.id] > masses[vars.startcell.id] then
					return 0
				end
			elseif not cell.updated then
				force = masses[cell.id] == math.huge and 0 or force-masses[cell.id]
				if force > 0 and dir%1 == 0 then
					local oldcell = table.copy(cell)
					local add = dir == 0 and cell.vars[1]/100 or dir == 2 and -cell.vars[1]/100 or dir == 1 and cell.vars[2]/100 or dir == 3 and -cell.vars[2]/100
					if dir == 0 then cell.vars[1] = math.ceil(cell.vars[1]/100)*100 + 100 elseif dir == 2 then cell.vars[1] = math.floor(cell.vars[1]/100)*100 - 100
					elseif dir == 1 then cell.vars[2] = math.ceil(cell.vars[2]/100)*100 + 100 elseif dir == 3 then cell.vars[2] = math.floor(cell.vars[2]/100)*100 - 100 end
					if add > 0 then vars.undocells[x+y*width] = vars.undocells[x+y*width] or oldcell end
					force = force + add
				end
			end
		elseif id == 142 or id == 639 and side == 0 then
			force = force == 1 and 1 or 0
		elseif id == 143 then
			force = force == rot+1 and rot+1 or 0
		elseif id == 1194 then
			force = force == math.huge and math.huge or 0
		elseif id == 1191 then
			force = force ~= 1 and force or 0
		elseif id == 1195 then
			force = force ~= rot+1 and force or 0
		elseif id == 1192 then
			force = force ~= math.huge and force or 0
		elseif id == 1193 then
			force = force ~= cell.vars[1]/cell.vars[2] and force or 0
		elseif id == 1185 then
			Queue("postpush",function()
				if vars.iforce and vars.iforce ~= 0 then
					for k,v in pairs(vars.undocells) do
						SetCell(k%width,math.floor(k/width),v)
					end
					vars.forcefalse = true
				end
			end)
		elseif id == 1196 then
			Queue("postpush",function()
				if not vars.iforce or vars.iforce == 0 then
					for k,v in pairs(vars.undocells) do
						SetCell(k%width,math.floor(k/width),v)
					end
					vars.forcefalse = true
				end
			end)
		elseif id == 1187 or id == 1188 then
			if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
			if cell.vars[1] <= (id == 1188 and cell.vars[2] or force) then
				if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
				cell.updated = true
				return 0
			end
			cell.updated = true
		elseif id == 1189 or id == 1190 then
			if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
			if cell.vars[1] > (id == 1190 and cell.vars[2] or force) then
				cell.updated = true
				return 0
			else
				if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
				cell.updated = true
			end
		elseif id == 1197 or id == 1198 then
			cell.vars[1] = cell.vars[1] + 1
			if cell.vars[1] >= (id == 1198 and cell.vars[2] or force) then
				cell.vars[1] = 0
			else
				return 0
			end
		elseif id == 144 or id == 631 and side == 0 then
			force = math.min(force,1)
		elseif id == 668 then
			force = force-(cell.vars[1]/cell.vars[2])
		elseif id == 669 then
			force = force == cell.vars[1]/cell.vars[2] and force or 0
		elseif id == 638 then
			if side == 0 then
				return 0
			else
				RotateCellRaw(cell,side)
			end
		elseif (id == 2 or id == 213 and (side == 0 or side == 2)) and not cell.frozen then
			if side == 2 then
				cell.updated = cell.updated or not vars.noupdate
				force = force+1
			elseif side == 0 then
				force = force-1
			end
		elseif (id == 28 or id == 72 or id == 74 or id == 59 or id == 60 or id == 76 or id == 78
		or id == 269 or id == 271 or id == 273 or id == 275 or id == 277 or id == 279 or id == 281 or id == 283
		or id == 206 or id == 303 or id == 304 or id == 311 or id == 400 or id == 423 or id == 700 or id == 718
		or id == 720 or id == 781 or id == 863 or id == 864 or id == 865 or id == 904 or id == 1160 and side == 2
		or (id == 905) and cell.updatekey ~= updatekey and cell.vars[1]) and not cell.frozen then
			if side == 2 then
				vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)	--dont update if movement fails
				cell.updated = cell.updated or not vars.noupdate
				force = force+1
			elseif side == 0 then
				force = force-1
			end
		elseif (id == 14 or id == 58 or id == 61 or id == 71 or id == 73 or id == 75 or id == 77 or id == 114
		or id == 115 or id == 270 or id == 272 or id == 274 or id == 276 or id == 278 or id == 280 or id == 282
		or id == 160 or id == 161 or (id == 175 or id == 362 or id == 704 or id == 821 or id == 822 or id == 823) and cell.updatekey ~= updatekey and cell.vars[1]
		or id == 178 or id == 179 or id == 180 or id == 181 or id == 182 or id == 183 or id == 184 or id == 185
		or id == 305 or id == 358 or id == 359 or id == 367 or id == 368 or id == 424 or id == 589 or id == 590
		or id == 591 or id == 592 or id == 597 or id == 598 or id == 599 or id == 600 or id == 719 or id == 786
		or id == 787 or id == 792 or id == 793 or id == 794 or id == 795 or id == 800 or id == 801 or id == 802
		or id == 803 or id == 319 or id == 454 or id == 456 or id == 820 or id == 903 or id == 906 or id == 1086
		or id == 1087 or id == 1162) and not IsTransparent(cell,dir,x,y,vars) then
			if side == 2 then
				vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
				cell.updated = cell.updated or not vars.noupdate
			end
		elseif id == 352 and (cell.updatedforce or cell.vars[2]-1 == cell.vars[3]) and not cell.frozen then
			if side == 2 then
				if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
				force = force+(cell.updatedforce or cell.vars[1])
			elseif side == 0 then
				force = force-(cell.updatedforce or cell.vars[1])
			end
		elseif id == 353 or id == 354 or id == 355 or id == 356 or id == 357 then
			if side == 2 then
				vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
				if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
			end
		elseif id == 346 then
			if side == 2 then
				vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
				if not cell.updated and not vars.noupdate then
					cell.updated = true
					if cell.rot%2 == 0 then
						PushCell(x,y-1,3,{force=1})
						PushCell(x,y+1,1,{force=1})
					else
						PushCell(x+1,y,0,{force=1})
						PushCell(x-1,y,2,{force=1})
					end
				end
				force = force+1
			elseif side == 0 then
				force = force-1
			else
				force = force <= 1 and 0 or force
			end
		elseif (id == 284 or id == 1161 and side == 2) and not cell.frozen then
			if side == 2 then
				force = math.huge
			elseif side == 0 then
				return 0
			end
		elseif id == 103 then
			force = force-rot
		elseif (id == 21 or id == 763 or id == 1175 or id == 222 or (id == 408 or id == 764 or id == 1175 or id == 1100) and side%2 == 0 or (id == 411 or id == 767 or id == 1178 or id == 1103) and side%2 == 1) and not cell.frozen then
			force = force <= 1 and 0 or force
		elseif ((id == 409 or id == 765 or id == 1176 or id == 1101) and side == 2 or (id == 410 or id == 766 or id == 1177 or id == 1102) and (side == 1 or side == 2) or (id == 411 or id == 767 or id == 1178 or id == 1103) and side == 2) and not cell.frozen then
			force = force+1
		elseif ((id == 409 or id == 765 or id == 1176 or id == 1101) and side == 0 or (id == 410 or id == 766 or id == 1177 or id == 1102) and (side == 0 or side == 3) or (id == 411 or id == 767 or id == 1178 or id == 1103) and side == 0) and not cell.frozen then
			force = force-1
		elseif (id == 417 or id == 418 and side%2 == 0 or id == 421 and side%2 == 1) and not cell.frozen then
			force = force <= 2 and 0 or force
		elseif (id == 419 and side == 2 or id == 420 and (side == 1 or side == 2) or id == 421 and side == 2) and not cell.frozen then
			force = force+2
		elseif (id == 419 and side == 0 or id == 420 and (side == 0 or side == 3) or id == 421 and side == 0) and not cell.frozen then
			force = force-2
		elseif id == 163 and not cell.protected and not cell.vars.armored and not IsUnbreakable(vars.lastcell,(dir-2)%4,x,y,{forcetype="destroy",lastcell=cell,lastx=vars.lastx,lasty=vars.lasty})  and not IsNonexistant(vars.lastcell,x,y,(dir+2)) then
			vars.undocells[x+y*width] = getempty()
			DamageCell(vars.lastcell,1,(dir+2)%4,x,y,vars)
			if vars.undocells[vars.lastx+vars.lasty*width] then vars.undocells[vars.lastx+vars.lasty*width] = table.copy(vars.lastcell) end
			EmitParticles("bulk",x,y)
			Play("destroy")
			vars.optimizegen = false
			return 0
		elseif (id == 733 or id == 734 or id == 861 or id == 862) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if vars.undocells[vars.lastx+vars.lasty*width] then vars.undocells[vars.lastx+vars.lasty*width] = getempty() end
			if id == 861 or id == 862 then
				local neighbors = (861 and GetNeighbors or GetSurrounding)(x,y)
				for k,v in pairs(neighbors) do
					local c = GetCell(v[1],v[2])
					if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
						DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
					end
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if id ~= 734 then Play("destroy") end
			vars.optimizegen = false
			return 0
		elseif id == 165 or (id == 175 or id == 362 or id == 704 or id == 821 or id == 822 or id == 823 or id == 831 or id == 905) and not cell.vars[1] then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			if cell.vars[1] then
				local cx,cy = StepForward(x,y,dir)
				if cell.supdatekey ~= supdatekey or cell.scrosses ~= 5 then
					cell.scrosses = (cell.supdatekey == supdatekey and cell.scrosses or 0) + 1
					cell.supdatekey = supdatekey
					PushCell(cx,cy,dir,{force=1,replacecell=GetStoredCell(cell,true),undocells=vars.undocells})
				end
				cell.vars = {}
				supdatekey = supdatekey + 1
			end
			if not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
				vars.ended = true
			end
		elseif (id == 645 or id == 1150 or id == 1151 or id == 1154) and not cell.vars[1] then
			if lid ~= 0 then
				cell.vars[1] = lid
				cell.vars[2] = lrot
				cell.updated = true
			end
			vars.ended = true
		elseif id == 198 and side == 2 then
			if cell.vars[1] then
				local cx,cy = StepForward(x,y,dir)
				local rc = GetStoredCell(cell,true)
				PushCell(cx,cy,dir,{force=1,replacecell=rc,undocells=vars.undocells})
			elseif not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
			end
		elseif id == 1083 and side == 2 then
			if cell.vars[1] then
				if cell.vars[4] < cell.vars[3] then
					cell.vars[4] = cell.vars[4] + 1
				else
					cell.vars[4] = 1
					local cx,cy = StepForward(x,y,dir)
					local rc = GetStoredCell(cell,true)
					PushCell(cx,cy,dir,{force=1,replacecell=rc,undocells=vars.undocells})
				end
			elseif not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
			end
		elseif id == 1043 and side == 2 then
			if cell.vars[1] then
				local cx,cy,cdir = NextCell(x,y,dir)
				local cell2 = GetCell(cx,cy)
				if not IsNonexistant(cell2,cdir,cx,cy) and not IsUnbreakable(cell2,cdir,cx,cy,{forcetype="transform",lastcell=cell}) then
					newcell = GetStoredCell(cell)
					newcell.lastvars = {cx,cy,0}
					newcell.eatencells = {cell2}
					SetCell(cx,cy,newcell)
				end
			elseif not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = lid
				cell.vars[2] = lrot
			end
		elseif id == 1164 and side == 2 then
			if not IsNonexistant(vars.lastcell,dir,x,y) then
				cell.vars[1] = 1
			end
		elseif id == 233 or id == 601 then
			table.safeinsert(cell,"eatencells",vars.lastcell)
			if side == 1 or side == 3 then cell.vars[1] = lid end
		elseif id == 207 and (side == 1 or side == 3) then
			local gvars = table.copy(vars)
			gvars.force = force
			gvars.strong = false
			Queue("postpush",function() if not vars.stopped then GrabEmptyCell(x,y,dir,gvars) end end)
		elseif id == 154 and lid == 153 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			SetCell(x,y,getempty())
			EmitParticles("sparkle",x,y)
			Play("unlock")
			Play("destroy")
		elseif id == 154 and lid == 584 then
			if vars.undocells then vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell) end
			cell.eatencells = {table.copy(cell),vars.lastcell}
			SetCell(x,y,vars.lastcell)
			EmitParticles("sparkle",x,y)
			Play("unlock")
			Play("destroy")
		elseif id == 162 then
			vars.undocells[x+y*width] = getempty()
			EmitParticles("staller",x,y)
			Play("destroy")
			return 0
		elseif id == 1181 and collectedkeys[cell.vars[1]] then
			vars.undocells[x+y*width] = getempty()
			Play("unlock")
			Play("destroy")
			EmitParticles("greysparkle",x,y)
			return 0
		elseif (id == 12 or id == 225 or id == 226 or id == 300 or id == 44 or id == 155 or id == 250 or id == 251 or id == 317 or id == 344 or id == 345 or id == 672 or id == 735 or id == 814
		or id == 436 or id == 437 or id == 517 or id == 518 or id == 519 or id == 520 or id == 521 or id == 815 or id == 816 or id == 817 or id == 819 or id == 1116) and vars.destroying and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			Play("destroy")
		elseif id == 205 and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		elseif (id == 347 or id == 349 or (id == 351 or id == 552) and (cell.vars[side+1] == 7 or cell.vars[side+1] == 8 or cell.vars[side+1] == 9 or cell.vars[side+1] == 10) or id == 438 or id == 439 or id == 440 or id == 441 or id == 463 or id == 694 or id == 695 or id == 856) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			local cdir = (id == 347 or id == 349 or (id == 351 or id == 552) and cell.vars[side+1] == 7) and dir
			or (id == 694 or id == 695 or (id == 351 or id == 552) and cell.vars[side+1] == 8) and (dir+2)%4
			or (id == 438 or id == 439 or (id == 351 or id == 552) and cell.vars[side+1] == 9) and (dir-1)%4
			or (id == 440 or id == 441 or (id == 351 or id == 552) and cell.vars[side+1] == 10) and (dir+1)%4
			or (id == 463 or id == 856) and cell.rot
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			local neighbors = GetNeighbors(x,y)
			if id == 351 or id == 552 then
				for k,v in pairs(neighbors) do
					local c = GetCell(v[1],v[2])
					if cell.vars[(k-cell.rot)%4+1] == 12 and not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
						vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
						DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
					end
				end
			end
			Queue("postpush",function() PushCell(x,y,cdir,{force=1,skipfirst=true}) end)
			if id ~= 349 and id ~= 439 and id ~= 441 and id ~= 856 then Play("destroy") end
		elseif id == 563 then
			table.safeinsert(cell,"eatencells",vars.lastcell)
			if not vars.checkonly then
				switches[cell.vars[1]] = not switches[cell.vars[1]] and true or nil
				cell.vars[2] = switches[cell.vars[1]]
				Play("destroy")
			end
		elseif id == 348 or id == 350 or id == 859 or id == 860 or (id == 351 or id == 552) and cell.vars[side+1] == 11 then
			local v = table.copy(vars)
			v.force = force
			v.skipfirst = true
			v.undocells = nil
			v.repeats = 0
			vars.destroying = not PushCell(x,y,dir,v)
			if vars.destroying then
				if id == 351 or id == 552 then
					local neighbors = GetNeighbors(x,y)
					for k,v in pairs(neighbors) do
						local c = GetCell(v[1],v[2])
						if cell.vars[(k-cell.rot)%4+1] == 12 and not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
							vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
							DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
						end
					end
				elseif id == 859 or id == 860 then
					local neighbors = (id == 859 and GetNeighbors or GetSurrounding)(x,y)
					for k,v in pairs(neighbors) do
						local c = GetCell(v[1],v[2])
						if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
							vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
							DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
						end
					end
				end
				if fancy then table.safeinsert(GetCell(x,y),"eatencells",vars.lastcell) end
				if id ~= 350 then Play("destroy") end
			end
		elseif (id == 51 or id == 670 or id == 848 or id == 850 or id == 852 or id == 854 or id == 857) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			local cdir = id == 848 and dir or id == 850 and (dir-1)%4 or id == 852 and (dir+1)%4 or id == 854 and (dir+2)%4 or id == 857 and cell.rot or nil
			local neighbors = GetNeighbors(x,y)
			for k,v in pairs(neighbors) do
				local c = GetCell(v[1],v[2])
				if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
					vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
					DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if cdir then Queue("postpush",function() PushCell(x,y,cdir,{force=1,skipfirst=true}) end) end
			if id ~= 670 then Play("destroy") end
		elseif (id == 141 or id == 671 or id == 849 or id == 851 or id == 853 or id == 855 or id == 858) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			local cdir = id == 849 and dir or id == 851 and (dir-1)%4 or id == 853 and (dir+1)%4 or id == 855 and (dir+2)%4 or id == 858 and cell.rot or nil
			local neighbors = GetSurrounding(x,y)
			for k,v in pairs(neighbors) do
				local c = GetCell(v[1],v[2])
				if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
					vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
					DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if cdir then Queue("postpush",function() PushCell(x,y,cdir,{force=1,skipfirst=true}) end) end
			if id ~= 671 then Play("destroy") end
		elseif (id == 351 or id == 552) and (cell.vars[side+1] == 5 or cell.vars[side+1] == 6 or cell.vars[side+1] == 12) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			local neighbors = GetNeighbors(x,y)
			for k,v in pairs(neighbors) do
				local c = GetCell(v[1],v[2])
				if cell.vars[(k-cell.rot)%4+1] == 12 and not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
					vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
					DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
				end
			end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			if cell.vars[side+1] ~= 6 then Play("destroy") end
		elseif id == 176 and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			if not IsUnbreakable(GetCell(vars.lastx,vars.lasty),(vars.lastdir+2)%4,vars.lastx,vars.lasty,{forcetype="infect",lastcell=cell}) then
				SetCell(vars.lastx,vars.lasty,table.copy(cell))
				Play("destroy")
				Play("infect")
				if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			end
		elseif (id == 890 or id == 891 or id == 892 or id == 893 or id == 894 or id == 895) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			if id == 890 or id == 892 or id == 894 then Play("destroy") end
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			local cdir = (id == 892 or id == 893) and (dir+1)%4 or (id == 894 or id == 895) and (dir-1)%4 or dir 
			local cx,cy = StepForward(x,y,cdir)
			Queue("postpush",function() PushCell(cx,cy,cdir,{force=1}) end)
		elseif (id == 897 or id == 898 or id == 899 or id == 900 or id == 901 or id == 902) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			Play("destroy")
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			local cdir = (id == 899 or id == 900) and (dir+1)%4 or (id == 901 or id == 902) and (dir-1)%4 or dir 
			local cx,cy = StepForward(x,y,cdir)
			Queue("postpush",function()
				PushCell(cx,cy,cdir,{force=1})
				local neighbors = ((id == 898 or id == 900 or id == 902) and GetSurrounding or GetNeighbors)(x,y)
				for k,v in pairs(neighbors) do
					local c = GetCell(v[1],v[2])
					if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
						vars.undocells[v[1]+v[2]*width] = table.copy(GetCell(v[1],v[2]))
						DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
					end
				end
			end)
		elseif id == 908 or id == 909 then
			Play("destroy")
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			cell.vars[2] = not cell.vars[2] and true or nil
		elseif (id == 47 or (id == 351 or id == 552) and cell.vars[side+1] == 18) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="infect",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			c = table.copy(cell)
			c.lastvars = table.copy(vars.lastcell.lastvars)
			c.lastvars[3] = c.rot
			vars.lastcell = c
			Play("infect")
		elseif id == 1154 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="infect",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) and not IsNonexistant(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty) then
			if cell.vars[3] ~= 1 then
				local c = table.copy(cell)
				c.lastvars = table.copy(vars.lastcell.lastvars)
				c.lastvars[3] = c.rot
				c.vars[3] = c.vars[3] - 1
				vars.lastcell = c
				Play("infect")
			else
				local c = GetStoredCell(cell, true)
				c.lastvars = table.copy(vars.lastcell.lastvars)
				c.lastvars[3] = c.rot
				vars.lastcell = c
				Play("infect")
			end
		elseif (id == 585) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
			RotateCellRaw(vars.lastcell,1)
			Play("rotate")
		elseif (id == 586) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
			RotateCellRaw(vars.lastcell,-1)
			Play("rotate")
		elseif (id == 587) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
			RotateCellRaw(vars.lastcell,2)
			Play("rotate")
		elseif (id == 966) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
			RotateCellRaw(vars.lastcell,math.randomsign())
			Play("rotate")
		elseif (id == 711) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
			FlipCellRaw(vars.lastcell,rot)
			Play("rotate")
		elseif (id == 712) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
			FlipCellRaw(vars.lastcell,rot-.5)
			Play("rotate")
		elseif (id == 1047) and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell,lastx=vars.lastx,lasty=vars.lasty}) then
			RotateCellRaw(vars.lastcell,rot-lrot)
			Play("rotate")
		elseif (id == 231 or id == 249) and not cell.sticky and not vars.checkonly then
			if not vars.sticking then stickkey = stickkey + 1 end
			vars.sticking = true
			cell.stickkey = stickkey
			if (dir == 0 or dir == 2) and (id == 231 or cell.rot%2 == 1) then
				local c2 = GetCell(x,y-1)
				if (c2.id == 231 or c2.id == 249 and (c2.rot == 1 or c2.rot == 3)) and c2.stickkey ~= stickkey then
					local vars2 = table.copy(vars)
					vars2.force = force
					vars2.replacecell = getempty()
					vars2.noupdate = true
					if PushCell(x,y-1,dir,vars2) then
						table.merge(vars.undocells,vars2.undocells)
					else
						return 0
					end
				end
				local c2 = GetCell(x,y+1)
				if (c2.id == 231 or c2.id == 249 and (c2.rot == 1 or c2.rot == 3)) and c2.stickkey ~= stickkey then
					local vars2 = table.copy(vars)
					vars2.force = force
					vars2.replacecell = getempty()
					vars2.noupdate = true
					if PushCell(x,y+1,dir,vars2) then
						table.merge(vars.undocells,vars2.undocells)
					else
						return 0
					end
				end
				if GetCell(x,y) ~= cell then
					vars.ended = true
				end
			elseif (dir == 1 or dir == 3) and (id == 231 or cell.rot%2 == 0) then
				local c2 = GetCell(x+1,y)
				if (c2.id == 231 or c2.id == 249 and (c2.rot == 0 or c2.rot == 2)) and c2.stickkey ~= stickkey then
					local vars2 = table.copy(vars)
					vars2.force = force
					vars2.replacecell = getempty()
					vars2.noupdate = true
					if PushCell(x+1,y,dir,vars2) then
						table.merge(vars.undocells,vars2.undocells)
					else
						return 0
					end
				end
				local c2 = GetCell(x-1,y)
				if (c2.id == 231 or c2.id == 249 and (c2.rot == 0 or c2.rot == 2)) and c2.stickkey ~= stickkey then
					local vars2 = table.copy(vars)
					vars2.force = force
					vars2.replacecell = getempty()
					vars2.noupdate = true
					if PushCell(x-1,y,dir,vars2) then
						table.merge(vars.undocells,vars2.undocells)
					else
						return 0
					end
				end
				if GetCell(x,y) ~= cell then
					vars.ended = true
				end
			end
		elseif id == 126 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="infect",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				vars.undocells[vars.lastx+vars.lasty*width] = CopyCell(x,y)	--since this is a wall it'll undo the changes
				Play("infect")
			end
			vars.optimizegen = false
			return 0
		elseif id == 150 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],1)
				Play("rotate")
			end
			vars.optimizegen = false
			return 0
		elseif id == 151 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],-1)
				Play("rotate")
				vars.optimizegen = false
			end
			vars.optimizegen = false
			return 0
		elseif id == 152 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],2)
				Play("rotate")
			end
			vars.optimizegen = false
			return 0
		elseif id == 965 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],math.randomsign())
				Play("rotate")
			end
			vars.optimizegen = false
			return 0
		elseif id == 709 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				FlipCellRaw(vars.undocells[vars.lastx+vars.lasty*width],rot)
				Play("rotate")
			end
			vars.optimizegen = false
			return 0
		elseif id == 710 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				FlipCellRaw(vars.undocells[vars.lastx+vars.lasty*width],rot-.5)
				Play("rotate")
			end
			vars.optimizegen = false
			return 0
		elseif id == 1046 and not IsUnbreakable(vars.lastcell,(dir-2)%4,vars.lastx,vars.lasty,{forcetype="rotate",lastcell=vars.lastcell}) then
			if vars.undocells[vars.lastx+vars.lasty*width] then
				RotateCellRaw(vars.undocells[vars.lastx+vars.lasty*width],cell.rot-vars.undocells[vars.lastx+vars.lasty*width].rot)
				Play("rotate")
			end
			vars.optimizegen = false
			return 0
		elseif id == 229 and side == 2 then
			local cx,cy = StepForward(x,y,dir)
			local gen = table.copy(vars.lastcell)
			gen.lastvars = {x,y,0}
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				Queue("postpush",function() PushCell(cx,cy,dir,{replacecell=gen,force=1,noupdate=true}) end)
			end
			vars.optimizegen = false
			return 0
		elseif id == 1088 and side == 2 then
			local cx,cy = StepForward(x,y,dir)
			if cell.vars[1] then
				Queue("postpush",function() PushCell(cx,cy,dir,{replacecell=GetStoredCell(cell),force=1,noupdate=true}) end)
			end
			vars.optimizegen = false
			return 0
		elseif (id == 32 or id == 33 or id == 34 or id == 35 or id == 36 or id == 37 or id == 194 or id == 195 or id == 196 or id == 197) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			if side == 3 then
				cell.inl = true
				if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			elseif side == 1 then
				cell.inr = true
				if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
			else return 0 end
		elseif (id == 186 or id == 187 or id == 188 or id == 189 or id == 190 or id == 191 or id == 192 or id == 193) and vars.destroying and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
			if not cell.output then
				cell.output = vars.lastcell
				if side == 1 and id < 190 then RotateCellRaw(cell.output,1)
				elseif side == 3 and id < 190 then RotateCellRaw(cell.output,-1) end
			end
		elseif id == 223 then
			vars.lastcell.vars.coins = (vars.lastcell.vars.coins or 0)+1
			EmitParticles("coin",x,y,25)
			Play("coin")
		elseif id == 1180 then
			collectedkeys[cell.vars[1]] = true
			EmitParticles("greysparkle",x,y,25)
			Play("coin")
		elseif id == 312 and not vars.balloonpopped then
			local c = getempty()
			c.eatencells = {cell}
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or c
			vars.balloonpopped = true
			vars.optimizegen = false
		elseif id == 401 or (id == 351 or id == 552) and cell.vars[side+1] == 19 then
			if not vars.negative then
				local vars2 = table.copy(vars)
				vars2.force = math.huge
				vars2.undocells = {}
				vars2.negative = true
				vars2.skipfirst = true
				vars2.replacecell = nil
				vars2.repeats = 0
				Queue("postpush",function() PushCell(x,y,(dir+2)%4,vars2) end)
			end
			vars.optimizegen = false
			return 0
		elseif id == 464 then
			if not vars.pullextended then
				local vars2 = table.copy(vars)
				vars2.force = 1
				vars2.undocells = {}
				vars2.repeats = 0
				vars2.maximum = math.huge
				local cx,cy = StepBack(vars.firstx,vars.firsty,dir)
				Queue("postpush",function() PullCell(cx,cy,vars.firstdir,vars2) end)
			end
			vars.pullextended = true
		elseif id == 477 then
			local vars2 = table.copy(vars)
			vars2.force = 1
			vars2.undocells = {}
			vars2.repeats = 0
			vars2.maximum = math.huge
			Queue("postpush",function() if not vars.stopped then GrabEmptyCell(x,y,dir,vars2) end end)
		elseif id == 552 and not IsUnbreakable(cell,dir,x,y,vars) then
			if side == 2 then
				if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
				if cell.vars[6] == 1 then force = force+(cell.updatedforce or cell.vars[11]) end
			elseif side == 0 then
				if cell.vars[6] == 1 then force = force-(cell.updatedforce or cell.vars[11]) end
			end
		elseif (id == 327 or id == 331 or id == 332 or id == 333 or id == 334 or id == 337 or id == 338 or id == 339 or id == 340) and side == 2 or id == 328 and (side == 2 or side == 1) then
			local gen = table.copy(vars.lastcell)
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				if id ~= 331 and id ~= 337 then
					gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
					local cx,cy = StepForward(x,y,dir)
					local gen = table.copy(gen)
					PushCell(cx,cy,dir,{replacecell=table.copy(gen),force=1,noupdate=true})
				end
				if id < 335 then gen.rot = (gen.rot-1)%4 end
				if id ~= 327 and id ~= 333 and id ~= 339 and id ~= 328 then
					gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
					local cx,cy = StepLeft(x,y,dir)
					PushCell(cx,cy,(dir-1)%4,{replacecell=table.copy(gen),force=1,noupdate=true})
				end
				if id < 335 then gen.rot = (gen.rot+2)%4 end
				if id ~= 327 and id ~= 334 and id ~= 340 and id ~= 328 then
					gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
					local cx,cy = StepRight(x,y,dir)
					PushCell(cx,cy,(dir+1)%4,{replacecell=table.copy(gen),force=1,noupdate=true})
				end
			end
		elseif (id == 329 or id == 335) and side == 1 then
			local cx,cy = StepRight(x,y,dir)
			local gen = table.copy(vars.lastcell)
			if id == 329 then gen.rot = (gen.rot+1)%4 end 
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
				PushCell(cx,cy,(dir+1)%4,{replacecell=gen,force=1,noupdate=true})
			end
		elseif (id == 330 or id == 336) and side == 3 then
			local cx,cy = StepLeft(x,y,dir)
			local gen = table.copy(vars.lastcell)
			if id == 330 then gen.rot = (gen.rot-1)%4 end 
			gen = ToGenerate(gen,dir,x,y)
			if gen then
				gen.lastvars = {cell.lastvars[1],cell.lastvars[2],0}
				PushCell(cx,cy,(dir-1)%4,{replacecell=gen,force=1,noupdate=true})
			end
		elseif id == 384 or id == 385 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			if side == 0 or side == 2 then RotateCellRaw(cell,1)
			elseif side == 1 or side == 3 then RotateCellRaw(cell,-1)
			end
		elseif id == 388 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			RotateCellRaw(cell,1)
		elseif id == 389 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			RotateCellRaw(cell,-1)
		elseif (id == 721 or id == 725) and not cell.frozen  then
			if side%2 == 0 then return 0 end
		elseif (id == 722 or id == 726) and not cell.frozen  then
			if side == 0 then return 0
			elseif side == 2 then force = math.huge end
		elseif (id == 723 or id == 727) and not cell.frozen  then
			if side == 0 or side == 3 then return 0
			else force = math.huge end
		elseif (id == 724 or id == 728) and not cell.frozen  then
			if side ~= 2 then return 0
			else force = math.huge end
		elseif id == 1155 and not cell.vars[2] and side == 2 and not vars.destroying then
			cell.vars[2] = 1
			cell.updated = true
		elseif id == 1200 then
			if not vars.checkonly then
				scriptx,scripty=x,y
				ExecuteScriptCell(cell)
			end
		elseif IsUnbreakable(cell,dir,x,y,vars) and not IsDestroyer(cell,dir,x,y,vars)
		or (id ~= 4 and id ~= 5 and id ~= 6 and id ~= 7 and id ~= 8 and id ~= 214 and id ~= 215 and id ~= 216 and id ~= 217 and id ~= 218
		and id ~= 618 and id ~= 620 and id ~= 621 and id ~= 622 and id ~= 623 and id ~= 840 and id ~= 841 and id ~= 842 and id ~= 843 and id ~= 844
		and id ~= 910 and id ~= 911 and id ~= 912 and id ~= 913 and id ~= 914 and id ~= 52 and id ~= 53 and id ~= 54 or lid ~= 422) ==
		((id == 5 or id == 215 or id == 620 or id == 841 or id == 911) and side ~= 2 and side ~= 0
		or (id == 6 or id == 216 or id == 621 or id == 842 or id == 912) and side ~= 2
		or (id == 7 or id == 217 or id == 622 or id == 843 or id == 913) and (side == 0 or side == 3)
		or (id == 8 or id == 218 or id == 623 or id == 844 or id == 914) and side == 0
		or id == 52 and side ~= 2 or id == 53 and (side == 0 or side == 3) or id == 54 and side == 0)
		or (id == 50 or id == 435) and not cell.frozen then 
			return 0
		elseif (id == 618 or id == 620 or id == 621 or id == 622 or id == 623) and not vars.pushbroken then
			Queue("postpush",function()
							cell.eatencells = {table.copy(cell)}
							cell.id = 0 end)
			vars.pushbroken = true
		end
	end
	if cell.sticky and not vars.checkonly and not vars.destroying and force > 0 then
		if not vars.sticking then stickkey = stickkey + 1 end
		vars.sticking = true
		cell.stickkey = stickkey
		if (dir == 0 or dir == 2) then
			local c2 = GetCell(x,y-1)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.replacecell = getempty()
				if PushCell(x,y-1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x,y+1)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.replacecell = getempty()
				if PushCell(x,y+1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		elseif (dir == 1 or dir == 3) then
			local c2 = GetCell(x+1,y)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.replacecell = getempty()
				if PushCell(x+1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x-1,y)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.replacecell = getempty()
				if PushCell(x-1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		end
	end
	return force
end

function HandleGrab(force,cell,dir,x,y,vars)
	local id = cell.id
	local rot = cell.rot
	local side = ToSide(rot,dir)
	vars.lastcell = vars.lastcell or getempty()
	vars.lastx,vars.lasty = vars.lastx or x,vars.lasty or y
	vars.firstx,vars.firsty = vars.firstx or vars.lastx,vars.firsty or vars.lasty
	if not vars.layer then
		local above = GetCell(x,y,1)
		local aboveside = ToSide(above.rot,dir+(vars.side=="left" and 3 or 1))
		if ((above.id == 553 or above.id == 558) and (aboveside > 3 or aboveside < 1) or (above.id == 554 or above.id == 559) and (aboveside > 2 or aboveside < 1)
		or (above.id == 555 or above.id == 560) and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3)
		or (above.id == 556 or above.id == 561) and aboveside ~= 2 or (above.id == 557 or above.id == 562)) and vars.repeats > 1
		or above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 566 and above.vars[2] == 0 or above.id == 706 or above.id == 916 then
			vars.ended = false
			return force
		end
	end
	if cell.grabclamped or cell.vars.grabpermaclamped or id == 698 or cell.vars.petrified then
		vars.ended = true
		return force
	elseif id == 42 and side == 0 or id == 22 or id == 227 and side == 0 or id == 228 and (side == 3 or side == 0) or (id == 351 or id == 552) and cell.vars[side+1] == 14 then
		force = force-1
	elseif id == 42 and side == 2 or id == 104 or id == 227 and side == 2 or id == 228 and (side == 1 or side == 2) or (id == 351 or id == 552) and cell.vars[side+1] == 15 then
		force = force+1
	elseif id == 1182 or id == 1183 or id == 1184 and side%2 == 0 then
		if vars.iforce then
			vars.iforce = id == 1182 and vars.iforce-1 or id == 1183 and vars.iforce+1 or id == 1184 and vars.iforce+side-1 
		else
			vars.iforce = id == 1182 and -1 or id == 1183 and 1 or id == 1184 and side
			Queue("postgrab",function()
				if vars.iforce < 0 and force > 0 then
					for k,v in pairs(vars.undocells) do
						SetCell(k%width,math.floor(k/width),v)
					end
					vars.forcefalse = true
				end
			end)
		end
	elseif ChunkId(cell.id) == 1133 then
		force = masses[cell.id] == math.huge and 0 or force-masses[cell.id]
	elseif id == 142 or id == 639 and side == 0 then
		force = force == 1 and 1 or 0
	elseif id == 143 then
		force = force == rot+1 and rot+1 or 0
	elseif id == 1194 then
		force = force == math.huge and math.huge or 0
	elseif id == 1191 then
		force = force ~= 1 and force or 0
	elseif id == 1195 then
		force = force ~= rot+1 and force or 0
	elseif id == 1192 then
		force = force ~= math.huge and force or 0
	elseif id == 1193 then
		force = force ~= cell.vars[1]/cell.vars[2] and force or 0
	elseif id == 1185 then
		Queue("postgrab",function()
			if vars.iforce and vars.iforce ~= 0 then
				for k,v in pairs(vars.undocells) do
					SetCell(k%width,math.floor(k/width),v)
				end
				vars.forcefalse = true
			end
		end)
	elseif id == 1196 then
		Queue("postgrab",function()
			if not vars.iforce or vars.iforce == 0 then
				for k,v in pairs(vars.undocells) do
					SetCell(k%width,math.floor(k/width),v)
				end
				vars.forcefalse = true
			end
		end)
	elseif id == 1187 or id == 1188 then
		if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
		if cell.vars[1] <= (id == 1188 and cell.vars[2] or force) then
			if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
			cell.updated = true
			return 0
		end
		cell.updated = true
	elseif id == 1189 or id == 1190 then
		if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
		if cell.vars[1] > (id == 1190 and cell.vars[2] or force) then
			cell.updated = true
			return 0
		else
			if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
			cell.updated = true
		end
	elseif id == 1197 or id == 1198 then
		cell.vars[1] = cell.vars[1] + 1
		if cell.vars[1] >= (id == 1198 and cell.vars[2] or force) then
			cell.vars[1] = 0
		else
			return 0
		end
	elseif id == 144 or id == 631 and side == 0 then
		force = math.min(force,1)
	elseif id == 668 then
		force = force-(cell.vars[1]/cell.vars[2])
	elseif id == 669 then
		force = force == cell.vars[1]/cell.vars[2] and force or 0
	elseif (id == 81 and vars.side == "left" or id == 82 and vars.side == "right") and not cell.frozen then
		force = force <= 1 and 0 or force
	elseif id == 638 then
		if side == 0 then
			return 0
		else
			RotateCellRaw(cell,side)
		end
	elseif (id == 71 or id == 72 or id == 73 or id == 74 or id == 75 or id == 76 or id == 77 or id == 78
	or id == 272 or id == 273 or id == 274 or id == 275 or id == 280 or id == 281 or id == 282 or id == 283 or id == 400
	or id == 206 and cell.vars[1] == 1) and not cell.frozen then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)	--dont update if movement fails
			cell.updated = cell.updated or not vars.noupdate
			force = force+1
		elseif side == 0 then
			force = force-1
		end
	elseif (id == 2 or id == 14 or id == 28 or id == 58 or id == 59 or id == 60 or id == 61 or id == 114 or id == 115
	or id == 269 or id == 270 or id == 271 or id == 276 or id == 277 or id == 278 or id == 279 or id == 160 or id == 161
	or (id == 175 or id == 362 or id == 704 or id == 821 or id == 822 or id == 823 or id == 905) and cell.vars[1] or id == 178 or id == 179 or id == 180 or id == 181 or id == 182
	or id == 183 or id == 184 or id == 185 or id == 206 or id == 213 and (side == 0 or side == 2) or id == 303 or id == 304 or id == 305
	or id == 311 or id == 358 or id == 359 or id == 367 or id == 368 or id == 423 or id == 424 or id == 589 or id == 590
	or id == 591 or id == 592 or id == 597 or id == 598 or id == 599 or id == 600 or id == 700 or id == 718 or id == 719
	or id == 720 or id == 781 or id == 786 or id == 787 or id == 792 or id == 793 or id == 794 or id == 795 or id == 800
	or id == 801 or id == 802 or id == 803 or id == 319 or id == 454 or id == 456 or id == 820 or id == 863 or id == 864
	or id == 865 or id == 903 or id == 904 or id == 906 or id == 1086 or id == 1087 or id == 1160 or id == 1162) and not IsTransparent(cell,dir,x,y,vars) then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			cell.updated = cell.updated or not vars.noupdate
		end
	elseif id == 354 and (cell.updatedforce or cell.vars[2]-1 == cell.vars[3]) and not cell.frozen then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
			force = force+(cell.updatedforce or cell.vars[1])
		elseif side == 0 then
			force = force-(cell.updatedforce or cell.vars[1])
		end
	elseif id == 352 or id == 353 or id == 355 or id == 356 or id == 357 then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
		end
	elseif id == 346 then
		if side == 2 then
			if not cell.updated and not vars.noupdate then
				cell.updated = true
				if cell.rot%2 == 0 then
					PushCell(x,y-1,3,{force=1})
					PushCell(x,y+1,1,{force=1})
				else
					PushCell(x+1,y,0,{force=1})
					PushCell(x-1,y,2,{force=1})
				end
			end
		end
	elseif id == 103 then
		force = force-rot
	elseif id == 384 or id == 385 then
		vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
		if side == 0 or side == 2 then RotateCellRaw(cell,1)
		elseif side == 1 or side == 3 then RotateCellRaw(cell,-1)
		end
	elseif id == 388 then
		vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
		RotateCellRaw(cell,-1)
	elseif id == 389 then
		vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
		RotateCellRaw(cell,1)
	elseif id == 32 or id == 33 or id == 34 or id == 35 or id == 36 or id == 37 or id == 194 or id == 195 or id == 196 or id == 197 then
		vars.ended = true
	elseif id == 401 or (id == 351 or id == 552) and vars.side == "left" and cell.vars[(side+3)%4+1] == 19 or vars.side == "right" and cell.vars[(side+1)%4+1] == 19 then
		if not vars.negative then
			local vars2 = table.copy(vars)
			vars2.force = math.huge
			vars2.undocells = {}
			vars2.negative = true
			vars2.skipfirst = true
			vars2.repeats = 0
			Queue("postgrab",function() if vars.side == "left" then LGrabCell(x,y,(dir+2)%4,vars2) else RGrabCell(x,y,(dir+2)%4,vars2) end end)
		end
		return 0
	elseif id == 464 then
		local vars2 = table.copy(vars)
		vars2.force = 1
		vars2.undocells = {}
		vars2.repeats = 0
		vars2.maximum = math.huge
		local cx,cy = StepBack(x,y,dir)
		Queue("postgrab",function() PullCell(cx,cy,dir,vars2) end)
	elseif id == 466 then
		local vars2 = table.copy(vars)
		vars2.force = 1
		vars2.undocells = {}
		vars2.repeats = 0
		vars2.maximum = math.huge
		local cx,cy = x,y
		Queue("postgrab",function() PushCell(x,y,dir,vars2) end)
	elseif id == 552 and not IsUnbreakable(cell,(dir+(vars.side=="left" and -1 or 1))%4,x,y,vars)then
		if side == 2 then
			if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
			if cell.vars[8] == 1 then force = force+(cell.updatedforce or cell.vars[11]) end
		elseif side == 0 then
			if cell.vars[8] == 1 then force = force-(cell.updatedforce or cell.vars[11]) end
		end
	elseif (id == 231 or id == 249) and not vars.checkonly  then
		if not vars.sticking then stickkey = stickkey + 1 end
		vars.sticking = true
		cell.stickkey = stickkey
		local func = vars.side == "left" and LGrabCell or RGrabCell
		if (dir == 1 or dir == 3) and (id == 231 or cell.rot == 0 or cell.rot == 2) then
			local c2 = GetCell(x,y-1)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 0 or c2.rot == 2)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				vars2.failonfirst = false
				if func(x,y-1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x,y+1)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 0 or c2.rot == 2)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				vars2.failonfirst = false
				if func(x,y+1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		elseif (dir == 0 or dir == 2) and (id == 231 or cell.rot == 1 or cell.rot == 3) then
			local c2 = GetCell(x+1,y)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 1 or c2.rot == 3)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				vars2.failonfirst = false
				if func(x+1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x-1,y)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 1 or c2.rot == 3)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				vars2.failonfirst = false
				if func(x-1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		end
	elseif IsUnbreakable(cell,(dir+(vars.side=="left" and -1 or 1))%4,x,y,vars) and not IsDestroyer(cell,(dir-2)%4,x,y,vars)
	or (id == 5 or id == 215 or id == 620 or id == 841 or id == 911) and side ~= 2 and side ~= 0
	or (id == 6 or id == 216 or id == 621 or id == 842 or id == 912) and side ~= 2
	or (id == 7 or id == 217 or id == 622 or id == 843 or id == 913) and (side == 0 or side == 3)
	or (id == 8 or id == 218 or id == 623 or id == 844 or id == 914) and side == 0
	or (id == 52 or id == 54) and side ~= 1 and side ~= 3 then 
		vars.ended = true
	elseif (id == 618 or id == 620 or id == 621 or id == 622 or id == 623) and not vars.pushbroken then
		Queue("postgrab",function()
						cell.eatencells = {table.copy(cell)}
						cell.id = 0 end)
		vars.pushbroken = true
	end
	return force
end

function HandlePull(force,cell,dir,x,y,vars)
	local id = cell.id
	local rot = cell.rot
	local side = ToSide(rot,dir)
	vars.lastcell = vars.lastcell or getempty()
	vars.lastx,vars.lasty = vars.lastx or x,vars.lasty or y
	vars.firstx,vars.firsty = vars.firstx or vars.lastx,vars.firsty or vars.lasty
	if not vars.layer and vars.repeats > 1 then
		local above = GetCell(x,y,1)
		local aboveside = ToSide(above.rot,dir+2)
		if ((above.id == 553 or above.id == 558) and (aboveside > 3 or aboveside < 1) or (above.id == 554 or above.id == 559) and (aboveside > 2 or aboveside < 1)
		or (above.id == 555 or above.id == 560) and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3)
		or (above.id == 556 or above.id == 561) and aboveside ~= 2 or (above.id == 557 or above.id == 562)) and vars.repeats > 1
		or above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 566 and above.vars[2] == 0 or above.id == 706 or above.id == 916 then
			vars.ended = false
			force = force
		end
	end
	if cell.pullclamped or cell.vars.pullpermaclamped or id == 697 or cell.vars.petrified then
		vars.ended = true
		return force
	elseif id == 42 and side == 0 or id == 22 or (id == 351 or id == 552) and cell.vars[side+1] == 14 then
		force = force-1
	elseif id == 42 and side == 2 or id == 104 or (id == 351 or id == 552) and cell.vars[side+1] == 15 then
		force = force+1
	elseif id == 1182 or id == 1183 or id == 1184 and side%2 == 0 then
		if vars.iforce then
			vars.iforce = id == 1182 and vars.iforce-1 or id == 1183 and vars.iforce+1 or id == 1184 and vars.iforce+side-1 
		else
			vars.iforce = id == 1182 and -1 or id == 1183 and 1 or id == 1184 and side-1
			Queue("postpull",function()
				if vars.iforce < 0 and force > 0 then
					for k,v in pairs(vars.undocells) do
						SetCell(k%width,math.floor(k/width),v)
					end
					vars.forcefalse = true
				end
			end)
		end
	elseif ChunkId(cell.id) == 1133 then
		force = masses[cell.id] == math.huge and 0 or force-masses[cell.id]
	elseif id == 142 or id == 639 and side == 0 then
		force = force == 1 and 1 or 0
	elseif id == 143 then
		force = force == rot+1 and rot+1 or 0
	elseif id == 1194 then
		force = force == math.huge and math.huge or 0
	elseif id == 1191 then
		force = force ~= 1 and force or 0
	elseif id == 1195 then
		force = force ~= rot+1 and force or 0
	elseif id == 1192 then
		force = force ~= math.huge and force or 0
	elseif id == 1193 then
		force = force ~= cell.vars[1]/cell.vars[2] and force or 0
	elseif id == 1185 then
		Queue("postpull",function()
			if vars.iforce and vars.iforce ~= 0 then
				for k,v in pairs(vars.undocells) do
					SetCell(k%width,math.floor(k/width),v)
				end
				vars.forcefalse = true
			end
		end)
	elseif id == 1196 then
		Queue("postpull",function()
			if not vars.iforce or vars.iforce == 0 then
				for k,v in pairs(vars.undocells) do
					SetCell(k%width,math.floor(k/width),v)
				end
				vars.forcefalse = true
			end
		end)
	elseif id == 1187 or id == 1188 then
		if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
		if cell.vars[1] <= (id == 1188 and cell.vars[2] or force) then
			if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
			cell.updated = true
			return 0
		end
		cell.updated = true
	elseif id == 1189 or id == 1190 then
		if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
		if cell.vars[1] > (id == 1190 and cell.vars[2] or force) then
			cell.updated = true
			return 0
		else
			if not cell.updated then cell.vars[1] = cell.vars[1] + 1 end
			cell.updated = true
		end
	elseif id == 1197 or id == 1198 then
		cell.vars[1] = cell.vars[1] + 1
		if cell.vars[1] >= (id == 1198 and cell.vars[2] or force) then
			cell.vars[1] = 0
		else
			return 0
		end
	elseif id == 144 or id == 631 and side == 0 then
		force = math.min(force,1)
	elseif id == 668 then
		force = force-(cell.vars[1]/cell.vars[2])
	elseif id == 669 then
		force = force == cell.vars[1]/cell.vars[2] and force or 0
	elseif id == 638 then
		if side == 0 then
			return 0
		else
			RotateCellRaw(cell,side)
		end
	elseif ((id == 29 or id == 1012 or id == 1104) or (id == 413 or id == 1013 or id == 1105) and side%2 == 0 or (id == 416 or id == 1016 or id == 1108) and side%2 == 1) and not cell.frozen then
		force = force <= 1 and 0 or force
	elseif ((id == 414 or id == 1014 or id == 1106) and side == 0 or (id == 415 or id == 1015 or id == 1107) and (side == 3 or side == 0) or (id == 416 or id == 1016 or id == 1108) and side == 0) and not cell.frozen then
		force = force+1
	elseif ((id == 414 or id == 101 or id == 1106) and side == 2 or (id == 415 or id == 1015 or id == 1107) and (side == 2 or side == 1) or (id == 416 or id == 1016 or id == 1108) and side == 2) and not cell.frozen then
		force = force-1
	elseif (id == 1007 or id == 1008 and side%2 == 0 or id == 1011 and side%2 == 1) and not cell.frozen then
		force = force <= 2 and 0 or force
	elseif (id == 1009 and side == 2 or id == 1010 and (side == 1 or side == 2) or id == 1011 and side == 2) and not cell.frozen then
		force = force+2
	elseif (id == 1009 and side == 0 or id == 1010 and (side == 0 or side == 3) or id == 1011 and side == 0) and not cell.frozen then
		force = force-2
	elseif (id == 14 or id == 28 or id == 73 or id == 74 or id == 61 or id == 60 or id == 77 or id == 78
	or id == 270 or id == 271 or id == 274 or id == 275 or id == 278 or id == 279 or id == 282 or id == 283
	or id == 206 and cell.vars[1] == 2 or id == 305 or id == 311 or id == 719 or id == 720) and not cell.frozen then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)	--dont update if movement fails
			cell.updated = cell.updated or not vars.noupdate
			force = force+1
		elseif side == 0 then
			force = force-1
		end
	elseif (id == 2 or id == 58 or id == 59 or id == 71 or id == 72 or id == 75 or id == 76 or id == 114 or id == 115
	or id == 269 or id == 272 or id == 273 or id == 276 or id == 277 or id == 280 or id == 281 or id == 160 or id == 161
	or (id == 175 or id == 362 or id == 704 or id == 821 or id == 822 or id == 823 or id == 905) and cell.vars[1] or id == 178 or id == 179 or id == 180 or id == 181 or id == 182
	or id == 183 or id == 184 or id == 185 or id == 206 or id == 213 and (side == 0 or side == 2) or id == 303 or id == 304
	or id == 358 or id == 359 or id == 367 or id == 368 or id == 400 or id == 423 or id == 424 or id == 589 or id == 590
	or id == 591 or id == 592 or id == 597 or id == 598 or id == 599 or id == 600 or id == 700 or id == 718 or id == 781
	or id == 786 or id == 787 or id == 792 or id == 793 or id == 794 or id == 795 or id == 800 or id == 801 or id == 802
	or id == 803 or id == 319 or id == 454 or id == 456 or id == 820 or id == 863 or id == 864 or id == 865 or id == 903
	or id == 904 or id == 906 or id == 1086 or id == 1087 or id == 1162) and not IsTransparent(cell,dir,x,y,vars) then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			cell.updated = cell.updated or not vars.noupdate
		end
	elseif id == 353 and (cell.updatedforce or cell.vars[2]-1 == cell.vars[3]) and not cell.frozen then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
			force = force+(cell.updatedforce or cell.vars[1])
		elseif side == 0 then
			force = force-(cell.updatedforce or cell.vars[1])
		end
	elseif id == 352 or id == 354 or id == 355 or id == 356 or id == 357 then
		if side == 2 then
			vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
			if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
		end
	elseif id == 346 then
		if side == 2 then
			if not cell.updated and not vars.noupdate then
				cell.updated = true
				if cell.rot%2 == 0 then
					PushCell(x,y-1,3,{force=1})
					PushCell(x,y+1,1,{force=1})
				else
					PushCell(x+1,y,0,{force=1})
					PushCell(x-1,y,2,{force=1})
				end
			end
		end
	elseif id == 103 then
		force = force-rot
	elseif id == 207 and (side == 1 or side == 3) then
		local gvars = table.copy(vars)
		gvars.force = force
		gvars.strong = false
		GrabEmptyCell(x,y,dir,gvars)
		table.merge(vars.undocells,gvars.undocells)
	elseif id == 384 or id == 385 then
		vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
		if side == 0 or side == 2 then RotateCellRaw(cell,1)
		elseif side == 1 or side == 3 then RotateCellRaw(cell,-1)
		end
	elseif id == 388 then
		vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
		RotateCellRaw(cell,-1)
	elseif id == 389 then
		vars.undocells[x+y*width] = vars.undocells[x+y*width] or table.copy(cell)
		RotateCellRaw(cell,1)
	elseif id == 32 or id == 33 or id == 34 or id == 35 or id == 36 or id == 37 or id == 194 or id == 195 or id == 196 or id == 197 then
		vars.ended = true
	elseif id == 401 or (id == 351 or id == 552) and cell.vars[(side+2)%4+1] == 19 then
		if not vars.negative then
			local vars2 = table.copy(vars)
			vars2.force = math.huge
			vars2.undocells = {}
			vars2.negative = true
			vars2.skipfirst = true
			vars2.repeats = 0
			Queue("postpull",function() PullCell(x,y,(dir+2)%4,vars2) end)
		end
		return 0
	elseif (id == 231 or id == 249) and not vars.checkonly then
		if not vars.sticking then stickkey = stickkey + 1 end
		vars.sticking = true
		cell.stickkey = stickkey
		if (dir == 0 or dir == 2) and (id == 231 or cell.rot == 1 or cell.rot == 3) then
			local c2 = GetCell(x,y-1)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 1 or c2.rot == 3)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				if PullCell(x,y-1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x,y+1)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 1 or c2.rot == 3)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				if PullCell(x,y+1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		elseif (dir == 1 or dir == 3) and (id == 231 or cell.rot == 0 or cell.rot == 2) then
			local c2 = GetCell(x+1,y)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 0 or c2.rot == 2)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				if PullCell(x+1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x-1,y)
			if (c2.id == 231 or c2.id == 249 and (c2.rot == 0 or c2.rot == 2)) and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				vars2.noupdate = true
				if PullCell(x-1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		end
	elseif id == 477 then
		local vars2 = table.copy(vars)
		vars2.force = 1
		vars2.undocells = {}
		vars2.repeats = 0
		vars2.maximum = math.huge
		QueueLast("postpull",function() if not vars.stopped then GrabEmptyCell(x,y,dir,vars2) end end)
	elseif id == 552 and not IsUnbreakable(cell,(dir-2)%4,x,y,vars) then
		if side == 2 then
			if not vars.noupdate then cell.updates = (cell.updates or 0)+1 end
			if cell.vars[7] == 1 then force = force+(cell.updatedforce or cell.vars[11]) end
		elseif side == 0 then
			if cell.vars[7] == 1 then force = force-(cell.updatedforce or cell.vars[11]) end
		end
	elseif id == 248 and not cell.frozen then
		return 0
	elseif id == 729 and not cell.frozen  then
		if side%2 == 0 then return 0 end
	elseif id == 730 and not cell.frozen  then
		if side == 2 then return 0
		elseif side == 0 then force = math.huge end
	elseif id == 731 and not cell.frozen  then
		if side == 1 or side == 2 then return 0
		else force = math.huge end
	elseif id == 732 and not cell.frozen  then
		if side ~= 0 then return 0
		else force = math.huge end
	elseif IsUnbreakable(cell,(dir-2)%4,x,y,vars) and not IsDestroyer(cell,(dir-2)%4,x,y,vars)
	or (id == 5 or id == 215 or id == 620 or id == 841 or id == 911) and side ~= 2 and side ~= 0
	or (id == 6 or id == 216 or id == 621 or id == 842 or id == 912) and side ~= 2
	or (id == 7 or id == 217 or id == 622 or id == 843 or id == 913) and (side == 0 or side == 3)
	or (id == 8 or id == 218 or id == 623 or id == 844 or id == 914) and side == 0
	or id == 52 and side ~= 0 or id == 53 and (side == 1 or side == 2) or id == 54 and side == 2 then 
		vars.ended = true
	elseif (id == 618 or id == 620 or id == 621 or id == 622 or id == 623) and not vars.pushbroken then
		Queue("postpull",function()
						cell.eatencells = {table.copy(cell)}
						cell.id = 0 end)
		vars.pushbroken = true
	end
	if cell.sticky and not vars.checkonly then
		if not vars.sticking then stickkey = stickkey + 1 end
		vars.sticking = true
		cell.stickkey = stickkey
		if (dir == 0 or dir == 2) then
			local c2 = GetCell(x,y-1)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				if PullCell(x,y-1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x,y+1)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				if PullCell(x,y+1,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		elseif (dir == 1 or dir == 3) then
			local c2 = GetCell(x+1,y)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				if PullCell(x+1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			local c2 = GetCell(x-1,y)
			if c2.sticky == cell.sticky and c2.stickkey ~= stickkey then
				local vars2 = table.copy(vars)
				vars2.force = force
				if PullCell(x-1,y,dir,vars2) then
					table.merge(vars.undocells,vars2.undocells)
				else
					return 0
				end
			end
			if GetCell(x,y) ~= cell then
				vars.ended = true
			end
		end
	end
	return force
end

function HandleSwap(cell,dir,x,y,vars)
	local id = cell.id
	local rot = cell.rot
	local side = ToSide(rot,dir)
	local above = GetCell(x,y,1)
	local aboveside = ToSide(above.rot,dir)
	if (above.id == 558) and (aboveside > 3 or aboveside < 1) or above.id == 559 and (aboveside > 2 or aboveside < 1)
	or above.id == 560 and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3) or above.id == 561 and aboveside ~= 2 or above.id == 562 then
		if fancy then table.safeinsert(above,"eatencells",vars.lastcell) end
		Play("destroy")
		return
	end
	if vars.active == "collide" then
		local dmg = math.min(GetHP(InvertLasts(cell,dir,x,y,vars)),GetHP(cell,dir,x,y,vars))
		DamageCell(vars.lastcell,dmg,(dir+2)%4,x,y,vars)
		DamageCell(cell,dmg,dir,x,y,vars)
		Play("destroy")
	elseif (id == 12 or id == 225 or id == 226 or id == 300 or id == 44 or id == 155 or id == 250 or id == 251 or id == 317 or id == 344 or id == 345 or id == 672 or id == 735
	or id == 814 or (id == 353 or id == 354) and side%2 == 1 or id == 436 or id == 437 or id == 815 or id == 816 or id == 817 or id == 819 or id == 1116) and vars.active == "destroy" then
		table.safeinsert(cell,"eatencells",vars.lastcell)
		Play("destroy")
	elseif (id == 205 or (id == 351 or id == 552) and cell.vars[side+1] == 6) and vars.active == "destroy" then
		table.safeinsert(cell,"eatencells",vars.lastcell)
	elseif (id == 347 or id == 349 or (id == 351 or id == 552) and (cell.vars[side+1] == 7 or cell.vars[side+1] == 8 or cell.vars[side+1] == 9 or cell.vars[side+1] == 10) or id == 438 or id == 439 or id == 440 or id == 441 or id == 463 or id == 694 or id == 695 or id == 856) and vars.active == "destroy" then
		local cdir = (id == 347 or id == 349 or (id == 351 or id == 552) and cell.vars[side+1] == 7) and dir
		or (id == 694 or id == 695 or (id == 351 or id == 552) and cell.vars[side+1] == 8) and (dir+2)%4
		or (id == 438 or id == 439 or (id == 351 or id == 552) and cell.vars[side+1] == 9) and (dir-1)%4
		or (id == 440 or id == 441 or (id == 351 or id == 552) and cell.vars[side+1] == 10) and (dir+1)%4
		or (id == 463 or id == 856) and rot
		if (id == 351 or id == 552) then
			local neighbors = GetNeighbors(x,y)
			for k,v in pairs(neighbors) do
				local c = GetCell(v[1],v[2])
				if cell.vars[(k-cell.rot)%4+1] == 12 and not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
					DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
				end
			end
		end
		table.safeinsert(cell,"eatencells",vars.lastcell)
		PushCell(x,y,cdir,{force=1,skipfirst=true})
		if id ~= 349 and id ~= 439 and id ~= 441 and id ~= 856 then Play("destroy") end
	elseif id == 563 and vars.active == "destroy" then
		table.safeinsert(cell,"eatencells",vars.lastcell)
		if not vars.checkonly then
			switches[cell.vars[1]] = not switches[cell.vars[1]] and true or nil
			cell.vars[2] = switches[cell.vars[1]]
			Play("destroy")
		end
	elseif id == 154 and vars.lastcell.id == 153 then
		SetCell(x,y,getempty())
		EmitParticles("sparkle",x,y)
		Play("unlock")
	elseif id == 154 and vars.lastcell.id == 584 then
		SetCell(x,y,vars.lastcell)
		EmitParticles("sparkle",x,y)
		Play("unlock")
	elseif id == 165 or (id == 175 or id == 362 or id == 704 or id == 821 or id == 822 or id == 823 or id == 831 or id == 905) and not cell.vars[1] then
		cell.updatekey = updatekey
		if cell.vars[1] then
			local cx,cy = StepForward(x,y,dir)
			PushCell(cx,cy,dir,{force=1,replacecell=GetStoredCell(cell,true)})
			cell.vars = {}
		end
		if not IsNonexistant(vars.lastcell,dir,x,y) then
			cell.vars[1] = vars.lastcell.id
			cell.vars[2] = vars.lastcell.rot
		end
	elseif (id == 645 or id == 1150 or id == 1151 or id == 1154) and not cell.vars[1] then
		if vars.lastcell.id ~= 0 then
			cell.vars[1] = vars.lastcell.id
			cell.vars[2] = vars.lastcell.rot
			cell.updated = true
		end
	elseif id == 51 or id == 670 or id == 848 or id == 850 or id == 852 or id == 854 or id == 857 then
		local cdir = id == 848 and dir or id == 850 and (dir-1)%4 or id == 852 and (dir+1)%4 or id == 854 and (dir+2)%4 or id == 857 and cell.rot or nil
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			local c = GetCell(v[1],v[2])
			if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
				DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
			end
		end
		if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		if cdir then PushCell(x,y,cdir,{force=1,skipfirst=true}) end
		if id ~= 670 then Play("destroy") end
	elseif id == 141 or id == 671 or id == 849 or id == 851 or id == 853 or id == 855 or id == 858 then
		local cdir = id == 849 and dir or id == 851 and (dir-1)%4 or id == 853 and (dir+1)%4 or id == 855 and (dir+2)%4 or id == 858 and cell.rot or nil
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			local c = GetCell(v[1],v[2])
			if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
				DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
			end
		end
		if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		if cdir then PushCell(x,y,cdir,{force=1,skipfirst=true}) end
		if id ~= 671 then Play("destroy") end
	elseif (id == 351 or id == 552) and (cell.vars[side+1] == 5 or cell.vars[side+1] == 6 or cell.vars[side+1] == 12) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			local c = GetCell(v[1],v[2])
			if cell.vars[(k-cell.rot)%4+1] == 12 and not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
				DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
			end
		end
		if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		if cell.vars[side+1] ~= 6 then Play("destroy") end
	elseif id == 176 then
		if not IsUnbreakable(GetCell(vars.lastx,vars.lasty),(vars.lastdir+2)%4,vars.lastx,vars.lasty,{forcetype="infect",lastcell=cell}) then
			SetCell(vars.lastx,vars.lasty,table.copy(cell))
			Play("destroy")
			Play("infect")
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		end
	elseif id == 890 or id == 891 or id == 892 or id == 893 or id == 894 or id == 895 then
		if id == 890 or id == 892 or id == 894 then Play("destroy") end
		if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		local cdir = (id == 892 or id == 893) and (dir+1)%4 or (id == 894 or id == 895) and (dir-1)%4 or dir 
		local cx,cy = StepForward(x,y,cdir)
		PushCell(cx,cy,cdir,{force=1})
	elseif id == 897 or id == 898 or id == 899 or id == 900 or id == 901 or id == 902 then
		Play("destroy")
		if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		local cdir = (id == 899 or id == 900) and (dir+1)%4 or (id == 901 or id == 902) and (dir-1)%4 or dir 
		local cx,cy = StepForward(x,y,cdir)
		PushCell(cx,cy,cdir,{force=1})
		local neighbors = ((id == 898 or id == 900 or id == 902) and GetSurrounding or GetNeighbors)(x,y)
		for k,v in pairs(neighbors) do
			local c = GetCell(v[1],v[2])
			if not IsUnbreakable(c,k,v[1],v[2],{forcetype="destroy",lastcell=cell}) then
				DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],vars)
			end
		end
	elseif id == 908 or id == 909 then
		Play("destroy")
		if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		cell.vars[2] = not cell.vars[2] and true or nil
	elseif (id == 32 or id == 33 or id == 34 or id == 35 or id == 36 or id == 37 or id == 194 or id == 195 or id == 196 or id == 197) and not IsNonexistant(vars.lastcell,dir,x,y,vars) then
		if side == 3 then
			cell.inl = true
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		elseif side == 1 then
			cell.inr = true
			if fancy then table.safeinsert(cell,"eatencells",vars.lastcell) end
		else return 0 end
	elseif id == 1200 then
		if not vars.checkonly then
			scriptx,scripty=x,y
			ExecuteScriptCell(cell)
		end
	end
	ExecuteQueue("swap")
end

function CanMove(cell,dir,x,y,ftype,force)
	local vars = {noupdate=true,checkonly=true,undocells={},lastx=x,lasty=y,lastcell=getempty(),repeats=1}
	if ftype == "pull" then
		return HandlePull(force or 1,cell,dir,x,y,vars) > 0 and not IsDestroyer(cell,dir,x,y,{forcetype="pull"}) and not vars.ended
	elseif ftype == "grab" then
		return HandleGrab(force or 1,cell,dir,x,y,vars) > 0 and not IsDestroyer(cell,dir,x,y,{forcetype="grab"}) and not vars.ended
	else
		return HandlePush(force or 1,cell,dir,x,y,vars) > 0 and not IsDestroyer(cell,dir,x,y,{forcetype="push"}) and not vars.ended
	end
end

function NudgeCell(x,y,dir,vars)
	vars = vars or {}
	local cell = GetCell(x,y)
	vars.lastcell = cell
	if IsNonexistant(cell,dir,x,y) then return true end
	local above = GetCell(x,y,1)
	local aboveside = ToSide(above.rot,dir)
	local oldcell = table.copy(cell)
	local cx,cy,cdir = NextCell(x,y,dir,vars)
	if above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 706 or above.id == 916 then
		return false,cx,cy,cdir
	elseif above.id == 566 and above.vars[2] == 0 then
		above.vars[2] = above.vars[1]+1
		EmitParticles("staller",x,y)
		return true,cx,cy,cdir
	end
	if cx then
		vars.replacecell = vars.replacecell or getempty()
		local checkedcell = GetCell(cx,cy)
		local above = GetCell(cx,cy,1)
		local aboveside = ToSide(above.rot,dir)
		if above.id == 553 and (aboveside > 3 or aboveside < 1) or above.id == 554 and (aboveside > 2 or aboveside < 1)
		or above.id == 555 and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3) or above.id == 556 and aboveside ~= 2 or above.id == 557
		or above.id == 564 and not switches[above.vars[1]] or above.id == 565 and switches[above.vars[1]] or above.id == 916 then
			SetCell(x,y,oldcell)
			return false,cx,cy,cdir
		elseif (above.id == 558) and (aboveside > 3 or aboveside < 1) or above.id == 559 and (aboveside > 2 or aboveside < 1) or above.id == 560 and (aboveside > 3 or aboveside < 1 or aboveside > 1 and aboveside < 3) or above.id == 561 and aboveside ~= 2 or above.id == 562 then
			SetCell(x,y,vars.replacecell)
			if fancy then table.safeinsert(above,"eatencells",cell) end
			return true,cx,cy,cdir
		elseif above.id == 566 and above.vars[2] == 0 then
			SetCell(x,y,oldcell)
			above.vars[2] = above.vars[1]+1
			EmitParticles("staller",cx,cy)
			return false,cx,cy,cdir
		elseif above.id == 706 then
			if oldcell == 705 then
				SetCell(x,y,vars.replacecell)
				above.id = 707
				Play("unlock")
				EmitParticles("quantum",cx,cy)
				return true,cx,cy,cdir
			else
				SetCell(x,y,oldcell)
				return false,cx,cy,cdir
			end
		elseif above.id == 707 and oldcell.id == 705 then
			SetCell(x,y,vars.replacecell)
			above.id = 706
			Play("unlock")
			EmitParticles("quantum",cx,cy)
			return true,cx,cy,cdir
		end
		vars.forcetype = "nudge"
		vars.lastcell = vars.skipfirst and getempty() or cell
		vars.lastx,vars.lasty = StepBack(x,y,dir)
		vars.lastdir = dir
		logforce(x,y,dir,vars,oldcell)
		vars.lastx,vars.lasty,vars.lastdir = x,y,dir
		local destroy = IsDestroyer(checkedcell,cdir,cx,cy,vars)
		if vars.forcedestroy or destroy and (x ~= cx or y ~= cy) then
			SetCell(x,y,vars.replacecell)
			vars.active = destroy
			HandleNudge(checkedcell,cdir,cx,cy,vars)
			Play("move")
			ExecuteQueue("postnudge")
			return true,cx,cy,cdir
		elseif IsNonexistant(checkedcell,cdir,cx,cy,vars) or x == cx and y == cy and IsNonexistant(vars.replacecell,cdir,cx,cy,vars) then
			if vars.undocells then vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or checkedcell end
			SetCell(x,y,vars.replacecell)
			SetCell(cx,cy,cell)
			vars.active = "replace"
			HandleNudge(checkedcell,cdir,cx,cy,vars)
			Play("move")
			ExecuteQueue("postnudge")
			return true,cx,cy,cdir
		end
		SetCell(x,y,oldcell)
		vars.lastcell = vars.skipfirst and getempty() or oldcell
		HandleNudge(checkedcell,cdir,cx,cy,vars)
	end
	ExecuteQueue("postnudge")
	return false,cx,cy,cdir
end

function NudgeCellTo(lastcell,x,y,dir,vars)
	vars = vars or {}
	local checkedcell = GetCell(x,y)
	vars.forcetype = "nudge"
	vars.lastcell = lastcell
	vars.lastx,vars.lasty,vars.lastdir = x,y,dir
	logforce(x,y,dir,vars,checkedcell)
	local destroy = IsDestroyer(checkedcell,dir,x,y,vars)
	if vars.forcedestroy or destroy then
		vars.active = destroy
		HandleNudge(checkedcell,dir,x,y,vars)
		Play("move")
		ExecuteQueue("postnudge")
		return true,x,y,dir
	elseif IsTransparent(checkedcell,dir,x,y,vars) then
		if vars.undocells then vars.undocells[x+y*width] = vars.undocells[x+y*width] or checkedcell end
		SetCell(x,y,lastcell)
		vars.active = "replace"
		HandleNudge(checkedcell,dir,x,y,vars)
		Play("move")
		ExecuteQueue("postnudge")
		return true,x,y,dir
	end
	ExecuteQueue("postnudge")
	return false,x,y,dir
end

function PushCell(x,y,dir,vars)
	vars = vars or {}
	vars.startcell = GetCell(x,y,vars.layer)
	if vars.startcell.id == 231 or vars.startcell.id == 249 and vars.startcell.rot%2 == dir%2 or vars.startcell.sticky then
		local cx,cy = StepBack(x,y,dir)
		if (GetCell(cx,cy).id == 231 or GetCell(cx,cy).id == 249 and GetCell(cx,cy).rot%2 == dir%2 or GetCell(cx,cy).sticky and GetCell(cx,cy).sticky == vars.startcell.sticky) and GetCell(cx,cy).stickkey ~= stickkey then
			return PushCell(cx,cy,dir,vars)
		end
	end
	vars.firstx,vars.firsty,vars.firstdir = x,y,dir
	x,y = StepBack(x,y,dir)
	local cx,cy,cdir = x,y,dir
	local force = vars.force or 0
	vars.lastcell = vars.replacecell or getempty()
	vars.forcetype = "push"
	vars.undocells = vars.undocells or {}
	vars.optimizegen = true
	vars.maximum = vars.maximum == 0 and math.huge or vars.maximum or math.huge
	vars.repeats = vars.repeats or (vars.noupdate and 1 or 0)
	vars.bend = vars.bend and 0
	updatekey = updatekey + 1
	if vars.startcell.vars.gravdir and vars.startcell.vars.gravdir%4 == dir and vars.repeats == 0 then	--mover shenanigans
		force = force - 1
	end
	local data
	repeat
		vars.lastx,vars.lasty,vars.lastdir = cx,cy,cdir
		cx,cy,cdir = NextCell(cx,cy,cdir,vars)
		if not cx or vars.repeats > vars.maximum then force = 0 break end
		local oldcell = GetCell(cx,cy,vars.layer)
		logforce(cx,cy,cdir,vars,oldcell)
		vars.destroying = vars.forcedestroy or not vars.skipfirst and IsDestroyer(oldcell,cdir,cx,cy,vars)
		local oldforce = force
		force = HandlePush(force,oldcell,cdir,cx,cy,vars)
		oldcell.testvar = force
		vars.stopped = force <= 0
		if vars.stopped and vars.bend and vars.bend ~= 2 then
			cx,cy,cdir = vars.lastx,vars.lasty,vars.lastdir
			local newdir = vars.bend == 1 and (cdir+2)%4 or (cdir%2 == 0 and 3 or 0)
			vars.benddifference = (vars.benddifference or 0)+newdir-cdir
			cdir = newdir
			vars.bend = vars.bend+1
			vars.repeats = vars.repeats-1
			force = oldforce
			goto continue
		end
		if vars.benddifference then
			RotateCellRaw(vars.lastcell,(vars.benddifference-2)%4+2)
			vars.benddifference = nil
		end
		vars.bend = vars.bend and 0
		if vars.ended then oldcell.testvar = "prebreak" break end	--silicon
		vars.ended = not vars.skipfirst and (IsTransparent(oldcell,cdir,cx,cy,vars) or force <= 0)
		vars.skipfirst = false
		if not vars.destroying then vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or table.copy(oldcell) SetCell(cx,cy,vars.lastcell) end
		if vars.row and cx >= 0 and cx < width and cy >= 0 and cy < height and force > 0 and vars.ended and not vars.destroying then
			vars.ended = false
			vars.undocells = {}
			vars.forcetrue = true
		end
		vars.lastcell = oldcell
		data = GetData(cx,cy)
		if data.updatekey == updatekey and data.crosses >= 5 then
			force = 0
			vars.lastcell.testvar = "loop"
			break
		else
			data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
		end
		data.updatekey = updatekey
		vars.repeats = vars.repeats + 1
		::continue::
	until vars.ended
	vars.endx,vars.endy,vars.enddir = cx,cy,cdir
	if force <= 0 then
		for k,v in pairs(vars.undocells) do
			SetCell(k%width,math.floor(k/width),v)
		end
		ExecuteQueue("postpush")
		return vars.forcetrue or false,vars.optimizegen
	end
	Play("move")
	ExecuteQueue("postpush")
	return not vars.forcefalse,false
end

function LGrabCell(x,y,dir,vars)
	vars = vars or {}
	vars.startcell = GetCell(x,y,vars.layer)
	if vars.startcell.id == 231 or vars.startcell.id == 249 and vars.startcell.rot%2 ~= dir%2 or vars.startcell.sticky then
		local cx,cy = StepRight(x,y,dir)
		if (GetCell(cx,cy).id == 231 or GetCell(cx,cy).id == 249 and GetCell(cx,cy).rot%2 ~= dir%2 or GetCell(cx,cy).sticky and GetCell(cx,cy).sticky == vars.startcell.sticky) and GetCell(cx,cy).stickkey ~= stickkey then
			return LGrabCell(cx,cy,dir,vars)
		end
	end
	vars.firstx,vars.firsty,vars.firstdir = x,y,dir
	x,y = StepRight(x,y,dir)
	local cx,cy,cdir = x,y,dir
	vars.lastcell = getempty()
	vars.undocells = {}
	vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or GetCell(cx,cy,vars.layer)
	vars.side = "left"
	vars.maximum = vars.maximum == 0 and math.huge or vars.maximum or math.huge
	vars.repeats = vars.failonfirst and 0 or 1
	local force = vars.force or 0
	updatekey = updatekey + 1
	repeat
		vars.forcetype = "grab"
		vars.repeats = vars.repeats + 1
		vars.lastx,vars.lasty,vars.lastdir = cx,cy,cdir
		cx,cy,cdir = NextCell(cx,cy,(cdir-1)%4,vars)
		if not cx or vars.repeats > vars.maximum then vars.ended = true break end
		cdir = (cdir+1)%4
		local oldcell = GetCell(cx,cy,vars.layer)
		vars.forcetype = "grabL"
		logforce(cx,cy,cdir,vars,oldcell)
		vars.forcetype = "grab"
		local transparent 
		local bluh
		if not vars.skipfirst or vars.repeats > 1 then
			force = HandleGrab(force,oldcell,cdir,cx,cy,vars)
			oldcell.testvar = force
			transparent = transparent or IsTransparent(oldcell,(cdir-1)%4,cx,cy,vars)
		else vars.skipfirst = false end
		if oldcell.pulledside == ToSide(oldcell.rot,cdir) and oldcell.updatekey == updatekey then transparent = true end
		oldcell.pulledside = ToSide(oldcell.rot,cdir)
		oldcell.updatekey = updatekey
		vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or table.copy(oldcell)
		if vars.strong then
			local pvars = table.copy(vars)
			pvars.undocells = {}
			pvars.maximum = nil
			pvars.force = HandlePush(1,oldcell,cdir,cx,cy,{checkonly=true,undocells=pvars.undocells,lastcell=getempty(),lastx=x,lasty=y})
			pvars.skipfirst = true
			vars.ended = vars.ended or transparent or not PushCell(cx,cy,cdir,pvars)
			table.merge(vars.undocells,pvars.undocells)
		else
			vars.ended = vars.ended or transparent or not NudgeCell(cx,cy,cdir,vars) and GetCell(cx,cy,vars.layer) == vars.lastcell
		end
		if vars.ended and not transparent and not vars.strong then SetCell(cx,cy,vars.undocells[cx+cy*width]) break end
		vars.lastcell = getempty()
		local data = GetData(cx,cy)
		if data.updatekey == updatekey and data.crosses >= 5 then
			force = 0
			break
		else
			data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
		end
		data.updatekey = updatekey
	until force <= 0 or vars.ended or cx == x and cy == y and cdir == dir
	vars.endx,vars.endy,vars.enddir = cx,cy,cdir
	if force <= 0 then
		for k,v in pairs(vars.undocells) do
			SetCell(k%width,math.floor(k/width),v)
		end
		ExecuteQueue("postgrab")
		return false
	end
	ExecuteQueue("postgrab")
	return not vars.failonfirst or vars.repeats > 1,force
end

function RGrabCell(x,y,dir,vars)
	vars = vars or {}
	vars.startcell = GetCell(x,y,vars.layer)
	if vars.startcell.id == 231 or vars.startcell.id == 249 and vars.startcell.rot%2 ~= dir%2 or vars.startcell.sticky then
		local cx,cy = StepLeft(x,y,dir)
		if (GetCell(cx,cy).id == 231 or GetCell(cx,cy).id == 249 and GetCell(cx,cy).rot%2 ~= dir%2 or GetCell(cx,cy).sticky and GetCell(cx,cy).sticky == vars.startcell.sticky) and GetCell(cx,cy).stickkey ~= stickkey then
			return RGrabCell(cx,cy,dir,vars)
		end
	end
	vars.firstx,vars.firsty,vars.firstdir = x,y,dir
	x,y = StepLeft(x,y,dir)
	local cx,cy,cdir = x,y,dir
	vars.lastcell = getempty()
	vars.undocells = {}
	vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or GetCell(cx,cy,vars.layer)
	vars.side = "right"
	vars.maximum = vars.maximum == 0 and math.huge or vars.maximum or math.huge
	vars.repeats = vars.failonfirst and 0 or 1
	local force = vars.force or 0
	updatekey = updatekey + 1
	repeat
		vars.forcetype = "grab"
		vars.repeats = vars.repeats + 1
		vars.lastx,vars.lasty,vars.lastdir = cx,cy,cdir
		cx,cy,cdir = NextCell(cx,cy,(cdir+1)%4,vars)
		if not cx or vars.repeats > vars.maximum then vars.ended = true break end
		cdir = (cdir-1)%4
		local oldcell = GetCell(cx,cy,vars.layer)
		vars.forcetype = "grabR"
		logforce(cx,cy,cdir,vars,oldcell)
		vars.forcetype = "grab"
		local transparent 
		if not vars.skipfirst or vars.repeats > 1 then
			force = HandleGrab(force,oldcell,cdir,cx,cy,vars)
			oldcell.testvar = force
			transparent = transparent or IsTransparent(oldcell,(cdir+1)%4,cx,cy,vars)
		else vars.skipfirst = false end
		if oldcell.pulledside == ToSide(oldcell.rot,cdir) and oldcell.updatekey == updatekey then transparent = true end
		oldcell.pulledside = ToSide(oldcell.rot,cdir)
		oldcell.updatekey = updatekey
		vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or table.copy(oldcell)
		if vars.strong then
			local pvars = table.copy(vars)
			pvars.undocells = {}
			pvars.force = HandlePush(1,oldcell,cdir,cx,cy,{checkonly=true,undocells=pvars.undocells,lastcell=getempty(),lastx=x,lasty=y})
			pvars.skipfirst = true
			vars.ended = vars.ended or transparent or not PushCell(cx,cy,cdir,pvars)
			table.merge(vars.undocells,pvars.undocells)
		else
			vars.ended = vars.ended or transparent or not NudgeCell(cx,cy,cdir,vars) and GetCell(cx,cy,vars.layer) == vars.lastcell
		end
		if vars.ended and not transparent and not vars.strong then SetCell(cx,cy,vars.undocells[cx+cy*width]) break end
		vars.lastcell = getempty()
		local data = GetData(cx,cy)
		if data.updatekey == updatekey and data.crosses >= 5 then
			force = 0
			break
		else
			data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
		end
		data.updatekey = updatekey
	until force <= 0 or vars.ended or cx == x and cy == y and cdir == dir
	vars.endx,vars.endy,vars.enddir = cx,cy,cdir
	if force <= 0 then
		for k,v in pairs(vars.undocells) do
			SetCell(k%width,math.floor(k/width),v)
		end
		ExecuteQueue("postgrab")
		return false
	end
	ExecuteQueue("postgrab")
	return not vars.failonfirst or vars.repeats > 1,force
end

function GrabCell(x,y,dir,vars)
	vars = vars or {}
	local vars2 = table.copy(vars)
	vars2.failonfirst = true
	local oldcell = GetCell(x,y,vars.layer)
	local vars3 = {}
	vars3.lastx,vars3.lasty = StepBack(x,y,dir)
	vars3.lastdir = dir
	vars3.forcetype = "grab"
	logforce(x,y,dir,vars3,oldcell)
	local success,force = LGrabCell(x,y,dir,vars2)
	if success and GetCell(x,y,vars.layer) ~= oldcell then
		vars.force = force
		x,y = StepRight(x,y,dir)
		local success2,undocells2 = RGrabCell(x,y,dir,vars)
		if not success2 then
			for k,v in pairs(vars2.undocells) do
				SetCell(k%width,math.floor(k/width),v)
			end
			return false
		end
		x,y = StepLeft(x,y,dir)
	else return false end
	table.merge(vars.undocells,vars2.undocells)
	Play("move")
	return true
end

function GrabEmptyCell(x,y,dir,vars)	--convenience
	vars = vars or {}
	local vars2 = table.copy(vars)
	x,y = StepLeft(x,y,dir)
	local success,force = LGrabCell(x,y,dir,vars2)
	if success then
		vars.force = force
		x,y = StepRight(x,y,dir)
		x,y = StepRight(x,y,dir)
		local success2 = RGrabCell(x,y,dir,vars)
		if not success2 then
			for k,v in pairs(vars2.undocells) do
				SetCell(k%width,math.floor(k/width),v)
			end
			return false
		end
		x,y = StepLeft(x,y,dir)
	else return false end
	table.merge(vars.undocells,vars2.undocells)
	Play("move")
	return true
end

function PullCell(x,y,dir,vars)
	vars = vars or {}
	vars.startcell = GetCell(x,y,vars.layer)
	if vars.startcell.id == 231 or vars.startcell.id == 249 and vars.startcell.rot%2 == dir%2 or vars.startcell.sticky then
		local cx,cy = StepForward(x,y,dir)
		if (GetCell(cx,cy).id == 231 or GetCell(cx,cy).id == 249 and GetCell(cx,cy).rot%2 == dir%2 or GetCell(cx,cy).sticky and GetCell(cx,cy).sticky == vars.startcell.sticky) and GetCell(cx,cy).stickkey ~= stickkey then
			return PullCell(cx,cy,dir,vars)
		end
	end
	vars.firstx,vars.firsty,vars.firstdir = x,y,dir
	x,y = StepForward(x,y,dir)
	local cx,cy,cdir = x,y,dir
	vars.lastcell = getempty()
	vars.undocells = vars.undocells or {}
	vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or GetCell(cx,cy,vars.layer)
	vars.maximum = vars.maximum == 0 and math.huge or vars.maximum or math.huge
	vars.repeats = 0
	local force = vars.force or 0
	updatekey = updatekey + 1
	repeat
		vars.forcetype = "pull"
		vars.repeats = vars.repeats + 1
		vars.lastx,vars.lasty,vars.lastdir = cx,cy,cdir
		cx,cy,cdir = NextCell(cx,cy,(cdir+2)%4,vars,true)
		if not cx or vars.repeats > vars.maximum then vars.ended = true break end
		cdir = (cdir+2)%4
		local oldcell = GetCell(cx,cy,vars.layer)
		logforce(cx,cy,cdir,vars,oldcell)
		local transparent
		if not vars.skipfirst or vars.repeats > 1 then
			force = HandlePull(force,oldcell,cdir,cx,cy,vars)
			oldcell.testvar = forc
			vars.row =  cx >= 0 and cx < width and cy >= 0 and cy < height and vars.row or false
			transparent = vars.row and IsDestroyer(oldcell,(cdir+2)%4,cx,cy,vars) or IsTransparent(oldcell,(cdir+2)%4,cx,cy,vars)
			if vars.row and IsNonexistant(oldcell,(cdir+2)%4,cx,cy,vars) then
				vars.undocells = {}
				vars.forcetrue = true
				transparent = false
				bluh = true
			end
		else vars.skipfirst = false end
		if oldcell.pulledside == ToSide(oldcell.rot,cdir) and oldcell.updatekey == updatekey then vars.ended = true end
		if not bluh then oldcell.pulledside = ToSide(oldcell.rot,cdir) end
		oldcell.updatekey = updatekey
		vars.undocells[cx+cy*width] = vars.undocells[cx+cy*width] or oldcell
		vars.ended = vars.ended or transparent or not NudgeCell(cx,cy,cdir,vars) and GetCell(cx,cy,vars.layer) == vars.lastcell
		if not vars.ended then vars.lastcell = getempty() end
		local data = GetData(cx,cy)
		if data.updatekey == updatekey and data.crosses >= 5 then
			force = 0
			break
		else
			data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
		end
		data.updatekey = updatekey
	until force <= 0 or vars.ended or cx == x and cy == y and cdir == dir
	vars.endx,vars.endy,vars.enddir = cx,cy,cdir
	if force <= 0 then
		for k,v in pairs(vars.undocells) do
			SetCell(k%width,math.floor(k/width),v)
		end
		ExecuteQueue("postpull")
		return vars.forcetrue or false
	end
	ExecuteQueue("postpull")
	x,y = StepBack(x,y,dir)
	if vars.repeats > 1 or vars.dontfailonfirst or IsNonexistant(vars.startcell,dir,x,y,vars) then Play("move") return true end
	return vars.forcetrue or false
end

function SwapCells(x1,y1,dir1,x2,y2,dir2,vars)
	vars = vars or {}
	local cell1 = GetCell(x1,y1,vars.layer)
	local cell2 = CopyCell(x2,y2,vars.layer)
	local dest1,dest2 = IsDestroyer(cell1,dir1,x1,y1,{lastcell=cell2,forcetype="swap",lastx=x2,lasty=y2,lastdir=dir2,layer=vars.layer}),IsDestroyer(cell2,dir2,x2,y2,{lastcell=cell1,lastx=x1,lasty=y1,lastdir=dir1,forcetype="swap",layer=vars.layer})
	local unb1,unb2 = IsUnbreakable(cell1,dir1,x1,y1,{lastcell=cell2,forcetype="swap",lastx=x2,lasty=y2,lastdir=dir2,layer=vars.layer}),IsUnbreakable(cell2,dir2,x2,y2,{lastcell=cell1,lastx=x1,lasty=y1,lastdir=dir1,forcetype="swap",layer=vars.layer})
	local non1,non2 = IsNonexistant(cell1,dir1,x1,y1),IsNonexistant(cell2,dir2,x2,y2)
	cell1.testvar = "A"
	cell2.testvar = "B"
	GetCell(x2,y2,vars.layer).testvar = "B"
	local mx, my = (x1+x2)/2, (y1+y2)/2
	local vars2 = {}
	vars2.lastx,vars2.lasty = mx,my
	vars2.lastdir = dir1
	vars2.forcetype = "swap"
	logforce(x1,y1,dir1,vars2,cell1,false)
	local vars3 = {}
	vars3.lastx,vars3.lasty = mx,my
	vars3.lastdir = dir2
	vars3.forcetype = "swap"
	logforce(x2,y2,dir2,vars3,cell2)
	if (not unb1 or dest1) or (not unb2 or dest2) then
		if dest1 and not unb2 and not non2 then
			SetCell(x2,y2,getempty())
			HandleSwap(cell1,dir1,x1,y1,{lastcell=cell2,lastx=x2,lasty=y2,lastdir=dir2,active=dest1})
			Play("move")
			return dest1
		elseif not unb1 and dest2 and not non1 then
			SetCell(x1,y1,getempty())
			HandleSwap(GetCell(x2,y2,vars.layer),dir2,x2,y2,{lastcell=cell1,lastx=x1,lasty=y1,lastdir=dir1,active=dest2})
			Play("move")
			return dest2
		elseif unb1 and not unb2 and not non2 then
			HandleSwap(GetCell(x1,y1,vars.layer),dir1,x1,y1,{lastcell=GetCell(x2,y2,vars.layer),lastx=x2,lasty=y2,lastdir=dir2})
			return false
		elseif not unb1 and unb2 and not non1 then
			HandleSwap(GetCell(x2,y2,vars.layer),dir2,x2,y2,{lastcell=cell1,lastx=x1,lasty=y1,lastdir=dir1})
			return false
		elseif not unb1 and not unb2 then
			SetCell(x2,y2,cell1)
			SetCell(x1,y1,cell2)
			HandleSwap(GetCell(x1,y1,vars.layer),dir1,x1,y1,{lastcell=GetCell(x2,y2,vars.layer),lastx=x2,lasty=y2,lastdir=dir2,active="swap"})
			HandleSwap(GetCell(x2,y2,vars.layer),dir2,x2,y2,{lastcell=cell1,lastx=x1,lasty=y1,lastdir=dir1,active="swap"})
			Play("move")
			return true
		end
	end
	return false
end

function RunOn(runwhen,torun,direction,chunktype,layer,startx,endx,starty,endy,hasborder,runafter)	
	return wrap(function(doyield)
		layer = layer or 0
		if not chunks[layer].all[chunktype] and not hasborder then return false end
		local right,down,xfirst
		right = direction == "rightdown" or direction == "downright" or direction == "rightup" or direction == "upright"
		down = direction == "rightdown" or direction == "downright" or direction == "leftdown" or direction == "downleft"
		xfirst = direction == "rightdown" or direction == "leftdown" or direction == "rightup" or direction == "leftup"
		local didsomething = false
		if xfirst then
			endx = endx or right and width-2 or 1
			endy = endy or down and height-2 or 1
			local cy = starty or down and 1 or height-2
			while down and cy <= endy or not down and cy >= endy do
				local didsomethinglocal = false
				local cx = startx or right and 1 or width-2
				local yinvsize = 1/2^maxchunksize
				while right and cx <= endx or not right and cx >= endx do
					local cell = layers[layer][cy][cx]
					if runwhen(cell) then
						torun(cx,cy,cell)
						updatekey = updatekey + 1
						didsomething = true
						didsomethinglocal = true
						cx = cx + (right and 1 or -1)
						yinvsize = 1
						if doyield then
							for i,force in ipairs(forcespread) do
								local cell = force.cell
								cell.vars.forceinterp = nil
								cell.lastvars = {force.x,force.y,cell.rot-force.rot}
							end
							forcespread = {}
							currentsst = cell
							coroutine.yield(true)
						end
					else
						local invsize = GetChunk(cx,cy,layer,chunktype)
						cx = right and math.floor(cx*invsize+1)/invsize or math.floor(cx*invsize)/invsize-1
						yinvsize = math.max(yinvsize,invsize)
						if hasborder then
							cx = right and math.min(cx,width-1) or math.max(cx,0)
						end
					end
				end
				local oldcy = cy
				cy = down and math.floor(cy*yinvsize+1)/yinvsize or math.floor(cy*yinvsize)/yinvsize-1
				if hasborder and oldcy > 0 and oldcy < height-1 then
					cy = down and math.min(cy,height-1) or math.max(cy,0)
				end
			end
		else
			endx = endx or right and width-2 or 1
			endy = endy or down and height-2 or 1
			local cx = startx or right and 1 or width-2
			while right and cx <= endx or not right and cx >= endx do
				local didsomethinglocal = false
				local cy = starty or down and 1 or height-2
				local xinvsize = 1/2^(maxchunksize+1)
				while down and cy <= endy or not down and cy >= endy do
					local cell = layers[layer][cy][cx]
					if runwhen(cell) then
						torun(cx,cy,cell)
						updatekey = updatekey + 1
						didsomething = true
						didsomethinglocal = true
						cy = cy + (down and 1 or -1)
						xinvsize = 1
						if doyield then
							for i,force in ipairs(forcespread) do
								local cell = force.cell
								cell.vars.forceinterp = nil
								cell.lastvars = {force.x,force.y,cell.rot-force.rot}
							end
							forcespread = {}
							currentsst = cell
							coroutine.yield(true)
						end
					else
						local invsize = GetChunk(cx,cy,layer,chunktype)
						cy = down and math.floor(cy*invsize+1)/invsize or math.floor(cy*invsize)/invsize-1
						xinvsize = math.max(xinvsize,invsize)
						if hasborder then
							cy = down and math.min(cy,height-1) or math.max(cy,0)
						end
					end
				end
				local oldcx = cx
				cx = right and math.floor(cx*xinvsize+1)/xinvsize or math.floor(cx*xinvsize)/xinvsize-1
				if hasborder and oldcx > 0 and oldcx < width-1 then
					cx = right and math.min(cx,width-1) or math.max(cx,0)
				end
			end
		end
		if runafter then runafter() end
		return didsomething
	end)
end

function DoCheater(x,y,cell)
	cell.updated = true
	if cell.id == 199 then
		local dir = cell.rot
		x,y = StepBack(x,y,dir)
		vars = vars or {}
		local cx,cy = x,y
		vars.lastcell = getempty()
		repeat
			cx,cy = StepForward(cx,cy,dir)
			local oldcell = GetCell(cx,cy)
			SetCell(cx,cy,vars.lastcell)
			vars.ended = IsNonexistant(oldcell,dir,cx,cy,vars)
			vars.lastcell = table.copy(oldcell)
		until vars.ended
		Play("move")
	elseif cell.id == 200 then
		local dir = cell.rot
		local cx,cy = x,y
		while not IsNonexistant(GetCell(cx,cy),dir,cx,cy) do
			cx,cy = StepBack(cx,cy,dir)
			if cx <= 0 or cy <= 0 or cx >= width-1 or cy >= height-1 then break end
		end
		vars = vars or {}
		vars.lastcell = getempty()
		repeat
			cx,cy = StepForward(cx,cy,dir)
			local oldcell = GetCell(cx,cy)
			if oldcell.id == 200 and oldcell.rot == dir then oldcell.updated = true end
			SetCell(cx,cy,vars.lastcell)
			vars.ended = IsNonexistant(oldcell,dir,cx,cy,vars)
			vars.lastcell = table.copy(oldcell)
		until vars.ended
		Play("move")
	elseif cell.id == 201 then
		local cx,cy = StepForward(x,y,cell.rot)
		local cell2 = CopyCell(cx,cy)
		SetCell(cx,cy,cell)
		SetCell(x,y,cell2)
		Play("move")
	elseif cell.id == 202 then
		local cx,cy,cx2,cy2 = x,y,x,y
		local cx,cy = StepForward(x,y,cell.rot)
		local cx2,cy2 = StepBack(x,y,cell.rot)
		local cell = CopyCell(cx,cy)
		local cell2 = CopyCell(cx2,cy2)
		SetCell(cx2,cy2,cell)
		SetCell(cx,cy,cell2)
		Play("move")
	elseif cell.id == 203 then
		local neighbors = GetSurrounding(x,y)
		RotateCellRaw(GetCell(neighbors[0.5][1],neighbors[0.5][2]),1)
		RotateCellRaw(GetCell(neighbors[1.5][1],neighbors[1.5][2]),1)
		RotateCellRaw(GetCell(neighbors[2.5][1],neighbors[2.5][2]),1)
		RotateCellRaw(GetCell(neighbors[3.5][1],neighbors[3.5][2]),1)
		local lastcell = getempty()
		for i=0,3.5,.5 do
			local v = neighbors[i]
			local cell = CopyCell(v[1],v[2])
			SetCell(v[1],v[2],lastcell)
			lastcell = cell
		end
		local v = neighbors[0]
		local cell = CopyCell(v[1],v[2])
		SetCell(v[1],v[2],lastcell)
		Play("move")
	elseif cell.id == 204 then
		local neighbors = GetSurrounding(x,y)
		RotateCellRaw(GetCell(neighbors[0.5][1],neighbors[0.5][2]),-1)
		RotateCellRaw(GetCell(neighbors[1.5][1],neighbors[1.5][2]),-1)
		RotateCellRaw(GetCell(neighbors[2.5][1],neighbors[2.5][2]),-1)
		RotateCellRaw(GetCell(neighbors[3.5][1],neighbors[3.5][2]),-1)
		local lastcell = getempty()
		for i=3.5,0,-.5 do
			local v = neighbors[i]
			local cell = CopyCell(v[1],v[2])
			SetCell(v[1],v[2],lastcell)
			lastcell = cell
		end
		local v = neighbors[3.5]
		local cell = CopyCell(v[1],v[2])
		SetCell(v[1],v[2],lastcell)
		Play("move")
	end
end

function DoAboveRefresh(x,y,cell)
	if cell.id == 566 then
		cell.vars[2] = math.max(cell.vars[2]-1,0)
	end
end

function DoThawer(x,y,cell)
	local neighbors = GetNeighbors(x,y)
	for k,v in pairs(neighbors) do
		ThawCell(v[1],v[2],k)
	end
	cell.thawed = true
end

function CheckInput(x,y,cell)
	if not cell.clicked then
		cell.updated = true
		cell.frozen = true
	end
end

function DoFreezer(x,y,cell)
	if cell.id == 286 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			FreezeCell(v[1],v[2],k,true)
		end
		cell.frozen = true
	elseif cell.id == 287 then
		local neighbors = GetNeighbors(x,y)
		if cell.rot == 0 or cell.rot == 2 then
			FreezeCell(neighbors[2][1],neighbors[2][2],2)
			FreezeCell(neighbors[0][1],neighbors[0][2],0)
		else
			FreezeCell(neighbors[1][1],neighbors[1][2],1)
			FreezeCell(neighbors[3][1],neighbors[3][2],3)
		end
		cell.frozen = true
	elseif cell.id == 1164 then
		if cell.vars[1] then
			cell.vars[1] = nil
		else
			local cx,cy = StepForward(x,y,cell.rot)
			FreezeCell(cx,cy,cell.rot)
		end
	else
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			FreezeCell(v[1],v[2],k)
		end
		cell.frozen = true
	end
end

function DoEffectGiver(x,y,cell)
	if cell.id == 43 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			ProtectCell(v[1],v[2],k)
		end
		cell.protected = true
	elseif cell.id == 112 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"locked","lock")
		end
		cell.locked = true
	elseif cell.id == 145 then
		for cx=x-2,x+2 do
			for cy=y-2,y+2 do
				ProtectCell(cx,cy,math.angleTo4(cx-x,cy-y),1)
			end
		end
	elseif cell.id == 136 then
		local neighbors = GetNeighbors(x,y)
		table.insert(neighbors,{x,y})
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"pushclamped","clamp")
		end
	elseif cell.id == 137 then
		local neighbors = GetNeighbors(x,y)
		table.insert(neighbors,{x,y})
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"pullclamped","clamp")
		end
	elseif cell.id == 138 then
		local neighbors = GetNeighbors(x,y)
		table.insert(neighbors,{x,y})
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"grabclamped","clamp")
		end
	elseif cell.id == 139 then
		local neighbors = GetNeighbors(x,y)
		table.insert(neighbors,{x,y})
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"swapclamped","clamp")
		end
	elseif cell.id == 253 then
		local neighbors = GetNeighbors(x,y)
		table.insert(neighbors,{x,y})
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"scissorclamped","clamp")
		end
	elseif cell.id == 935 then
		local neighbors = GetNeighbors(x,y)
		table.insert(neighbors,{x,y})
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"tunnelclamped","clamp")
		end
	elseif cell.id == 232 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			GravitizeCell(v[1],v[2],k,cell.rot)
		end
	elseif cell.id == 588 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			GravitizeCell(v[1],v[2],k,cell.rot+4)
		end
	elseif cell.id == 252 or cell.id == 647 or cell.id == 648 or cell.id == 788 or cell.id == 789
	or cell.id == 649 or cell.id == 650 or cell.id == 651 or cell.id == 790 or cell.id == 791 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			if (cell.id ~= 647 and cell.id ~= 650 or k%2 == cell.rot%2) and (cell.id ~= 648 and cell.id ~= 651 or k == cell.rot)
			and (cell.id ~= 788 and cell.id ~= 790 or k == cell.rot or k == (cell.rot-1)%4) and (cell.id ~= 789 and cell.id ~= 791 or k ~= (cell.rot+2)%4) then
				StickCell(v[1],v[2],k,cell.id >= 649 and cell.id ~= 788 and cell.id ~= 789 and 2 or 1)
			end
		end
		cell.sticky = cell.id >= 649 and cell.id ~= 788 and cell.id ~= 789 and 2 or 1
	elseif cell.id == 308 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			ProtectCell(v[1],v[2],k,-1)
		end
		cell.protected = true
	elseif cell.id == 309 then
		cell.protected = true
	elseif cell.id == 310 then
		local neighbors = GetNeighbors(x,y)
		table.insert(neighbors,{x,y})
		for k,v in pairs(neighbors) do
			DoBasicEffect(v[1],v[2],k,"pushclamped","clamp")
			updatekey = updatekey + 1
			DoBasicEffect(v[1],v[2],k,"pullclamped","clamp")
			updatekey = updatekey + 1
			DoBasicEffect(v[1],v[2],k,"grabclamped","clamp")
			updatekey = updatekey + 1
			DoBasicEffect(v[1],v[2],k,"swapclamped","clamp")
			updatekey = updatekey + 1
			DoBasicEffect(v[1],v[2],k,"scissorclamped","clamp")
			updatekey = updatekey + 1
			DoBasicEffect(v[1],v[2],k,"tunnelclamped","clamp")
		end
	elseif cell.id == 522 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PerpetualRotateCell(v[1],v[2],k,1)
		end
	elseif cell.id == 523 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PerpetualRotateCell(v[1],v[2],k,-1)
		end
	elseif cell.id == 524 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PerpetualRotateCell(v[1],v[2],k,2)
		end
	elseif cell.id == 967 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PerpetualRotateCell(v[1],v[2],k,7)
		end
	elseif cell.id == 535 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PerpetualRotateCell(v[1],v[2],k,cell.rot%2+3)
		end
	elseif cell.id == 715 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PerpetualRotateCell(v[1],v[2],k,cell.rot%2+5)
		end
	elseif cell.id == 619 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			ArmorCell(v[1],v[2],k)
		end
		cell.vars.armored = true
	elseif cell.id == 1199 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			BoltCell(v[1],v[2],k)
		end
		cell.vars.bolted = true
	elseif cell.id == 736 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PetrifyCell(v[1],v[2],k)
		end
		cell.vars.petrified = true
	elseif cell.id == 896 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			GooCell(v[1],v[2],k)
		end
		cell.vars.gooey = nil
	elseif cell.id == 745 then
		local cx,cy = StepForward(x,y,cell.rot)
		PaintCell(cx,cy,cell.rot,cell.vars.paint)
	elseif cell.id == 824 or cell.id == 825 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			CompelCell(v[1],v[2],k,cell.id == 824 and 1 or cell.id == 825 and 2)
		end
		cell.vars.compelled = nil
	end
end

function DoEffectRemover(x,y,cell)
	if cell.id == 266 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			GravitizeCell(v[1],v[2],k,false)
		end
		cell.vars.gravdir = nil
	elseif cell.id == 525 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			PerpetualRotateCell(v[1],v[2],k,false)
		end
		cell.vars.perpetualrot = nil
	elseif cell.id == 826 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			CompelCell(v[1],v[2],k,nil)
		end
		cell.vars.compelled = nil
	end
end

function DoDumpster(x,y,dir)
	local dir,cx,cy = dir,x,y
	while true do
		if dir == 0 then cx = cx + 1
		else cy = cy + 1 end
		if not IsUnbreakable(GetCell(cx,cy),dir,cx,cy,{forcetype="destroy"}) then
			SetCell(cx,cy,{id=735,rot=dir,lastvars={x,y,0},vars={},eatencells={GetCell(cx,cy)}})
		else
			break
		end
	end
	dir,cx,cy = dir+2,x,y
	while true do
		if dir == 2 then cx = cx - 1
		else cy = cy - 1 end
		if not IsUnbreakable(GetCell(cx,cy),dir,cx,cy,{forcetype="destroy"}) then
			SetCell(cx,cy,{id=735,rot=dir,lastvars={x,y,0},vars={},eatencells={GetCell(cx,cy)}})
		else
			break
		end
	end
end

function DoPerpetualRotation(x,y,cell)
	cell.prupdated = true
	if cell.vars.perpetualrot == 3 and FlipCell(x,y,0,0,nil,true) then return
	elseif cell.vars.perpetualrot == 4 and FlipCell(x,y,1,0,nil,true) then return
	elseif cell.vars.perpetualrot == 5 and FlipCell(x,y,1.5,0,nil,true) then return
	elseif cell.vars.perpetualrot == 6 and FlipCell(x,y,0.5,0,nil,true) then return
	elseif cell.vars.perpetualrot == 7 and RotateCell(x,y,math.randomsign(),0,nil,true) then return
	elseif RotateCell(x,y,cell.vars.perpetualrot,0,nil,true) then return end
end

function UpdateGoo(x,y,cell)
	cell.updated = true
	cell.frozen = true
end

function CheckCompel(x,y,cell)
	if cell.vars.gooey and (cell.firstx ~= x or cell.firsty ~= y) then cell.vars.gooey = nil end
	if cell.vars.compelled == 1 and (cell.firstx ~= x or cell.firsty ~= y)
	or cell.vars.compelled == 2 and cell.firstx == x and cell.firsty == y then
		table.safeinsert(cell,"eatencells",table.copy(cell))
		cell.id = 0
		Play("destroy")
	elseif (cell.id == 1150 and cell.vars[1] and (cell.firstx == x and cell.firsty == y)
	or cell.id == 1151 and cell.vars[1] and (cell.firstx ~= x or cell.firsty ~= y))
	and not cell.updated then
		SetCell(x,y,GetStoredCell(cell,false,{cell}))
	end
end

function DoSuperTimewarper(x,y,cell,dir)
	if Override("DoSuperTimewarper"..cell.id,x,y,cell,dir) then return end
	if id == 833 then cell.updated = true
	elseif cell.id == 834 then
		if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
	elseif cell.id == 835 then
		if dir == 0 or dir == 3 then cell.firstupdated = true else cell.updated = true end
	else 
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	end
	local cx,cy,cdir = NextCell(x,y,dir)
	while true do
		local cell2 = GetCell(cx,cy)
		if not IsUnbreakable(cell2,cdir,cx,cy,{forcetype="transform",lastcell=cell})
		and (not IsNonexistant(cell2,cdir,cx,cy,{forcetype="transform",lastcell=cell})
		or not IsNonexistant(table.copy(initiallayers[0][cy][cx]),cdir,cx,cy,{forcetype="transform",lastcell=cell})) then
			local c = table.copy(initiallayers[0][cy][cx])
			c.lastvars = table.copy(cell2.lastvars)
			c.lastvars[3] = 0
			c.eatencells = {cell2}
			SetCell(cx,cy,c)
		else
			return
		end
		cx,cy,cdir = NextCell(cx,cy,cdir)
	end
end

function DoTimewarper(x,y,cell,dir)
	if Override("DoTimewarper"..cell.id,x,y,cell,dir) then return end
	if cell.id == 146 or cell.id == 148 or cell.id == 615 or cell.id == 616 or cell.id == 617 then
		if id == 146 then cell.updated = true
		elseif cell.id == 148 then
			if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
		elseif cell.id == 615 then
			if dir == 0 or dir == 3 then cell.firstupdated = true else cell.updated = true end
		else 
			if dir == 0 then cell.Rupdated = true
			elseif dir == 2 then cell.Lupdated = true
			elseif dir == 3 then cell.Uupdated = true
			else cell.updated = true end
		end
		local cx,cy,cdir = NextCell(x,y,dir)
		if cx then
			local cell2 = GetCell(cx,cy)
			if not IsUnbreakable(cell2,cdir,cx,cy,{forcetype="transform",lastcell=cell}) then
				local c = table.copy(initiallayers[0][cy][cx])
				c.lastvars = table.copy(cell2.lastvars)
				c.lastvars[3] = 0
				c.eatencells = {cell2}
				SetCell(cx,cy,c)
			end
		end
	elseif cell.id == 147 then
		cell.updated = true
		local cx,cy,cdir,c = NextCell(x,y,(dir+2)%4,nil,true)
		if cx then
			local gencell = table.copy(initiallayers[0][cy][cx])
			gencell.rot = (gencell.rot-c.rot)%4
			gencell = ToGenerate(gencell,cdir,cx,cy)
			if gencell then
				gencell.lastvars = table.copy(cell.lastvars)
				gencell.lastvars[3] = 0
				x,y = StepForward(x,y,dir)
				PushCell(x,y,dir,{replacecell=gencell,noupdate=true,force=1})
			end
		end
	end
end

function DoTimewarpZone(x,y,cell)
	if Override("DoTimewarpZone"..cell.id,x,y,cell,dir) then return end
	local cell2 = GetCell(x,y)
	local c = table.copy(initiallayers[0][y][x])
	c.lastvars = table.copy(cell2.lastvars)
	c.lastvars[3] = 0
	c.eatencells = {cell2}
	SetCell(x,y,c)
end

function DoWorm(x,y,cell,dir)
	if Override("DoWorm"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local copycell = table.copy(cell)
	local cx,cy,cdir = NextCell(x,y,dir,copycell)
	if cx then
		local c = GetCell(cx,cy)
		if not IsNonexistant(c,cdir,cx,cy) and not IsUnbreakable(c,cdir,cx,cy,{forcetype="transform",lastcell=copycell}) then
			if copycell.id == 1078 then RotateCellRaw(copycell,1)
			elseif copycell.id == 1079 then RotateCellRaw(copycell,-1)
			elseif copycell.id == 1080 then RotateCellRaw(copycell,-2)
			elseif copycell.id == 1081 then FlipCellRaw(copycell,cell.rot+.5)
			elseif copycell.id == 1082 then FlipCellRaw(copycell,cell.rot-.5)
			end
			copycell.lastvars = table.copy(c.lastvars)
			copycell.lastvars[3] = 0
			copycell.eatencells = {c}
			SetCell(x,y,getempty({cell}))
			SetCell(cx,cy,copycell)
		end
	end
end

function DoTransformer(x,y,cell,dir)
	if Override("DoTransformer"..cell.id,x,y,cell,dir) then return end
	if (cell.id == 238 or cell.id == 268) then
		if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
	elseif IsMultiCell(cell.id) then
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	else cell.updated = true end
	local cx,cy,cdir,c = NextCell(x,y,(dir+((cell.id == 505 or cell.id == 507 or cell.id == 509 or cell.id == 511) and 1 or (cell.id == 506 or cell.id == 508 or cell.id == 510 or cell.id == 512) and 3 or cell.id >= 536 and (cell.rot-dir+2) or 2))%4,nil,true)
	local ccx,ccy,ccdir = NextCell(x,y,dir)
	if cx and ccx then
		local cell2 = GetCell(ccx,ccy)
		local cell1 = GetCell(cx,cy)
		local copycell
		if cell.copiedcell then
			copycell = table.copy(cell.copiedcell)
		else
			copycell = ToGenerate(CopyCell(cx,cy),cdir,cx,cy)
			if copycell then
				RotateCellRaw(copycell,-c.rot)
			end
		end
		if cell.id == 761 or cell.id == 762 then
			if copycell and copycell.id ~= 0 then
				cell.vars[1] = copycell.id
				cell.vars[2] = copycell.rot
			elseif cell.vars[1] then
				copycell = GetStoredCell(cell)
			end
		end
		if copycell then
			if not IsNonexistant(cell2,ccdir,ccx,ccy) and ((cell.copiedcell or not IsNonexistant(copycell,ccdir,ccx,ccy)) and not IsUnbreakable(cell2,ccdir,ccx,ccy,{forcetype="transform",lastcell=cell}) and
			((cell.id == 237 or cell.id == 238 or cell.id == 505 or cell.id == 506 or cell.id == 507 or cell.id == 508 or cell.id >= 536 and cell.id < 544) or CanMove(copycell,cx,cy,cdir,"pull"))) then
				if cell.id == 505 or cell.id == 509 then RotateCellRaw(copycell,1)
				elseif cell.id == 506 or cell.id == 510 then RotateCellRaw(copycell,-1)
				elseif cell.id >= 536 and cell.id < 540 or cell.id >= 544 and cell.id < 548 then
					RotateCellRaw(copycell,(dir-cell.rot))
				end
				NextCell(x,y,dir,copycell)
				copycell.lastvars = table.copy(cell2.lastvars)
				copycell.lastvars[3] = 0
				copycell.eatencells = {cell2}
				if cell.id == 267 or cell.id == 268 or cell.id == 509 or cell.id == 510 or cell.id == 511 or cell.id == 512 or cell.id >= 544 and cell.id ~= 761 then
					if not cell.copiedcell then SetCell(cx,cy,getempty()) end
					SetCell(ccx,ccy,copycell)
					if cell.id < 544 or not cell.copiedcell then 
						local px,py = StepForward(cx,cy,cdir)
						if not PullCell(px,py,(cdir+2)%4,{force=1,noupdate=true,dontfailonfirst=true}) then
							SetCell(cx,cy,cell1)
							SetCell(ccx,ccy,cell2)
						else
							cell.eatencells = cell.eatencells or {}
							table.insert(cell.eatencells,cell1)
							if cell.id >= 544 then cell.copiedcell = table.copy(copycell); if cell.id < 548 then RotateCellRaw(cell.copiedcell,-(dir-cell.rot)) end end
						end
					end
				else
					SetCell(ccx,ccy,copycell)
				end
			end
		end
	end
end

function DoMidas(x,y,cell,dir)
	if Override("DoMidas"..cell.id,x,y,cell,dir) then return end
	if dir == 0 then cell.Rupdated = true
	elseif dir == 2 then cell.Lupdated = true
	elseif dir == 3 then cell.Uupdated = true
	else cell.updated = true end
	if cell.vars[1] then
		local copycell = GetStoredCell(cell)
		if cell.id == 426 or cell.id == 742 or cell.id == 743 or cell.id == 744 then RotateCellRaw(copycell,(dir-cell.rot)) copycell.lastvars[3] = 0 end
		local cx,cy,cdir = NextCell(x,y,dir,copycell)
		if cx then
			local cell2 = GetCell(cx,cy)
			if not IsNonexistant(cell2,cdir,cx,cy) and not IsUnbreakable(cell2,cdir,cx,cy,{forcetype="transform",lastcell=cell}) then
				local old3 = copycell.lastvars[3]
				copycell.lastvars = table.copy(cell2.lastvars)
				copycell.lastvars[3] = old3
				copycell.eatencells = {cell2}
				SetCell(cx,cy,copycell)
			end
		end
	end
end

ismirror = {
	[0]={
		[15]=true,[56]=true,[80]=true,[489]=true,[490]=true,[491]=true,[492]=true,[478]=true,[629]=true,[630]=true,[657]=true,[313]=true,[314]=true,
		[445]=true,[446]=true,[660]=true,[661]=true,[662]=true,[663]=true,[664]=true,[479]=true,[480]=true,[481]=true,
	},
	[2]={
		[15]=true,[56]=true,[80]=true,[489]=true,[490]=true,[491]=true,[492]=true,[478]=true,[630]=true,[657]=true,[313]=true,[314]=true,
		[445]=true,[446]=true,[660]=true,[661]=true,[662]=true,[663]=true,[664]=true,[479]=true,[480]=true,[481]=true,
	},
	[1]={
		[56]=true,[80]=true,[492]=true,[629]=true,[630]=true,[657]=true,[314]=true,[446]=true,[660]=true,[664]=true,[481]=true,
	},
	[3]={
		[56]=true,[80]=true,[492]=true,[630]=true,[657]=true,[314]=true,[446]=true,[660]=true,[664]=true,[481]=true,
	},
	[0.5]={
		[80]=true,[316]=true,[490]=true,[491]=true,[660]=true,[659]=true,[662]=true,[663]=true,
	},
	[2.5]={
		[80]=true,[316]=true,[490]=true,[491]=true,[660]=true,[659]=true,[662]=true,[663]=true,
	},
	[1.5]={
		[80]=true,[315]=true,[316]=true,[489]=true,[491]=true,[492]=true,[660]=true,[658]=true,[659]=true,[661]=true,[663]=true,[664]=true,
	},
	[3.5]={
		[80]=true,[315]=true,[316]=true,[489]=true,[491]=true,[492]=true,[660]=true,[658]=true,[659]=true,[661]=true,[663]=true,[664]=true,
	},
}

function IsMirror(cell,dir)
	return get(ismirror[ToSide(cell.rot,dir)][cell.id])
end

isreflector = {
	[445]=true,[446]=true,[658]=true,[659]=true,[660]=true,[661]=true,
	[662]=true,[663]=true,[664]=true,[479]=true,[480]=true,[481]=true,
}

function DoSuperMirror(x,y,cell,dir)
	if Override("DoSuperMirror"..cell.id,x,y,cell,dir) then return end
	local cx,cy,ccx,ccy = x,y,x,y
	while true do
		if dir == 0 or dir == 2 then
			cx = cx + 1
			ccx = ccx - 1
		else
			cy = cy + 1
			ccy = ccy - 1
		end
		local cell1,cell2 = GetCell(cx,cy),GetCell(ccx,ccy)
		if IsMirror(cell1,dir) or IsMirror(cell2,(dir+2)%4) or IsNonexistant(cell1,cx,cy,dir) and IsNonexistant(cell2,ccx,ccy,(dir+2)%4) or SwapCells(cx,cy,dir,ccx,ccy,(dir+2)%4) ~= true then
			break
		elseif isreflector[cell.id] then
			FlipCell(cx,cy,dir,dir)
			FlipCell(ccx,ccy,dir,(dir+2)%4)
		end
	end
end

function DoMirror(x,y,cell,dir)
	if Override("DoMirror"..cell.id,x,y,cell,dir) then return end
	local cx,cy,ccx,ccy = x,y,x,y
	local cx,cy = StepForward(x,y,dir)
	local ccx,ccy = StepForward(x,y,(dir+2)%4)
	local cell1 = GetCell(cx,cy)
	local cell2 = GetCell(ccx,ccy)
	if not (IsMirror(cell1,dir) or IsMirror(cell2,(dir+2)%4)) then
		SwapCells(cx,cy,dir,ccx,ccy,(dir+2)%4)
		if isreflector[cell.id] then
			FlipCell(cx,cy,dir,dir)
			FlipCell(ccx,ccy,dir,(dir+2)%4)
		end
	end
	if cell.id == 478 or cell.id == 479 then
		for i=-1,1,2 do
			local cx,cy,ccx,ccy = x,y,x,y
			if dir == 0 or dir == 2 then
				cx = cx + 1
				ccx = ccx - 1
				cy = cy + i
				ccy = ccy + i
			else
				cy = cy + 1
				ccy = ccy - 1
				cx = cx + i
				ccx = ccx + i
			end
			local cell1 = GetCell(cx,cy)
			local cell2 = GetCell(ccx,ccy)
			if not (IsMirror(cell1,dir) or IsMirror(cell2,(dir+2)%4)) then
				SwapCells(cx,cy,dir,ccx,ccy,(dir+2)%4)
				if isreflector[cell.id] then
					FlipCell(cx,cy,dir,dir)
					FlipCell(ccx,ccy,dir,(dir+2)%4)
				end
			end
		end
	end
end

function DoCurvedMirror(x,y,cell,dir)
	if Override("DoCurvedMirror"..cell.id,x,y,cell,dir) then return end
	dir = (dir+.5)%4
	local cx,cy = StepForward(x,y,dir)
	local ccx,ccy = StepForward(x,y,(dir-1)%4)
	local cell1 = GetCell(cx,cy)
	local cell2 = GetCell(ccx,ccy)
	if not (IsMirror(cell1,dir) or IsMirror(cell2,(dir-1)%4)) then
		SwapCells(cx,cy,dir,ccx,ccy,(dir-1)%4)
	end
end

function DoCrystal(x,y,cell,dir)
	if Override("DoCrystal"..cell.id,x,y,cell,dir) then return end
	local cx,cy = StepForward(x,y,dir)
	local ccx,ccy = StepForward(cx,cy,dir)
	SwapCells(cx,cy,(dir+2)%4,ccx,ccy,dir)
end

function DoAmethyst(x,y,cell,dir)
	if Override("DoAmethyst"..cell.id,x,y,cell,dir) then return end
	local cx,cy,ccx,ccy,run,rise = x,y,x,y,
	cell.id >= 493 and cell.id <= 497 and 2 or cell.id >= 919 and cell.id <= 928 and 3 or cell.id >= 1095 and cell.id <= 1099 and cell.vars[1] or 4,
	cell.id >= 952 and cell.id < 957 and 3 or (cell.id >= 924 and cell.id < 929 or cell.id >= 947 and cell.id < 952) and 2 or cell.id >= 1095 and cell.id <= 1099 and cell.vars[2] or 1
	if dir == 0.5 then
		cx = cx + run
		cy = cy + rise
		ccx = ccx + rise
		ccy = ccy + run
	elseif dir == 1.5 then
		cx = cx - rise
		cy = cy + run
		ccx = ccx - run
		ccy = ccy + rise
	elseif dir == 2.5 then
		cx = cx - run
		cy = cy - rise
		ccx = ccx - rise
		ccy = ccy - run
	elseif dir == 3.5 then
		cx = cx + rise
		cy = cy - run
		ccx = ccx + run
		ccy = ccy - rise
	end
	SwapCells(cx,cy,(dir-1)%4,ccx,ccy,(dir+1)%4)
end

function DoCycler(x,y,cell,dir)
	if Override("DoCycler"..cell.id,x,y,cell,dir) then return end
	local cx,cy = StepForward(x,y,dir)
	for i=-1,1 do
		local ccx,ccy = cx + (dir%2 == 1 and i or 0),cy + (dir%2 == 0 and i or 0)
		if IsUnbreakable(GetCell(ccx,ccy),dir,ccx,ccy,{forcetype="swap",lastcell=cell}) then return end
	end
	if cell.id == 625 or cell.id == 627 or cell.id == 632 or cell.id == 634 or cell.id == 636 or cell.id == 642 and dir == cell.rot then
		cx,cy = StepLeft(cx,cy,dir)
		local cell = GetCell(cx,cy)
		cx,cy = StepRight(cx,cy,dir)
		local oldcell = GetCell(cx,cy)
		SetCell(cx,cy,cell)
		cx,cy = StepRight(cx,cy,dir)
		cell = GetCell(cx,cy)
		SetCell(cx,cy,oldcell)
		cx,cy = StepLeft(cx,cy,dir)
		cx,cy = StepLeft(cx,cy,dir)
		SetCell(cx,cy,cell)
	else
		cx,cy = StepRight(cx,cy,dir)
		local cell = GetCell(cx,cy)
		cx,cy = StepLeft(cx,cy,dir)
		local oldcell = GetCell(cx,cy)
		SetCell(cx,cy,cell)
		cx,cy = StepLeft(cx,cy,dir)
		cell = GetCell(cx,cy)
		SetCell(cx,cy,oldcell)
		cx,cy = StepRight(cx,cy,dir)
		cx,cy = StepRight(cx,cy,dir)
		SetCell(cx,cy,cell)
	end
end

function DoSuperIntaker(x,y,cell,dir)
	if Override("DoSuperIntaker"..cell.id,x,y,cell,dir) then return end
	if cell.id == 518 and (dir == 0 or dir == 2) then cell.hupdated = true
	elseif cell.id == 519 and (dir == 0 or dir == 3) then cell.firstupdated = true
	elseif (cell.id == 520 or cell.id == 521) and dir == 0 then cell.Rupdated = true
	elseif (cell.id == 520 or cell.id == 521) and dir == 2 then cell.Lupdated = true
	elseif (cell.id == 520 or cell.id == 521) and dir == 3 then cell.Uupdated = true
	else cell.updated = true end
	x,y = StepForward(x,y,dir)
	local vars
	repeat
		vars = {force=1,noupdate=true}
	until not PullCell(x,y,(dir+2)%4,vars) or vars.repeats <= 1
end

function DoIntaker(x,y,cell,dir)
	if Override("DoIntaker"..cell.id,x,y,cell,dir) then return end
	if cell.id == 155 and (dir == 0 or dir == 2) then cell.hupdated = true
	elseif cell.id == 250 and (dir == 0 or dir == 3) then cell.firstupdated = true
	elseif (cell.id == 251 or cell.id == 317) and dir == 0 then cell.Rupdated = true
	elseif (cell.id == 251 or cell.id == 317) and dir == 2 then cell.Lupdated = true
	elseif (cell.id == 251 or cell.id == 317) and dir == 3 then cell.Uupdated = true
	else cell.updated = true end
	x,y = StepForward(x,y,dir)
	PullCell(x,y,(dir+2)%4,{force=1,noupdate=true})
end

function DoShifter(x,y,cell,dir)
	if Override("DoShifter"..cell.id,x,y,cell,dir) then return end
	if cell.id ~= 107 and cell.id ~= 1153 or dir == 1 or dir == 3 then cell.updated = true
	else cell.hupdated = true end
	local cx,cy,cdir,c = x,y,dir
	if cell.id == 254 or cell.id == 260 then cx,cy,cdir,c = NextCell(x,y,(dir+1)%4,nil,true)
	elseif cell.id == 255 or cell.id == 261 then cx,cy,cdir,c = NextCell(x,y,(dir-1)%4,nil,true)
	else cx,cy,cdir,c = NextCell(x,y,(dir+2)%4,nil,true) end
	if cx then
		local cell2 = GetCell(cx,cy)
		local gencell = table.copy(cell2)
		gencell.rot = (gencell.rot-c.rot)%4
		if not IsNonexistant(gencell,cdir,cx,cy) and CanMove(cell2,(cdir+2)%4,cx,cy,"pull") then
			if cell.id == 254 then gencell.rot = (gencell.rot+1)%4
			elseif cell.id == 255 then gencell.rot = (gencell.rot-1)%4
			elseif cell.id == 653 then
				if cell.vars[1] then
					gencell.id = cell.vars[1]
					gencell.rot = cell.vars[2]
				end
			elseif cell.id == 679 then
				FlipCellRaw(gencell,cell.rot+1)
			end
			gencell.lastvars = table.copy(cell.lastvars)
			gencell.lastvars[3] = 0
			cell.eatencells = cell.eatencells or {}
			SetCell(cx,cy,getempty())
			cx,cy = StepForward(cx,cy,cdir)
			local vars = {force=1,noupdate=true,dontfailonfirst=true}
			if not PullCell(cx,cy,(cdir+2)%4,vars) then
				cx,cy = StepBack(cx,cy,cdir)
				SetCell(cx,cy,cell2)
				return
			end
			local success = false
			local ccx,ccy = StepForward(x,y,dir)
			if cell.id == 665 then
				success = PushCell(ccx,ccy,dir,{replacecell=gencell,force=1}) or PushCell(x,y,(dir+2)%4,{replacecell=gencell,force=1})
			elseif cell.id == 666 then
				success = PushCell(x,y,(dir+2)%4,{replacecell=gencell,force=1}) or PushCell(ccx,ccy,dir,{replacecell=gencell,force=1})
			elseif cell.id == 667 then
				success = PushCell(x,y,(dir+2)%4,{replacecell=gencell,force=1})
			elseif cell.id == 847 then
				success = PushCell(ccx,ccy,dir,{replacecell=gencell,force=1})
				if success then
					cell = gencell
					local cx,cy,cdir = ccx,ccy,dir
					while true do
						local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
						if GetCell(cx,cy) ~= cell or not PushCell(cx,cy,cdir,{noupdate=true,force=1}) then
							break
						end
						updatekey = updatekey + 1
						local data = GetData(cx,cy)
						if data.supdatekey == supdatekey and data.scrosses >= 5 then
							break
						else
							data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
						end
						data.supdatekey = supdatekey
						if not nextx then break end
						cx,cy,cdir = nextx,nexty,nextdir
					end
					supdatekey = supdatekey + 1
				end
			elseif cell.id ~= 256 and cell.id ~= 262 then
				success = PushCell(ccx,ccy,dir,{replacecell=gencell,force=1})
			end
			if cell.id == 256 or cell.id == 257 or cell.id == 258 or cell.id == 262 or cell.id == 263 or cell.id == 264 then
				local dir = (dir - 1)%4
				local ccx,ccy = StepForward(x,y,dir)
				local gencell = table.copy(gencell)
				if cell.id == 256 or cell.id == 257 or cell.id == 258 then
					gencell.rot = (gencell.rot-1)%4
				end
				success = PushCell(ccx,ccy,dir,{replacecell=gencell,force=1}) or success
			end
			if cell.id == 256 or cell.id == 257 or cell.id == 259 or cell.id == 262 or cell.id == 263 or cell.id == 265 then
				local dir = (dir + 1)%4
				local ccx,ccy = StepForward(x,y,dir)
				local gencell = table.copy(gencell)
				if cell.id == 256 or cell.id == 257 or cell.id == 259 then
					gencell.rot = (gencell.rot+1)%4
				end
				success = PushCell(ccx,ccy,dir,{replacecell=gencell,force=1}) or success
			end
			if not success then
				for k,v in pairs(vars.undocells) do
					SetCell(k%width,math.floor(k/width),v)
				end
				cx,cy = StepBack(cx,cy,cdir)
				SetCell(cx,cy,cell2)
			else
				table.safeinsert(cell,"eatencells",cell2)
			end
		elseif cell.id == 1152 or cell.id == 1153 then
			FlipCellRaw(cell,dir)
		end
	end
end

function DoMemory(x,y,cell)
	if Override("DoMemory"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy,cdir,c = NextCell(x,y,(cell.rot+2)%4)
	if cx then
		local gencell = CopyCell(cx,cy)
		gencell.rot = (gencell.rot-c.rot)%4
		gencell = ToGenerate(gencell,cdir,cx,cy)
		if gencell then
			if gencell.id == 0 then
				cell.vars[1] = nil
				cell.vars[2] = nil
			else
				cell.vars[1] = gencell.id
				cell.vars[2] = gencell.rot
			end
		end
	end
	if cell.vars[1] then
		local gencell = GetStoredCell(cell)
		gencell.lastvars = table.copy(cell.lastvars)
		gencell.lastvars[3] = 0
		x,y = StepForward(x,y,cell.rot)
		PushCell(x,y,cell.rot,{replacecell=gencell,noupdate=true,force=1})
		--no optimizing here just so that memory will keep reading the cells behind them, even if they dont generate anything
	end
end

function DoMemoryRep(x,y,cell)
	if Override("DoMemoryRep"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy,cdir,c = NextCell(x,y,cell.rot)
	if cx then
		local gencell = CopyCell(cx,cy)
		gencell.rot = (gencell.rot-c.rot)%4
		gencell = ToGenerate(gencell,cdir,cx,cy)
		if gencell then
			if gencell.id == 0 then
				cell.vars[1] = nil
				cell.vars[2] = nil
			else
				cell.vars[1] = gencell.id
				cell.vars[2] = gencell.rot
			end
		end
	end
	if cell.vars[1] then
		local gencell = GetStoredCell(cell)
		gencell.lastvars = table.copy(cell.lastvars)
		gencell.lastvars[3] = 0
		x,y = StepForward(x,y,cell.rot)
		PushCell(x,y,cell.rot,{replacecell=gencell,noupdate=true,force=1})
	end
end

function FindGenerated(x,y,dir,t,capx,capy,capdir)
	--[[if cells[0][0] == 428 then
		x = x < 1 and width-2 or x > width-2 and 1 or x
		y = y < 1 and height-2 or y > height-2 and 1 or y
	end]]
	if GetCell(x,y).supdatekey ~= supdatekey then
		GetCell(x,y).testvar = "gen"
		t[x+y*width] = ToGenerate(CopyCell(x,y),dir,x,y)
		if t[x+y*width] then
			GetCell(x,y).supdatekey = supdatekey
			local neighbors = GetNeighbors(x,y)
			for k,v in pairs(neighbors) do
				if (capdir ~= 0 or v[1] < capx) and (capdir ~= 1 or v[2] < capy) and (capdir ~= 2 or v[1] > capx) and (capdir ~= 3 or v[2] > capy) then
					Queue("hypergen",function() FindGenerated(v[1],v[2],k,t,capx,capy,capdir) end)
				end
			end
		end
	end
	ExecuteQueue("hypergen")
	return t
end

function HyperGen(x,y,dir,t,si,ei,idir)
	local cx,cy,cdir,c = x,y,dir,getempty()
	for i=si,ei,idir do
		if cx then
			nomove = IsDestroyer(GetCell(cx,cy),cdir,cx,cy,{forcetype="push",lastcell=t[i] or cell,lastx=x,lasty=y})
			t[i] = t[i] or getempty()
			RotateCellRaw(t[i],c.rot)
			local a,b = PushCell(cx,cy,cdir,{replacecell=t[i],noupdate=true,force=1})
			if not a then
				break
			end
		else
			break
		end
		if not nomove then
			cx,cy,cdir = NextCell(cx,cy,cdir,c)	
		end
	end
end

function DoHyperGenerator(x,y,cell)
	if Override("DoHyperGenerator"..cell.id,x,y,cell,dir) then return end
	local dir = cell.rot
	if cell.id == 1115 then
		cell.updated = true
		local cx,cy,cdir,c = NextCell(x,y,(dir+2)%4,nil,true)
		local gencell = ToGenerate(CopyCell(cx,cy),cdir,cx,cy)
		if gencell then
			local ccx,ccy = StepForward(x,y,dir)
			RotateCellRaw(gencell,-c.rot)
			PushCell(ccx,ccy,dir,{replacecell=gencell,noupdate=true,force=1})
			for i=-1,1,2 do
				local cx,cy,cdir,c = NextCell(cx,cy,(cdir-i)%4,table.copy(c))
				local iter = 0
				local xmult,ymult = dir == 3 and i or dir == 1 and -i or 0,dir == 0 and i or dir == 2 and -i or 0
				while true do
					iter = iter + 1
					if cx then
						local gencell = ToGenerate(CopyCell(cx,cy),cdir,cx,cy)
						if gencell then
							RotateCellRaw(gencell,-c.rot)
							PushCell(ccx+iter*xmult,ccy+iter*ymult,dir,{replacecell=gencell,noupdate=true,force=1})
						else
							break
						end	
					end	
					cx,cy,cdir = NextCell(cx,cy,cdir,c)
				end
			end
		end
	else
		cell.updated = true
		cell.supdatekey = supdatekey
		local cx,cy = StepBack(x,y,cell.rot)
		local gencells = FindGenerated(cx,cy,(cell.rot+2)%4,{},x,y,cell.rot)
		supdatekey = supdatekey + 1
		local genrows = {}
		local shiftover = 0
		for k,v in pairs(gencells) do
			if cell.rot == 0 then 		shiftover = math.min(shiftover,k%width-x)
			elseif cell.rot == 1 then 	shiftover = math.min(shiftover,math.floor(k/width)-y)
			elseif cell.rot == 2 then 	shiftover = math.max(shiftover,k%width-x)
			elseif cell.rot == 3 then 	shiftover = math.max(shiftover,math.floor(k/width)-y) end
			if cell.rot%2 == 0 then
				genrows[math.floor(k/width)] = genrows[math.floor(k/width)] or {}
				genrows[math.floor(k/width)][k%width] = v
			elseif cell.rot%2 == 1 then
				genrows[k%width] = genrows[k%width] or {}
				genrows[k%width][math.floor(k/width)] = v
			end
		end
		cx,cy = StepForward(x,y,cell.rot)
		for k,v in pairs(genrows) do
			if cell.rot%2 == 0 then
				HyperGen(cx,k,cell.rot,genrows[k],shiftover+x,x+(cell.rot < 2 and -1 or 1),cell.rot > 1 and -1 or 1)
			else
				HyperGen(k,cy,cell.rot,genrows[k],shiftover+y,y+(cell.rot < 2 and -1 or 1),cell.rot > 1 and -1 or 1)
			end
		end
	end
end

MergeIntoInfo("genrot",{
	[26]=1,[110]=1,[749]=1,[751]=1,[753]=1,[755]=1,[757]=1,[759]=1,
	[458]=1,[460]=1,[769]=1,[771]=1,[773]=1,[775]=1,[777]=1,[779]=1,
	
	[27]=-1,[111]=-1,[750]=-1,[752]=-1,[754]=-1,[756]=-1,[758]=-1,[760]=-1,
	[459]=-1,[461]=-1,[770]=-1,[772]=-1,[774]=-1,[776]=-1,[778]=-1,[780]=-1,
})

function GenRot(cell)
	return GetAttribute(cell.id,"genrot",cell)
end

MergeIntoInfo("iscloner",{
	[110]=true,[751]=true,[755]=true,[759]=true,[460]=true,[771]=true,[775]=true,[779]=true,
	[111]=true,[752]=true,[756]=true,[760]=true,[461]=true,[772]=true,[776]=true,[780]=true,
	
	[235]=true,[526]=true,[527]=true,[528]=true,[529]=true,[530]=true,
	[1050]=true,[1051]=true,[1052]=true,[1053]=true,[1054]=true,
	[1059]=true,[1060]=true,[1061]=true,[1062]=true,[1063]=true,
	[1068]=true,[1069]=true,[1070]=true,[1071]=true,[1072]=true,
})

function IsCloner(cell)
	return GetAttribute(cell.id,"iscloner",cell)
end

--1 = physical, 2 = physical back, 3 = back
MergeIntoInfo("isphysical",{
	[342]=1,[749]=1,[750]=1,[751]=1,[752]=1,[673]=1,[769]=1,[770]=1,[771]=1,[772]=1,
	[395]=2,[753]=2,[754]=2,[755]=2,[756]=2,[674]=2,[773]=2,[774]=2,[775]=2,[776]=2,
	[393]=3,[757]=3,[758]=3,[759]=3,[760]=3,[675]=3,[777]=3,[778]=3,[779]=3,[780]=3,
	[343]=1,[866]=1,[869]=1,[872]=1,[875]=1,[676]=1,[878]=1,[881]=1,[884]=1,[887]=1,
	[396]=2,[867]=2,[870]=2,[873]=2,[876]=2,[677]=2,[879]=2,[882]=2,[885]=2,[888]=2,
	[394]=3,[868]=3,[871]=3,[874]=3,[877]=3,[678]=3,[880]=3,[883]=3,[886]=3,[889]=3,
	[1050]=1,[1051]=1,[1052]=1,[1053]=1,[1054]=1,[1055]=1,[1056]=1,[1057]=1,[1058]=1,
	[1059]=2,[1060]=2,[1061]=2,[1062]=2,[1063]=2,[1064]=2,[1065]=2,[1066]=2,[1067]=2,
	[1068]=3,[1069]=3,[1070]=3,[1071]=3,[1072]=3,[1073]=3,[1074]=3,[1075]=3,[1076]=3,
})

function IsPhysical(cell)
	return GetAttribute(cell.id,"isphysical",cell)
end

function DoSuperGenerator(x,y,cell,dir)
	if Override("DoSuperGenerator"..cell.id,x,y,cell,dir) then return end
	if cell.id == 457 and (dir == 0 or dir == 3) then cell.firstupdated = true
	elseif IsMultiCell(cell.id) then
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	else cell.updated = true end
	local gencells = {}
	local cx,cy,cdir,c = x,y,(dir+(GenRot(cell) or IsMultiCell(cell.id) and cell.id ~= 457 and (cell.rot-dir+2) or 2))%4,getempty()
	c.rot = not IsCloner(cell) and GenRot(cell) and -GenRot(cell) or (cell.id == 606 or cell.id == 607 or cell.id == 608 or cell.id == 609) and (cell.rot-dir) or 0
	while true do
		cx,cy,cdir = NextCell(cx,cy,cdir,c,true)	
		if cx then
			local gencell = CopyCell(cx,cy)
			RotateCellRaw(gencell,-c.rot)
			gencell = ToGenerate(gencell,cdir,cx,cy)
			if gencell then
				gencell.lastvars = table.copy(cell.lastvars)
				gencell.lastvars[3] = 0
				table.insert(gencells,gencell)
			else
				break
			end
			local data = GetData(cx,cy)
			if data.updatekey == updatekey and data.crosses >= 5 then
				gencells = {}
				break
			else
				data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
			end
			data.updatekey = updatekey
		else
			gencells = {}
			break
		end
	end
	updatekey = updatekey + 1
	local cx,cy,cdir,c = x,y,dir,getempty()
	local lastx,lasty,lastdir,lastc
	local nomove = false
	for i=#gencells,1,-1 do
		if not nomove then
			lastx,lasty,lastdir,lastc = cx,cy,cdir,table.copy(c)
			cx,cy,cdir = NextCell(cx,cy,cdir,c)	
		end
		if i == 1 and cell.id == 1089 then
			SetCell(x,y,getempty())
			if fancy then GetCell(x,y).eatencells = {cell} end
		end
		if cx then
			nomove = IsDestroyer(GetCell(cx,cy),cdir,cx,cy,{forcetype="push",lastcell=gencells[i] or cell,lastx=x,lasty=y})
			RotateCellRaw(gencells[i],c.rot)
			local success,frontblocked,backblocked
			local backdist = 0
			if IsPhysical(cell) == 2 or IsPhysical(cell) == 3 then
				local vars = {replacecell=gencells[i],noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(lastx,lasty,(lastdir+2)%4,vars)
				backdist = vars.repeats
				nomove = success
			end
			if IsPhysical(cell) ~= 3 and (IsPhysical(cell) ~= 2 or not success) then
				success,frontblocked = PushCell(cx,cy,cdir,{replacecell=gencells[i],noupdate=true,force=1})
			end
			if IsPhysical(cell) == 1 and not success then
				local vars = {replacecell=gencells[i],noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(lastx,lasty,(lastdir+2)%4,vars)
				backdist = vars.repeats
				nomove = success
			end
			if not success then
				if frontblocked or backblocked then
					local cx,cy,c,reps = x,y,getempty(),0
					updatekey = updatekey + 1
					while true do
						reps = reps + 1
						cx,cy = StepBack(cx,cy,cdir)
						if dir == 0 and cx < 1
						or dir == 2 and cx > width-2
						or dir == 1 and cy < 1
						or dir == 3 and cy > height-2 then return end
						local newcell,gencell = GetCell(cx,cy)
						local genx,geny,gendir,c = cx,cy,(dir+(GenRot(newcell) or IsMultiCell(newcell.id) and newcell.id ~= 457 and (newcell.rot-dir+2) or 2))%4,getempty()
						c.rot = not IsCloner(newcell) and GenRot(newcell) and -GenRot(newcell) or (newcell.id == 606 or newcell.id == 607 or newcell.id == 608 or newcell.id == 609) and (newcell.rot-dir) or 0
						while true do
							genx,geny,gendir = NextCell(genx,geny,gendir,getempty(),true)
							if genx then
								local newgen = ToGenerate(CopyCell(genx,geny),gendir,genx,geny)
								if not newgen then break end
								gencell = newgen
								gencell.rot = (gencell.rot-c.rot)%4
							else break end
							local data = GetData(cx,cy)
							if data.updatekey == updatekey and data.crosses >= 5 then
								gencell = nil
								break;
							else
								data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
							end
							data.updatekey = updatekey
						end
						gencell = gencell or getempty()
						local nextx,nexty = NextCell(cx,cy,dir,nil,false,true)
						if StopsOptimize(newcell,dir,cx,cy,{forcetype="push",lastcell=gencell,lastx=cx,lasty=cy}) or (dir == 1 or dir == 3) and nextx ~= cx or (dir == 0 or dir == 2) and nexty ~= cy then
							return
						elseif frontblocked and backblocked and reps < backdist and newcell.rot == dir and (IsPhysical(cell) == 1 or IsPhysical(cell) == 2) then
							newcell.updated = true
						elseif backblocked and reps < backdist and newcell.rot == dir and IsPhysical(cell) == 3 then
							newcell.updated = true
						elseif frontblocked then
							if (newcell.id == 55 or newcell.id == 458 or newcell.id == 459 or newcell.id == 460 or newcell.id == 461) and newcell.rot == dir then
								newcell.updated = true
							elseif newcell.id == 457 and (newcell.rot == dir or (newcell.rot-1)%4 == dir) then
								if dir == 0 or dir == 2 then newcell.hupdated = true
								else newcell.updated = true end
							elseif IsMultiCell(newcell.id) then
								if dir == 0 then newcell.Rupdated = true
								elseif dir == 2 then newcell.Lupdated = true
								elseif dir == 3 then newcell.Uupdated = true
								else newcell.updated = true end
							end
						end
					end
				end
				return
			end
		else
			return
		end
	end
end

function DoGenerator(x,y,cell,dir)
	if Override("DoGenerator"..cell.id,x,y,cell,dir) then return end
	if cell.id == 23 then
		if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
	elseif cell.id == 363 then
		if dir == 0 or dir == 3 then cell.firstupdated = true else cell.updated = true end
	elseif IsMultiCell(cell.id) then
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	else cell.updated = true end
	local cx,cy,cdir,c
	if GenRot(cell) then cx,cy,cdir,c = NextCell(x,y,(dir+GenRot(cell))%4,nil,true)
	elseif IsMultiCell(cell.id) and cell.id ~= 23 and cell.id ~= 363 and cell.id ~= 364 then cx,cy,cdir,c = NextCell(x,y,(cell.rot+2)%4,nil,true)
	else cx,cy,cdir,c = NextCell(x,y,(dir+2)%4,nil,true) end
	if cx then
		local gencell
		if cell.id == 363 or cell.id == 364 then
			if dir == 0 or dir == 3 then
				gencell = CopyCell(cx,cy)
				RotateCellRaw(gencell,-c.rot)
				gencell = ToGenerate(gencell,cdir,cx,cy)
				local ccx,ccy,ccdir,c = NextCell(x,y,dir,nil,true)
				if ccx then
					cell.togen = CopyCell(ccx,ccy)
					RotateCellRaw(cell.togen,-c.rot)
					cell.togen = ToGenerate(cell.togen,ccdir,ccx,ccy)
				end
			else
				gencell = cell.togen
				cell.togen = nil
			end
		else
			gencell = CopyCell(cx,cy)
			RotateCellRaw(gencell,-c.rot)
			gencell = ToGenerate(gencell,cdir,cx,cy)
		end
		if gencell then
			if not IsCloner(cell) and GenRot(cell) then RotateCellRaw(gencell,GenRot(cell))
			elseif cell.id == 167 or cell.id == 168 or cell.id == 169 or cell.id == 170 then RotateCellRaw(gencell,(dir-cell.rot)) 
			elseif cell.id == 40 then FlipCellRaw(gencell,cell.rot+1)
			elseif cell.id == 113 then RotateCellRaw(gencell,(dir-gencell.rot)) gencell.rot = dir
			elseif cell.id == 652 then
				if cell.vars[1] then
					gencell.id = cell.vars[1]
					gencell.rot = cell.vars[2]
				end
			end
			gencell.lastvars = table.copy(cell.lastvars)
			gencell.lastvars[3] = 0
			if cell.id == 301 then
				SetCell(x,y,getempty())
				if fancy then GetCell(x,y).eatencells = {cell} end
			end
			local cx,cy,cdir,backdist = x,y,dir,0
			if cell.id == 366 then
				cx,cy,cdir = NextCell(x,y,dir,gencell)
			else
				cx,cy = StepForward(cx,cy,dir)
			end
			local success,frontblocked,backblocked
			if IsPhysical(cell) == 2 or IsPhysical(cell) == 3 then
				local vars = {replacecell=gencell,noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(x,y,(dir+2)%4,vars)
				backdist = vars.repeats
			end
			if cell.id == 366 then
				success = NudgeCellTo(gencell,cx,cy,cdir)
			elseif cell.id == 646 then
				success,frontblocked = PushCell(cx,cy,cdir,{replacecell=gencell,noupdate=true,force=1})
				if success then
					cell = gencell
					local cx,cy,cdir = cx,cy,cdir
					while true do
						local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
						if GetCell(cx,cy) ~= cell or not PushCell(cx,cy,cdir,{noupdate=true,force=1}) then
							break
						end
						updatekey = updatekey + 1
						local data = GetData(cx,cy)
						if data.supdatekey == supdatekey and data.scrosses >= 5 then
							break
						else
							data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
						end
						data.supdatekey = supdatekey
						if not nextx then break end
						cx,cy,cdir = nextx,nexty,nextdir
					end
					supdatekey = supdatekey + 1
				end
			elseif IsPhysical(cell) ~= 3 and (IsPhysical(cell) ~= 2 or not success) then
				local vars = {replacecell=gencell,noupdate=true,force=cell.id == 365 and math.huge or 1,bend=cell.id == 701}
				success,frontblocked = PushCell(cx,cy,cdir,vars)
			end
			if not success and cell.id == 301 then
				SetCell(x,y,cell)
			elseif IsPhysical(cell) == 1 and not success then
				local vars = {replacecell=gencell,noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(x,y,(dir+2)%4,vars)
				backdist = vars.repeats
			end
			if not success and (frontblocked or backblocked) then
				local cx,cy,reps = x,y,0
				while true do
					reps = reps + 1
					cx,cy = StepBack(cx,cy,dir)
					if dir == 0 and cx < 1
					or dir == 2 and cx > width-2
					or dir == 1 and cy < 1
					or dir == 3 and cy > height-2 then break end
					local newcell,gencell = GetCell(cx,cy)
					local genx,geny,gendir,c
					if ChunkId(newcell.id) == 3 and newcell.rot == dir then
						if GenRot(cell) then
							genx,geny,gendir,c = NextCell(cx,cy,(newcell.rot+GenRot(cell))%4,nil,true)
						else
							genx,geny,gendir,c = NextCell(cx,cy,(newcell.rot+2)%4,nil,true)
						end
					end
					if genx then
						gencell = CopyCell(genx,geny)
						gencell.rot = (gencell.rot-c.rot)%4
					else gencell = getempty() end
					if newcell.id == 40 then FlipCellRaw(gencell,cell.rot+1) end
					local nextx,nexty = NextCell(cx,cy,dir)
					if StopsOptimize(newcell,dir,cx,cy,{forcetype="push",lastcell=gencell,lastx=cx,lasty=cy}) or (dir == 0 or dir == 2) and nexty ~= cy or (dir == 1 or dir == 3) and nextx ~= cx then
						break
					elseif ChunkId(newcell.id) == 3 then
						if frontblocked and backblocked and reps < backdist and newcell.rot == dir and (IsPhysical(cell) == 1 or IsPhysical(cell) == 2) then
							newcell.updated = true
						elseif backblocked and reps < backdist and newcell.rot == dir and IsPhysical(cell) == 3 then
							newcell.updated = true
						elseif frontblocked then
							if newcell.rot == dir and (newcell.id == 3 or newcell.id == 26 or newcell.id == 27 or newcell.id == 110 or newcell.id == 111 or newcell.id == 301 or newcell.id == 366 or newcell.id == 365 and cell.id == 365 or newcell.id == 646) then
								newcell.updated = true
							elseif newcell.id == 23 and (newcell.rot == dir or newcell.rot == (dir+1)%4) then
								if dir == 0 or dir == 2 then newcell.hupdated = true
								else newcell.updated = true end
							elseif newcell.id == 363 and newcell.rot%2 == dir%2 then
								if dir == 1 or dir == 2 then newcell.updated = true end
							elseif newcell.id == 364 then
								if dir == 2 then newcell.Lupdated = true
								elseif dir == 1 then newcell.updated = true end
							elseif IsMultiCell(newcell.id) then
								if dir == 0 then newcell.Rupdated = true
								elseif dir == 2 then newcell.Lupdated = true
								elseif dir == 3 then newcell.Uupdated = true
								else newcell.updated = true end
							end
						end
					end
				end
			end
		end
	end
end

function DoSuperReplicator(x,y,cell,dir)
	if Override("DoSuperReplicator"..cell.id,x,y,cell,dir) then return end
	if cell.id == 513 or cell.id == 878 or cell.id == 879 or cell.id == 880 then
		if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
	elseif cell.id == 514 or cell.id == 881 or cell.id == 882 or cell.id == 883 then
		if dir == 0 or dir == 3 then cell.firstupdated = true else cell.updated = true end
	elseif IsMultiCell(cell.id) then
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	else cell.updated = true end
	local gencells = {}
	local cx,cy,cdir = x,y,dir
	while true do
		cx,cy,cdir = NextCell(cx,cy,cdir,nil,nil,nil,true)
		if cx then
			local gencell = CopyCell(cx,cy)
			gencell = ToGenerate(gencell,cdir,cx,cy)
			if gencell then
				gencell.lastvars = table.copy(cell.lastvars)
				gencell.lastvars[3] = 0
				table.insert(gencells,gencell)
			else
				break
			end
			local data = GetData(cx,cy)
			if data.updatekey == updatekey and data.crosses >= 5 then
				gencells = {}
				break
			else
				data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
			end
			data.updatekey = updatekey
		else
			gencells = {}
			break
		end
	end
	updatekey = updatekey + 1
	local cx,cy,cdir,nomove = x,y,dir
	local lastx,lasty,lastdir
	for i=1,#gencells do
		if not nomove then
			lastx,lasty,lastdir = cx,cy,cdir
			cx,cy,cdir = NextCell(cx,cy,cdir)	
		end
		if i == 1 and cell.id == 1090 then
			SetCell(x,y,getempty())
			if fancy then GetCell(x,y).eatencells = {cell} end
		end
		if cx then
			nomove = IsDestroyer(GetCell(cx,cy),cdir,cx,cy,{forcetype="push",lastcell=gencells[i] or cell,lastx=x,lasty=y})
			local success,frontblocked,backblocked
			local backdist = 0
			if IsPhysical(cell) == 2 or IsPhysical(cell) == 3 then
				local vars = {replacecell=gencells[i],noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(lastx,lasty,(lastdir+2)%4,vars)
				backdist = vars.repeats
				nomove = success
			end
			if IsPhysical(cell) ~= 3 and (IsPhysical(cell) ~= 2 or not success) then
				success,frontblocked = PushCell(cx,cy,cdir,{replacecell=gencells[i],noupdate=true,force=1})
			end
			if IsPhysical(cell) == 1 and not success then
				local vars = {replacecell=gencells[i],noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(lastx,lasty,(lastdir+2)%4,vars)
				backdist = vars.repeats
				nomove = success
			end
			if not success then
				if frontblocked or backblocked then
					local cx,cy,reps = x,y,0
					while true do 
						reps = reps + 1
						cx,cy = StepBack(cx,cy,dir)
						if dir == 0 and cx < 1
						or dir == 2 and cx > width-2
						or dir == 1 and cy < 1
						or dir == 3 and cy > height-2 then gencells = {} break end
						local newcell = GetCell(cx,cy)
						local gencell = GetCell(cx+(rot == 0 and 1 or rot == 2 and -1 or 0),cy+(rot == 1 and 1 or rot == 3 and -1 or 0))
						local nextx,nexty = NextCell(cx,cy,dir,nil,false,true)
						if StopsOptimize(newcell,dir,cx,cy,{forcetype="push",lastcell=gencell,lastx=cx,lasty=cy}) or (dir == 1 or dir == 3) and nextx ~= cx or (dir == 0 or dir == 2) and nexty ~= cy then
							gencells = {} break
						elseif frontblocked and not IsPhysical(cell)
						or backblocked and reps < backdist and IsPhysical(cell) == 3
						or backblocked and reps < backdist and frontblocked then
							if (newcell.id == 177 or newcell.id == 676 or newcell.id == 677 or newcell.id == 678) and newcell.rot == dir then
								newcell.updated = true
							elseif (newcell.id == 513 or newcell.id == 878 or newcell.id == 879 or newcell.id == 880) and (newcell.rot == dir or newcell.rot == (dir+1)%4) then
								if dir == 0 or dir == 2 then newcell.hupdated = true
								else newcell.updated = true end
							elseif (newcell.id == 514 or newcell.id == 881 or newcell.id == 882 or newcell.id == 883) and (newcell.rot%2 == dir%2) then
								if dir == 0 or dir == 3 then newcell.firstupdated = true
								else newcell.updated = true end
							elseif newcell.id == 515 or newcell.id == 516 or newcell.id == 884 or newcell.id == 885 or newcell.id == 886 or newcell.id == 887 or newcell.id == 888 or newcell.id == 889 then
								if dir == 0 then newcell.Rupdated = true
								elseif dir == 2 then newcell.Lupdated = true
								elseif dir == 3 then newcell.Uupdated = true
								else newcell.updated = true end
							end
						end
					end
					updatekey = updatekey + 1
				end
				break
			end
		else
			break
		end
	end
end

function DoReplicator(x,y,cell,dir)
	if Override("DoReplicator"..cell.id,x,y,cell,dir) then return end
	if cell.id == 46 or cell.id == 866 or cell.id == 867 or cell.id == 868 then
		if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
	elseif cell.id == 397 or cell.id == 869 or cell.id == 870 or cell.id == 871 then
		if dir == 0 or dir == 3 then cell.firstupdated = true else cell.updated = true end
	elseif IsMultiCell(cell.id) then
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	else cell.updated = true end
	local cx,cy,cdir = NextCell(x,y,dir)
	if cx then
		local gencell = ToGenerate(CopyCell(cx,cy),cdir,cx,cy)
		if gencell then
			gencell.lastvars = table.copy(cell.lastvars)
			gencell.lastvars[3] = 0
			if cell.id == 302 then
				SetCell(x,y,getempty())
				if fancy then GetCell(x,y).eatencells = {cell} end
			end
			local success,frontblocked,backblocked
			local backdist = 0
			if IsPhysical(cell) == 2 or IsPhysical(cell) == 3 then
				local vars = {replacecell=gencell,noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(x,y,(dir+2)%4,vars)
				backdist = vars.repeats
			end
			if IsPhysical(cell) ~= 3 and (IsPhysical(cell) ~= 2 or not success) then
				success,frontblocked = PushCell(cx,cy,cdir,{replacecell=gencell,noupdate=true,force=1})
			end
			if not success and cell.id == 302 then
				SetCell(x,y,cell)
			elseif IsPhysical(cell) == 1 and not success then
				local vars = {replacecell=gencell,noupdate=true,repeats=0,force=1}
				success,backblocked = PushCell(x,y,(dir+2)%4,vars)
				backdist = vars.repeats
			end
			if not success and (frontblocked or backblocked) and not StopsOptimize(gencell,dir,cx,cy,{forcetype="push"}) then
				local cx,cy,reps = x,y,0
				while true do
					reps = reps + 1
					cx,cy = StepBack(cx,cy,dir)
					if dir == 0 and cx < 1
					or dir == 2 and cx > width-2
					or dir == 1 and cy < 1
					or dir == 3 and cy > height-2 then break end
					local newcell = GetCell(cx,cy)
					local gencell = GetCell(cx+(dir == 0 and 1 or dir == 2 and -1 or 0),cy+(dir == 1 and 1 or dir == 3 and -1 or 0))
					local nextx,nexty = NextCell(cx,cy,dir,nil,false,true)
					if StopsOptimize(newcell,dir,cx,cy,{forcetype="push",lastcell=gencell,lastx=cx,lasty=cy}) or (dir == 0 or dir == 2) and nexty ~= cy or (dir == 1 or dir == 3) and nextx ~= cx then
						break
					elseif frontblocked and not IsPhysical(cell)
					or backblocked and reps < backdist and IsPhysical(cell) == 3
					or backblocked and reps < backdist and frontblocked then
						if (newcell.id == 45 or newcell.id == 343 or newcell.id == 396 or newcell.id == 394) and newcell.rot == dir then
							newcell.updated = true
						elseif (newcell.id == 46 or newcell.id == 866 or newcell.id == 867 or newcell.id == 868) and (newcell.rot == dir or newcell.rot == (dir+1)%4) then
							if dir == 0 or dir == 2 then newcell.hupdated = true
							else newcell.updated = true end
						elseif (newcell.id == 397 or newcell.id == 869 or newcell.id == 870 or newcell.id == 871) and (newcell.rot%2 == dir%2) then
							if dir == 0 or dir == 3 then newcell.firstupdated = true
							else newcell.updated = true end
						elseif newcell.id == 398 or newcell.id == 399 or newcell.id == 872 or newcell.id == 873 or newcell.id == 875 or newcell.id == 876 or newcell.id == 874 or newcell.id == 877 then
							if dir == 0 then newcell.Rupdated = true
							elseif dir == 2 then newcell.Lupdated = true
							elseif dir == 3 then newcell.Uupdated = true
							else newcell.updated = true end
						end
					end
				end
			end
		end
	end
end

function DoMaker(x,y,cell,dir)
	if Override("DoMaker"..cell.id,x,y,cell,dir) then return end
	if cell.id == 527 or cell.id == 531 or cell.id == 1051 or cell.id == 1055
	or cell.id == 1060 or cell.id == 1064 or cell.id == 1069 or cell.id == 1073 then
		if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
	elseif cell.id == 528 or cell.id == 532 or cell.id == 1052 or cell.id == 1056
	or cell.id == 1061 or cell.id == 1065 or cell.id == 1070 or cell.id == 1074 then
		if dir == 0 or dir == 3 then cell.firstupdated = true else cell.updated = true end
	elseif IsMultiCell(cell.id) then
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	else cell.updated = true end
	if cell.vars[1] then
		local gencell = GetStoredCell(cell)
		if not IsCloner(cell) then RotateCellRaw(gencell,(dir-cell.rot)) gencell.lastvars[3] = 0 end
		gencell.lastvars = table.copy(cell.lastvars)
		gencell.lastvars[3] = 0
		local cx,cy,cdir = NextCell(x,y,dir)
		local success,frontblocked,backblocked
		local backdist = 0
		if IsPhysical(cell) == 2 or IsPhysical(cell) == 3 then
			local vars = {replacecell=gencell,noupdate=true,repeats=0,force=1}
			success,backblocked = PushCell(x,y,(dir+2)%4,vars)
			backdist = vars.repeats
		end
		if cx then
			if IsPhysical(cell) ~= 3 and (IsPhysical(cell) ~= 2 or not success) then
				success,frontblocked = PushCell(cx,cy,cdir,{replacecell=gencell,noupdate=true,force=1})
			end
		else frontblocked = true end
		if not success and cell.id == 302 then
			SetCell(x,y,cell)
		elseif IsPhysical(cell) == 1 and not success then
			local vars = {replacecell=gencell,noupdate=true,repeats=0,force=1}
			success,backblocked = PushCell(x,y,(dir+2)%4,vars)
			backdist = vars.repeats
		end
		if not success and (frontblocked or backblocked) then
			local cx,cy,reps = x,y,0
			while true do
				reps = reps + 1
				cx,cy = StepBack(cx,cy,dir)
				if dir == 0 and cx < 1
				or dir == 2 and cx > width-2
				or dir == 1 and cy < 1
				or dir == 3 and cy > height-2 then break end
				local newcell = GetCell(cx,cy)
				local gencell
				if ChunkId(newcell.id) == 526 and newcell.vars[1] then
					gencell = {id=newcell.vars[1],rot=(newcell.vars[2]+((newcell.id > 530 or newcell.id == 427) and (dir-newcell.rot) or 0))%4,lastvars={x,y,0},vars = DefaultVars(newcell.vars[1])}
				else
					gencell = getempty()
				end	
				local nextx,nexty = NextCell(cx,cy,dir,nil,false,true)
				if StopsOptimize(newcell,dir,cx,cy,{forcetype="push",lastcell=gencell,lastx=cx,lasty=cy}) or (dir == 0 or dir == 2) and nexty ~= cy or (dir == 1 or dir == 3) and nextx ~= cx then
					break
				elseif ChunkId(newcell.id) == 526 
				and (frontblocked and not IsPhysical(cell)
				or backblocked and reps < backdist and IsPhysical(cell) == 3
				or backblocked and reps < backdist and frontblocked) then
					if (newcell.id == 527 or newcell.id == 531 or newcell.id == 1051 or newcell.id == 1055
					or newcell.id == 1060 or newcell.id == 1064 or newcell.id == 1069 or newcell.id == 1073) and (dir == 0 or dir == 2) then newcell.hupdated = true
					elseif (newcell.id == 528 or newcell.id == 532 or newcell.id == 1052 or newcell.id == 1056
					or newcell.id == 1061 or newcell.id == 1065 or newcell.id == 1070 or newcell.id == 1074) and (dir == 0 or dir == 3) then newcell.firstupdated = true
					elseif (IsMultiCell(newcell.id) or newcell.id == 235 or newcell.id == 427) and dir ~= 1 then
						if dir == 0 then newcell.Rupdated = true
						elseif dir == 2 then newcell.Lupdated = true
						elseif dir == 3 then newcell.Uupdated = true
						end
					elseif newcell.rot == dir then newcell.updated = true
					end
				end
			end
		end
	end
end

function DoRecursor(x,y,cell)
	if Override("DoRecursor"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy,cdir = NextCell(x,y,cell.rot)
	if cx then
		local gencell 
		if cell.vars[1] then
			gencell = table.copy(cell)
			gencell.vars[1] = gencell.vars[1]-1
			if gencell.vars[1] == 0 then gencell.vars[1] = nil end
		else
			gencell = {id=4,rot=cell.rot,lastvars=cell.lastvars,vars={}}
		end
		a,b = PushCell(cx,cy,cdir,{replacecell=gencell,noupdate=true,force=1})
		if not a and b and not StopsOptimize(gencell,cell.rot,cx,cy,{forcetype="push"}) then
			local cx,cy = x,y
			while true do
				cx,cy = StepBack(cx,cy,cell.rot)
				if cell.rot == 0 and cx < 1
				or cell.rot == 2 and cx > width-2
				or cell.rot == 1 and cy < 1
				or cell.rot == 3 and cy > height-2 then break end
				local newcell = GetCell(cx,cy)
				local gencell = GetCell(cx+(cell.rot == 0 and 1 or cell.rot == 2 and -1 or 0),cy+(cell.rot == 1 and 1 or cell.rot == 3 and -1 or 0))
				local nextx,nexty = NextCell(cx,cy,cell.rot,nil,false,true)
				if StopsOptimize(newcell,cell.rot,cx,cy,{forcetype="push",lastcell=gencell,lastx=cx,lasty=cy}) or (cell.rot == 0 or cell.rot == 2) and nexty ~= cy or (cell.rot == 1 or cell.rot == 3) and nextx ~= cx then
					break
				elseif newcell.id == 412 and newcell.rot == cell.rot then
					newcell.updated = true
				end
			end
		end
	end
end

function SuperFlip(x,y,rot,dir)
	if not IsNonexistant(GetCell(x,y),dir,x,y) and GetCell(x,y).updatekey ~= updatekey and not IsUnbreakable(GetCell(x,y),dir,x,y,{forcetype="rotate",lastcell=cell}) then
		FlipCell(x,y,rot,dir)
		GetCell(x,y).updatekey = updatekey
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			Queue("superflip", function() SuperFlip(v[1],v[2],rot,k) end)
		end
	end
	ExecuteQueue("superflip")
end

function DoSuperFlipper(x,y,cell)
	if Override("DoSuperFlipper"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	FreezeQueue("flip",true)
	SuperFlip(x,y,cell.rot%2 - (cell.id == 714 and 0.5 or 0),0)
	FreezeQueue("flip",false)
end

function DoFlipper(x,y,cell)
	if Override("DoFlipper"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	FreezeQueue("flip",true)
	if cell.id == 30 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			FlipCell(v[1],v[2],cell.rot,k)
		end
	elseif cell.id == 640 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			FlipCell(v[1],v[2],cell.rot,k,true)
		end
	elseif cell.id == 1048 then
		local neighbors = GetDiagonals(x,y)
		for k,v in pairs(neighbors) do
			FlipCell(v[1],v[2],cell.rot,k,true)
		end
	elseif cell.id == 89 then
		local neighbors = GetNeighbors(x,y)
		if cell.rot == 0 or cell.rot == 2 then
			FlipCell(neighbors[2][1],neighbors[2][2],0,2)
			FlipCell(neighbors[0][1],neighbors[0][2],0,0)
		else
			FlipCell(neighbors[1][1],neighbors[1][2],1,1)
			FlipCell(neighbors[3][1],neighbors[3][2],1,3)
		end
	elseif cell.id == 90 then
		local neighbors = GetNeighbors(x,y)
		if cell.rot == 0 or cell.rot == 2 then
			FlipCell(neighbors[1][1],neighbors[1][2],0,1)
			FlipCell(neighbors[3][1],neighbors[3][2],0,3)
		else
			FlipCell(neighbors[0][1],neighbors[0][2],1,0)
			FlipCell(neighbors[2][1],neighbors[2][2],1,2)
		end
	elseif cell.id == 654 then
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			FlipCell(v[1],v[2],(cell.rot+1.5),k)
		end
	elseif cell.id == 713 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			FlipCell(v[1],v[2],(cell.rot+1.5),k,true)
		end
	elseif cell.id == 1049 then
		local neighbors = GetDiagonals(x,y)
		for k,v in pairs(neighbors) do
			FlipCell(v[1],v[2],(cell.rot+1.5),k,true)
		end
	elseif cell.id == 655 then
		local neighbors = GetNeighbors(x,y)
		if cell.rot == 0 or cell.rot == 2 then
			FlipCell(neighbors[2][1],neighbors[2][2],.5,2)
			FlipCell(neighbors[0][1],neighbors[0][2],.5,0)
		else
			FlipCell(neighbors[1][1],neighbors[1][2],1.5,1)
			FlipCell(neighbors[3][1],neighbors[3][2],1.5,3)
		end
	elseif cell.id == 656 then
		local neighbors = GetNeighbors(x,y)
		if cell.rot == 0 or cell.rot == 2 then
			FlipCell(neighbors[1][1],neighbors[1][2],.5,0)
			FlipCell(neighbors[3][1],neighbors[3][2],.5,2)
		else
			FlipCell(neighbors[0][1],neighbors[0][2],1.5,0)
			FlipCell(neighbors[2][1],neighbors[2][2],1.5,2)
		end
	end
	FreezeQueue("flip",false)
end

function SuperRotate(x,y,rot,dir)
	if not IsNonexistant(GetCell(x,y),dir,x,y) and GetCell(x,y).updatekey ~= updatekey and not IsUnbreakable(GetCell(x,y),dir,x,y,{forcetype="rotate",lastcell=cell}) then
		RotateCell(x,y,rot,dir)
		GetCell(x,y).updatekey = updatekey
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			Queue("superrotate", function() SuperRotate(v[1],v[2],rot,k) end)
		end
	end
	ExecuteQueue("superrotate")
end

function DoSuperRotator(x,y,cell)
	if Override("DoSuperRotator"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	FreezeQueue("rotate",true)
	local rot = math.randomsign()
	SuperRotate(x,y,cell.id == 442 and 1 or cell.id == 443 and -1 or cell.id == 444 and -2 or rot,0)
	FreezeQueue("rotate",false)
	RotateCellRaw(cell,-(cell.id == 442 and 1 or cell.id == 443 and -1 or cell.id == 444 and -2 or rot),true)
end

function DoRotator(x,y,cell)
	if Override("DoRotator"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	FreezeQueue("rotate",true)
	local neighbors = GetNeighbors(x,y)
	if cell.id == 9 then
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],1,k)
		end
	elseif cell.id == 10 then
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],-1,k)
		end
	elseif cell.id == 11 then
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],2,k)
		end
	elseif cell.id == 960 then
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],math.randomsign(),k)
		end
	elseif cell.id == 66 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,1,cell.rot)
		cx,cy = StepBack(x,y,cell.rot)
		RotateCell(cx,cy,1,(cell.rot+2)%4)
	elseif cell.id == 67 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,-1,cell.rot)
		cx,cy = StepBack(x,y,cell.rot)
		RotateCell(cx,cy,-1,(cell.rot+2)%4)
	elseif cell.id == 68 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,2,cell.rot)
		cx,cy = StepBack(x,y,cell.rot)
		RotateCell(cx,cy,2,(cell.rot+2)%4)
	elseif cell.id == 961 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),cell.rot)
		cx,cy = StepBack(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),(cell.rot+2)%4)
	elseif cell.id == 994 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,1,cell.rot)
	elseif cell.id == 995 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,-1,cell.rot)
	elseif cell.id == 996 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,2,cell.rot)
	elseif cell.id == 997 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),cell.rot)
	elseif cell.id == 998 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,1,cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,1,(cell.rot-1)%4)
	elseif cell.id == 999 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,-1,cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,-1,(cell.rot-1)%4)
	elseif cell.id == 1001 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,2,cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,2,(cell.rot-1)%4)
	elseif cell.id == 1002 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),(cell.rot-1)%4)
	elseif cell.id == 1003 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,1,cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,1,(cell.rot-1)%4)
		cx,cy = StepRight(x,y,cell.rot)
		RotateCell(cx,cy,1,(cell.rot+1)%4)
	elseif cell.id == 1004 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,-1,cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,-1,(cell.rot-1)%4)
		cx,cy = StepRight(x,y,cell.rot)
		RotateCell(cx,cy,-1,(cell.rot+1)%4)
	elseif cell.id == 1005 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,2,cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,2,(cell.rot-1)%4)
		cx,cy = StepRight(x,y,cell.rot)
		RotateCell(cx,cy,2,(cell.rot+1)%4)
	elseif cell.id == 1006 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),(cell.rot-1)%4)
		cx,cy = StepRight(x,y,cell.rot)
		RotateCell(cx,cy,math.randomsign(),(cell.rot+1)%4)
	elseif cell.id == 67 then
		if cell.rot == 0 or cell.rot == 2 then
			RotateCell(neighbors[2][1],neighbors[2][2],-1,2)
			RotateCell(neighbors[0][1],neighbors[0][2],-1,0)
		else
			RotateCell(neighbors[1][1],neighbors[1][2],-1,1)
			RotateCell(neighbors[3][1],neighbors[3][2],-1,3)
		end
	elseif cell.id == 68 then
		if cell.rot == 0 or cell.rot == 2 then
			RotateCell(neighbors[2][1],neighbors[2][2],2,2)
			RotateCell(neighbors[0][1],neighbors[0][2],2,0)
		else
			RotateCell(neighbors[1][1],neighbors[1][2],2,1)
			RotateCell(neighbors[3][1],neighbors[3][2],2,3)
		end
	elseif cell.id == 961 then
		if cell.rot == 0 or cell.rot == 2 then
			RotateCell(neighbors[2][1],neighbors[2][2],math.randomsign(),2)
			RotateCell(neighbors[0][1],neighbors[0][2],math.randomsign(),0)
		else
			RotateCell(neighbors[1][1],neighbors[1][2],math.randomsign(),1)
			RotateCell(neighbors[3][1],neighbors[3][2],math.randomsign(),3)
		end
	elseif cell.id == 57 then
		if cell.rot == 0 then
			RotateCell(neighbors[0][1],neighbors[0][2],1,0)
			RotateCell(neighbors[1][1],neighbors[1][2],1,1)
			RotateCell(neighbors[2][1],neighbors[2][2],-1,2)
			RotateCell(neighbors[3][1],neighbors[3][2],-1,3)
		elseif cell.rot == 1 then
			RotateCell(neighbors[0][1],neighbors[0][2],-1,0)
			RotateCell(neighbors[1][1],neighbors[1][2],1,1)
			RotateCell(neighbors[2][1],neighbors[2][2],1,2)
			RotateCell(neighbors[3][1],neighbors[3][2],-1,3)
		elseif cell.rot == 2 then
			RotateCell(neighbors[0][1],neighbors[0][2],-1,0)
			RotateCell(neighbors[1][1],neighbors[1][2],-1,1)
			RotateCell(neighbors[2][1],neighbors[2][2],1,2)
			RotateCell(neighbors[3][1],neighbors[3][2],1,3)
		else
			RotateCell(neighbors[0][1],neighbors[0][2],1,0)
			RotateCell(neighbors[1][1],neighbors[1][2],-1,1)
			RotateCell(neighbors[2][1],neighbors[2][2],-1,2)
			RotateCell(neighbors[3][1],neighbors[3][2],1,3)
		end
	elseif cell.id == 70 then
		if cell.rot == 0 or cell.rot == 2 then
			RotateCell(neighbors[0][1],neighbors[0][2],1,0)
			RotateCell(neighbors[1][1],neighbors[1][2],-1,1)
			RotateCell(neighbors[2][1],neighbors[2][2],1,2)
			RotateCell(neighbors[3][1],neighbors[3][2],-1,3)
		else
			RotateCell(neighbors[0][1],neighbors[0][2],-1,0)
			RotateCell(neighbors[1][1],neighbors[1][2],1,1)
			RotateCell(neighbors[2][1],neighbors[2][2],-1,2)
			RotateCell(neighbors[3][1],neighbors[3][2],1,3)
		end
	elseif cell.id == 245 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],1,k,true)
		end
	elseif cell.id == 246 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],-1,k,true)
		end
	elseif cell.id == 247 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],2,k,true)
		end
	elseif cell.id == 962 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],math.randomsign(),k,true)
		end
	elseif cell.id == 957 then
		local neighbors = GetDiagonals(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],1,k,true)
		end
	elseif cell.id == 958 then
		local neighbors = GetDiagonals(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],-1,k,true)
		end
	elseif cell.id == 959 then
		local neighbors = GetDiagonals(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],2,k,true)
		end
	elseif cell.id == 963 then
		local neighbors = GetDiagonals(x,y)
		for k,v in pairs(neighbors) do
			RotateCell(v[1],v[2],math.randomsign(),k,true)
		end
	elseif cell.id == 552 then
		if cell.rupdated then return end
		cell.updated = false
		cell.rupdated = true
		if cell.vars[16] == cell.vars[12]-1 then
			local neighbors = GetSurrounding(x,y)
			for k,v in pairs(neighbors) do
				if k%1 == 0 then
					local val = cell.vars[(k-cell.rot)%4+1]
					if val > 19 then
						RotateCell(v[1],v[2],val == 20 and 1 or val == 21 and -1 or val == 22 and -2 or math.randomsign(),k)
					end
				else
					local val = cell.vars[(k-cell.rot)%4+16.5]
					if val > 2 then
						RotateCell(v[1],v[2],val == 3 and 1 or val == 4 and -1 or val == 5 and -2 or math.randomsign(),k)
					end
				end
			end
		end
	end
	FreezeQueue("rotate",false)
end

function DoRotateZone(x,y,cell)
	if Override("DoRotateZone"..cell.id,x,y,cell,dir) then return end
	if cell.id == 1118 then
		RotateCell(x,y,1,0,false,true)
	elseif cell.id == 1119 then
		RotateCell(x,y,-1,0,false,true)
	elseif cell.id == 1120 then
		RotateCell(x,y,2,0,false,true)
	elseif cell.id == 1121 then
		RotateCell(x,y,math.randomsign(),0,false,true)
	end
end

function DoBasicGear(x,y,cell,neighbors,dir,rotateneighbors,rotation)
	FreezeQueue("rotate",true)
	neighbors = (neighbors or GetSurrounding)(x,y)
	rotateneighbors = (rotateneighbors or GetNeighbors)(x,y)
	rotation = rotation or dir
	local jammed
	for k,v in pairs(neighbors) do
		jammed = jammed or IsUnbreakable(GetCell(v[1],v[2]),k,v[1],v[2],{forcetype="swap",lastcell=cell}) or GetAttribute(GetCell(v[1],v[2]).id,"isgear",GetCell(v[1],v[2]),k,v[1],v[2])
	end
	if not jammed then
		local lastpos = dir == 1 and (neighbors[3.5] or neighbors[3]) or (neighbors[0] or neighbors[.5])
		local lastcell = GetCell(lastpos[1],lastpos[2])
		for i=dir == 1 and 0 or 3.5,dir == -1 and 0 or 3.5,dir/2 do
			local v = neighbors[i]
			if v then
				local cell = GetCell(v[1],v[2])
				SetCell(v[1],v[2],lastcell)
				lastcell = cell
			end
		end
		for i=0,3.5,.5 do
			local v = rotateneighbors[i]
			if v then
				RotateCell(v[1],v[2],rotation,i)
			end
		end
		Play("move")
	end
	FreezeQueue("rotate",false)
end

function DoFlipGear(x,y,cell,neighbors,dir,rotateneighbors)
	FreezeQueue("flip",true)
	neighbors = (neighbors or GetSurrounding)(x,y)
	rotateneighbors = (rotateneighbors or GetSurrounding)(x,y)
	dir = dir%2
	local jammed
	for k,v in pairs(neighbors) do
		jammed = jammed or IsUnbreakable(GetCell(v[1],v[2]),k,v[1],v[2],{forcetype="swap",lastcell=cell}) or GetAttribute(GetCell(v[1],v[2]).id,"isgear",GetCell(v[1],v[2]),k,v[1],v[2])
	end
	if not jammed then
		local min = dir == 0 and 1.5 or dir - 0.5
		for i=min,min+1,.5 do
			local v = neighbors[i]
			local fv = neighbors[(-i+dir*2+2)%4]
			if v then
				local cell = GetCell(v[1],v[2])
				SetCell(v[1],v[2],GetCell(fv[1],fv[2]))
				SetCell(fv[1],fv[2],cell)
			end
		end
		for i=0,3.5,.5 do
			local v = rotateneighbors[i]
			if v then
				FlipCell(v[1],v[2],dir,i)
			end
		end
		Play("move")
	end
	FreezeQueue("flip",false)
end

function DoGear(x,y,cell)
	if Override("DoGear"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if cell.id == 18 or cell.id == 322 then
		DoBasicGear(x,y,cell,GetSurrounding,1,cell.id == 18 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 108 or cell.id == 324 then
		DoBasicGear(x,y,cell,GetNeighbors,1,cell.id == 108 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 469 or cell.id == 471 then
		for i=1,2 do
			DoBasicGear(x,y,cell,GetSurrounding,1,cell.id == 469 and GetNeighbors or GetNoNeighbors)
		end
	elseif cell.id == 473 or cell.id == 475 then
		for i=1,3 do
			DoBasicGear(x,y,cell,GetSurrounding,1,cell.id == 473 and GetNeighbors or GetNoNeighbors)
		end
	elseif cell.id == 482 or cell.id == 485 then
		DoBasicGear(x,y,cell,GetDiagonals,1,cell.id == 482 and GetDiagonals or GetNoNeighbors)
	elseif cell.id == 19 or cell.id == 323 then
		DoBasicGear(x,y,cell,GetSurrounding,-1,cell.id == 19 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 109 or cell.id == 325 then
		DoBasicGear(x,y,cell,GetNeighbors,-1,cell.id == 109 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 470 or cell.id == 472 then
		for i=1,2 do
			DoBasicGear(x,y,cell,GetSurrounding,-1,cell.id == 470 and GetNeighbors or GetNoNeighbors)
		end
	elseif cell.id == 474 or cell.id == 476 then
		for i=1,3 do
			DoBasicGear(x,y,cell,GetSurrounding,-1,cell.id == 474 and GetNeighbors or GetNoNeighbors)
		end
	elseif cell.id == 483 or cell.id == 486 then
		DoBasicGear(x,y,cell,GetDiagonals,-1,cell.id == 483 and GetDiagonals or GetNoNeighbors)
	elseif cell.id == 449 or cell.id == 451 then
		for i=1,4 do
			DoBasicGear(x,y,cell,GetSurrounding,1,cell.id == 449 and GetNeighbors or GetNoNeighbors,2)
		end
	elseif cell.id == 450 or cell.id == 452 then
		for i=1,2 do
			DoBasicGear(x,y,cell,GetNeighbors,1,cell.id == 450 and GetNeighbors or GetNoNeighbors)
		end
	elseif cell.id == 484 or cell.id == 487 then
		for i=1,2 do
			DoBasicGear(x,y,cell,GetDiagonals,1,cell.id == 484 and GetDiagonals or GetNoNeighbors)
		end
	elseif cell.id == 968 or cell.id == 973 then
		DoBasicGear(x,y,cell,GetSurrounding,math.randomsign(),cell.id == 968 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 971 or cell.id == 976 then
		DoBasicGear(x,y,cell,GetNeighbors,math.randomsign(),cell.id == 971 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 969 or cell.id == 974 then
		local s = math.randomsign()
		for i=1,2 do
			DoBasicGear(x,y,cell,GetSurrounding,s,cell.id == 969 and GetNeighbors or GetNoNeighbors)
		end
	elseif cell.id == 970 or cell.id == 975 then
		local s = math.randomsign()
		for i=1,3 do
			DoBasicGear(x,y,cell,GetSurrounding,s,cell.id == 970 and GetNeighbors or GetNoNeighbors)
		end
	elseif cell.id == 972 or cell.id == 977 then
		DoBasicGear(x,y,cell,GetDiagonals,math.randomsign(),cell.id == 972 and GetDiagonals or GetNoNeighbors)
	elseif cell.id == 1021 or cell.id == 1027 then
		DoFlipGear(x,y,cell,GetSurrounding,cell.rot,cell.id == 1021 and GetSurrounding or GetNoNeighbors)
	elseif cell.id == 1022 or cell.id == 1028 then
		DoFlipGear(x,y,cell,GetSurrounding,cell.rot-.5,cell.id == 1022 and GetSurrounding or GetNoNeighbors)
	elseif cell.id == 1023 or cell.id == 1029 then
		DoFlipGear(x,y,cell,GetNeighbors,cell.rot,cell.id == 1023 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 1024 or cell.id == 1030 then
		DoFlipGear(x,y,cell,GetNeighbors,cell.rot-.5,cell.id == 1024 and GetNeighbors or GetNoNeighbors)
	elseif cell.id == 1025 or cell.id == 1031 then
		DoFlipGear(x,y,cell,GetDiagonals,cell.rot,cell.id == 1025 and GetDiagonals or GetNoNeighbors)
	elseif cell.id == 1026 or cell.id == 1032 then
		DoFlipGear(x,y,cell,GetDiagonals,cell.rot-.5,cell.id == 1026 and GetDiagonals or GetNoNeighbors)
	end
end

function DoSawblade(x,y,cell)
	if Override("DoSawblade"..cell.id,x,y,cell,dir) then return end
	if cell.vars[1] ~= 0 then
		local neighbors = {}
		if cell.vars[1] > 0 then
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x+i,y-cell.vars[2],0})
			end
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x+cell.vars[2],y+i,1})
			end
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x-i,y+cell.vars[2],2})
			end
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x-cell.vars[2],y-i,3})
			end
		else
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x+i,y+cell.vars[2],0})
			end
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x+cell.vars[2],y-i,3})
			end
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x-i,y-cell.vars[2],2})
			end
			for i=-cell.vars[2]+1,cell.vars[2] do
				table.insert(neighbors,{x-cell.vars[2],y+i,1})
			end
		end
		for i=1,#neighbors do
			if GetCell(neighbors[i][1],neighbors[i][2]).id ~= 1116 and IsUnbreakable(GetCell(neighbors[i][1],neighbors[i][2]),neighbors[i][3],neighbors[i][1],neighbors[i][2],{forcetype="destroy"}) then
				return
			end
		end
		for j=1,math.abs(cell.vars[1]) do
			local lastcell
			if GetCell(neighbors[#neighbors][1],neighbors[#neighbors][2]).id == 1116 then
				lastcell = GetCell(neighbors[#neighbors][1],neighbors[#neighbors][2])
			end
			for i=1,#neighbors do
				local x,y,dir,c = neighbors[i][1],neighbors[i][2],neighbors[i][3],GetCell(neighbors[i][1],neighbors[i][2])
				if c.id == 1116 then
					local oldcell = c
					SetCell(x,y,lastcell or getempty())
					lastcell = oldcell
				elseif lastcell then
					if not IsNonexistant(c,dir,x,y) then
						table.safeinsert(lastcell,"eatencells",c)
						Play("destroy")
					end
					SetCell(x,y,lastcell)
					lastcell = nil
				end
			end
		end
	end
end

function DoChainsaw(x,y,cell)
	if Override("DoChainsaw"..cell.id,x,y,cell,dir) then return end
	local cx,cy,ccx,ccy,dir = x,y,x,y,cell.rot
	if cell.id == 344 then
		cx,cy = StepRight(x,y,dir)
		RotateCellRaw(cell,1)
		ccx,ccy = StepForward(x,y,dir)
		local blade = GetCell(ccx,ccy)
		if blade.id == 735 and blade.rot == dir then
			if not IsUnbreakable(GetCell(cx,cy),(dir+1)%4,cx,cy,{forcetype="destroy",lastx=x,lasty=y,lastcell=cell}) then
				RotateCellRaw(blade,1)
				blade.eatencells = {GetCell(cx,cy)}
				if not IsNonexistant(GetCell(cx,cy),(dir+1)%4,cx,cy) then Play("destroy") end
				SetCell(cx,cy,blade)
			else
				cell.eatencells={blade}
			end
			SetCell(ccx,ccy,getempty())
		else
			if not IsUnbreakable(GetCell(cx,cy),(dir+1)%4,cx,cy,{forcetype="destroy",lastx=x,lasty=y,lastcell=cell}) then
				if not IsNonexistant(GetCell(cx,cy),(dir+1)%4,cx,cy) then Play("destroy") end
				SetCell(cx,cy,{id=735,rot=cell.rot,lastvars={x,y,0},vars={paint=cell.paint},eatencells={GetCell(cx,cy)}})
			end
		end
	elseif cell.id == 345 then
		cx,cy = StepLeft(x,y,dir)
		RotateCellRaw(cell,-1)
		ccx,ccy = StepForward(x,y,dir)
		local blade = GetCell(ccx,ccy)
		if blade.id == 735 and blade.rot == dir then
			if not IsUnbreakable(GetCell(cx,cy),(dir-1)%4,cx,cy,{forcetype="destroy",lastx=x,lasty=y,lastcell=cell}) then
				RotateCellRaw(blade,-1)
				blade.eatencells = {GetCell(cx,cy)}
				if not IsNonexistant(GetCell(cx,cy),(dir-1)%4,cx,cy) then Play("destroy") end
				SetCell(cx,cy,blade)
			else
				cell.eatencells={blade}
			end
			SetCell(ccx,ccy,getempty())
		else
			if not IsUnbreakable(GetCell(cx,cy),(dir-1)%4,cx,cy,{forcetype="destroy",lastx=x,lasty=y,lastcell=cell}) then
				if not IsNonexistant(GetCell(cx,cy),(dir-1)%4,cx,cy) then Play("destroy") end
				SetCell(cx,cy,{id=735,rot=cell.rot,lastvars={x,y,0},vars={paint=cell.paint},eatencells={GetCell(cx,cy)}})
			end
		end
	elseif cell.id == 672 then
		cx,cy = StepBack(x,y,dir)
		RotateCellRaw(cell,2)
		ccx,ccy = StepForward(x,y,dir)
		local blade = GetCell(ccx,ccy)
		if blade.id == 735 and blade.rot == dir then
			if not IsUnbreakable(GetCell(cx,cy),(dir-2)%4,cx,cy,{forcetype="destroy",lastx=x,lasty=y,lastcell=cell}) then
				RotateCellRaw(blade,2)
				blade.eatencells = {GetCell(cx,cy)}
				if not IsNonexistant(GetCell(cx,cy),(dir-2)%4,cx,cy) then Play("destroy") end
				SetCell(cx,cy,blade)
			else
				cell.eatencells={blade}
			end
			SetCell(ccx,ccy,getempty())
		else
			if not IsUnbreakable(GetCell(cx,cy),(dir-2)%4,cx,cy,{forcetype="destroy",lastx=x,lasty=y,lastcell=cell}) then
				if not IsNonexistant(GetCell(cx,cy),(dir-2)%4,cx,cy) then Play("destroy") end
				SetCell(cx,cy,{id=735,rot=cell.rot,lastvars={x,y,0},vars={paint=cell.paint},eatencells={GetCell(cx,cy)}})
			end
		end
	elseif cell.id == 814 then
		cx,cy = StepForward(x,y,dir)
		if not IsUnbreakable(GetCell(cx,cy),(dir-2)%4,cx,cy,{forcetype="destroy",lastx=x,lasty=y,lastcell=cell}) then
			if not IsNonexistant(GetCell(cx,cy),(dir-2)%4,cx,cy) then Play("destroy") end
			SetCell(cx,cy,{id=735,rot=cell.rot,lastvars={x,y,0},vars={paint=cell.paint},eatencells={GetCell(cx,cy)}})
		end
	end
end

function DoOrientator(x,y,cell,dir)
	if Override("DoOrientator"..cell.id,x,y,cell,dir) then return end
	if cell.id == 570 then
		if dir == 0 or dir == 2 then cell.hupdated = true else cell.updated = true end
	elseif IsMultiCell(cell.id) then
		if dir == 0 then cell.Rupdated = true
		elseif dir == 2 then cell.Lupdated = true
		elseif dir == 3 then cell.Uupdated = true
		else cell.updated = true end
	else cell.updated = true end
	local cx,cy,cdir,c = NextCell(x,y,(dir+((cell.id == 571 or cell.id == 577) and 1 or (cell.id == 572 or cell.id == 578) and 3 or (cell.id == 573 or cell.id == 574 or cell.id == 575 or cell.id == 576 or cell.id == 579 or cell.id == 580 or cell.id == 581 or cell.id == 582) and (cell.rot-dir+2) or 2))%4,nil,true)
	local ccx,ccy,ccdir = NextCell(x,y,dir)
	if cx and ccx then
		local cell1 = GetCell(cx,cy)
		local cell2 = GetCell(ccx,ccy)
		local copyrot = cell1.rot-c.rot
		if not IsNonexistant(cell1,cdir,cx,cy) and not IsNonexistant(cell2,ccdir,ccx,ccy) then
			if cell.id == 571 then copyrot = copyrot+1
			elseif cell.id == 572 then copyrot = copyrot-1
			elseif cell.id == 573 or cell.id == 574 or cell.id == 575 or cell.id == 576 then copyrot = copyrot+dir-cell.rot end
			RotateCellTo(ccx,ccy,copyrot%4,ccdir)
		end
	end
end

function SuperRotateTo(x,y,rot,dir,force)
	if not IsNonexistant(GetCell(x,y),dir,x,y) and GetCell(x,y).updatekey ~= updatekey and (force or not IsUnbreakable(GetCell(x,y),dir,x,y,{forcetype="redirect",lastcell=cell})) then
		RotateCellTo(x,y,rot,dir)
		GetCell(x,y).updatekey = updatekey
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			Queue("superredirect", function() SuperRotateTo(v[1],v[2],rot,k) end)
		end
	end
	ExecuteQueue("superredirect")
end

function DoSuperRedirector(x,y,cell)
	if Override("DoSuperRedirector"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	FreezeQueue("redirect",true)
	SuperRotateTo(x,y,cell.rot,0,true)
	FreezeQueue("redirect",false)
end

function DoRedirector(x,y,cell)
	if Override("DoRedirector"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	FreezeQueue("redirect",true)
	local neighbors = GetNeighbors(x,y)
	if cell.id == 17 then
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],cell.rot,k)
		end
	elseif cell.id == 62 then
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],k,k)
		end
	elseif cell.id == 63 then
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],(k+2)%4,k)
		end
	elseif cell.id == 64 then
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],(k+1)%4,k)
		end
	elseif cell.id == 65 then
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],(k-1)%4,k)
		end
	elseif cell.id == 989 then
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],math.random(0,3),k)
		end
	elseif cell.id == 741 then
		neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],cell.rot,k,true)
		end
	elseif cell.id == 1044 then
		neighbors = GetDiagonals(x,y)
		for k,v in pairs(neighbors) do
			RotateCellTo(v[1],v[2],cell.rot,k)
		end
	elseif cell.id == 990 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),cell.rot)
		cx,cy = StepBack(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),(cell.rot+2)%4)
	elseif cell.id == 991 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),cell.rot)
	elseif cell.id == 992 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),(cell.rot-1)%4)
	elseif cell.id == 993 then
		local cx,cy = StepForward(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),cell.rot)
		cx,cy = StepLeft(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),(cell.rot-1)%4)
		cx,cy = StepRight(x,y,cell.rot)
		RotateCellTo(cx,cy,math.random(0,3),(cell.rot+1)%4)
	end
	FreezeQueue("redirect",false)
end

function DoRedirectZone(x,y,cell)
	if Override("DoRedirectZone"..cell.id,x,y,cell,dir) then return end
	RotateCellTo(x,y,cell.rot,0,true)
end

function DoInertia(x,y,cell,dir)
	if Override("DoInertia"..cell.id,x,y,cell,dir) then return end
	if not PushCell(x,y,dir) then
		if dir == 0 or dir == 2 then
			GetCell(x,y).vars[1] = 0
		else
			GetCell(x,y).vars[2] = 0
		end
	end
end

function DoVacuum(x,y,cell,dir)
	if Override("DoVacuum"..cell.id,x,y,cell,dir) then return end
	dir = (dir+2)%4
	local x,y,dir = NextCell(x,y,dir,nil,true)
	local cx,cy,cdir = NextCell(x,y,dir,nil,true)
	if IsTransparent(GetCell(cx,cy),(cdir+2)%4,cx,cy,{forcetype="nudge"}) then
		local ccx,ccy = StepForward(cx,cy,dir)
		if PullCell(ccx,ccy,(dir+2)%4,{force=1,noupdate=true}) then
			PullCell(cx,cy,(dir+2)%4,{force=2,noupdate=true})
		end
	else
		PullCell(cx,cy,(dir+2)%4,{force=2,noupdate=true})
	end
end

function DoSuperImpulsor(x,y,cell,dir)
	if Override("DoSuperImpulsor"..cell.id,x,y,cell,dir) then return end
	local cx,cy,cdir = x,y,(dir + 2)%4
	while true do
		cx,cy,cdir = NextCell(cx,cy,cdir,nil,true)
		if cx then
			if not IsTransparent(GetCell(cx,cy),(cdir+2)%4,cx,cy,{forcetype="nudge",lastcell=GetCell(cx,cy)}) then
				break
			end
			local data = GetData(cx,cy)
			if data.updatekey == updatekey and data.crosses >= 5 then
				break
			else
				data.crosses = data.updatekey == updatekey and data.crosses + 1 or 1
			end
			data.updatekey = updatekey
		else break end
	end
	updatekey = updatekey + 1
	if cx then
		cdir = (cdir + 2)%4
	end
	while true do
		if cx then
			if IsTransparent(GetCell(cx,cy),(cdir + 2)%4,cx,cy,{forcetype="nudge",lastcell=GetCell(cx,cy)}) or not PullCell(cx,cy,cdir,{force=math.huge,noupdate=true}) then
				break
			end
			local data = GetData(cx,cy)
			if data.supdatekey == supdatekey and data.scrosses >= 5 then
				break
			else
				data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
			end
			data.supdatekey = supdatekey
		else break end
		cx,cy,cdir = NextCell(cx,cy,cdir)
	end
	supdatekey = supdatekey + 1
end

function DoTimeImpulse(x,y,cell,dir)
	if Override("DoTimeImpulse"..cell.id,x,y,cell,dir) then return end
	local k = dir==0 and "timeimpulseright" or dir==2 and "timeimpulseleft" or dir==3 and "timeimpulseup" or "timeimpulsedown"
	if cell.vars[k] then
		cell.vars[k] = cell.vars[k] - 1
		if cell.vars[k] <= 0 then
			cell.vars[k] = nil
			PullCell(x,y,dir,{force=1,noupdate=true,repeats=0})
		end
	end
end

function DoTimeImpulsor(x,y,cell)
	if Override("DoTimeImpulsor"..cell.id,x,y,cell,dir) then return end
	for i=0,3 do
		if HasOnesidedDirection(cell,i,1107,1105,1108,1104,1106) then
			local cx,cy,cdir = NextCell(x,y,i,nil,true)
			local cx,cy = StepForward(cx,cy,cdir)
			local c = GetCell(cx,cy)
			local k = i==2 and "timeimpulseright" or i==0 and "timeimpulseleft" or i==1 and "timeimpulseup" or "timeimpulsedown"
			c.vars[k] = math.min(c.vars[k] or math.huge,cell.vars[1])
			SetChunkId(x,y,"timeimp")
		end
	end
end

function DoImpulsor(x,y,cell,dir)
	if Override("DoImpulsor"..cell.id,x,y,cell,dir) then return end
	dir = (dir+2)%4
	local x,y,dir = NextCell(x,y,dir,nil,true)
	local cx,cy = StepForward(x,y,dir)
	PullCell(cx,cy,(dir+2)%4,{force=1,noupdate=true,row=cell.id >= 1012 and cell.id <= 1016})
end

function DoGrapulsor(x,y,cell,dir)
	if Override("DoGrapulsor"..cell.id,x,y,cell,dir) then return end
	if cell.id == 227 or cell.id == 228 then
		x,y = StepRight(x,y,dir)
		RGrabCell(x,y,dir,{force=1,noupdate=true})
		x,y = StepLeft(x,y,dir,2)
		LGrabCell(x,y,dir,{force=1,noupdate=true})
	else
		if cell.id == 81 then dir = (dir-1)%4 else dir = (dir+1)%4 end
		x,y = StepForward(x,y,dir)
		if cell.id == 81 then
			LGrabCell(x,y,(dir+1)%4,{force=1,noupdate=true})
		else
			RGrabCell(x,y,(dir-1)%4,{force=1,noupdate=true})
		end
	end
end

function DoSuperFan(x,y,cell,dir)
	if Override("DoSuperFan"..cell.id,x,y,cell,dir) then return end
	local cx,cy,cdir = NextCell(x,y,dir)
	if cx then
		while true do
			local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
			if not PushCell(cx,cy,cdir,{force=math.huge,noupdate=true}) then
				break
			end
			local data = GetData(cx,cy)
			if data.supdatekey == supdatekey and data.scrosses >= 5 then
				break
			else
				data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
			end
			data.supdatekey = supdatekey
			if not nextx then break end
			cx,cy,cdir = nextx,nexty,nextdir
		end
		supdatekey = supdatekey + 1
	end
end

function DoFan(x,y,cell,dir)
	if Override("DoFan"..cell.id,x,y,cell,dir) then return end
	local cx,cy,cdir = NextCell(x,y,dir)
	if PushCell(cx,cy,cdir,{force=2,noupdate=true}) then
		cx,cy = StepForward(cx,cy,dir)
		PushCell(cx,cy,cdir,{force=1,noupdate=true})
	end
end

function DoRandulsor(x,y,cell,dir)
	if Override("DoRandulsor"..cell.id,x,y,cell,dir) then return end
	if math.random() < .5 then
		DoImpulsor(x,y,cell,(dir+2)%4)
	else
		DoRepulsor(x,y,cell,dir)
	end
end

function DoSuperRepulsor(x,y,cell,dir)
	if Override("DoSuperRepulsor"..cell.id,x,y,cell,dir) then return end
	local cx,cy,cdir = NextCell(x,y,dir)
	if cx then
		while true do
			local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
			if IsTransparent(GetCell(cx,cy),cdir,cx,cy,{forcetype="push"}) or not PushCell(cx,cy,cdir,{force=math.huge,noupdate=true}) then
				break
			end
			local data = GetData(cx,cy)
			if data.supdatekey == supdatekey and data.scrosses >= 5 then
				break
			else
				data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
			end
			data.supdatekey = supdatekey
			if not nextx then break end
			cx,cy,cdir = nextx,nexty,nextdir
		end
		supdatekey = supdatekey + 1
	end
end

function DoTimeRepulse(x,y,cell,dir)
	if Override("DoTimeRepulse"..cell.id,x,y,cell,dir) then return end
	local k = dir==0 and "timerepulseright" or dir==2 and "timerepulseleft" or dir==3 and "timerepulseup" or "timerepulsedown"
	if cell.vars[k] then
		cell.vars[k] = cell.vars[k] - 1
		if cell.vars[k] <= 0 then
			cell.vars[k] = nil
			PushCell(x,y,dir,{force=1,noupdate=true,repeats=0})
		end
	end
end

function DoTimeRepulsor(x,y,cell)
	if Override("DoTimeRepulsor"..cell.id,x,y,cell,dir) then return end
	for i=0,3 do
		if HasOnesidedDirection(cell,i,1102,1100,1103,222,1101) then
			local cx,cy,cdir = NextCell(x,y,i)
			local c = GetCell(cx,cy)
			local k = i==0 and "timerepulseright" or i==2 and "timerepulseleft" or i==3 and "timerepulseup" or "timerepulsedown"
			c.vars[k] = math.min(c.vars[k] or math.huge,cell.vars[1])
			SetChunkId(x,y,"timerep")
		end
	end
end

function DoRepulsor(x,y,cell,dir)
	if Override("DoRepulsor"..cell.id,x,y,cell,dir) then return end
	if cell.id >= 1175 and cell.id < 1180 then
		local nextx,nexty,nextdir = NextCell(x,y,dir)
		local vars = {force=1,noupdate=true}
		if not PushCell(nextx,nexty,nextdir,vars) and vars.repeats > 2 then
			local hitcell = GetCell(nextx,nexty)
			if not IsUnbreakable(hitcell,nextdir,nextx,nexty,{forcetype="destroy"}) then
				DamageCell(GetCell(nextx,nexty),1,nextdir,nextx,nexty,{lastcell=cell,lastx=x,lasty=y,lastdir=cdir})
				Play("destroy")
			end
		end
	else
		x,y = StepForward(x,y,dir)
		PushCell(x,y,dir,{force=1,noupdate=true,row=cell.id >= 763 and cell.id <= 767})
	end
end

masses = {[1133]=1,[1134]=1,[1135]=1,[1136]=1,[1137]=0,[1138]=0,[1139]=0,[1140]=0,[1141]=0,[1142]=0,[1143]=0,[1144]=0,[1145]=1,[1146]=1,[1147]=1,[1148]=1,[236]=0,[1149]=0}
charges = {[1133]=1,[1134]=-1,[1137]=-1,[1138]=1,[1139]=-2,[1140]=2,[1141]=-4,[1142]=4}
gravity = {[1143]=1,[1144]=-1}
mult = {[1144]=-1}
function DoParticleCharges(x,y,cell)
	if Override("DoParticleCharges"..cell.id,x,y,cell,dir) then return end
	local charge1 = charges[cell.id] or 0
	local neighbors = GetArea(x,y,5)
	for k,v in pairs(neighbors) do
		local cell2 = GetCell(v[1],v[2])
		if cell2 ~= cell then
			local charge2 = charges[cell2.id] or 0
			local dist = math.distSqr(x-v[1],y-v[2])	--we need to square it for force equations anyways
			local angle = math.angle(x-v[1],y-v[2])
			local force = (charge1*charge2 - (gravity[cell2.id] or 0)*(mult[cell.id] or 1))/dist*100
			local ax = math.cos(angle)*force
			local ay = math.sin(angle)*force
			if ax > 0 then ax = math.floor(ax+.5) else ax = -math.floor(-ax+.5) end
			if ay > 0 then ay = math.floor(ay+.5) else ay = -math.floor(-ay+.5) end
			cell.vars[1] = cell.vars[1] + ax
			cell.vars[2] = cell.vars[2] + ay
		end
	end
end

function DoParticleStrongForce(x,y,cell)
	if Override("DoParticleStrongForce"..cell.id,x,y,cell,dir) then return end
	if cell.id == 1135 or cell.id == 1136 or cell.id == 1145 or cell.id == 1146 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			local cell2 = GetCell(v[1],v[2])
			if cell.id%2 == cell2.id%2 and (cell2.id == 1133 or cell2.id == 1134) then
				if cell.id == 1145 or cell.id == 1146 then
					cell2.vars[1] = cell.vars[1]
					cell2.vars[2] = cell.vars[2]
				else
					local mult = (v[1] == x or v[2] == y) and 100 or 70
					if cell2.vars[1] > 0 then
						cell2.vars[1] = math.max(cell.vars[1], cell2.vars[1] - mult)
					else
						cell2.vars[1] = math.min(cell.vars[1], cell2.vars[1] + mult)
					end
					if cell2.vars[2] > 0 then
						cell2.vars[2] = math.max(cell.vars[2], cell2.vars[2] - mult)
					else
						cell2.vars[2] = math.min(cell.vars[2], cell2.vars[2] + mult)
					end
				end
			end
		end
	elseif cell.id == 1149 then
		local neighbors = GetSurrounding(x,y)
		for k,v in pairs(neighbors) do
			local cell2 = GetCell(v[1],v[2])
			if cell2.id == 1135 or cell2.id == 1136 then
				cell.id = cell2.id + 2
				cell2.id = cell2.id - 2
				break
			end
		end
	end
end

function DoParticleChargeStick(x,y,cell)
	if Override("DoParticleChargeStick"..cell.id,x,y,cell,dir) then return end
	local neighbors = GetNeighbors(x,y)
	for k,v in pairs(neighbors) do
		local cell2 = GetCell(v[1],v[2])
		if charges[cell.id] and charges[cell2.id] and (masses[cell.id] or 0) >= (masses[cell2.id] or 0) then
			local stick = (charges[cell.id] or 0)*(charges[cell2.id] or 0)*((v[1] == x or v[2] == y) and 100 or 70)
			if stick < 0 and cell2.id%2 == cell.id%2 then
				if cell2.vars[1] > 0 then
					cell2.vars[1] = math.max(cell.vars[1], cell2.vars[1] + stick)
				else
					cell2.vars[1] = math.min(cell.vars[1], cell2.vars[1] - stick)
				end
				if cell2.vars[2] > 0 then
					cell2.vars[2] = math.max(cell.vars[2], cell2.vars[2] + stick)
				else
					cell2.vars[2] = math.min(cell.vars[2], cell2.vars[2] - stick)
				end
			end
		end
	end
end

function DoParticleMovement(x,y,cell)
	if Override("DoParticleMovement"..cell.id,x,y,cell,dir) then return end
	cell.pupdated = true
	local vx,vy = cell.vars[1]/100,cell.vars[2]/100
	if vx > 0 then
		if tickcount%(1/(vx%1)) < 1 then
			vx = vx + 1
		end
		vx = math.floor(vx)
	elseif vx < 0 then
		vx = -vx
		if tickcount%(1/(vx%1)) < 1 then
			vx = vx + 1
		end
		vx = -math.floor(vx)
	end
	if vy > 0 then
		if tickcount%(1/(vy%1)) < 1 then
			vy = vy + 1
		end
		vy = math.floor(vy)
	elseif vy < 0 then
		vy = -vy
		if tickcount%(1/(vy%1)) < 1 then
			vy = vy + 1
		end
		vy = -math.floor(vy)
	end
	local cx,cy = x,y
	while vx ~= 0 or vy ~= 0 do
		local xfirst =  math.abs(vx) >= math.abs(vy)
		if xfirst and vx ~= 0 then
			local nextx,nexty = NextCell(cx,cy,vx > 0 and 0 or 2)
			if GetCell(cx,cy).id ~= cell.id then
				break
			elseif not PushCell(cx,cy,vx > 0 and 0 or 2,{force=math.abs(vx),skipfirst=true,particlepush=true}) then
				if GetCell(cx,cy).id == cell.id then
					GetCell(cx,cy).vars[1] = vx*100
				end
				vx = 1	--subtraction applies after
				nextx,nexty = cx,cy
			end
			updatekey = updatekey + 1
			if not nextx then break end
			cx,cy = nextx,nexty
			vx = vx > 0 and vx - 1 or vx + 1
		end
		if vy ~= 0 then
			local nextx,nexty = NextCell(cx,cy,vy > 0 and 1 or 3)
			if GetCell(cx,cy).id ~= cell.id then
				break
			elseif not PushCell(cx,cy,vy > 0 and 1 or 3,{force=math.abs(vy),skipfirst=true,particlepush=true}) then
				if GetCell(cx,cy).id == cell.id then
					GetCell(cx,cy).vars[2] = vy*100
				end
				vy = 1
				nextx,nexty = cx,cy
			end
			updatekey = updatekey + 1
			if not nextx then break end
			cx,cy = nextx,nexty
			vy = vy > 0 and vy - 1 or vy + 1
		end
		if not xfirst and vx ~= 0 then
			local nextx,nexty = NextCell(cx,cy,vx > 0 and 0 or 2)
			if GetCell(cx,cy).id ~= cell.id then
				break
			elseif not PushCell(cx,cy,vx > 0 and 0 or 2,{force=math.abs(vx),skipfirst=true,particlepush=true}) then
				if GetCell(cx,cy).id == cell.id then
					GetCell(cx,cy).vars[1] = vx*100
				end
				vx = 1	--subtraction applies after
				nextx,nexty = cx,cy
			end
			updatekey = updatekey + 1
			if not nextx then break end
			cx,cy = nextx,nexty
			vx = vx > 0 and vx - 1 or vx + 1
		end
	end
	if dodebug then GetCell(cx,cy).testvar = (cell.vars[1]/100).." "..(cell.vars[2]/100) end
end

function DoMagnet(x,y,cell)
	if Override("DoMagnet"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cdir = cell.rot
	local cx,cy = StepForward(x,y,cell.rot)
	if GetCell(cx,cy).id == 156 and GetCell(cx,cy).rot == (cell.rot+2)%4 then
		PushCell(cx,cy,cell.rot,{force=1,noupdate=true})
	elseif IsNonexistant(GetCell(cx,cy),cell.rot,cx,cy) then
		local cx,cy,cdir = NextCell(cx,cy,cell.rot,nil,true,true)
		if cx and GetCell(cx,cy).id == 156 and GetCell(cx,cy).rot == cell.rot then
			PullCell(cx,cy,(cdir+2)%4,{force=1,noupdate=true})
		end
	end
	if GetCell(x,y) == cell then
		local cdir = cell.rot
		local cx,cy = StepBack(x,y,cell.rot)
		if GetCell(cx,cy).id == 156 and GetCell(cx,cy).rot == (cell.rot+2)%4 then
			PushCell(cx,cy,(cell.rot+2)%4,{force=1,noupdate=true})
		elseif IsNonexistant(GetCell(cx,cy),cell.rot,cx,cy) then
			local cx,cy,cdir = NextCell(cx,cy,(cell.rot+2)%4,nil,true,true)
			if cx and GetCell(cx,cy).id == 156 and GetCell(cx,cy).rot == cell.rot then
				PullCell(cx,cy,(cdir+2)%4,{force=1,noupdate=true})
			end
		end
	end
end

function DoSuperSpring(x,y,cell)
	if Override("DoSuperSpring"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy,cdir,ccx,ccy,ccdir = x,y,(cell.rot%2==0 and 0 or 3),x,y,(cell.rot%2==0 and 2 or 1)
	while true do
		cx,cy,cdir = NextCell(cx,cy,cdir)
		if not PushCell(cx,cy,cdir,{replacecell=table.copy(cell),force=math.huge}) or IsDestroyer(GetCell(cx,cy),cdir,cx,cy,{forcetype="push"}) then
			break
		end
	end
	while true do
		ccx,ccy,ccdir = NextCell(ccx,ccy,ccdir)
		if not PushCell(ccx,ccy,ccdir,{replacecell=table.copy(cell),force=math.huge}) or IsDestroyer(GetCell(ccx,ccy),ccdir,ccx,ccy,{forcetype="push"}) then
			break
		end
	end
end

function DoSpring(x,y,cell)
	if Override("DoSpring"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy,cdir = x,y,(cell.rot%2==0 and 0 or 3)
	if cell.rot%2 == 0 then cx = x + 1 elseif cell.rot%2 == 1 then cy = y - 1 end
	if cell.vars[1] then
		local old = cell.vars[1]
		local topush = math.ceil(cell.vars[1]/2)-1
		cell.vars[1] = math.floor(cell.vars[1]/2)
		if cell.vars[1] == 0 then
			cell.vars[1] = nil
		end
		if topush == 0 then
			topush = nil
		end
		if not PushCell(cx,cy,cdir,{replacecell = {id=402,rot=cell.rot,lastvars=cell.lastvars,vars={topush}},force = old+1,sprung = true}) then
			if cell.rot%2 == 0 then cx = x - 1 elseif cell.rot%2 == 1 then cy = y + 1 end
			if not PushCell(cx,cy,(cdir+2)%4,{replacecell = {id=402,rot=cell.rot,lastvars=cell.lastvars,vars={topush}},force = old+1,sprung = true}) then
				cell.vars[1] = old
			end
		end
	end
end

function DoConveyorZone(x,y,cell,dir)
	if Override("DoConveyorZone"..cell.id,x,y,cell,dir) then return end
	PushCell(x,y,dir,{force=1})
end

function DoSuperDeleter(x,y,cell,dir)
	if Override("DoSuperDeleter"..cell.id,x,y,cell,dir) then return end
	local cx,cy,cdir = x,y,dir
	while true do
		cx,cy,cdir = NextCell(cx,cy,cdir)
		if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) and not IsUnbreakable(GetCell(cx,cy),cdir,cx,cy,{forcetype="destroy",lastcell=cell}) then
			DamageCell(GetCell(cx,cy),1,cdir,cx,cy,{lastcell=cell,lastx=x,lasty=y,undocells={}})
			Play("destroy")
		else
			break
		end
	end
end

function DoDeleter(x,y,cell,dir)
	if Override("DoDeleter"..cell.id,x,y,cell,dir) then return end
	local cx,cy,cdir = NextCell(x,y,dir)
	if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) and not IsUnbreakable(GetCell(cx,cy),cdir,cx,cy,{forcetype="destroy",lastcell=cell}) then
		DamageCell(GetCell(cx,cy),1,cdir,cx,cy,{lastcell=cell,lastx=x,lasty=y,undocells={}})
		Play("destroy")
	end
end

function DoTermite(x,y,cell)
	if Override("DoTermite"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if cell.id == 306 then
		RotateCellRaw(cell,1)
		for i=1,4 do
			if not PushCell(x,y,GetCell(x,y).rot,{force=1,noupdate=true}) and GetCell(x,y).id == 306 then
				RotateCellRaw(GetCell(x,y),-1)
			else
				break
			end
		end
	elseif cell.id == 307 then
		RotateCellRaw(cell,-1)
		for i=1,4 do
			if not PushCell(x,y,(GetCell(x,y).rot+2)%4,{force=1,noupdate=true}) and GetCell(x,y).id == 307 then
				RotateCellRaw(GetCell(x,y),1)
			else
				break
			end
		end
	end
end

function SliceCell(x,y,dir,vars)
	local cell = GetCell(x,y)
	vars = vars or {}
	vars.force = vars.force or 1
	local vars2 = {}
	vars2.lastx,vars2.lasty = StepBack(x,y,dir)
	vars2.lastdir = dir
	vars2.forcetype = "slice"
	logforce(x,y,dir,vars2,cell)
	local nvars = {}
	if not NudgeCell(x,y,dir,nvars) then
		local cx,cy = StepForward(x,y,dir)
		local cdir = (dir == 0 or dir == 2) and 3 or 0
		if not IsUnbreakable(GetCell(cx,cy),dir,cx,cy,{forcetype="slice",lastcell=cell}) and PushCell(cx,cy,cdir,table.copy(vars)) then
			if GetCell(x,y) == nvars.lastcell then return NudgeCell(x,y,dir) end
		else
			if not IsUnbreakable(GetCell(cx,cy),dir,cx,cy,{forcetype="slice",lastcell=cell}) and PushCell(cx,cy,(cdir+2)%4,vars) then
				if GetCell(x,y) == nvars.lastcell then return NudgeCell(x,y,dir) end
			end
		end
	else
		return true
	end
end

function StapleCell(x,y,dir,vars)
	local cell = GetCell(x,y)
	vars = vars or {}
	vars.force = vars.force or 1
	local vars2 = {}
	vars2.lastx,vars2.lasty = StepBack(x,y,dir)
	vars2.lastdir = dir
	vars2.forcetype = "staple"
	logforce(x,y,dir,vars2,cell)
	local nvars = {}
	if NudgeCell(x,y,dir,nvars) then
		local cdir = (dir == 0 or dir == 2) and 1 or 2
		local cx,cy = StepBackwards(x,y,cdir)
		PullCell(cx,cy,cdir,table.copy(vars))
		local cx,cy = StepForwards(x,y,cdir)
		PullCell(cx,cy,(cdir+2)%4,vars)
		return true
	end
end

function StapleEmptyCell(x,y,dir,vars)
	vars = vars or {}
	vars.force = vars.force or 1
	local vars2 = {}
	vars2.lastx,vars2.lasty = StepBack(x,y,dir)
	vars2.lastdir = dir
	vars2.forcetype = "staple"
	logforce(x,y,dir,vars2,getempty())
	local cdir = (dir == 0 or dir == 2) and 1 or 2
	local cx,cy = StepBackwards(x,y,cdir)
	PullCell(cx,cy,cdir,table.copy(vars))
	local cx,cy = StepForwards(x,y,cdir)
	PullCell(cx,cy,(cdir+2)%4,vars)
	return tru
end

function TunnelCell(x,y,dir,strong)
	local cx,cy,cell = x,y,GetCell(x,y)
	local vars = {}
	vars.lastx,vars.lasty = StepBack(x,y,dir)
	vars.lastdir = dir
	vars.forcetype = strong and "dig" or "tunnel" -- two distinct forces
	logforce(x,y,dir,vars,cell)
	SetCell(x,y,getempty())
	while true do
		cx,cy = StepForward(cx,cy,dir)
		if strong and PushCell(cx,cy,dir,{replacecell=cell,force=1}) or NudgeCellTo(cell,cx,cy,dir) then
			return true
		elseif IsUnbreakable(GetCell(cx,cy),dir,cx,cy,{forcetype="tunnel"}) then
			break
		end
	end
	SetCell(x,y,cell)
end

function TrespassCell(x,y,dir)
	local cx,cy,cell = x,y,GetCell(x,y)
	while true do
		nextx,nexty = StepForward(cx,cy,dir)
		if IsUnbreakable(GetCell(nextx,nexty),dir,nextx,nexty,{forcetype="swap"}) then
			break
		elseif IsNonexistant(GetCell(nextx,nexty),dir,nextx,nexty,{forcetype="swap"}) then
			if cx == x and cy == y then
				cx,cy = nextx,nexty
			end
			break
		end
		cx,cy = nextx,nexty
	end
	SwapCells(x,y,(dir+2)%4,cx,cy,dir)
end

function LSliceCell(x,y,dir,vars)
	local cell = GetCell(x,y)
	vars = vars or {}
	vars.force = vars.force or 1
	local vars2 = {}
	vars2.lastx,vars2.lasty = StepBack(x,y,dir)
	vars2.lastdir = dir
	vars2.forcetype = "sliceL"
	logforce(x,y,dir,vars2,cell)
	local nvars = {}
	if not NudgeCell(x,y,dir,nvars) then
		local cx,cy = StepForward(x,y,dir)
		local cdir = (dir-1)%4
		if not IsUnbreakable(GetCell(cx,cy),dir,cx,cy,{forcetype="slice",lastcell=cell}) and PushCell(cx,cy,cdir,table.copy(vars)) then
			if GetCell(x,y) == nvars.lastcell then return NudgeCell(x,y,dir) end
		end
	else
		return true
	end
end

function RSliceCell(x,y,dir,vars)
	local cell = GetCell(x,y)
	vars = vars or {}
	vars.force = vars.force or 1
	local vars2 = {}
	vars2.lastx,vars2.lasty = StepBack(x,y,dir)
	vars2.lastdir = dir
	vars2.forcetype = "slice"
	logforce(x,y,dir,vars2,cell)
	local nvars = {}
	if not NudgeCell(x,y,dir,nvars) then
		local cx,cy = StepForward(x,y,dir)
		local cdir = (dir+1)%4
		if not IsUnbreakable(GetCell(cx,cy),dir,cx,cy,{forcetype="slice",lastcell=cell}) and PushCell(cx,cy,cdir,table.copy(vars)) then
			if GetCell(x,y) == nvars.lastcell then return NudgeCell(x,y,dir) end
		end
	else
		return true
	end
end

function CustomMove(cell,x,y,dir,push,pull,grab,drill,slice,vars)
	vars.pushmax,vars.pullmax,vars.grabmax = vars.pushmax or 0,vars.pullmax or 0,vars.grabmax or 0
	local cx,cy = StepForward(x,y,dir)
	local ccx,ccy = StepBack(x,y,dir)
	if push == 1 and PushCell(x,y,dir,{force=vars.force,maximum=vars.pushmax == 0 and vars.pushmax or vars.pushmax+1,skipfirst=true})
	or push == 2 and NudgeCell(x,y,dir) then
		if grab ~= 0 then GrabEmptyCell(x,y,dir,{force=vars.force,maximum=vars.grabmax == 0 and vars.grabmax or vars.grabmax+1,strong=grab==2}) end
		if pull == 1 then PullCell(ccx,ccy,dir,{force=vars.force,maximum=vars.pullmax}) end
		return true
	elseif slice == 1 and SliceCell(x,y,dir) then
		if grab ~= 0 then GrabEmptyCell(x,y,dir,{force=vars.force,maximum=vars.grabmax == 0 and vars.grabmax or vars.grabmax+1,strong=grab==2}) end
		if pull == 1 then PullCell(ccx,ccy,dir,{force=vars.force,maximum=vars.pullmax}) end
		return true
	elseif drill == 1 and SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
		if grab ~= 0  then GrabEmptyCell(x,y,dir,{force=vars.force,maximum=vars.grabmax == 0 and vars.grabmax or vars.grabmax+1,strong=grab==2}) end
		if pull == 1 then PullCell(ccx,ccy,dir,{force=vars.force,maximum=vars.pullmax}) end
		return true
	elseif grab ~= 0 and GrabCell(x,y,dir,{force=force,maximum=vars.grabmax == 0 and vars.grabmax or vars.grabmax+1,skipfirst=true,strong=grab==2}) then
		if pull == 1 then PullCell(ccx,ccy,dir,{force=vars.force,maximum=vars.pullmax}) end
		return true
	elseif pull == 1 and PullCell(x,y,dir,{force=vars.force,maximum=vars.pullmax == 0 and vars.pullmax or vars.pullmax+1,skipfirst=true}) then
		return true
	end
	return false
end

function ApeirocellMovement(x,y,cell,f)
	for j=0,3 do
		if cell.vars[21+j] == 1 then
			local cx,cy,cdir = NextCell(x,y,(cell.rot+j)%4)
			if IsNonexistant(GetCell(cx,cy),cdir,cx,cy) then
				return nil
			end
		end
	end
	return CustomMove(cell,x,y,cell.rot,cell.vars[6],cell.vars[7],cell.vars[8],cell.vars[9],cell.vars[10],{force=f,pushmax=cell.vars[13],pullmax=cell.vars[14],grabmax=cell.vars[15]})
end

function DoApeirocell(x,y,cell)
	if Override("DoApeirocell"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	cell.vars[16] = (cell.vars[16]+1)%cell.vars[12]
	if cell.vars[16] == 0 then
		local old11 = cell.vars[11]
		cell.vars[11] = cell.vars[11] + cell.vars[27]
		local cx,cy,cdir,i = x,y,cell.rot,cell.updates or 0
		while i < old11 or old11 == 0 do
			local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
			local newc = GetCell(cx,cy)
			if newc ~= cell or newc.rot ~= cdir then
				break
			end
			local success = ApeirocellMovement(cx,cy,newc,old11 == 0 and math.huge or old11-i)
			if success == false then
				newc = GetCell(cx,cy)
				if newc.id == cell.id then
					if newc.vars[25] == 4 then
						SetCell(cx,cy,getempty({newc}))
					elseif newc.vars[25] ~= 0 then
						RotateCellRaw(newc,newc.vars[25] == 1 and 1 or newc.vars[25] == 2 and -1 or -2)
					end
				end
				break
			elseif not success then
				break
			end
			updatekey = updatekey + 1
			local data = GetData(cx,cy)
			if data.supdatekey == supdatekey and data.scrosses >= 5 then
				break
			else
				data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
			end
			data.supdatekey = supdatekey
			if not nextx then break end
			cx,cy,cdir = nextx,nexty,nextdir
			i = i + 1
		end
	end
	supdatekey = supdatekey + 1
end

function GetRandomRutziceGene()
	local t = {0,1}
	local canabsorb
	while true do
		table.insert(t,math.random(17))
		canabsorb = canabsorb or t[#t] == 1
		if canabsorb and math.random(10) == 10 then break end
	end
	return t
end

function DoRutzice(x,y,cell)
	if Override("DoRutzice"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy,cdir = NextCell(x,y,cell.rot)
	if cell.vars[1] >= math.random(7,13) and math.random() > .25 then
		if PushCell(x,y,(cell.rot+2)%4,{force=1,replacecell={id=624,rot=cell.rot,lastvars=table.copy(cell.lastvars),vars=GetRandomRutziceGene()}}) then
			cell.vars[1] = 0
		end
	elseif math.random(25*cell.vars[1]+25) == 1 then
		cell.vars = table.merge({cell.vars[1]},GetRandomRutziceGene())
	else
		cell.vars[2] = (cell.vars[2])%(#cell.vars-2)+1
		local gene = cell.vars[cell.vars[2]+2]
		if gene == 1 then
			if GetCell(cx,cy).id ~= 624 and not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) and CanMove(GetCell(cx,cy),cdir,cx,cy,"pull") then
				cell.eatencells = {GetCell(cx,cy)}
				SetCell(cx,cy,getempty())
				cell.vars[1] = cell.vars[1] + 1
			end
		elseif gene == 2 then
			PushCell(x,y,cell.rot,{force=1})
		elseif gene == 3 then RotateCellRaw(cell,1)
		elseif gene == 4 then RotateCellRaw(cell,2)
		elseif gene == 5 then RotateCellRaw(cell,3)
		elseif gene == 6 then RotateCell(cx,cy,1,cdir)
		elseif gene == 7 then RotateCell(cx,cy,2,cdir)
		elseif gene == 8 then RotateCell(cx,cy,3,cdir)
		elseif gene == 9 then
			if IsNonexistant(GetCell(cx,cy),cdir,cx,cy) then
				cell.vars[2] = (cell.vars[2])%(#cell.vars-2)+1
			end
		elseif gene == 10 then
			if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) then
				cell.vars[2] = (cell.vars[2])%(#cell.vars-2)+1
			end
		elseif gene == 11 then RotateCellRaw(cell,math.random(3))
		elseif gene == 12 then RotateCell(cx,cy,math.random(3),cdir)
		elseif gene == 13 then
			if math.random(2) == 2 then
				cell.vars[2] = (cell.vars[2])%(#cell.vars-2)+1
			end
		elseif gene == 14 then
			RotateCellRaw(cell,1)
			PushCell(x,y,cell.rot,{force=1})
		elseif gene == 15 then
			RotateCellRaw(cell,2)
			PushCell(x,y,cell.rot,{force=1})
		elseif gene == 16 then
			RotateCellRaw(cell,3)
			PushCell(x,y,cell.rot,{force=1})
		elseif gene == 17 then
			RotateCellRaw(cell,math.random(3))
			PushCell(x,y,cell.rot,{force=1})
		end
	end
end

function DoDriller(x,y,cell)
	if Override("DoDriller"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local dir = cell.rot
	local cx,cy = StepForward(x,y,dir)
	local ccx,ccy = StepBack(x,y,dir)
	if cell.id == 58 then
		SwapCells(x,y,(dir+2)%4,cx,cy,dir)
	elseif cell.id == 59 then
		if not PushCell(x,y,dir) then 
			SwapCells(x,y,(dir+2)%4,cx,cy,dir)
		end
	elseif cell.id == 60 then
		if PushCell(x,y,dir) then
			PullCell(ccx,ccy,dir,{force=1})
		elseif not PullCell(x,y,dir) then
			SwapCells(x,y,(dir+2)%4,cx,cy,dir)
		end
	elseif cell.id == 61 then
		if not PullCell(x,y,dir) then
			SwapCells(x,y,(dir+2)%4,cx,cy,dir)
		end
	elseif cell.id == 75 then 
		if SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
		else
			GrabCell(x,y,dir)
		end
	elseif cell.id == 76 then
		if PushCell(x,y,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
		else
			GrabCell(x,y,dir)
		end
	elseif cell.id == 77 then
		if GrabCell(x,y,dir) then
			PullCell(ccx,ccy,dir,{force=1})
		elseif PullCell(x,y,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		end
	elseif cell.id == 78 then
		if PushCell(x,y,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		elseif GrabCell(x,y,dir) then
			PullCell(ccx,ccy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 276 then
		if not SliceCell(x,y,dir) then 
			SwapCells(x,y,(dir+2)%4,cx,cy,dir)
		end
	elseif cell.id == 277 then
		if not PushCell(x,y,dir) then 
			if not SliceCell(x,y,dir) then 
				SwapCells(x,y,(dir+2)%4,cx,cy,dir)
			end
		end
	elseif cell.id == 278 then
		if SliceCell(x,y,dir) then 
			PullCell(ccx,ccy,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			PullCell(ccx,ccy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 279 then
		if PushCell(x,y,dir) then 
			PullCell(ccx,ccy,dir,{force=1})
		elseif SliceCell(x,y,dir) then 
			PullCell(ccx,ccy,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			PullCell(ccx,ccy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 280 then
		if SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
		else
			GrabCell(x,y,dir)
		end
	elseif cell.id == 281 then
		if PushCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		elseif SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
		else
			GrabCell(x,y,dir)
		end
	elseif cell.id == 282 then
		if SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		elseif GrabCell(x,y,dir) then 
			PullCell(ccx,ccy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 283 then
		if PushCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		elseif SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		elseif SwapCells(x,y,(dir+2)%4,cx,cy,dir) then
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(ccx,ccy,dir,{force=1})
		elseif GrabCell(x,y,dir) then 
			PullCell(ccx,ccy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 355 then
		cell.updated = true
		cell.vars[3] = (cell.vars[3]+1)%cell.vars[2]
		if cell.vars[3] == 0 then
			local cx,cy = x,y
			for i=cell.updates or 0,cell.vars[1]-1 do
				local nextx,nexty = StepForward(cx,cy,dir)
				if GetCell(cx,cy) ~= cell or not SwapCells(cx,cy,(dir+2)%4,nextx,nexty,dir) then
					break
				end
				updatekey = updatekey + 1
				cx,cy = nextx,nexty
			end
		end
	elseif cell.id == 552 then
		DoApeirocell(x,y,cell)
	elseif cell.id == 1162 then
		TrespassCell(x,y,cell.rot)
	end
end

function DoPuller(x,y,cell)
	if Override("DoPuller"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local dir = cell.rot
	local cx,cy = StepBack(x,y,dir)
	if cell.id == 14 then
		PullCell(x,y,dir)
	elseif cell.id == 28 then
		if PushCell(x,y,dir) then
			PullCell(cx,cy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 73 then
		if GrabCell(x,y,dir) then
			PullCell(cx,cy,dir,{force=1})
		elseif PullCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		end
	elseif cell.id == 74 then
		if PushCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(cx,cy,dir,{force=1})
		elseif GrabCell(x,y,dir) then
			PullCell(cx,cy,dir,{force=1})
		else
			PullCell(x,y,dir,{force=1})
		end
	elseif cell.id == 270 then
		if SliceCell(x,y,dir) then 
			PullCell(cx,cy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 271 then
		if PushCell(x,y,dir) then 
			PullCell(cx,cy,dir,{force=1})
		elseif SliceCell(x,y,dir) then 
			PullCell(cx,cy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 274 then
		if SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(cx,cy,dir,{force=1})
		elseif GrabCell(x,y,dir) then 
			PullCell(cx,cy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 275 then
		if PushCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(cx,cy,dir,{force=1})
		elseif SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
			PullCell(cx,cy,dir,{force=1})
		elseif GrabCell(x,y,dir) then 
			PullCell(cx,cy,dir,{force=1})
		else
			PullCell(x,y,dir)
		end
	elseif cell.id == 305 then
		local ccx,ccy = NextCell(x,y,dir)
		if PullCell(x,y,dir) and not IsTransparent(GetCell(x,y),dir,x,y,{forcetype="pull",lastcell=cell}) then
			if fancy then cell.eatencells = {table.copy(cell)} end
			cell.id = 0
		end
	elseif cell.id == 311 then
		local v = {}
		if PushCell(x,y,dir,v) then
			PullCell(cx,cy,dir,{force=1,undocells=v.undocells})
		end
	elseif cell.id == 353 then
		cell.updated = true
		cell.vars[3] = (cell.vars[3]+1)%cell.vars[2]
		cell.updatedforce = 0
		if cell.vars[3] == 0 then
			cell.updatedforce = cell.vars[1]
			local cx,cy,cdir = x,y,dir
			for i=cell.updates or 0,cell.vars[1]-1 do
				local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
				if GetCell(cx,cy) ~= cell or not PullCell(cx,cy,cdir,{force=-i,maximum=cell.vars[4] == 0 and cell.vars[4] or cell.vars[4]+1}) then
					break
				end
				updatekey = updatekey + 1
				local data = GetData(cx,cy)
				if data.supdatekey == supdatekey and data.scrosses >= 5 then
					break
				else
					data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
				end
				data.supdatekey = supdatekey
				if not nextx then break end
				cx,cy,cdir = nextx,nexty,nextdir
			end
			supdatekey = supdatekey + 1
		end
	elseif cell.id == 552 then
		DoApeirocell(x,y,cell)
	elseif cell.id == 719 then
		PullCell(x,y,dir,{row=true})
	elseif cell.id == 720 then
		if PushCell(x,y,dir,{row=true}) then
			PullCell(cx,cy,dir,{force=1,row=true})
		else
			PullCell(x,y,dir,{row=true})
		end
	end
end

function DoGrabber(x,y,cell)
	if Override("DoGrabber"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local dir = cell.rot
	if cell.id == 71 then
		GrabCell(x,y,dir)
	elseif cell.id == 72 then
		if PushCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		else
			GrabCell(x,y,dir)
		end
	elseif cell.id == 272 then
		if SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		else
			GrabCell(x,y,dir)
		end
	elseif cell.id == 273 then
		if PushCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		elseif SliceCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1})
		else
			GrabCell(x,y,dir)
		end
	elseif cell.id == 354 then
		cell.updated = true
		cell.vars[3] = (cell.vars[3]+1)%cell.vars[2]
		cell.updatedforce = 0
		if cell.vars[3] == 0 then
			cell.updatedforce = cell.vars[1]
			local cx,cy,cdir = x,y,dir
			for i=cell.updates or 0,cell.vars[1]-1 do
				local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
				if GetCell(cx,cy) ~= cell or not (NudgeCell(cx,cy,cdir) and GrabEmptyCell(cx,cy,cdir,{force=cell.vars[1]-i,maximum=cell.vars[4] == 0 and cell.vars[4] or cell.vars[4]+1})) then
					break
				end
				updatekey = updatekey + 1
				local data = GetData(cx,cy)
				if data.supdatekey == supdatekey and data.scrosses >= 5 then
					break
				else
					data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
				end
				data.supdatekey = supdatekey
				if not nextx then break end
				cx,cy,cdir = nextx,nexty,nextdir
			end
			supdatekey = supdatekey + 1
		end
	elseif cell.id == 400 then
		if PushCell(x,y,dir) then 
			GrabEmptyCell(x,y,dir,{force=1,strong=true})
		else
			GrabCell(x,y,dir,{strong=true})
		end
	elseif cell.id == 552 then
		DoApeirocell(x,y,cell)
	end
end

function DoSuperMover(x,y,cell)
	if Override("DoSuperMover"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy,cdir = x,y,cell.rot
	while true do
		local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
		local vars = {}
		if GetCell(cx,cy) ~= cell then
			break
		elseif not PushCell(cx,cy,cdir,vars) and vars.repeats > 2 then
			if cell.id == 1161 then
				local hitcell = GetCell(nextx,nexty)
				if not IsUnbreakable(hitcell,nextdir,nextx,nexty,{forcetype="destroy"}) then
					DamageCell(GetCell(nextx,nexty),math.huge,nextdir,nextx,nexty,{lastcell=cell,lastx=cx,lasty=cy,lastdir=cdir})
					Play("destroy")
				end
			end
			break
		end
		updatekey = updatekey + 1
		local data = GetData(cx,cy)
		if data.supdatekey == supdatekey and data.scrosses >= 5 then
			break
		else
			data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
		end
		data.supdatekey = supdatekey
		if not nextx then break end
		cx,cy,cdir = nextx,nexty,nextdir
	end
	supdatekey = supdatekey + 1
end

function DoMover(x,y,cell)
	if Override("DoMover"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local dir = cell.rot
	if cell.id == 2 or cell.id == 213 or cell.id == 423 or cell.id == 863 or cell.id == 864 or cell.id == 865 then
		PushCell(x,y,dir)
	elseif cell.id == 269 then
		if not PushCell(x,y,dir) then
			SliceCell(x,y,dir)
		end
	elseif cell.id == 904 then
		TunnelCell(x,y,cell.rot,true)
	elseif cell.id == 905 and cell.vars[1] then
		if not PushCell(x,y,dir) then
			SetCell(x,y,GetStoredCell(cell,true,{cell}))
		end
	elseif cell.id == 303 then
		if not PushCell(x,y,dir) then
			local cx,cy,cdir = NextCell(x,y,dir)
			if cx then 
				local cell2 = GetCell(cx,cy)
				if not IsUnbreakable(cell2,cdir,cx,cy,{forcetype="destroy",lastcell=cell}) then
					SetCell(cx,cy,getempty())
					if fancy then GetCell(x,y).eatencells = {cell2} end
					PushCell(x,y,dir)
				end
			end
		end
	elseif cell.id == 304 then
		local cx,cy,cdir = NextCell(x,y,dir)
		if cx then 
			local cell2 = GetCell(cx,cy)
			if IsTransparent(cell2,cdir,cx,cy,{forcetype="push",lastcell=cell}) then
				PushCell(x,y,dir)
			else
				SetCell(x,y,getempty())
				PushCell(cx,cy,cdir,{force=1,undocells={[x+y*width] = cell},replacecell={id=0,rot=0,lastvars={x,y,0},vars={},eatencells={cell}}})
			end
		end
	elseif cell.id == 346 then
		if dir%2 == 0 then
			PushCell(x,y-1,3,{force=1})
			PushCell(x,y+1,1,{force=1})
		else
			PushCell(x+1,y,0,{force=1})
			PushCell(x-1,y,2,{force=1})
		end
		PushCell(x,y,dir)
	elseif cell.id == 352 then
		cell.updated = true
		cell.vars[3] = (cell.vars[3]+1)%cell.vars[2]
		cell.updatedforce = 0
		if cell.vars[3] == 0 then
			cell.updatedforce = cell.vars[1]
			local cx,cy,cdir = x,y,dir
			for i=cell.updates or 0,cell.vars[1]-1 do
				local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
				if GetCell(cx,cy).id ~= cell.id or not PushCell(cx,cy,cdir,{force=-i,maximum=cell.vars[4] == 0 and cell.vars[4] or cell.vars[4]+1}) then
					break
				end
				updatekey = updatekey + 1
				local data = GetData(cx,cy)
				if data.supdatekey == supdatekey and data.scrosses >= 5 then
					break
				else
					data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
				end
				data.supdatekey = supdatekey
				if not nextx then break end
				cx,cy,cdir = nextx,nexty,nextdir
			end
			supdatekey = supdatekey + 1
		end
	elseif cell.id == 552 then
		DoApeirocell(x,y,cell)
	elseif cell.id == 700 then
		PushCell(x,y,dir,{bend=true})
	elseif cell.id == 718 then
		PushCell(x,y,dir,{row=true})
	elseif cell.id == 781 then
		local cx,cy = StepForward(x,y,dir)
		if dir%2 == 0 then
			cy = cy - 1
			PullCell(cx,cy,(dir%2+1)%4,{force=1})
			cy = cy + 2
			PullCell(cx,cy,(dir%2-1)%4,{force=1})
		else
			cx = cx + 1
			PullCell(cx,cy,(dir%2+1)%4,{force=1})
			cx = cx - 2
			PullCell(cx,cy,(dir%2-1)%4,{force=1})
		end
		PushCell(x,y,dir)
	elseif cell.id == 1160 then
		local nextx,nexty,nextdir = NextCell(x,y,cell.rot)
		local vars = {}
		if not PushCell(x,y,cell.rot,vars) and vars.repeats > 2 then
			local hitcell = GetCell(nextx,nexty)
			if not IsUnbreakable(hitcell,nextdir,nextx,nexty,{forcetype="destroy"}) then
				DamageCell(GetCell(nextx,nexty),1,nextdir,nextx,nexty,{lastcell=cell,lastx=x,lasty=y,lastdir=cdir})
				Play("destroy")
			end
		end
	end
end

function DoSlicer(x,y,cell)
	if Override("DoSlicer"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if cell.id == 115 then
		SliceCell(x,y,cell.rot)
	elseif cell.id == 356 then
		cell.updated = true
		cell.vars[3] = (cell.vars[3]+1)%cell.vars[2]
		if cell.vars[3] == 0 then
			local cx,cy,cdir = x,y,cell.rot
			for i=cell.updates or 0,cell.vars[1]-1 do
				local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
				if GetCell(cx,cy) ~= cell or not SliceCell(cx,cy,cdir) then
					break
				end
				updatekey = updatekey + 1
				local data = GetData(cx,cy)
				if data.supdatekey == supdatekey and data.scrosses >= 5 then
					break
				else
					data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
				end
				data.supdatekey = supdatekey
				if not nextx then break end
				cx,cy,cdir = nextx,nexty,nextdir
			end
			supdatekey = supdatekey + 1
		end
	elseif cell.id == 786 then
		local dir = cell.rot
		if RSliceCell(x,y,dir) then
			local cx,cy = StepBackwards(x,y,(dir-1)%4)
			PullCell(cx,cy,(dir-1)%4,{force=1})
		end
	elseif cell.id == 787 then
		local dir = cell.rot
		if LSliceCell(x,y,dir) then
			local cx,cy = StepBackwards(x,y,(dir+1)%4)
			PullCell(cx,cy,(dir+1)%4,{force=1})
		end
	elseif cell.id == 906 then
		local dir = cell.rot
		if SliceCell(x,y,dir) then
			StapleEmptyCell(x,y,dir)
		end
	elseif cell.id == 552 then
		DoApeirocell(x,y,cell)
	elseif cell.id == 820 then
		StapleCell(x,y,cell.rot)
	elseif cell.id == 903 then
		TunnelCell(x,y,cell.rot)
	elseif cell.id == 1086 then
		RSliceCell(x,y,cell.rot)
	elseif cell.id == 1087 then
		LSliceCell(x,y,cell.rot)
	end
end

function getAct(num,x,y,dir)
	if num == 0 then return PushCell(x,y,dir)
	elseif num == 1 then if PushCell(x,y,dir) then 
							GrabEmptyCell(x,y,dir,{force=1})
							return true
						else return GrabCell(x,y,dir) end
	elseif num == 2 then if PushCell(x,y,dir)  then
							x,y = StepBack(x,y,dir)
							PullCell(x,y,dir,{force=1})
							return true
						else
							return PullCell(x,y,dir)
						end
	elseif num == 3 then if dir == 0 then if not PushCell(x,y,0) then return SwapCells(x,y,2,x+1,y,0) else return true end
						elseif dir == 2 then if not PushCell(x,y,2) then return SwapCells(x,y,0,x-1,y,2) else return true end
						elseif dir == 3 then if not PushCell(x,y,3) then return SwapCells(x,y,1,x,y-1,3) else return true end
						elseif dir == 1 then if not PushCell(x,y,1) then return SwapCells(x,y,3,x,y+1,1) else return true end end
	elseif num == 4 then return PushCell(x,y,dir) or SliceCell(x,y,dir)
	end
end

function DoNudger(x,y,cell)
	if Override("DoNudger"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if cell.id == 114 or cell.id == 160 or cell.id == 178 or cell.id == 179 or cell.id == 180 or cell.id == 181 or cell.id == 182 or cell.id == 183
	or cell.id == 184 or cell.id == 185 or cell.id == 358 or cell.id == 359 or cell.id == 367 or cell.id == 368 or cell.id == 456 or cell.id == 589
	or cell.id == 590 or cell.id == 591 or cell.id == 592 or cell.id == 597 or cell.id == 598 or cell.id == 599 or cell.id == 600 then
		NudgeCell(x,y,cell.rot)
	elseif cell.id == 161 then
		if not NudgeCell(x,y,cell.rot) then
			SetCell(x,y,{id=149,rot=cell.rot,lastvars=cell.lastvars,vars={},updated=true,eatencells={cell}})
		end
	elseif cell.id == 206 then
		local cx,cy = StepForward(x,y,cell.rot)
		local cell2 = GetCell(cx,cy)
		local neighbors = GetSurrounding(x,y)
		if LlueaEats(cell2,cell.rot,cx,cy) then
			cell.eatencells = {cell2}
			if math.random() <= .1 then
				cell2 = table.copy(cell)
				RotateCellRaw(cell2,cell.rot-cell2.rot+math.random(-1,1))
				SetCell(cx,cy,cell2)
				cell2.vars[math.random(3)] = math.random(5)-1
				cell.vars[4] = tickcount+100
				cell2.vars[4] = tickcount+100
			else
				cell.vars[math.random(3)] = math.random(5)-1
				SetCell(cx,cy,getempty())
				cell.vars[4] = tickcount+200
			end
		else
			cx,cy = StepLeft(x,y,cell.rot)
			local cell2 = GetCell(cx,cy)
			if LlueaEats(cell2,(cell.rot-1)%4,cx,cy) then
				cell.eatencells = {cell2}
				RotateCellRaw(cell,-1)
				if math.random() <= .1 then
					cell2 = table.copy(cell)
					RotateCellRaw(cell2,cell.rot-cell2.rot+math.random(-1,1))
					SetCell(cx,cy,cell2)
					cell2.vars[math.random(3)] = math.random(5)-1
					cell.vars[4] = tickcount+100
					cell2.vars[4] = tickcount+100
				else
					cell.vars[math.random(3)] = math.random(5)-1
					SetCell(cx,cy,getempty())
					cell.vars[4] = tickcount+200
				end
			else
				cx,cy = StepRight(x,y,cell.rot)
				local cell2 = GetCell(cx,cy)
				if LlueaEats(cell2,(cell.rot+1)%4,cx,cy) then
					cell.eatencells = {cell2}
					RotateCellRaw(cell,1)
					if math.random() <= .1 then
						cell2 = table.copy(cell)
						RotateCellRaw(cell2,cell.rot-cell2.rot+math.random(-1,1))
						SetCell(cx,cy,cell2)
						cell2.vars[math.random(3)] = math.random(5)-1
						cell.vars[4] = tickcount+100
						cell2.vars[4] = tickcount+100
					else
						cell.vars[math.random(3)] = math.random(5)-1
						SetCell(cx,cy,getempty())
						cell.vars[4] = tickcount+200
					end
				end
			end
		end	
		if cell.vars[4] <= tickcount or GetCell(x+1,y).id == 206 and GetCell(x,y+1).id == 206 and GetCell(x-1,y).id == 206 and GetCell(x,y-1).id == 206 then
			cell.id = (cell.vars[1] == 0 and 2 or cell.vars[1] == 1 and 72 or cell.vars[1] == 2 and 28 or cell.vars[1] == 3 and 59 or 269)
		end
		cell.testvar = cell.vars[4]-tickcount
		if not getAct(cell.vars[1],x,y,cell.rot) then 
			cell = GetCell(x,y)
			if cell.id ~= 206 then return end
			RotateCellRaw(cell,math.random(0,1)*2-1)
			if not getAct(cell.vars[2],x,y,cell.rot) then
				cell = GetCell(x,y)
				if cell.id ~= 206 then return end
				RotateCellRaw(cell,2)
				getAct(cell.vars[3],x,y,cell.rot)
			end
		end
	elseif cell.id == 242 then
		if not NudgeCell(x,y,cell.rot) then
			SetCell(x,y,{id=240,rot=cell.rot,lastvars=cell.lastvars,vars={},updated=true,eatencells={cell}})
		end
	elseif cell.id == 243 then
		if not NudgeCell(x,y,cell.rot) then
			SetCell(x,y,{id=241,rot=cell.rot,lastvars=cell.lastvars,vars={},updated=true,eatencells={cell}})
		end
	elseif cell.id == 603 then
		if not NudgeCell(x,y,cell.rot) then
			SetCell(x,y,{id=602,rot=cell.rot,lastvars=cell.lastvars,vars={},updated=true,eatencells={cell}})
		end
	elseif cell.id == 319 or cell.id == 454 or cell.id == 792 or cell.id == 793 or cell.id == 794
	or cell.id == 795 or cell.id == 800 or cell.id == 801 or cell.id == 802 or cell.id == 803 then
		local dir
		local dist = math.huge
		for i=0,3 do
			local cx,cy,cdir = x,y,i
			for j=1,math.huge do
				cx,cy,cdir = NextCell(cx,cy,cdir)
				if not cx then break end
				local c = GetCell(cx,cy)
				c.testvar = i.."-"..j
				if IsUnfriendly(cell) and IsFriendly(c)
				or IsFriendly(cell) and IsUnfriendly(c) then
					if j < dist then
						dir = i
						dist = j
					end
					break
				elseif not IsNonexistant(c,i,cx,cy) and not IsInvisibleToSeekers(c) then
					break
				end
			end
			updatekey = updatekey + 1
		end
		if dir then
			RotateCellRaw(cell,dir-cell.rot)
			NudgeCell(x,y,dir)
			return
		end
		local cx,cy,cdir = NextCell(x,y,cell.rot)
		if cx and IsNonexistant(GetCell(cx,cy),cdir,cx,cy) or IsInvisibleToSeekers(GetCell(cx,cy)) then
			NudgeCell(x,y,cell.rot)
		else
			RotateCellRaw(cell,-1)
			updatekey = updatekey + 1
			cx,cy,cdir = NextCell(x,y,cell.rot)
			if cx and IsNonexistant(GetCell(cx,cy),cdir,cx,cy) or IsInvisibleToSeekers(GetCell(cx,cy)) then
				NudgeCell(x,y,cell.rot)
			else
				updatekey = updatekey + 1
				cx,cy,cdir = NextCell(x,y,cell.rot)
				if cx and IsNonexistant(GetCell(cx,cy),cdir,cx,cy) or IsInvisibleToSeekers(GetCell(cx,cy)) then
					NudgeCell(x,y,cell.rot)
				else
					RotateCellRaw(cell,-1)
					NudgeCell(x,y,cell.rot)
				end
			end
		end
	elseif cell.id == 357 then
		cell.vars[3] = (cell.vars[3]+1)%cell.vars[2]
		if cell.vars[3] == 0 then
			local cx,cy,cdir = x,y,cell.rot
			for i=cell.updates or 0,cell.vars[1]-1 do
				local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
				if GetCell(cx,cy).id ~= cell.id or not NudgeCell(cx,cy,cdir) then
					break
				end
				if not nextx then break end
				cx,cy,cdir = nextx,nexty,nextdir
			end
		end
	elseif cell.id == 175 and cell.vars[1] then
		if not NudgeCell(x,y,cell.rot) then
			local cx,cy = StepLeft(x,y,cell.rot)
			local cx2,cy2 = StepRight(x,y,cell.rot)
			local replacecell = GetStoredCell(cell,true)
			if cell.vars[2] == (cell.rot+1)%4 then
				if PushCell(cx2,cy2,(cell.rot+1)%4,{force=1,replacecell=replacecell}) then
					GetCell(x,y).vars = {}
				elseif PushCell(cx,cy,(cell.rot-1)%4,{force=1,replacecell=replacecell}) then
					GetCell(x,y).vars = {}
				end
			else
				if PushCell(cx,cy,(cell.rot-1)%4,{force=1,replacecell=replacecell}) then
					GetCell(x,y).vars = {}
				elseif PushCell(cx2,cy2,(cell.rot+1)%4,{force=1,replacecell=replacecell}) then
					GetCell(x,y).vars = {}
				end
			end
		end
	elseif cell.id == 362 and cell.vars[1] then
		if not NudgeCell(x,y,cell.rot) then
			SetCell(x,y,GetStoredCell(cell,true,{cell}))
		end
	elseif cell.id == 821 and cell.vars[1] then
		if not NudgeCell(x,y,cell.rot) then
			local cx,cy = StepBack(x,y,cell.rot)
			if PushCell(cx,cy,(cell.rot+2)%4,{replacecell=GetStoredCell(cell,true)}) then
				GetCell(x,y).vars = {}
			end
		end
	elseif cell.id == 822 and cell.vars[1] then
		local cx,cy,cdir = NextCell(x,y,cell.rot)
		if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy,{forcetype="push",lastcell=cell}) and CanMove(GetCell(cx,cy),cdir,cx,cy,"push") then
			local ccx,ccy = StepLeft(x,y,cell.rot)
			local ccx2,ccy2 = StepRight(x,y,cell.rot)
			local replacecell = GetStoredCell(cell,true)
			if cell.vars[2] == (cell.rot+1)%4 then
				if PushCell(ccx2,ccy2,(cell.rot+1)%4,{force=1,replacecell=replacecell}) then
					SetCell(x,y,getempty())
					cell.vars = {GetCell(cx,cy).id,GetCell(cx,cy).rot}
					SetCell(cx,cy,cell)
				elseif PushCell(ccx,ccy,(cell.rot-1)%4,{force=1,replacecell=replacecell}) then
					SetCell(x,y,getempty())
					cell.vars = {GetCell(cx,cy).id,GetCell(cx,cy).rot}
					SetCell(cx,cy,cell)
				end
			else
				if PushCell(ccx,ccy,(cell.rot-1)%4,{force=1,replacecell=replacecell}) then
					SetCell(x,y,getempty())
					cell.vars = {GetCell(cx,cy).id,GetCell(cx,cy).rot}
					SetCell(cx,cy,cell)
				elseif PushCell(ccx2,ccy2,(cell.rot+1)%4,{force=1,replacecell=replacecell}) then
					SetCell(x,y,getempty())
					cell.vars = {GetCell(cx,cy).id,GetCell(cx,cy).rot}
					SetCell(cx,cy,cell)
				end
			end
		else NudgeCell(x,y,cell.rot) end
	elseif cell.id == 823 and cell.vars[1] then
		local cx,cy,cdir = NextCell(x,y,cell.rot)
		if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy,{forcetype="push",lastcell=cell}) and CanMove(GetCell(cx,cy),cdir,cx,cy,"push") then
			SetCell(x,y,GetStoredCell(cell,true))
			cell.vars = {GetCell(cx,cy).id,GetCell(cx,cy).rot}
			SetCell(cx,cy,cell)
		else NudgeCell(x,y,cell.rot) end
	elseif cell.id == 424 then
		if not NudgeCell(x,y,cell.rot) and GetCell(x,y).id == 424 then
			local cx,cy,cdir = NextCell(x,y,cell.rot)
			if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) and not IsUnbreakable(GetCell(cx,cy),cell.rot,cx,cy,{forcetype="gravitize"}) then
				SetCell(x,y,getempty())
				GetCell(cx,cy).vars.gravdir = cdir
				SetChunkId(cx,cy,"gravity")
				table.safeinsert(GetCell(cx,cy),"eatencells",cell)
			end
		end
	elseif cell.id == 500 then
		local dir = (cell.vars[2] == 0 or cell.vars[2] == 1 or cell.vars[2] == 4 or cell.vars[2] == 5) and 1 or (cell.vars[2] == 3 or cell.vars[2] == 7) and 3 or cell.vars[2] < 4 and 0 or 2
		cell.vars[2] = (cell.vars[2]+1)%8
		RotateCellRaw(cell,math.random(-1,1))
		PushCell(x,y,dir,{force=1})
	elseif cell.id == 552 then
		DoApeirocell(x,y,cell)
	elseif cell.id == 704 and cell.vars[1] then
		NudgeCell(x,y,cell.rot,{replacecell=GetStoredCell(cell)})
	end
end


function DoSapper(x,y,cell)
	if Override("DoSapper"..cell.id,x,y,cell,dir) then return end
	if cell.id == 467 then
		for cx=x-2,x+2 do
			for cy=y-2,y+2 do
				local cell2 = GetCell(cx,cy)
				if ChunkId(cell2.id) == 318 then
					DamageCell(cell2,1,k,cx,cy,{lastcell=cell,lastx=x,lasty=y,undocells={}})
					Play("destroy")
				end
			end
		end
		return
	end
	local neighbors = cell.id == 465 and GetSurrounding(x,y) or GetNeighbors(x,y)
	for k,v in pairs(neighbors) do
		local cell2 = GetCell(v[1],v[2])
		if ChunkId(cell2.id) == 318 then
			DamageCell(cell2,1,k,v[1],v[2],{lastcell=cell,lastx=x,lasty=y,undocells={}})
			Play("destroy")
		end
	end
end

sentrytomissile = {
	[319]=160,
	[320]=319,
	[589]=358,
	[590]=359,
	[591]=367,
	[592]=368,
	[455]=454,
	[453]=456,
	[593]=597,
	[594]=598,
	[595]=599,
	[596]=600,
	[796]=792,
	[797]=793,
	[798]=794,
	[799]=795,
	[804]=800,
	[805]=801,
	[806]=802,
	[807]=803,
}
function DoSentry(x,y,cell)
	if Override("DoSentry"..cell.id,x,y,cell,dir) then return end
	local dir
	local dist = math.huge
	for i=0,3 do
		local cx,cy,cdir = NextCell(x,y,i)
		if not cx then return end
		for j=1,cell.vars[1] == 0 and math.huge or cell.vars[1] do
			local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
			if not cx then break end
			local c = GetCell(cx,cy)
			if IsFriendly(cell) and IsUnfriendly(c) or IsUnfriendly(cell) and IsFriendly(c) or IsUnsmartMissile(c) and c.rot == (cdir+2)%4 and j <= 4 then
				if j < dist then
					dir = i
					dist = j
				end
				break
			elseif not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) and not IsInvisibleToSeekers(GetCell(cx,cy)) then
				break
			end
			local data = GetData(cx,cy)
			if data.supdatekey == supdatekey and data.scrosses >= 5 then
				break
			else
				data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
			end
			data.supdatekey = supdatekey
			if not nextx then break end
			cx,cy,cdir = nextx,nexty,nextdir
		end
		supdatekey = supdatekey + 1
	end
	if dir then
		local cx,cy = StepForward(x,y,dir)
		RotateCellRaw(cell,dir-cell.rot)
		NudgeCellTo({id=sentrytomissile[cell.id] or 160,rot=dir,lastvars={x,y,0},vars={paint=cell.vars.paint}},cx,cy,dir)
		Play("shoot")
	end
end

forbidsjumping = {
	[1159] = function(cell,dir,x,y)
		if cell.rot%2 ~= dir%2 then
			return true
		end
	end
}

function ForbidsJumping(cell,dir,x,y)
	return get(forbidsjumping[cell.id],cell,dir,x,y)
end

function DoPlatformerPlayer(x,y,cell)
	--side movement/drag
	if cell.rot%2 == 1 then
		if cell.vars[2] > 0 then
			cell.vars[2] = cell.vars[2] - 1
		elseif cell.vars[2] < 0 then
			cell.vars[2] = cell.vars[2] + 1
		end
		cell.vars[2] = cell.vars[2] + (1-(heldhori or 1))
	else
		if cell.vars[3] > 0 then
			cell.vars[3] = cell.vars[3] - 1
		elseif cell.vars[3] < 0 then
			cell.vars[3] = cell.vars[3] + 1
		end
		cell.vars[3] = cell.vars[3] + (2-(heldvert or 2))
	end
	--gravity
	if cell.rot == 0 then
		cell.vars[2] = cell.vars[2] + 1
	elseif cell.rot == 1 then
		cell.vars[3] = cell.vars[3] + 1
	elseif cell.rot == 2 then
		cell.vars[2] = cell.vars[2] - 1
	else
		cell.vars[3] = cell.vars[3] - 1
	end
	--jumpy
	local gx,gy,gdir = NextCell(x,y,cell.rot)
	local groundcell = GetCell(gx,gy)
	if not IsNonexistant(groundcell,gdir,gx,gy) and not IsDestroyer(groundcell,gdir,gx,gy,{forcetype="push",lastcell=cell}) and not ForbidsJumping(groundcell,gdir,gx,gy) then
		if cell.rot%2 == 0 and heldhori and cell.rot ~= heldhori or cell.rot%2 == 1 and heldvert and cell.rot ~= heldvert then
			if cell.rot == 0 and cell.vars[2] >= 0 then
				cell.vars[2] = -cell.vars[1]
			elseif cell.rot == 1 and cell.vars[3] >= 0 then
				cell.vars[3] = -cell.vars[1]
			elseif cell.rot == 2 and cell.vars[2] <= 0 then
				cell.vars[2] = cell.vars[1]
			elseif cell.rot == 3 and cell.vars[3] <= 0 then
				cell.vars[3] = cell.vars[1]
			end
		end
	end
	cell.testvar = cell.vars[2].."\n"..cell.vars[3]
	local cx,cy,c = x,y,cell
	local vel = {cell.vars[2],cell.vars[3]}
	local startvel = {cell.vars[2],cell.vars[3]}
	local done = {false,false}
	-- 1 = hori, 2 = verti
	local function step(dir)
		if vel[dir] ~= 0 then
			local oldvel = vel[dir]
			vel[dir] = vel[dir] > 0 and vel[dir] - 1 or vel[dir] + 1
			local nextx,nexty,nextdir = NextCell(cx,cy,dir-1+(oldvel > 0 and 0 or 2))
			if not PushCell(cx,cy,dir-1+(oldvel > 0 and 0 or 2),{force=1}) then
				c = GetCell(cx,cy)
				if c.id ~= cell.id then
					return false
				end
				collided = GetCell(nextx,nexty)
				if collided.id == 1159 and collided.rot%2 == dir%2 then
					c.vars[dir+1] = (collided.vars[1]+1) * (oldvel > 0 and -1 or 1)
					startvel[dir] = c.vars[dir+1]
					vel[0] = 0
					done[0] = true
					vel[1] = 0
					done[1] = true
				elseif collided.id == 1163 and collided.rot%2 == dir%2 then
					c.vars[dir+1] = 0
					vel[dir] = oldvel
					done[dir] = true
					local d = collided.rot%2+2
					local speed = (collided.vars[1]+1) * (1-math.floor(collided.rot*.5)*2)
					if speed < 0 and c.vars[d] > speed or speed > 0 and c.vars[d] < speed then
						if c.vars[d] > 0 and speed < 0 or c.vars[d] < 0 and speed > 0 then
							vel[d-1] = 0
							startvel[d-1] = 0
							done[d-1] = true
						end
						c.vars[d] = speed
					end
				else
					c.vars[dir+1] = 0
					vel[dir] = oldvel
					done[dir] = true
				end
			else
				c = GetCell(nextx,nexty)
				if c.id ~= cell.id then
					return false
				end
				cx,cy = nextx,nexty
				c.vars[dir+1] = startvel[dir]
				done[dir] = false
			end
		else
			done[dir] = true
		end
		return true
	end
	--steps in diagonal motion without missing holes that the player could fit into 
	while not done[1] or not done[2] do
		if cell.rot%2 == 0 then
			if not step(2) then
				return	--panic, cant find cell anymore (probably ded)
			elseif not step(1) then
				return
			end
		else
			if not step(1) then
				return
			elseif not step(2) then
				return
			end
		end
	end
end

playerpos,freezecam = {},false
function DoPlayer(x,y,cell)
	if Override("DoPlayer"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if cell.id == 614 then
		DoPlatformerPlayer(x,y,cell)
	elseif cell.id == 845 then
		local cx,cy,cdir = x,y,held or cell.rot
		if held then
			RotateCellRaw(cell,held-cell.rot)
			if PushCell(x,y,held,{force=1,skipfirst=sf}) then
				cx,cy,cdir = NextCell(cx,cy,cdir)
			end
		end
		if actionpressed then
			cx,cy,cdir = NextCell(cx,cy,cdir)
			NudgeCellTo({id=456,rot=cdir,lastvars={x,y,0},vars={}},cx,cy,cdir,{})
			Play("shoot")
		end
	elseif cell.id == 846 then
		if cell.vars[1] and actionpressed then
			cell.vars[1] = nil
			EmitParticles("smoke",x,y)
		elseif actionpressed then
			local neighbors = GetNeighbors(x,y)
			for k,v in pairs(neighbors) do
				if not IsNonexistant(GetCell(v[1],v[2]),k,v[1],v[2]) then
					local dcell = ToGenerate(CopyCell(v[1],v[2]),k,v[1],v[2])
					if dcell and dcell.id ~= 846 and dcell.firstx == v[1] and dcell.firsty == v[2] then
						cell.vars[1] = dcell.id
						EmitParticles("smoke",x,y)
						break
					end
				end
			end
		end
		if held then
			PushCell(x,y,held,{force=1,skipfirst=sf})
		end
	elseif held then
		if cell.id == 289 or cell.id == 293 then
			PullCell(x,y,held,{force=1,skipfirst=true})
		elseif cell.id == 829 or cell.id == 830 then
			if PushCell(x,y,held,{force=1,skipfirst=true}) then
				local cx,cy = StepBack(x,y,held)
				PullCell(cx,cy,held,{force=1})
			else
				PullCell(x,y,held,{force=1,skipfirst=true})
			end
		elseif cell.id == 290 or cell.id == 294 then
			GrabCell(x,y,held,{force=1,skipfirst=true})
		elseif cell.id == 291 or cell.id == 295 then
			local cx,cy = x,y
			if held == 0 then cx = x + 1 elseif held == 2 then cx = x - 1
			elseif held == 1 then cy = y + 1 elseif held == 3 then cy = y - 1 end
			SwapCells(x,y,(held+2)%4,cx,cy,held)
		elseif cell.id == 297 or cell.id == 298 then
			SliceCell(x,y,held,{skipfirst=true})
		elseif cell.id == 292 or cell.id == 296 then
			NudgeCell(x,y,held,{skipfirst=true})
		elseif cell.id == 552 then
			RotateCellRaw(cell,held-cell.rot)
			DoApeirocell(x,y,cell,held)
		else
			PushCell(x,y,held,{force=1,skipfirst=true})
		end
	end
end

function ChaserPathfind(x,y,dir,vars,dirstring)
	if x > 0 and x < width-1 and y > 0 and y < height-1 and not vars.dirs and #dirstring <= vars.max then
		local data = GetData(x,y)
		if data.supdatekey == supdatekey then
			return
		end
		data.supdatekey = supdatekey
		if vars.friendly and IsUnfriendly(GetCell(x,y)) or not vars.friendly and IsFriendly(GetCell(x,y)) then
			vars.dirs = dirstring
		elseif IsNonexistant(GetCell(x,y),dir,x,y) or ChunkId(GetCell(x,y).id) == 1167 or #dirstring == 0 then
			local dirs = {0,2,3,1}
			for i=1,4 do
				local cx,cy,cdir = NextCell(x,y,dirs[i])
				updatekey = updatekey + 1
				if cx then
					QueueLast("fill", function() ChaserPathfind(cx,cy,cdir,vars,dirstring..dirs[i]) end)
				end
			end
		elseif vars.super then
			if not IsUnbreakable(GetCell(x,y),dir,x,y) and GetHP(GetCell(x,y),dir,x,y) ~= math.huge 
			and (vars.friendly and not IsFriendly(GetCell(x,y)) or not vars.friendly and not IsUnfriendly(GetCell(x,y))) then
				table.insert(vars.pushables, {dirs=dirstring})
			end
		else
			local pvars = {force=1,checkonly = true}
			local sfxv = settings.sfxvolume
			settings.sfxvolume = 0
			local f = fancy
			fancy = false
			if PushCell(x,y,dir,pvars) and not vars.destroying then
				table.insert(vars.pushables, {dirs=dirstring,vars=pvars})
				for k,v in pairs(pvars.undocells) do
					SetCell(k%width,math.floor(k/width),v)
				end
			end
			settings.sfxvolume = sfxv
			fancy = f
		end
	end
end

function DoChaser(x,y,cell)
	if Override("DoChaser"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	cell.vars[4] = (cell.vars[4]+1)%cell.vars[3]
	if cell.vars[4] == 0 then
		local vars = {super=cell.id == 1168 or cell.id == 1170,friendly=cell.id == 1169 or cell.id == 1170, pushables = {}, max=cell.vars[1] == 0 and math.huge or cell.vars[1]}
		ChaserPathfind(x,y,0,vars,"")
		ExecuteQueue("fill")
		local directions = vars.dirs
		if not directions then
			if cell.id == 1168 or cell.id == 1170 then
				directions = (vars.pushables[1] or {}).dirs
			else
				for i=1,#vars.pushables do
					local pvars = vars.pushables[i].vars
					if GetData(pvars.endx,pvars.endy).supdatekey ~= supdatekey then
						directions = vars.pushables[i].dirs
						break
					end
				end
			end
		end
		supdatekey = supdatekey + 1
		if directions then
			local cx,cy = x,y
			for i=1,math.min(cell.vars[2],#directions) do
				local dir = tonumber(directions:sub(i,i))
				local nextx,nexty = NextCell(cx,cy,dir)
				if GetCell(cx,cy) ~= cell or not PushCell(cx,cy,dir,{force=1,skipfirst=true}) then
					break
				end
				local data = GetData(cx,cy)
				if data.supdatekey == supdatekey and data.scrosses >= 5 then
					break
				else
					data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
				end
				data.supdatekey = supdatekey
				if not nextx then break end
				cx,cy = nextx,nexty
			end
			supdatekey = supdatekey + 1
		end
	end
end

function DoObserver(x,y,cell)
	if Override("DoObserver"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if not cell.vars[2] then
		for i=1,4 do
			local cx,cy,cdir = NextCell(x,y,i)
			if not cx then return end
			for j=1,(cell.vars[1] == 0 and math.huge or cell.vars[1]) do
				local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
				local c = GetCell(cx,cy)
				if cell.id == 1157 and IsFriendly(c) or cell.id == 1158 and IsUnfriendly(c) then
					cell.vars[2] = (i-cell.rot)%4
					cell.vars[3],cell.vars[4] = x,y
					break
				elseif not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) and not IsInvisibleToSeekers(GetCell(cx,cy)) then
					break
				end
				updatekey = updatekey + 1
				local data = GetData(cx,cy)
				if data.supdatekey == supdatekey and data.scrosses >= 5 then
					break
				else
					data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
				end
				data.supdatekey = supdatekey
				if not nextx then break end
				cx,cy,cdir = nextx,nexty,nextdir
			end
			supdatekey = supdatekey + 1
		end
	end
	if cell.vars[2] then
		local nextx,nexty,nextdir = NextCell(x,y,(cell.vars[2]+cell.rot)%4)
		local vars = {force=1,skipfirst=true}
		if not PushCell(x,y,(cell.vars[2]+cell.rot)%4,vars) then
			if vars.repeats > 2 then
				local hitcell = GetCell(nextx,nexty)
				if not IsUnbreakable(hitcell,nextdir,nextx,nexty,{forcetype="destroy"}) then
					DamageCell(GetCell(nextx,nexty),1,nextdir,nextx,nexty,{lastcell=cell,lastx=x,lasty=y,lastdir=cdir})
					Play("destroy")
				end
			end
			GetCell(x,y).vars[2] = (GetCell(x,y).vars[2]+2)%4
		else
			if nextx == cell.vars[3] and nexty == cell.vars[4] then
				cell.vars[2] = nil
				cell.vars[3] = nil
				cell.vars[4] = nil
			end
		end
	end
end

function DoIcicle(x,y,cell)
	if Override("DoIcicle"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if not cell.vars[2] then
		local cx,cy,cdir = NextCell(x,y,cell.rot)
		if not cx then return end
		for j=1,(cell.vars[1] == 0 and math.huge or cell.vars[1]) do
			local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
			local c = GetCell(cx,cy)
			if c.id == 0 and c.tick == tickcount or c.id ~= 0 and (c.firstx ~= cx or c.firsty ~= cy) then
				cell.vars[2] = 1
				break
			elseif not IsNonexistant(c,cdir,cx,cy) and not IsInvisibleToSeekers(c) then
				break
			end
			updatekey = updatekey + 1
			local data = GetData(cx,cy)
			if data.supdatekey == supdatekey and data.scrosses >= 5 then
				break
			else
				data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
			end
			data.supdatekey = supdatekey
			if not nextx then break end
			cx,cy,cdir = nextx,nexty,nextdir
		end
		supdatekey = supdatekey + 1
	else
		local cx,cy,cdir = x,y,cell.rot
		for i=1,cell.vars[2] do
			local nextx,nexty,nextdir = NextCell(cx,cy,cdir)
			if GetCell(cx,cy) ~= cell then
				break
			elseif not PushCell(cx,cy,cdir,{force=1}) then
				SetCell(cx,cy,getempty())
				EmitParticles("swivel",cx,cy)
				Play("destroy")
				break
			end
			local data = GetData(cx,cy)
			if data.supdatekey == supdatekey and data.scrosses >= 5 then
				break
			else
				data.scrosses = data.supdatekey == supdatekey and data.scrosses + 1 or 1
			end
			data.supdatekey = supdatekey
			if not nextx then break end
			cx,cy,cdir = nextx,nexty,nextdir
		end
		supdatekey = supdatekey + 1
		cell.vars[2] = (cell.vars[2] or 0) + 1 -- there's a really weird bug with icicles right around here and idk wtf it is
		-- I SHOULD be keeping bugs in since this is, y'know, a WIKI mod, but I don't like this one. it's stupid.
	end
end

function DoInputPushable()
	if draggedx then
		local cell = GetCell(draggedx,draggedy)
		if cell.id ~= 910 and cell.id ~= 911 and cell.id ~= 912 and cell.id ~= 913 and cell.id ~= 914 then
			return true
		end
		local cx = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
		local cy = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
		if cx < draggedx then
			local cdx,cdy = NextCell(draggedx,draggedy,2)
			if PushCell(draggedx,draggedy,2,{force=1}) then
				draggedx,draggedy = cdx,cdy
			end
		elseif cx > draggedx then
			local cdx,cdy = NextCell(draggedx,draggedy,0)
			if PushCell(draggedx,draggedy,0,{force=1}) then
				draggedx,draggedy = cdx,cdy
			end
		end
		local newcell = GetCell(draggedx,draggedy)
		if cell.id == newcell.id then
			cell = newcell
		end
		if cy < draggedy then
			local cdx,cdy = NextCell(draggedx,draggedy,3)
			if PushCell(draggedx,draggedy,3,{force=1}) then
				draggedx,draggedy = cdx,cdy
			end
		elseif cy > draggedy then
			local cdx,cdy = NextCell(draggedx,draggedy,1)
			if PushCell(draggedx,draggedy,1,{force=1}) then
				draggedx,draggedy = cdx,cdy
			end
		end
		return true
	end
end

function DoGate(x,y,cell)
	if Override("DoGate"..cell.id,x,y,cell,dir) then return end
	if (cell.id == 32 and (cell.inl or cell.inr)) or (cell.id == 33 and (cell.inl and cell.inr)) or (cell.id == 34 and (cell.inl ~= cell.inr)) or
	   (cell.id == 35 and not (cell.inl or cell.inr)) or (cell.id == 36 and not (cell.inl and cell.inr)) or (cell.id == 37 and not (cell.inl ~= cell.inr)) or
	   (cell.id == 194 and (not cell.inl or cell.inr)) or (cell.id == 195 and (cell.inl or not cell.inr)) or (cell.id == 196 and (cell.inl and not cell.inr)) or (cell.id == 197 and (not cell.inl and cell.inr)) then
		cell.updated = true
		local cx,cy,cdir,c = NextCell(x,y,(cell.rot+2)%4,nil,true)
		if cx then
			local gencell = CopyCell(cx,cy)
			gencell.rot = (gencell.rot-c.rot)%4
			gencell = ToGenerate(gencell,cdir,cx,cy)
			if gencell then
				gencell.lastvars = table.copy(cell.lastvars)
				gencell.lastvars[3] = 0
				x,y = StepForward(x,y,cell.rot)
				PushCell(x,y,cell.rot,{replacecell=gencell,noupdate=true,force=1})
			end
		end
	elseif (cell.id == 186 or cell.id == 187 or cell.id == 188 or cell.id == 189 or cell.id == 190 or cell.id == 191 or cell.id == 192 or cell.id == 193) then
		cell.updated = true
		if cell.output then
			x,y = StepForward(x,y,cell.rot)
			PushCell(x,y,cell.rot,{replacecell=cell.output,noupdate=true,force=1})
		end
	end
end

function DoCoinExtractor(x,y,cell)
	if Override("DoCoinExtractor"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local cx,cy = NextCell(x,y,(cell.rot+2)%4,nil,true)
	local ccx,ccy = NextCell(x,y,cell.rot)
	if cx then
		local gencell = GetCell(cx,cy)
		local tocell = GetCell(ccx,ccy)
		if tocell.id ~= 223 and gencell.vars.coins then
			if IsNonexistant(tocell,cell.rot,ccx,ccy) then
				SetCell(ccx,ccy,{id=223,rot=0,lastvars={x,y,0},vars={}})
			else
				tocell.vars.coins = (tocell.vars.coins or 0)+1
			end
			gencell.vars.coins = gencell.vars.coins - 1
			if gencell.vars.coins == 0 then
				gencell.vars.coins = nil
			end
		elseif tocell.id ~= 223 and gencell.id == 223 then
			if IsNonexistant(tocell,cell.rot,ccx,ccy) then
				SetCell(ccx,ccy,{id=223,rot=0,lastvars={x,y,0},vars={}})
			else
				tocell.vars.coins = (tocell.vars.coins or 0)+1
			end
			SetCell(cx,cy,getempty())
		end
	end
end

function SendGlunkiSignal(x,y,life)
	local neighbors = GetNeighbors(x,y)
	for k,v in pairs(neighbors) do
		local cell2 = GetCell(v[1],v[2])
		if cell2.id == 212 and updatekey ~= cell2.updatekey and cell2.rot == k then
			cell2.updatekey = updatekey
			cell2.vars[4] = life
			SendGlunkiSignal(v[1],v[2],life+1)
		end
	end
end

function getcopy(cell,cell2)
	local copy = table.copy(cell)
	copy.eatencells = {cell2}
	--if cell2.id ~= 0 then copy.lastvars = cell2.lastvars end
	copy.updated = true
	return copy
end

function DoBasicInfector(x,y,cell,neighborfunc,ediblefunc,disappear,force,newid,overtakechance)
	if cell.protected then SetCell(x,y,getempty({cell})) return end
	local neighbors = neighborfunc(x,y)
	for k,v in pairs(neighbors) do
		local cell2 = GetCell(v[1],v[2])
		if cell2.id ~= cell.id and ediblefunc(cell2,k,v[1],v[2],cell,force or "infect") and (not LlueaEats(cell2,k,v[1],v[2]) or math.random() < (overtakechance or .5)) then
			local copy = getcopy(newcell or cell,cell2)
			copy.id = newid or copy.id
			SetCell(v[1],v[2],copy)
			Play("infect")
		end
	end
	if disappear then
		SetCell(x,y,getempty({cell}))
	end
end

function DoVineInfector(x,y,cell,dir,ediblefunc,disappear,force,newid,overtakechance)
	newid = newid or cell.id + 1
	if cell.protected then SetCell(x,y,getempty({cell})) return end
	RotateCellRaw(cell,dir*2,true)
	for i=1,3 do
		RotateCellRaw(cell,-dir)
		local cx,cy = StepForward(x,y,cell.rot)
		local cell2 = GetCell(cx,cy)
		if cell2.id ~= cell.id and cell2.id ~= newid and ediblefunc(GetCell(cx,cy),cell.rot,cx,cy,force or "infect") and (not LlueaEats(cell2,cell.rot,cx,cy) or math.random() < (overtakechance or .5)) then
			SetCell(cx,cy,getcopy(cell,cell2))
			cell.id = disappear and 0 or newid
			Play("infect")
			return
		end
	end	
	RotateCellRaw(cell,dir)
end

function eatall(cell,dir,x,y,lastcell,force)
	return not IsUnbreakable(cell,dir,x,y,{forcetype=force,lastcell=lastcell})
end

function eatcells(cell,dir,x,y,lastcell,force)
	return not IsNonexistant(cell,dir,x,y) and not IsUnbreakable(cell,dir,x,y,{forcetype=force,lastcell=lastcell})
end

function eatair(cell,dir,x,y,lastcell)
	return IsNonexistant(cell,dir,x,y)
end

function DoInfectious(x,y,cell)
	if Override("DoInfectious"..cell.id,x,y,cell,dir) then return end
	if cell.id == 123 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatcells)
	elseif cell.id == 124 then
		DoBasicInfector(x,y,cell,GetDiagonals,eatcells)
	elseif cell.id == 125 then
		DoBasicInfector(x,y,cell,GetSurrounding,eatcells)
	elseif cell.id == 127 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatall)
	elseif cell.id == 128 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatair)
	elseif cell.id == 129 then
		DoBasicInfector(x,y,cell,GetDiagonals,eatall)
	elseif cell.id == 130 then
		DoBasicInfector(x,y,cell,GetDiagonals,eatair)
	elseif cell.id == 131 then
		DoBasicInfector(x,y,cell,GetSurrounding,eatall)
	elseif cell.id == 132 then
		DoBasicInfector(x,y,cell,GetSurrounding,eatair)
	elseif cell.id == 133 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatair)
	elseif cell.id == 134 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatcells)
	elseif cell.id == 135 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatall)
	elseif cell.id == 149 then
		if cell.protected then SetCell(x,y,getempty({cell})) GetCell(x,y).updated=true return end
		local neighbors = GetSurrounding(x,y)
		local nnum = 0
		for k,v in pairs(neighbors) do
			local cell2 = GetCell(v[1],v[2])
			local data = GetData(v[1],v[2])
			if cell2.id == 149 and not cell2.updated or cell2.id == 0 and cell2.updated and cell2.tick == tickcount then
				nnum = nnum+1
			elseif IsNonexistant(cell2,k,v[1],v[2]) then
				if not (data.lifeupdated and data.lifekey == updatekey) and not (cell2.updated and cell2.tick == tickcount) then
					data.lifeupdated = true
					data.lifekey = updatekey
					SetChunkId(v[1],v[2],"all")
					local neighbors = GetSurrounding(v[1],v[2])
					local nnum = 0
					for k,v in pairs(neighbors) do
						local cell2 = GetCell(v[1],v[2])
						if cell2.id == 149 and not cell2.updated or cell2.id == 0 and cell2.updated and cell2.tick == tickcount then
							nnum = nnum+1
						end
					end
					if nnum == 3 then
						SetCell(v[1],v[2],getcopy(cell,cell2))
						Play("infect")
					end
				end
			elseif cell2.id ~= 149 and not IsUnbreakable(cell2,k,v[1],v[2],{forcetype="infect",lastcell=cell}) then
				SetCell(v[1],v[2],getcopy(cell,cell2))
				Play("infect")
			elseif cell2.id == 149 and (v[1] == x or v[2] == y) then
				cell2.lastvars = table.copy(cell.lastvars)
			end
		end
		if nnum ~= 2 and nnum ~= 3 then
			SetCell(x,y,{id=0,rot=0,lastvars=cell.lastvars,vars={},updated=true,eatencells={cell},tick=tickcount})
			GetData(x,y).lifeupdated = true
			GetData(x,y).lifekey = updatekey
		end
	elseif cell.id == 211 or cell.id == 212 then
		if cell.protected then SetCell(x,y,cell.vars[1] and GetStoredCell(cell,true) or getempty()) GetCell(x,y).eatencells={cell} return end
		if not cell.vars[1] then
			local neighbors = GetNeighbors(x,y)
			local todo = {[0]=true,true,true,true}
			while todo[0] or todo[1] or todo[2] or todo[3] do
				local k = math.random(0,3)
				local v = neighbors[k]
				local cell2 = GetCell(v[1],v[2])
				if not IsNonexistant(cell2,k,v[1],v[2]) and cell2.id ~= 211 and (cell2.id ~= 212 or cell.id == 211 and cell2.rot ~= k) and not IsUnbreakable(cell2,k,v[1],v[2],{forcetype="infect",lastcell=cell}) and (not LlueaEats(cell2,k,v[1],v[2]) or math.random() < .5) then
					SetCell(v[1],v[2],{id=212,rot=k,updated=true,lastvars={x,y,0},vars={cell2.id,cell2.rot,250,cell.id == 212 and cell.vars[4] or 0},eatencells={cell2}})
					Play("infect")
					break
				end
				todo[k] = false
			end
			cell.vars[3] = cell.vars[3] - 1
			if cell.vars[3] == 0 then
				SetCell(x,y,getempty())
				GetCell(x,y).eatencells={cell}
				return
			end
			cell.testvar = cell.vars[3]
			if cell.id == 212 then
				cell.vars[4] = cell.vars[4] + 1
				if cell.vars[4] >= 250 then
					SetCell(x,y,getempty())
					GetCell(x,y).eatencells={cell}
				end
				cell.testvar = cell.vars[3].."\n"..cell.vars[4]
			end
		else
			if cell.id == 211 then
				if cell.vars[1] == 212 then
					cell.vars[1] = nil
					cell.vars[2] = nil
					cell.vars[4] = 25
					return
				end
				cell.vars[4] = math.max(cell.vars[4] - 1,0)
				cell.testvar = cell.vars[4]
				if cell.vars[4] == 0 then
					cell.vars[1] = nil
					cell.vars[2] = nil
					cell.vars[3] = 250
					cell.vars[4] = 25
					SendGlunkiSignal(x,y,0)
				end
				cell.testvar = cell.vars[3].."\n"..cell.vars[4]
			elseif cell.id == 212 then
				local cx,cy = StepBack(x,y,cell.rot)
				local cell2 = GetCell(cx,cy)
				if cell2.id == 211 or cell2.id == 212 then
					if not cell2.vars[1] and not cell2.updated then
						cell2.vars[1] = cell.vars[1]
						cell2.vars[2] = cell.vars[2]
						if cell2.id == 212 then cell2.vars[3] = 250 end
						cell2.updated = true
						cell.vars[1] = nil
						cell.vars[2] = nil
					end
				else
					local neighbors = GetNeighbors(x,y)
					for k,v in pairs(neighbors) do
						local cell2 = GetCell(v[1],v[2])
						if cell2.id == 211 or cell2.id == 212 then
							RotateCellRaw(cell,k+2-cell.rot)
							break
						end
					end
					cell.vars[3] = cell.vars[3] - 1
					if cell.vars[3] == 0 then
						SetCell(x,y,cell.vars[1] and GetStoredCell(cell,true) or getempty())
						GetCell(x,y).eatencells={cell}
					end
				end
				cell.vars[4] = cell.vars[4] + 1
				if cell.vars[4] >= 250 then
					SetCell(x,y,cell.vars[1] and GetStoredCell(cell,true) or getempty())
					GetCell(x,y).eatencells={cell}
				end
				cell.testvar = cell.vars[3].."\n"..cell.vars[4]
			end
		end
	elseif cell.id == 234 then
		if cell.protected then SetCell(x,y,getempty({cell})) return end
		cell.updated = true
		local neighbors = GetNeighbors(x,y)
		for k,v in pairs(neighbors) do
			local cell2 = GetCell(v[1],v[2])
			if not IsNonexistant(cell2,k,v[1],v[2]) and cell2.id ~= 234 and not IsUnbreakable(cell2,k,v[1],v[2],{forcetype="burn",lastcell=cell}) and math.random() < .5 then
				SetCell(v[1],v[2],getcopy(cell,cell2))
				Play("infect")
			end
		end
		if math.random() < .5 then
			NudgeCell(x,y,(cell.rot-1)%4)
		elseif math.random() < .8 then
			NudgeCell(x,y,math.random(0,3))
		else
			SetCell(x,y,getempty())
			GetCell(x,y).eatencells={cell}
		end
	elseif cell.id == 240 or cell.id == 242 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatcells,cell.id == 240,"burn",240,1)
	elseif cell.id == 241 or cell.id == 243 then
		DoBasicInfector(x,y,cell,GetSurrounding,eatcells,cell.id == 241,"burn",241,1)
	elseif cell.id == 602 or cell.id == 603 then
		DoBasicInfector(x,y,cell,GetDiagonals,eatcells,cell.id == 602,"burn",602,1)
	elseif cell.id == 369 then
		DoVineInfector(x,y,cell,1,eatair)
	elseif cell.id == 371 then
		DoVineInfector(x,y,cell,1,eatcells)
	elseif cell.id == 373 then
		DoVineInfector(x,y,cell,1,eatall)
	elseif cell.id == 375 then
		DoVineInfector(x,y,cell,-1,eatair)
	elseif cell.id == 377 then
		DoVineInfector(x,y,cell,-1,eatcells)
	elseif cell.id == 379 then
		DoVineInfector(x,y,cell,-1,eatall)
	elseif cell.id == 567 then
		if cell.protected then SetCell(x,y,getempty({cell})) GetCell(x,y).updated=true return end
		local neighbors = GetSurrounding(x,y)
		local nnum = 0
		for k,v in pairs(neighbors) do
			local cell2 = GetCell(v[1],v[2])
			local data = GetData(v[1],v[2])
			if cell2.id == 567 and not cell2.updated or cell2.id == 0 and cell2.updated and cell2.tick == tickcount or cell2.id == 568 and cell2.updated then
				nnum = nnum+1
			elseif IsNonexistant(cell2,k,v[1],v[2]) then
				if not (data.clifeupdated and data.clifekey == updatekey) and cell2.tick ~= tickcount then
					data.clifeupdated = true
					data.clifekey = updatekey
					SetChunkId(v[1],v[2],"all")
					local neighbors = GetSurrounding(v[1],v[2])
					local nnum = 0
					for k,v in pairs(neighbors) do
						local cell2 = GetCell(v[1],v[2])
						if cell2.id == 567 and not cell2.updated or cell2.id == 0 and cell2.updated and cell2.tick == tickcount or cell2.id == 568 and cell2.updated then
							nnum = nnum+1
						end
					end
					if cell.vars[nnum+1] > 1 then
						SetCell(v[1],v[2],getcopy(cell,cell2))
						Play("infect")
					end
				end
			elseif cell2.id ~= 567 and not IsUnbreakable(cell2,k,v[1],v[2],{forcetype="infect",lastcell=cell}) and cell2.id ~= 568 then
				SetCell(v[1],v[2],getcopy(cell,cell2))
				Play("infect")
			elseif cell2.id == 567 and (v[1] == x or v[2] == y) then
				cell2.lastvars = table.copy(cell.lastvars)
			end
		end
		if cell.vars[nnum+1] == 0 or cell.vars[nnum+1] == 2 then
			local copy = table.copy(cell);
			copy.id=cell.vars[10] ~= 0 and 568 or 0
			copy.updated = true
			copy.tick = tickcount
			copy.vars[1]=cell.vars[10] ~= 0 and cell.vars[10] or nil
			copy.vars[2],copy.vars[3],copy.vars[4],copy.vars[5],copy.vars[6],copy.vars[7],copy.vars[8],copy.vars[9],copy.vars[10] = nil,nil,nil,nil,nil,nil,nil,nil,nil
			copy.eatencells = {cell}
			SetCell(x,y,copy)
			GetData(x,y).lifeupdated = true
			GetData(x,y).lifekey = updatekey
		end
	elseif cell.id == 604 then
		if cell.protected then SetCell(x,y,getempty()) GetCell(x,y).eatencells={cell} return end
		local nnum = 0
		local bstring = cell.vars[3]..cell.vars[4]
		for cx=x-cell.vars[5],x+cell.vars[5] do
			for cy=y-cell.vars[5],y+cell.vars[5] do
				if (layers[0][0][0].id == 428 or cx > 0 and cx < width-1 and cy > 0 and cy < height-1)
				and (cell.vars[7] ~= 1 or math.abs(cx-x)+math.abs(cy-y) <= cell.vars[5])
				and (cell.vars[7] ~= 2 or (cx-x+cy-y)%2 == 0)
				and (cell.vars[7] ~= 3 or math.distSqr(cx-x,cy-y) <= (cell.vars[5]+.5)*(cell.vars[5]+.5)) then
					local cell2 = GetCell(cx,cy)
					local data = GetData(cx,cy)
					if cell2.id == 604 and not cell2.updated or cell2.id == 0 and cell2.updated and cell2.tick == tickcount or cell2.id == 605 and cell2.updated then
						nnum = nnum+1
					elseif IsNonexistant(cell2,math.angleTo4(cx-x,cy-y),cx,cy) then
						if not (data.ltlupdated == bstring and data.ltlkey == updatekey) and cell2.tick ~= tickcount then
							data.ltlupdated = bstring
							data.ltlkey = updatekey
							SetChunkId(cx,cy,"all")
							local nnum = 0
							for ccx=cx-cell.vars[5],cx+cell.vars[5] do
								for ccy=cy-cell.vars[5],cy+cell.vars[5] do
									if (layers[0][0][0].id == 428 or ccx > 0 and ccx < width-1 and ccy > 0 and ccy < height-1)
									and (cell.vars[7] ~= 1 or math.abs(ccx-cx)+math.abs(ccy-cy) <= cell.vars[5])
									and (cell.vars[7] ~= 2 or (ccx-cx+ccy-cy)%2 == 0)
									and (cell.vars[7] ~= 3 or math.distSqr(ccx-cx,ccy-cy) <= (cell.vars[5]+.5)*(cell.vars[5]+.5)) then
										local cell2 = GetCell(ccx,ccy)
										if cell2.id == 604 and not cell2.updated or cell2.id == 0 and cell2.updated and cell2.tick == tickcount or cell2.id == 605 and cell2.updated then
											nnum = nnum+1
										end
									end
								end
							end
							if (nnum >= cell.vars[3] and nnum <= cell.vars[4]) then
								SetCell(cx,cy,getcopy(cell,cell2))
								Play("infect")
							end
						end
					elseif cell2.id ~= 604 and not IsUnbreakable(cell2,math.angleTo4(cx-x,cy-y),cx,cy,{forcetype="infect",lastcell=cell}) and cell2.id ~= 605 then
						SetCell(cx,cy,getcopy(cell,cell2))
						Play("infect")
					end
				end
			end
		end
		if not (nnum >= cell.vars[1]+1 and nnum <= cell.vars[2]+1) then
			local copy = table.copy(cell);
			copy.id=cell.vars[6] ~= 0 and 605 or 0
			copy.updated = true
			copy.tick = tickcount
			copy.vars[1]=cell.vars[6] ~= 0 and cell.vars[6] or nil
			copy.vars[2],copy.vars[3],copy.vars[4],copy.vars[5],copy.vars[6],copy.vars[7] = nil,nil,nil,nil,nil,nil
			copy.eatencells = {cell}
			SetCell(x,y,copy)
			GetData(x,y).lifeupdated = true
			GetData(x,y).lifekey = updatekey
		end
	elseif cell.id == 808 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetDiagonals,eatcells)
	elseif cell.id == 809 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetDiagonals,eatall)
	elseif cell.id == 810 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetDiagonals,eatair)
	elseif cell.id == 811 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetSurrounding,eatcells)
	elseif cell.id == 812 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetSurrounding,eatall)
	elseif cell.id == 813 and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetSurrounding,eatair)
	elseif cell.id == 1109 then
		DoVineInfector(x,y,cell,math.randomsign(),eatair)
	elseif cell.id == 1111 then
		DoVineInfector(x,y,cell,math.randomsign(),eatcells)
	elseif cell.id == 1113 then
		DoVineInfector(x,y,cell,math.randomsign(),eatall)
	elseif cell.id == 1125 and math.random() < cell.vars[5]*.01 then
		local eatfunc = cell.vars[3] == 1 and (cell.vars[4] == 1 and eatall or eatcells) or cell.vars[4] == 1 and eatair
		if eatfunc then
			if cell.vars[1] == 3 then
				DoVineInfector(x,y,cell,cell.vars[2] == 0 and 0 or cell.vars[2] == 1 and 1 or cell.vars[2] == 2 and -1 or cell.vars[2] == 3 and math.randomsign(),eatfunc,nil,nil,1125)
			else
				DoBasicInfector(x,y,cell,cell.vars[1] == 0 and GetNeighbors or cell.vars[1] == 1 and GetSurrounding or GetDiagonals,eatfunc)
			end
		end
	elseif (cell.id == 1147 or cell.id == 1148) and math.random() < .5 then
		DoBasicInfector(x,y,cell,GetNeighbors,eatcells)
	end
end

function DoPostInfectious(x,y,cell)
	if Override("DoPostInfectious"..cell.id,x,y,cell,dir) then return end
	if cell.id == 568 or cell.id == 605 then
		cell.vars[1] = cell.vars[1] - 1
		if cell.vars[1] == 0 then
			SetCell(x,y,getempty({cell}))
		end
	end
end

function DoCoil(x,y,cell)
	if Override("UpdateCoil"..cell.id,x,y,cell,dir) then return end
	if cell.vars[1] > 0 then
		cell.vars[1] = cell.vars[1] - 1
	end
end

function DoFearfulEnemy(x,y,cell)
	if Override("DoFearfulEnemy"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local hmove = false
	for i=0,2,2 do
		local cx,cy,cdir = NextCell(x,y,i)
		if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) then
			hmove = (hmove or 0) + i - 1
		end
	end
	if hmove and hmove ~= 0 then
		PushCell(x,y,-hmove+1,{force=1,skipfirst=true})
		return
	end
	local vmove = false
	for i=1,3,2 do
		local cx,cy,cdir = NextCell(x,y,i)
		if not IsNonexistant(GetCell(cx,cy),cdir,cx,cy) then
			vmove = (vmove or 0) + i - 2
		end
	end
	if vmove and vmove ~= 0 then
		PushCell(x,y,-vmove+2,{force=1,skipfirst=true})
		return
	end
	if hmove and not vmove then
		PushCell(x,y,math.randomsign()+2,{force=1,skipfirst=true})
		return
	elseif vmove and not hmove then
		PushCell(x,y,math.randomsign()+1,{force=1,skipfirst=true})
		return
	end
end

function DoAngryEnemy(x,y,cell)
	if Override("DoAngryEnemy"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	local neighbors = (cell.id == 827 or cell.id == 838) and GetNeighbors(x,y) or GetSurrounding(x,y)
	for k,v in pairs(neighbors) do
		if not IsNonexistant(GetCell(v[1],v[2]),k,v[1],v[2],{forcetype="destroy"})
		and not IsUnbreakable(GetCell(v[1],v[2]),k,v[1],v[2],{forcetype="destroy"}) and not IsUnbreakable(cell,(k+2)%4,x,y,{forcetype="destroy"}) then
			if cell.id == 838 or cell.id == 839 then
				DamageCell(cell, GetHP(GetCell(v[1],v[2]),k,v[1],v[2]), (k+2)%4,x,y)
				DamageCell(GetCell(v[1],v[2]),math.huge,k,v[1],v[2],{lastcell=cell})
			else
				DamageCell(GetCell(v[1],v[2]),1,k,v[1],v[2],{lastcell=cell})
				DamageCell(cell,1,(k+2)%4,x,y)
			end
			Play("destroy")
			if cell.id == 0 then break end
		end
	end
end

function DoLaser(x,y,cell)
	if Override("DoLaser"..cell.id,x,y,cell,dir) then return end
	cell.updated = true
	if cell.vars[1] == nil then
		local cx,cy,cdir = x,y,cell.rot
		for j=1,math.huge do
			cx,cy,cdir = NextCell(cx,cy,cdir)
			if not cx then break end
			local c = GetCell(cx,cy)
			if IsFriendly(c) then
				cell.vars[1] = 1
				break
			elseif not IsNonexistant(c,cdir,cx,cy) then
				break
			end
		end
	elseif cell.vars[1] == 1 then
		local cx,cy,cdir = x,y,cell.rot
		for j=1,math.huge do
			cx,cy,cdir = NextCell(cx,cy,cdir)
			if not cx then break end
			local c = GetCell(cx,cy)
			if not IsNonexistant(c,cdir,cx,cy) then
				if IsUnbreakable(c,cdir,cx,cy,{forcetype="destroy",lastcell=cell}) then break end
				Play("destroy")
				SetCell(cx,cy,{id=819,rot=cdir,lastvars={cx,cy,0},vars={paint=cell.vars.paint},eatencells={c}})
			else
				SetCell(cx,cy,{id=819,rot=cdir,lastvars={cx,cy,0},vars={paint=cell.vars.paint}})
				if c.id == 819 and c.rot%2 ~= cdir%2 or c.crossed then GetCell(cx,cy).crossed = true end
			end
		end
		cell.vars[1] = 2
		Play("laser")
	else
		cell.vars[1] = nil
	end
end

function CheckBlade(x,y,cell)
	if Override("CheckBlade"..cell.id,x,y,cell,dir) then return end
	local cx,cy = StepBack(x,y,cell.rot)
	local cell2 = GetCell(cx,cy)
	if cell.id == 819 or cell2.id ~= 344 and cell2.id ~= 345 and cell2.id ~= 672 and cell2.id ~= 814 or cell2.rot ~= cell.rot then
		SetCell(x,y,getempty(cell.eatencells))
	end
end

function CheckEnemies()
	if puzzle then
		local clear = true
		local allies = 0
		local player = false
		RunOn(function(c) return IsEnemy(c) or IsAlly(c) or IsNeutral(c) end,
		function(x,y,c)
			if IsEnemy(c) then clear = false
			elseif IsAlly(c) then allies = allies + 1
			elseif IsNeutral(c) then player = true end
		end,
		"rightup",
		"tagged")()
		local victory = {}
		local failure = {}
		RunOn(function(c) return ChunkId(c.id) == 908 end,
		function(x,y,c)
			if c.id == 908 then 
				if victory[c.vars[1]] ~= false then
					victory[c.vars[1]] = c.vars[2] or false
				end
			else 
				if failure[c.vars[1]] ~= false then
					failure[c.vars[1]] = c.vars[2] or false
				end
			end
		end,
		"rightup",
		908)()
		local forcewin,forcefail
		for k,v in pairs(victory) do
			if v then
				forcewin = true
			end
		end
		for k,v in pairs(failure) do
			if v then
				forcefail = true
			end
		end 
		if allies < totalallies or forcefail then
			TogglePause(true)
			inmenu = false
			winscreen = -1
		elseif totalenemies > 0 and clear or forcewin then
			TogglePause(true)
			inmenu = false
			winscreen = 1
			if level then GetSaved("completed")[title] = true end
		elseif totalplayers > 0 and not player then
			TogglePause(true)
			inmenu = false
			winscreen = -1
		end
	end
end

function FocusCam()
	freezecam = false
	playerpos = {}
	RunOn(function(c) return not c.frozen and (ChunkId(c.id) == 239 or c.id == 552 and c.vars[26] == 1) end,
	function(x,y,c) if playercam then table.insert(playerpos,{x+.5,y+.5}) cam.tarx,cam.tary = 0,0 end freezecam = true end,
	held == 0 and "upleft" or held == 2 and "upright" or held == 3 and "rightdown" or "rightup",
	239)()
	for i=1,#playerpos do
		cam.tarx = cam.tarx+cam.tarzoom*playerpos[i][1]/#playerpos
		cam.tary = cam.tary+cam.tarzoom*playerpos[i][2]/#playerpos 
	end
end

function HasDirection(c,dir,cross,bi,tri,diCW,diCCW,biN,triN,diCWN,diCCWN,para,tetra)	--wtf am i supposed to call this
	local dir1,dir2,dir3 = (dir+1)%4,(dir+2)%4,(dir+3)%4
	return c.id == cross and (dir%2 == 1 or not c.hupdated) and (c.rot == dir or c.rot == dir1) or c.id == para and c.rot%2 == dir%2 and (dir == 1 or dir == 2 or not c.firstupdated)
	or (c.id == tetra or (c.id == tri or c.id == triN) and c.rot ~= dir2 or (c.id == bi or c.id == biN) and c.rot ~= dir2 and c.rot ~= dir
	or (c.id == diCW or c.id == diCWN) and c.rot ~= dir2 and c.rot ~= dir1 or (c.id == diCCW or c.id == diCCWN) and c.rot ~= dir2 and c.rot ~= dir3)
	and (dir == 0 and not c.Rupdated or dir == 2 and not c.Lupdated or dir == 3 and not c.Uupdated or dir == 1)
end

function HasOnesidedDirection(c,dir,cross,bi,tri,tetra,uni)
	local dir1,dir2,result = (dir+1)%4,(dir+2)%4
	cross,bi,tri,tetra,uni = type(cross) == "table" and cross or {cross}, type(bi) == "table" and bi or {bi},
	type(tri) == "table" and tri or {tri}, type(tetra) == "table" and tetra or {tetra}, type(uni) == "table" and uni or {uni}
	for i=1,math.max(#cross,#bi,#tri,#tetra,#uni) do
		local cross,bi,tri,tetra,uni = cross[i],bi[i],tri[i],tetra[i],uni[i]
		result = result or c.id == uni and not c.updated and c.rot == dir or c.id == cross and (dir%2 == 1 or not c.hupdated) and (c.rot == dir or c.rot == dir1) or c.id == bi and c.rot%2 == dir%2 and (dir == 1 or dir == 2 or not c.firstupdated)
		or (c.id == tri and c.rot ~= dir2 or c.id == tetra) and (dir == 0 and not c.Rupdated or dir == 2 and not c.Lupdated or dir == 3 and not c.Uupdated or dir == 1)
	end
	return result
end

--behold the funcularity
subticks = {
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 199 and (c.rot == 0 and c.id ~= 202) and c.id ~= 203 and c.id ~= 204 end,DoCheater, "upleft", 199) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 199 and c.rot == 2 or c.id == 202 and c.rot == 0) and c.id ~= 203 and c.id ~= 204 end,DoCheater, "upright", 199) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 199 and c.rot == 3 and c.id ~= 202 or c.id == 203 or c.id == 204) end,DoCheater, "rightdown", 199) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 199 and c.rot == 1 or c.id == 202 and c.rot == 3) and c.id ~= 203 and c.id ~= 204 end,DoCheater, "rightup", 199) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 566 end,																DoAboveRefresh, "rightup", 566, 1) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 285 end,																DoThawer, "rightup", 285) end,
	function() return RunOn(function(c) return c.vars.input end, 																		CheckInput, "rightup", "input") end,
	function() return RunOn(function(c) return ChunkId(c.id) == 25 end,																	DoFreezer, "rightup", 25) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 43 end,												DoEffectGiver, "rightup", 43) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 266 end,												DoEffectRemover, "rightup", 266) end,
	function() return RunOn(function(c) return c.vars.gooey end, 																		UpdateGoo, "rightup", "compel") end,
	function() return RunOn(function(c) return not c.updated and c.id == 436 and c.rot%2 == 0 or c.id == 437 end,						function(x,y,c) DoDumpster(x,y,0) end, "upright", 436) end,
	function() return RunOn(function(c) return not c.updated and c.id == 436 and c.rot%2 == 1 or c.id == 437 end,						function(x,y,c) DoDumpster(x,y,1) end, "rightup", 436) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 833 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,834,835,836,837))end,function(x,y,c) DoSuperTimewarper(x,y,c,0) end, "upleft", 833) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 833 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,834,835,836,837))end,function(x,y,c) DoSuperTimewarper(x,y,c,2) end, "upright", 833) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 833 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,834,835,836,837))end,function(x,y,c) DoSuperTimewarper(x,y,c,3) end, "rightdown", 833) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 833 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,834,835,836,837))end,function(x,y,c) DoSuperTimewarper(x,y,c,1) end, "rightup", 833) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 146 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,148,615,616,617))end,function(x,y,c) DoTimewarper(x,y,c,0) end, "upleft", 146) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 146 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,148,615,616,617))end,function(x,y,c) DoTimewarper(x,y,c,2) end, "upright", 146) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 146 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,148,615,616,617))end,function(x,y,c) DoTimewarper(x,y,c,3) end, "rightdown", 146) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 146 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,148,615,616,617))end,function(x,y,c) DoTimewarper(x,y,c,1) end, "rightup", 146) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1123 end,												DoTimewarpZone, "upleft", 1123, 1) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1077 and c.rot == 0) end,							function(x,y,c) DoWorm(x,y,c,0) end, "upleft", 1077) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1077 and c.rot == 2) end,							function(x,y,c) DoWorm(x,y,c,2) end, "upright", 1077) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1077 and c.rot == 3) end,							function(x,y,c) DoWorm(x,y,c,3) end, "rightdown", 1077) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1077 and c.rot == 1) end	,							function(x,y,c) DoWorm(x,y,c,1) end, "rightup", 1077) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 237 and not IsMultiCell(c.id) and c.rot == 0 or HasDirection(c,0,238,536,537,538,539,540,541,542,543) or HasDirection(c,0,268,544,545,546,547,548,549,550,551)) end,function(x,y,c) DoTransformer(x,y,c,0) end, "upleft", 237) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 237 and not IsMultiCell(c.id) and c.rot == 2 or HasDirection(c,2,238,536,537,538,539,540,541,542,543) or HasDirection(c,2,268,544,545,546,547,548,549,550,551)) end,function(x,y,c) DoTransformer(x,y,c,2) end, "upright", 237) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 237 and not IsMultiCell(c.id) and c.rot == 3 or HasDirection(c,3,238,536,537,538,539,540,541,542,543) or HasDirection(c,3,268,544,545,546,547,548,549,550,551)) end,function(x,y,c) DoTransformer(x,y,c,3) end, "rightdown", 237) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 237 and not IsMultiCell(c.id) and c.rot == 1 or HasDirection(c,1,238,536,537,538,539,540,541,542,543) or HasDirection(c,1,268,544,545,546,547,548,549,550,551)) end,function(x,y,c) DoTransformer(x,y,c,1) end, "rightup", 237) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 425 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,{738,742},{739,743},{740,744},{425,426})) end,function(x,y,c) DoMidas(x,y,c,0) end, "upleft", 425) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 425 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,{738,742},{739,743},{740,744},{425,426})) end,function(x,y,c) DoMidas(x,y,c,2) end, "upright", 425) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 425 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,{738,742},{739,743},{740,744},{425,426})) end,function(x,y,c) DoMidas(x,y,c,3) end, "rightdown", 425) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 425 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,{738,742},{739,743},{740,744},{425,426})) end,function(x,y,c) DoMidas(x,y,c,1) end, "rightup", 425) end,
	function() return RunOn(function(c) return not c.updated and ((c.id == 313 or c.id == 480) and (c.rot == 0 or c.rot == 2) or c.id == 314 or c.id == 481) end,function(x,y,c) DoSuperMirror(x,y,c,0) end, "upright", 313) end,
	function() return RunOn(function(c) return not c.updated and ((c.id == 313 or c.id == 480) and (c.rot == 1 or c.rot == 3) or c.id == 314 or c.id == 481) end,function(x,y,c) DoSuperMirror(x,y,c,1) end, "upright", 313) end,
	function() return RunOn(function(c) return not c.updated and ((c.id == 15 or c.id == 445 or c.id == 478 or c.id == 479 or c.id == 489 or c.id == 490 or c.id == 491 or c.id == 661 or c.id == 662 or c.id == 663) and c.rot%2 == 0 or c.id == 56 or c.id == 80 or c.id == 446 or c.id == 492 or c.id == 660 or c.id == 664) end,function(x,y,c) DoMirror(x,y,c,0) end, "upright", 15) end,
	function() return RunOn(function(c) return not c.updated and ((c.id == 315 or c.id == 489 or c.id == 492 or c.id == 657 or c.id == 658 or c.id == 661 or c.id == 664) and c.rot%2 == 0 or (c.id == 490 or c.id == 662) and c.rot%2 == 1 or c.id == 316 or c.id == 80 or c.id == 491 or c.id == 660 or c.id == 659 or c.id == 663) end,function(x,y,c) DoMirror(x,y,c,1.5) end, "rightup", 15) end,
	function() return RunOn(function(c) return not c.updated and ((c.id == 315 or c.id == 489 or c.id == 492 or c.id == 657 or c.id == 658 or c.id == 661 or c.id == 664) and c.rot%2 == 1 or (c.id == 490 or c.id == 662) and c.rot%2 == 0 or c.id == 316 or c.id == 80 or c.id == 491 or c.id == 660 or c.id == 659 or c.id == 663) end,function(x,y,c) DoMirror(x,y,c,0.5) end, "rightdown", 15) end,
	function() return RunOn(function(c) return not c.updated and ((c.id == 15 or c.id == 445 or c.id == 478 or c.id == 479 or c.id == 489 or c.id == 490 or c.id == 491 or c.id == 661 or c.id == 662 or c.id == 663) and c.rot%2 == 1 or c.id == 56 or c.id == 80 or c.id == 446 or c.id == 492 or c.id == 660 or c.id == 664) end,function(x,y,c) DoMirror(x,y,c,1) end, "rightup", 15) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 629 and c.rot == 3 or (c.id == 630 or c.id == 657) and c.rot == 1) end,function(x,y,c) DoCurvedMirror(x,y,c,3.5) end, "rightup", 629) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 629 and c.rot == 1 or (c.id == 630 or c.id == 657) and c.rot == 3) end,function(x,y,c) DoCurvedMirror(x,y,c,1.5) end, "leftdown", 629) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 629 and c.rot == 0 or (c.id == 630 or c.id == 657) and c.rot == 2) end,function(x,y,c) DoCurvedMirror(x,y,c,0.5) end, "rightdown", 629) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 629 and c.rot == 2 or (c.id == 630 or c.id == 657) and c.rot == 0) end,function(x,y,c) DoCurvedMirror(x,y,c,2.5) end, "leftup", 629) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 403 or c.id == 404 and c.rot%2 == 0 or c.id == 405 and c.rot == 0 or c.id == 406 and (c.rot == 0 or c.rot == 1) or c.id == 407 and c.rot ~= 2 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,0) end, "upright", 403) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 403 or c.id == 404 and c.rot%2 == 0 or c.id == 405 and c.rot == 2 or c.id == 406 and (c.rot == 2 or c.rot == 3) or c.id == 407 and c.rot ~= 0 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,2) end, "upleft", 403) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 499 and c.rot%2 == 1 or c.id == 501 and c.rot == 3 or c.id == 502 and (c.rot == 0 or c.rot == 3) or c.id == 503 and c.rot ~= 1 or c.id == 498 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,3.5) end, "rightup", 403) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 499 and c.rot%2 == 1 or c.id == 501 and c.rot == 1 or c.id == 502 and (c.rot == 2 or c.rot == 1) or c.id == 503 and c.rot ~= 3 or c.id == 498 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,1.5) end, "leftdown", 403) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 499 and c.rot%2 == 0 or c.id == 501 and c.rot == 0 or c.id == 502 and (c.rot == 1 or c.rot == 0) or c.id == 503 and c.rot ~= 2 or c.id == 498 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,0.5) end, "rightdown", 403) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 499 and c.rot%2 == 0 or c.id == 501 and c.rot == 2 or c.id == 502 and (c.rot == 3 or c.rot == 2) or c.id == 503 and c.rot ~= 0 or c.id == 498 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,2.5) end, "leftup", 403) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 403 or c.id == 404 and c.rot%2 == 1 or c.id == 405 and c.rot == 3 or c.id == 406 and (c.rot == 3 or c.rot == 0) or c.id == 407 and c.rot ~= 1 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,3) end, "rightup", 403) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 403 or c.id == 404 and c.rot%2 == 1 or c.id == 405 and c.rot == 1 or c.id == 406 and (c.rot == 1 or c.rot == 2) or c.id == 407 and c.rot ~= 3 or c.id == 504) end,function(x,y,c) DoCrystal(x,y,c,1) end, "rightdown", 403) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 493 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,{496,922,927,945,950,955,1098},{494,920,925,943,948,953,1096},{497,923,928,946,951,956,1099},{493,919,924,942,947,952,1095})) end,function(x,y,c) DoAmethyst(x,y,c,3.5) end, "rightup", 493) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 493 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,{496,922,927,945,950,955,1098},{494,920,925,943,948,953,1096},{497,923,928,946,951,956,1099},{493,919,924,942,947,952,1095})) end,function(x,y,c) DoAmethyst(x,y,c,1.5) end, "leftdown", 493) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 493 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,{496,922,927,945,950,955,1098},{494,920,925,943,948,953,1096},{497,923,928,946,951,956,1099},{493,919,924,942,947,952,1095})) end,function(x,y,c) DoAmethyst(x,y,c,0.5) end, "rightdown", 493) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 493 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,{496,922,927,945,950,955,1098},{494,920,925,943,948,953,1096},{497,923,928,946,951,956,1099},{493,919,924,942,947,952,1095})) end,function(x,y,c) DoAmethyst(x,y,c,2.5) end, "leftup", 493) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 625 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,627,632,634,636) or c.id == 642 and c.rot == 0)end,function(x,y,c) DoCycler(x,y,c,0) end, "upright", 625) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 625 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,627,632,634,636) or c.id == 642 and c.rot == 2)end,function(x,y,c) DoCycler(x,y,c,2) end, "downleft", 625) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 625 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,627,632,634,636) or c.id == 642 and c.rot == 3)end,function(x,y,c) DoCycler(x,y,c,3) end, "leftup", 625) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 625 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,627,632,634,636) or c.id == 642 and c.rot == 1)end,function(x,y,c) DoCycler(x,y,c,1) end, "rightdown", 625) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 626 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,628,633,635,637) or c.id == 642 and c.rot == 2)end,function(x,y,c) DoCycler(x,y,c,0) end, "downright", 626) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 626 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,628,633,635,637) or c.id == 642 and c.rot == 0)end,function(x,y,c) DoCycler(x,y,c,2) end, "upleft", 626) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 626 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,628,633,635,637) or c.id == 642 and c.rot == 1)end,function(x,y,c) DoCycler(x,y,c,3) end, "rightup", 626) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 626 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,628,633,635,637) or c.id == 642 and c.rot == 3)end,function(x,y,c) DoCycler(x,y,c,1) end, "leftdown", 626) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 517 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,518,519,520,521))end,function(x,y,c) DoSuperIntaker(x,y,c,0) end, "upright", 517) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 517 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,518,519,520,521))end,function(x,y,c) DoSuperIntaker(x,y,c,2) end, "upleft", 517) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 517 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,518,519,520,521))end,function(x,y,c) DoSuperIntaker(x,y,c,3) end, "rightup", 517) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 517 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,518,519,520,521))end,function(x,y,c) DoSuperIntaker(x,y,c,1) end, "rightdown", 517) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 44 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,155,250,317,251))end,function(x,y,c) DoIntaker(x,y,c,0) end, "upright", 44) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 44 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,155,250,317,251))end,function(x,y,c) DoIntaker(x,y,c,2) end, "upleft", 44) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 44 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,155,250,317,251))end,function(x,y,c) DoIntaker(x,y,c,3) end, "rightup", 44) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 44 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,155,250,317,251))end,function(x,y,c) DoIntaker(x,y,c,1) end, "rightdown", 44) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 106 and c.id ~= 107 and c.id ~= 1153 and c.rot == 0 or (c.id == 107 or c.id == 1153) and not c.hupdated and (c.rot == 0 or c.rot == 1))end,function(x,y,c) DoShifter(x,y,c,0) end, "upleft", 106) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 106 and c.id ~= 107 and c.id ~= 1153 and c.rot == 2 or (c.id == 107 or c.id == 1153) and not c.hupdated and (c.rot == 2 or c.rot == 3))end,function(x,y,c) DoShifter(x,y,c,2) end, "upright", 106) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 106 and c.rot == 3 or (c.id == 107 or c.id == 1153) and c.rot == 0)end,function(x,y,c) DoShifter(x,y,c,3) end, "rightdown", 106) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 106 and c.rot == 1 or (c.id == 107 or c.id == 1153) and c.rot == 2)end,function(x,y,c) DoShifter(x,y,c,1) end, "rightup", 106) end,
	function() return RunOn(function(c) return not c.updated and c.id == 166 and c.rot == 0 end,										DoMemory, "upleft", 166) end,
	function() return RunOn(function(c) return not c.updated and c.id == 166 and c.rot == 2 end,										DoMemory, "upright", 166) end,
	function() return RunOn(function(c) return not c.updated and c.id == 166 and c.rot == 3 end,										DoMemory, "rightdown", 166) end,
	function() return RunOn(function(c) return not c.updated and c.id == 166 and c.rot == 1 end,										DoMemory, "rightup", 166) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 448 and c.rot == 0 end,								DoHyperGenerator, "upleft", 448) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 448 and c.rot == 2 end,								DoHyperGenerator, "upright", 448) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 448 and c.rot == 3 end,								DoHyperGenerator, "rightdown", 448) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 448 and c.rot == 1 end,								DoHyperGenerator, "rightup", 448) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 55 and not IsMultiCell(c.id) and c.rot == 0 or HasDirection(c,0,457,606,607,608,609,610,611,612,613)) end,function(x,y,c) DoSuperGenerator(x,y,c,0) end, "upleft", 55) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 55 and not IsMultiCell(c.id) and c.rot == 2 or HasDirection(c,2,457,606,607,608,609,610,611,612,613)) end,function(x,y,c) DoSuperGenerator(x,y,c,2) end, "upright", 55) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 55 and not IsMultiCell(c.id) and c.rot == 3 or HasDirection(c,3,457,606,607,608,609,610,611,612,613)) end,function(x,y,c) DoSuperGenerator(x,y,c,3) end, "rightdown", 55) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 55 and not IsMultiCell(c.id) and c.rot == 1 or HasDirection(c,1,457,606,607,608,609,610,611,612,613)) end,function(x,y,c) DoSuperGenerator(x,y,c,1) end, "rightup", 55) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 3 and not IsMultiCell(c.id) and c.rot == 0 or HasDirection(c,0,23,168,167,169,170,172,171,173,174,363,364)) end,function(x,y,c) DoGenerator(x,y,c,0) end, "upleft", 3) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 3 and not IsMultiCell(c.id) and c.rot == 2 or HasDirection(c,2,23,168,167,169,170,172,171,173,174,363,364)) end,function(x,y,c) DoGenerator(x,y,c,2) end, "upright", 3) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 3 and not IsMultiCell(c.id) and c.rot == 3 or HasDirection(c,3,23,168,167,169,170,172,171,173,174,363,364)) end,function(x,y,c) DoGenerator(x,y,c,3) end, "rightdown", 3) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 3 and not IsMultiCell(c.id) and c.rot == 1 or HasDirection(c,1,23,168,167,169,170,172,171,173,174,363,364)) end,function(x,y,c) DoGenerator(x,y,c,1) end, "rightup", 3) end,
	function() return RunOn(function(c) return not c.updated and c.id == 341 and c.rot == 0 end,										DoMemoryRep, "upleft", 341) end,
	function() return RunOn(function(c) return not c.updated and c.id == 341 and c.rot == 2 end,										DoMemoryRep, "upright", 341) end,
	function() return RunOn(function(c) return not c.updated and c.id == 341 and c.rot == 3 end,										DoMemoryRep, "rightdown", 341) end,
	function() return RunOn(function(c) return not c.updated and c.id == 341 and c.rot == 1 end,										DoMemoryRep, "rightup", 341) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 177 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,{513,878,879,880},{514,881,882,883},{515,884,885,886},{516,887,888,889})) end,function(x,y,c) DoSuperReplicator(x,y,c,0) end, "upleft", 177) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 177 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,{513,878,879,880},{514,881,882,883},{515,884,885,886},{516,887,888,889})) end,function(x,y,c) DoSuperReplicator(x,y,c,2) end, "upright", 177) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 177 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,{513,878,879,880},{514,881,882,883},{515,884,885,886},{516,887,888,889})) end,function(x,y,c) DoSuperReplicator(x,y,c,3) end, "rightdown", 177) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 177 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,{513,878,879,880},{514,881,882,883},{515,884,885,886},{516,887,888,889})) end,function(x,y,c) DoSuperReplicator(x,y,c,1) end, "rightup", 177) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 45 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,{46,866,867,868},{397,869,870,871},{398,872,873,874},{399,875,876,877})) end,function(x,y,c) DoReplicator(x,y,c,0) end, "upleft", 45) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 45 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,{46,866,867,868},{397,869,870,871},{398,872,873,874},{399,875,876,877})) end,function(x,y,c) DoReplicator(x,y,c,2) end, "upright", 45) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 45 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,{46,866,867,868},{397,869,870,871},{398,872,873,874},{399,875,876,877})) end,function(x,y,c) DoReplicator(x,y,c,3) end, "rightdown", 45) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 45 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,{46,866,867,868},{397,869,870,871},{398,872,873,874},{399,875,876,877})) end,function(x,y,c) DoReplicator(x,y,c,1) end, "rightup", 45) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 526 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,{527,531,1051,1055,1060,1064,1069,1073},{528,532,1052,1056,1061,1065,1070,1074},{529,533,1053,1057,1062,1066,1071,1075},{530,534,1054,1058,1063,1067,1072,1076}) or (c.id == 235 or c.id == 427 and not c.Rupdated))end,function(x,y,c) DoMaker(x,y,c,0) end, "upleft", 526) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 526 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,{527,531,1051,1055,1060,1064,1069,1073},{528,532,1052,1056,1061,1065,1070,1074},{529,533,1053,1057,1062,1066,1071,1075},{530,534,1054,1058,1063,1067,1072,1076}) or (c.id == 235 or c.id == 427 and not c.Lupdated))end,function(x,y,c) DoMaker(x,y,c,2) end, "upright", 526) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 526 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,{527,531,1051,1055,1060,1064,1069,1073},{528,532,1052,1056,1061,1065,1070,1074},{529,533,1053,1057,1062,1066,1071,1075},{530,534,1054,1058,1063,1067,1072,1076}) or (c.id == 235 or c.id == 427 and not c.Uupdated))end,function(x,y,c) DoMaker(x,y,c,3) end, "rightdown", 526) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 526 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,{527,531,1051,1055,1060,1064,1069,1073},{528,532,1052,1056,1061,1065,1070,1074},{529,533,1053,1057,1062,1066,1071,1075},{530,534,1054,1058,1063,1067,1072,1076}) or c.id == 235 or c.id == 427)end,function(x,y,c) DoMaker(x,y,c,1) end, "rightup", 526) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 412 and c.rot == 0 end,								DoRecursor, "upleft", 412) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 412 and c.rot == 2 end,								DoRecursor, "upright", 412) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 412 and c.rot == 3 end,								DoRecursor, "rightdown", 412) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 412 and c.rot == 1 end,								DoRecursor, "rightup", 412) end,
	function() FreezeQueue("rotate",true) FreezeQueue("flip",true) return RunOn(function(c) return c.vars.perpetualrot and not c.prupdated end, DoPerpetualRotation, "rightup", "perpetualrotate", nil,nil,nil,nil,nil,nil, function() FreezeQueue("rotate",false) FreezeQueue("flip",false) end) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 641 end,												DoSuperFlipper, "upright", 641) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 30 end,												DoFlipper, "upright", 30) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 442 end,												DoSuperRotator, "rightup", 442) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 9 end,												DoRotator, "rightup", 9) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1118 end,												DoRotateZone, "rightup", 1118, 1) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1021 end,												DoGear, "rightup", 1021) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 18 end,												DoGear, "rightup", 18) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 19 end,												DoGear, "leftup", 19) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 449 end,												DoGear, "leftup", 449) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 968 end,												DoGear, "leftup", 968) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1117 end,												DoSawblade, "rightup", 1117) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 344 end,												DoChainsaw, "rightup", 344) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1045 end,												DoSuperRedirector, "rightup", 1045) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 17 end,												DoRedirector, "rightup", 17) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1122 end,												DoRedirectZone, "rightup", 1122, 1) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 569 and not IsMultiCell(c.id) and c.rot == 0 or HasDirection(c,0,570,573,574,575,576,579,580,581,582)) end,function(x,y,c) DoOrientator(x,y,c,0) end, "upleft", 569) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 569 and not IsMultiCell(c.id) and c.rot == 2 or HasDirection(c,2,570,573,574,575,576,579,580,581,582)) end,function(x,y,c) DoOrientator(x,y,c,2) end, "upright", 569) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 569 and not IsMultiCell(c.id) and c.rot == 3 or HasDirection(c,3,570,573,574,575,576,579,580,581,582)) end,function(x,y,c) DoOrientator(x,y,c,3) end, "rightdown", 569) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 569 and not IsMultiCell(c.id) and c.rot == 1 or HasDirection(c,1,570,573,574,575,576,579,580,581,582)) end,function(x,y,c) DoOrientator(x,y,c,1) end, "rightup", 569) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 1133 end,																DoParticleCharges, "rightup", 1133) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 1133 end,																DoParticleStrongForce, "rightup", 1133) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 1133 end,																DoParticleChargeStick, "rightup", 1133) end,
	function() return RunOn(function(c) return not c.updated and not c.pupdated and ChunkId(c.id) == 1133 end,							DoParticleMovement, "rightup", 1133) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1007 and not IsMultiCell(c.id) or HasOnesidedDirection(c,2,1010,1008,1011,1007,1009)) end,function(x,y,c) DoVacuum(x,y,c,0) end, "upleft", 1007) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1007 and not IsMultiCell(c.id) or HasOnesidedDirection(c,0,1010,1008,1011,1007,1009)) end,function(x,y,c) DoVacuum(x,y,c,2) end, "upright", 1007) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1007 and not IsMultiCell(c.id) or HasOnesidedDirection(c,1,1010,1008,1011,1007,1009)) end,function(x,y,c) DoVacuum(x,y,c,3) end, "rightdown", 1007) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1007 and not IsMultiCell(c.id) or HasOnesidedDirection(c,3,1010,1008,1011,1007,1009)) end,function(x,y,c) DoVacuum(x,y,c,1) end, "rightup", 1007) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 248 and not IsMultiCell(c.id) or HasOnesidedDirection(c,2,731,729,732,248,730)) end,function(x,y,c) DoSuperImpulsor(x,y,c,0) end, "upleft", 248) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 248 and not IsMultiCell(c.id) or HasOnesidedDirection(c,0,731,729,732,248,730)) end,function(x,y,c) DoSuperImpulsor(x,y,c,2) end, "upright", 248) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 248 and not IsMultiCell(c.id) or HasOnesidedDirection(c,1,731,729,732,248,730)) end,function(x,y,c) DoSuperImpulsor(x,y,c,3) end, "rightdown", 248) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 248 and not IsMultiCell(c.id) or HasOnesidedDirection(c,3,731,729,732,248,730)) end,function(x,y,c) DoSuperImpulsor(x,y,c,1) end, "rightup", 248) end,
	function() return RunOn(function(c) return c.vars.timeimpulseright end,																function(x,y,c) DoTimeImpulse(x,y,c,0) end, "upleft", "timeimp") end,
	function() return RunOn(function(c) return c.vars.timeimpulseleft end,																function(x,y,c) DoTimeImpulse(x,y,c,2) end, "upright", "timeimp") end,
	function() return RunOn(function(c) return c.vars.timeimpulseup end,																function(x,y,c) DoTimeImpulse(x,y,c,3) end, "rightdown", "timeimp") end,
	function() return RunOn(function(c) return c.vars.timeimpulsedown end,																function(x,y,c) DoTimeImpulse(x,y,c,1) end, "rightup", "timeimp") end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1104 end,												DoTimeImpulsor, "upright", 1104) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 29 and not IsMultiCell(c.id) or HasOnesidedDirection(c,2,{415,1015},{413,1013},{416,1016},{29,1012},{414,1014})) end,function(x,y,c) DoImpulsor(x,y,c,0) end, "upleft", 29) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 29 and not IsMultiCell(c.id) or HasOnesidedDirection(c,0,{415,1015},{413,1013},{416,1016},{29,1012},{414,1014})) end,function(x,y,c) DoImpulsor(x,y,c,2) end, "upright", 29) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 29 and not IsMultiCell(c.id) or HasOnesidedDirection(c,1,{415,1015},{413,1013},{416,1016},{29,1012},{414,1014})) end,function(x,y,c) DoImpulsor(x,y,c,3) end, "rightdown", 29) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 29 and not IsMultiCell(c.id) or HasOnesidedDirection(c,3,{415,1015},{413,1013},{416,1016},{29,1012},{414,1014})) end,function(x,y,c) DoImpulsor(x,y,c,1) end, "rightup", 29) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 81 and (c.id ~= 227 or c.rot == 0) and (c.id ~= 228 or c.rot == 0 or c.rot == 1) end,function(x,y,c) DoGrapulsor(x,y,c,0) end, "upleft", 81) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 81 and (c.id ~= 227 or c.rot == 2) and (c.id ~= 228 or c.rot == 2 or c.rot == 3) end,function(x,y,c) DoGrapulsor(x,y,c,2) end, "upright", 81) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 81 and (c.id ~= 227 or c.rot == 3) and (c.id ~= 228 or c.rot == 3 or c.rot == 0) end,function(x,y,c) DoGrapulsor(x,y,c,3) end, "rightdown", 81) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 81 and (c.id ~= 227 or c.rot == 1) and (c.id ~= 228 or c.rot == 1 or c.rot == 2) end,function(x,y,c) DoGrapulsor(x,y,c,1) end, "rightup", 81) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 435 and not IsMultiCell(c.id) or HasOnesidedDirection(c,0,727,725,728,435,726)) end,function(x,y,c) DoSuperFan(x,y,c,0) end, "upleft", 435) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 435 and not IsMultiCell(c.id) or HasOnesidedDirection(c,2,727,725,728,435,726)) end,function(x,y,c) DoSuperFan(x,y,c,2) end, "upright", 435) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 435 and not IsMultiCell(c.id) or HasOnesidedDirection(c,3,727,725,728,435,726)) end,function(x,y,c) DoSuperFan(x,y,c,3) end, "rightdown", 435) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 435 and not IsMultiCell(c.id) or HasOnesidedDirection(c,1,727,725,728,435,726)) end,function(x,y,c) DoSuperFan(x,y,c,1) end, "rightup", 435) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 417 or c.id == 418 and c.rot%2 == 0 or c.id == 419 and c.rot == 0 or c.id == 420 and (c.rot == 0 or c.rot == 1) or c.id == 421 and c.rot ~= 2) end,function(x,y,c) DoFan(x,y,c,0) end, "upleft", 417) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 417 or c.id == 418 and c.rot%2 == 0 or c.id == 419 and c.rot == 2 or c.id == 420 and (c.rot == 2 or c.rot == 3) or c.id == 421 and c.rot ~= 0) end,function(x,y,c) DoFan(x,y,c,2) end, "upright", 417) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 417 or c.id == 418 and c.rot%2 == 1 or c.id == 419 and c.rot == 3 or c.id == 420 and (c.rot == 3 or c.rot == 0) or c.id == 421 and c.rot ~= 1) end,function(x,y,c) DoFan(x,y,c,3) end, "rightdown", 417) end,
	function() return RunOn(function(c) return not c.updated and (c.id == 417 or c.id == 418 and c.rot%2 == 1 or c.id == 419 and c.rot == 1 or c.id == 420 and (c.rot == 1 or c.rot == 2) or c.id == 421 and c.rot ~= 3) end,function(x,y,c) DoFan(x,y,c,1) end, "rightup", 417) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 984 and not IsMultiCell(c.id) or HasOnesidedDirection(c,0,987,985,988,984,986)) end,function(x,y,c) DoRandulsor(x,y,c,0) end, "upleft", 984) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 984 and not IsMultiCell(c.id) or HasOnesidedDirection(c,2,987,985,988,984,986)) end,function(x,y,c) DoRandulsor(x,y,c,2) end, "upright", 984) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 984 and not IsMultiCell(c.id) or HasOnesidedDirection(c,3,987,985,988,984,986)) end,function(x,y,c) DoRandulsor(x,y,c,3) end, "rightdown", 984) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 984 and not IsMultiCell(c.id) or HasOnesidedDirection(c,1,987,985,988,984,986)) end,function(x,y,c) DoRandulsor(x,y,c,1) end, "rightup", 984) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 50 and not IsMultiCell(c.id) or HasOnesidedDirection(c,0,723,721,724,50,722)) end,function(x,y,c) DoSuperRepulsor(x,y,c,0) end, "upleft", 50) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 50 and not IsMultiCell(c.id) or HasOnesidedDirection(c,2,723,721,724,50,722)) end,function(x,y,c) DoSuperRepulsor(x,y,c,2) end, "upright", 50) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 50 and not IsMultiCell(c.id) or HasOnesidedDirection(c,3,723,721,724,50,722)) end,function(x,y,c) DoSuperRepulsor(x,y,c,3) end, "rightdown", 50) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 50 and not IsMultiCell(c.id) or HasOnesidedDirection(c,1,723,721,724,50,722)) end,function(x,y,c) DoSuperRepulsor(x,y,c,1) end, "rightup", 50) end,
	function() return RunOn(function(c) return c.vars.timerepulseright end,																function(x,y,c) DoTimeRepulse(x,y,c,0) end, "upleft", "timerep") end,
	function() return RunOn(function(c) return c.vars.timerepulseleft end,																function(x,y,c) DoTimeRepulse(x,y,c,2) end, "upright", "timerep") end,
	function() return RunOn(function(c) return c.vars.timerepulseup end,																function(x,y,c) DoTimeRepulse(x,y,c,3) end, "rightdown", "timerep") end,
	function() return RunOn(function(c) return c.vars.timerepulsedown end,																function(x,y,c) DoTimeRepulse(x,y,c,1) end, "rightup", "timerep") end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 222 end,												DoTimeRepulsor, "upright", 222) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 21 and not IsMultiCell(c.id) or HasOnesidedDirection(c,0,{410,766},{408,764},{411,767},{21,763},{409,765})) end,function(x,y,c) DoRepulsor(x,y,c,0) end, "upleft", 21) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 21 and not IsMultiCell(c.id) or HasOnesidedDirection(c,2,{410,766},{408,764},{411,767},{21,763},{409,765})) end,function(x,y,c) DoRepulsor(x,y,c,2) end, "upright", 21) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 21 and not IsMultiCell(c.id) or HasOnesidedDirection(c,3,{410,766},{408,764},{411,767},{21,763},{409,765})) end,function(x,y,c) DoRepulsor(x,y,c,3) end, "rightdown", 21) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 21 and not IsMultiCell(c.id) or HasOnesidedDirection(c,1,{410,766},{408,764},{411,767},{21,763},{409,765})) end,function(x,y,c) DoRepulsor(x,y,c,1) end, "rightup", 21) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 156 and c.rot%2 == 0 end,								DoMagnet, "rightup", 156) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 156 and c.rot%2 == 1 end,								DoMagnet, "rightup", 156) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 832 and c.rot%2 == 0 end,								DoSuperSpring, "rightup", 832) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 832 and c.rot%2 == 1 end,								DoSuperSpring, "rightup", 832) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 402 and c.rot%2 == 0 end,								DoSpring, "rightup", 402) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 402 and c.rot%2 == 1 end,								DoSpring, "rightup", 402) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1124 and c.rot == 0) end,							function(x,y,c) DoConveyorZone(x,y,c,0) end, "upleft", 1124, 1) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1124 and c.rot == 2) end,							function(x,y,c) DoConveyorZone(x,y,c,2) end, "upright", 1124, 1) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1124 and c.rot == 3) end,							function(x,y,c) DoConveyorZone(x,y,c,3) end, "rightdown", 1124, 1) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1124 and c.rot == 1) end	,							function(x,y,c) DoConveyorZone(x,y,c,1) end, "rightup", 1124, 1) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1038 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,1039,1040,1041,1042)) end,function(x,y,c) DoSuperDeleter(x,y,c,0) end, "upleft", 1038) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1038 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,1039,1040,1041,1042)) end,function(x,y,c) DoSuperDeleter(x,y,c,2) end, "upright", 1038) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1038 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,1039,1040,1041,1042)) end,function(x,y,c) DoSuperDeleter(x,y,c,3) end, "rightdown", 1038) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1038 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,1039,1040,1041,1042)) end,function(x,y,c) DoSuperDeleter(x,y,c,1) end, "rightup", 1038) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1033 and not IsMultiCell(c.id) and c.rot == 0 or HasOnesidedDirection(c,0,1034,1035,1036,1037)) end,function(x,y,c) DoDeleter(x,y,c,0) end, "upleft", 1033) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1033 and not IsMultiCell(c.id) and c.rot == 2 or HasOnesidedDirection(c,2,1034,1035,1036,1037)) end,function(x,y,c) DoDeleter(x,y,c,2) end, "upright", 1033) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1033 and not IsMultiCell(c.id) and c.rot == 3 or HasOnesidedDirection(c,3,1034,1035,1036,1037)) end,function(x,y,c) DoDeleter(x,y,c,3) end, "rightdown", 1033) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 1033 and not IsMultiCell(c.id) and c.rot == 1 or HasOnesidedDirection(c,1,1034,1035,1036,1037)) end,function(x,y,c) DoDeleter(x,y,c,1) end, "rightup", 1033) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 306 end,												DoTermite, "rightup", 306) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 306 end,												DoTermite, "leftup", 306) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 624 end,												DoRutzice, "upright", 624) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 58 or c.id == 552 and c.vars[9] == 1 and c.vars[26] ~= 1) and c.rot == 0 end,DoDriller, "upleft", 58) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 58 or c.id == 552 and c.vars[9] == 1 and c.vars[26] ~= 1) and c.rot == 2 end,DoDriller, "upright", 58) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 58 or c.id == 552 and c.vars[9] == 1 and c.vars[26] ~= 1) and c.rot == 3 end,DoDriller, "rightdown", 58) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 58 or c.id == 552 and c.vars[9] == 1 and c.vars[26] ~= 1) and c.rot == 1 end,DoDriller, "rightup", 58) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 14 or c.id == 552 and c.vars[7] == 1 and c.vars[9] == 0 and c.vars[26] ~= 1) and c.rot == 0 end,DoPuller, "upleft", 14) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 14 or c.id == 552 and c.vars[7] == 1 and c.vars[9] == 0 and c.vars[26] ~= 1) and c.rot == 2 end,DoPuller, "upright", 14) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 14 or c.id == 552 and c.vars[7] == 1 and c.vars[9] == 0 and c.vars[26] ~= 1) and c.rot == 3 end,DoPuller, "rightdown", 14) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 14 or c.id == 552 and c.vars[7] == 1 and c.vars[9] == 0 and c.vars[26] ~= 1) and c.rot == 1 end,DoPuller, "rightup", 14) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 71 or c.id == 552 and c.vars[8] ~= 0 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[26] ~= 1) and c.rot == 0 end,DoGrabber, "upleft", 71) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 71 or c.id == 552 and c.vars[8] ~= 0 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[26] ~= 1) and c.rot == 2 end,DoGrabber, "upright", 71) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 71 or c.id == 552 and c.vars[8] ~= 0 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[26] ~= 1) and c.rot == 3 end,DoGrabber, "rightdown", 71) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 71 or c.id == 552 and c.vars[8] ~= 0 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[26] ~= 1) and c.rot == 1 end,DoGrabber, "rightup", 71) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 284 and c.rot == 0 end,DoSuperMover, "upright", 284) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 284 and c.rot == 2 end,DoSuperMover, "upleft", 284) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 284 and c.rot == 3 end,DoSuperMover, "rightup", 284) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 284 and c.rot == 1 end,DoSuperMover, "rightdown", 284) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 2 or c.id == 552 and c.vars[6] == 1 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 0 end,DoMover, "upright", 2) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 2 or c.id == 552 and c.vars[6] == 1 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 2 end,DoMover, "upleft", 2) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 2 or c.id == 552 and c.vars[6] == 1 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 3 end,DoMover, "rightup", 2) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 2 or c.id == 552 and c.vars[6] == 1 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 1 end,DoMover, "rightdown", 2) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 115 or c.id == 552 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[6] == 0 and c.vars[26] ~= 1) and c.rot == 0 end,DoSlicer, "upleft", 115) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 115 or c.id == 552 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[6] == 0 and c.vars[26] ~= 1) and c.rot == 2 end,DoSlicer, "upright", 115) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 115 or c.id == 552 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[6] == 0 and c.vars[26] ~= 1) and c.rot == 3 end,DoSlicer, "rightdown", 115) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 115 or c.id == 552 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[6] == 0 and c.vars[26] ~= 1) and c.rot == 1 end,DoSlicer, "rightup", 115) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 114 or c.id == 552 and c.vars[6] == 2 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 0 end,DoNudger, "upleft", 114) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 114 or c.id == 552 and c.vars[6] == 2 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 2 end,DoNudger, "upright", 114) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 114 or c.id == 552 and c.vars[6] == 2 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 3 end,DoNudger, "rightdown", 114) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 114 or c.id == 552 and c.vars[6] == 2 and c.vars[9] == 0 and c.vars[7] == 0 and c.vars[8] == 0 and c.vars[26] ~= 1) and c.rot == 1 end,DoNudger, "rightup", 114) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 465 end,												DoSapper, "rightup", 465) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 318 end,												DoSentry, "rightup", 318) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 819 end,																CheckBlade, "rightup", 819) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 818 end,																DoLaser, "rightup", 818) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 239 or c.id == 552 and c.vars[26] == 1 end,			DoPlayer, held == 0 and "upleft" or held == 2 and "upright" or held == 3 and "rightdown" or "rightup", 239) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1167 end,												DoChaser, "rightup", 1167) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1157 end,												DoObserver, "rightup", 1157) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 1155 end,												DoIcicle, "rightup", 1155) end,
	function() return wrap(function() return DoInputPushable() end) end,
	function() return RunOn(function(c) return  not c.updated and ChunkId(c.id) == 1172 end,											DoFearfulEnemy, "rightup", 1172) end,
	function() return RunOn(function(c) return  not c.updated and ChunkId(c.id) == 827 end,												DoAngryEnemy, "rightup", 827) end,
	function() return RunOn(function(c) return c.vars.gravdir and c.vars.gravdir%4 == 0 and not c.gupdated end,							function(x,y,c) c.gupdated = true; PushCell(x,y,0,{force=1}) end, "upleft", "gravity") end,
	function() return RunOn(function(c) return c.vars.gravdir and c.vars.gravdir%4 == 2 and not c.gupdated end,							function(x,y,c) c.gupdated = true; PushCell(x,y,2,{force=1}) end, "upright", "gravity") end,
	function() return RunOn(function(c) return c.vars.gravdir and c.vars.gravdir%4 == 3 and not c.gupdated end,							function(x,y,c) c.gupdated = true; PushCell(x,y,3,{force=1}) end, "rightdown", "gravity") end,
	function() return RunOn(function(c) return c.vars.gravdir and c.vars.gravdir%4 == 1 and not c.gupdated end,							function(x,y,c) c.gupdated = true; PushCell(x,y,1,{force=1}) end, "rightup", "gravity") end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 32 and c.rot == 0 end,								DoGate, "upright", 32) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 32 and c.rot == 2 end,								DoGate, "upleft", 32) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 32 and c.rot == 3 end,								DoGate, "rightup", 32) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 32 and c.rot == 1 end,								DoGate, "rightdown", 32) end,
	function() return RunOn(function(c) return not c.updated and c.id == 230 and c.rot == 0 end,			 							DoCoinExtractor, "upright", 230) end,
	function() return RunOn(function(c) return not c.updated and c.id == 230 and c.rot == 2 end,										DoCoinExtractor, "upleft", 230) end,
	function() return RunOn(function(c) return not c.updated and c.id == 230 and c.rot == 3 end,										DoCoinExtractor, "rightup", 230) end,
	function() return RunOn(function(c) return not c.updated and c.id == 230 and c.rot == 1 end,										DoCoinExtractor, "rightdown", 230) end,
	function() return RunOn(function(c) return not c.updated and (ChunkId(c.id) == 240 or c.id == 1147 or c.id == 1148) or c.id == 242 or c.id == 243 or c.id == 603 end,DoInfectious, "rightup", 240) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 123 end,												DoInfectious, "rightup", 123) end,
	function() return RunOn(function(c) return not c.updated and ChunkId(c.id) == 568 end,												DoPostInfectious, "rightup", 568) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 1187 end, 																DoCoil, "rightup", 1187) end,
	function() return RunOn(function(c) return ChunkId(c.id) == 735 end,																CheckBlade, "rightup", 735) end,
	function() return RunOn(function(c) return c.vars.compelled or c.vars.gooey or ChunkId(c.id) == "compel" and not c.updated end, 	CheckCompel, "rightup", "compel") end,
	function() return wrap(function() return CheckEnemies() end) end,
	function() return wrap(function() return FocusCam() end) end,
}

function AddSubtick(func,index)
	index = index or #subticks+1
	table.insert(subticks,index,func)
end

function ResetCells(first)
	if first then
		for i,force in ipairs(forcespread) do
			force.lx = force.x
			force.ly = force.y
			force.ldir = force.dir
		end
	end
	for z=0,depth-1 do
		chunks[z].all.new = {}
		RunOn(function(c) return c.id ~= 0 end,
		function(x,y,c)
			if first then
				c.lastvars = {x,y,0}
				c.eatencells = nil
				c.testvar = nil
			end
			if subtick == 0 then
				if x > 0 and x < width-1 and y > 0 and y < height-1 then
					local ids = AllChunkIds(c)
					for j=1,#ids do
						for i=1,maxchunksize do
							local invsize = 1/2^i
							local chunk = chunks[z][i][math.floor(y*invsize)][math.floor(x*invsize)]
							chunk.new = chunk.new or {}
							if chunk.new[ids[j]] then
								break
							end
							chunk.new[ids[j]] = true
						end
						chunks[z].all.new[ids[j]] = true
					end
				end
				for k,v in pairs(c) do
					if k == "clicked" and v == true then
						c.clicked = 1
					elseif k ~= "id" and k ~= "rot" and k ~= "vars" and k ~= "lastvars" and k ~= "eatencells" then
						c[k] = nil
					end
				end
				c.firstx,c.firsty,c.firstrot = x,y,c.rot
			end
		end
		,"rightup","all",z,0,width-1,height-1,0)()
	end
	if subtick == 0 then
		for z=0,depth-1 do
			chunks[z].all = chunks[z].all.new
			chunks[z].all.new = nil
			for i=1,maxchunksize do
				local invsize = 1/2^i
				for y=0,(height-1)*invsize do
					for x=0,(width-1)*invsize do
						chunks[z][i][y][x] = chunks[z][i][y][x].new or {}
						chunks[z][i][y][x].new = nil
					end
				end
			end
		end
	end
end

--[[
	DAWS ?
	.... 0
	d... 1
	.a.. 2
	da.. 3
	..w. 4
	d.w. 5
	.aw. 6
	daw. 7
	...s 8
	d..s 9
	.a.s a
	da.s b
	..ws c
	d.ws d
	.aws e
	daws f
]]

function DoTick(first)
	if winscreen then return end
	if not v and draggedcell then
		local cx = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
		local cy = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
		if GetPlaceable(cx,cy) == GetPlaceable(draggedcell.lastvars[1],draggedcell.lastvars[2]) then
			PlaceCell(draggedcell.lastvars[1],draggedcell.lastvars[2],GetCell(cx,cy))
			PlaceCell(cx,cy,draggedcell)
		else
			PlaceCell(draggedcell.lastvars[1],draggedcell.lastvars[2],draggedcell)
		end
		draggedcell = nil
	end
	if mainmenu then return end
	if updatekey > 1000000000000 then updatekey = 0 end --juuuust in case
	if supdatekey > 1000000000000 then supdatekey = 0 end
	if stickkey > 1000000000000 then stickkey = 0 end
	if tickcount == 0 then overallcount = 0; inputrecording = "" end
	local keyid = 0
	local curkey = recording and tonumber(recorddata.animation.input:sub(overallcount+1, overallcount+1), 16) or 0
	if (not recording and love.keyboard.isDown("d") or love.keyboard.isDown("right")) or (recording and curkey % 2 == 1) then held = held or 0; heldhori = heldhori or 0; keyid = keyid + 1 end
	if (not recording and love.keyboard.isDown("a") or love.keyboard.isDown("left")) or (recording and curkey % 4 >= 2) then held = held or 2; heldhori = heldhori or 2; keyid = keyid + 2 end
	if (not recording and love.keyboard.isDown("w") or love.keyboard.isDown("up")) or (recording and curkey % 8 >= 4) then held = held or 3; heldvert = heldvert or 3; keyid = keyid + 4 end
	if (not recording and love.keyboard.isDown("s") or love.keyboard.isDown("down")) or (recording and curkey >= 8) then held = held or 1; heldvert = heldvert or 1; keyid = keyid + 8 end
	if recordinginput then inputrecording = inputrecording..(keyid == 0 and "." or string.format("%x", keyid)) end
	if subticking == 0 or level then
		subtickco = nil
		currentsst = nil
		forcespread = {}
		subtick = 0
		tickcount = tickcount + 1
		ResetCells(first)
		for i=subtick%#subticks+1,#subticks do
			subticks[i]()()
		end
	elseif subticking == 1 then
		subtickco = nil
		currentsst = nil
		forcespread = {}
		if subtick == 0 then tickcount = tickcount + 1 end
		ResetCells(first)
		repeat
			subtick = subtick%#subticks+1
		until subticks[subtick]()() or subtick == #subticks
		if subtick == #subticks then subtick = 0 end
	else
		if not subtickco or coroutine.status(subtickcothread) == "dead" then
			if subtick == 0 then tickcount = tickcount + 1 end
			currentsst = nil
			forcespread = {}
			local hit = false
			ResetCells(first)
			repeat
				subtick = subtick%#subticks+1
				subtickco, subtickcothread = subticks[subtick]()
				hit = subtickco(true)
			until hit or subtick == #subticks
			if not hit then subtickco = nil end
			if hit then
				goto out
			end
		end
		if subtickco then
			ResetCells(first)
			subtickco(true)
		end
		::out::
		if subtick == #subticks then subtick = 0; subtickco = nil end
	end
	overallcount = overallcount + 1
	held = nil
	heldhori = nil
	heldvert = nil
	actionpressed = nil
	isinitial = false
	recorddata.debug = dtime..", "..(level and .2 or delay)..", "..(dtime - (level and .2 or delay))
	dtime = recording and math.max(0, dtime - (level and .2 or delay)) or 0
	itime = 0
end

function love.resize()
	winxm = love.graphics.getWidth()/800
	winym = love.graphics.getHeight()/600
	centerx = 400*winxm
	centery = 300*winym
	settings.window_width = love.graphics.getWidth()
	settings.window_height = love.graphics.getHeight()
	settings.fullscreen = love.window.getFullscreen()
	love.window.setVSync(settings.fullscreen)
end

function love.load()
	LoadTexturePacks()
	ReadSavedVars()
	winxm = love.graphics.getWidth()/800
	winym = love.graphics.getHeight()/600
	centerx = 400*winxm
	centery = 300*winym
	for k,v in pairs(GetSaved("secrets")) do
		HandleSecret(k)
	end
	table.insert(truequeue, LoadAudio)
	table.insert(truequeue, CreateCategories)
	table.insert(truequeue, CreateMenu)
	table.insert(truequeue, CreateLevelMenu)
	table.insert(truequeue, function() PlayMusic(settings.music) end)
	table.insert(truequeue, ReloadStamps)
	if love._os ~= "Android" and love._os ~= "iOS" then
		love.window.updateMode(settings.window_width,settings.window_height)
		love.window.setFullscreen(settings.fullscreen)
		love.resize()
	end
end

function HandleTool(x,y,z,c)
	if Override("HandleTool"..chosen.id,x,y,z,c) then return end
	if chosen.id == "paint" then
		if c.id ~= 0 then
			c.vars.paint = tonumber("0x"..chosen.data[1]) ~= 0 and tonumber("0x"..chosen.data[1]) or nil
			if c.vars.paint and c.vars.paint > 0xffffff then c.vars.paint = nil end
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "invertpaint" then
		if c.id ~= 0 then
			c.vars.paint = "i"
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "invertcolorpaint" then
		if c.id ~= 0 then
			c.vars.paint = tonumber("0x"..chosen.data[1]) ~= 0 and -tonumber("0x"..chosen.data[1]) or nil
			if c.vars.paint and c.vars.paint < -0xffffff then c.vars.paint = nil end
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "hsvpaint" then
		if c.id ~= 0 then
			c.vars.paint = "H"..chosen.data[1].."S"..chosen.data[2].."V"..chosen.data[3]
			if c.vars.paint == "H0S100V100" then c.vars.paint = nil end
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "inverthsvpaint" then
		if c.id ~= 0 then
			c.vars.paint = "h"..chosen.data[1].."s"..chosen.data[2].."v"..chosen.data[3]
			if c.vars.paint == "h0s100v100" then c.vars.paint = "i" end
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "invispaint" then
		if c.id ~= 0 then
			c.vars.paint = "I"
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "shadowpaint" then
		if c.id ~= 0 then
			c.vars.paint = "s"
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "blendmode" then
		if c.id ~= 0 then
			c.vars.blending = chosen.data[1] ~= 0 and chosen.data[1] or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "timerep_tool" then
		if c.id ~= 0 then
			if chosen.rot == 0 then
				c.vars[chosen.data[1] == 0 and "timerepulseright" or "timeimpulseright"] = chosen.data[2] ~= 0 and chosen.data[2] or nil
			elseif chosen.rot == 2 then
				c.vars[chosen.data[1] == 0 and "timerepulseleft" or "timeimpulseleft"] = chosen.data[2] ~= 0 and chosen.data[2] or nil
			elseif chosen.rot == 3 then
				c.vars[chosen.data[1] == 0 and "timerepulseup" or "timeimpulseup"] = chosen.data[2] ~= 0 and chosen.data[2] or nil
			elseif chosen.rot == 1 then
				c.vars[chosen.data[1] == 0 and "timerepulsedown" or "timeimpulsedown"] = chosen.data[2] ~= 0 and chosen.data[2] or nil
			end
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "grav_tool" then
		if c.id ~= 0 then
			c.vars.gravdir = chosen.data[1] == 1 and chosen.rot+4 or chosen.data[1] == 0 and chosen.rot or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "prot_tool" then
		if c.id ~= 0 then
			c.vars.perpetualrot = chosen.data[1] == 0 and 1 or chosen.data[1] == 1 and -1 or chosen.data[1] ~= 8 and chosen.data[1] or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "tag_tool" then
		if c.id ~= 0 then
			c.vars.tag = chosen.data[1] ~= 3 and chosen.data[1]+1 or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "spikes_tool" then
		if c.id ~= 0 then
			c.vars.spiked = chosen.data[1] == 0 and true or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "armor_tool" then
		if c.id ~= 0 then
			c.vars.armored = chosen.data[1] == 0 and true or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "bolt_tool" then
		if c.id ~= 0 then
			c.vars.bolted = chosen.data[1] == 0 and true or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "petrify_tool" then
		if c.id ~= 0 then
			c.vars.petrified = chosen.data[1] == 0 and true or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "goo_tool" then
		if c.id ~= 0 then
			c.vars.gooey = chosen.data[1] == 0 and true or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "compel_tool" then
		if c.id ~= 0 then
			c.vars.compelled = chosen.data[1] ~= 2 and chosen.data[1]+1 or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "entangle_tool" then
		if c.id ~= 0 then
			c.vars.entangled = chosen.data[2] ~= 1 and chosen.data[1] or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "permaclamp_tool" then
		if c.id ~= 0 then
			if chosen.data[1] == 1 then
				c.vars.pushpermaclamped = chosen.data[2] == 0 and chosen.data[2] or nil
			elseif chosen.data[1] == 2 then
				c.vars.pullpermaclamped = chosen.data[2] == 0 and chosen.data[2] or nil
			elseif chosen.data[1] == 3 then
				c.vars.grabpermaclamped = chosen.data[2] == 0 and chosen.data[2] or nil
			elseif chosen.data[1] == 4 then
				c.vars.swappermaclamped = chosen.data[2] == 0 and chosen.data[2] or nil
			elseif chosen.data[1] == 5 then
				c.vars.scissorpermaclamped = chosen.data[2] == 0 and chosen.data[2] or nil
			elseif chosen.data[1] == 6 then
				c.vars.tunnelpermaclamped = chosen.data[2] == 0 and chosen.data[2] or nil
			end
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "ghost_tool" then
		if c.id ~= 0 then
			c.vars.ghostified = chosen.data[1] > 0 and chosen.data[1] or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "coin_tool" then
		if c.id ~= 0 then
			c.vars.coins = chosen.data[1] ~= 0 and chosen.data[1] or nil
			PlaceCell(x,y,c,z)
		end
	elseif chosen.id == "input_tool" then
		if c.id ~= 0 then
			c.vars.input = chosen.data[1] ~= 1 and true or nil
			PlaceCell(x,y,c,z)
		end
	end
end

mx,my = 0,0
function love.update(dt)
	if recording then
		dt = 1/recorddata.animation.fps
		recorddata.timer = recorddata.timer + dt
		winxm = 0
		winym = 0
	end
	delta = dt
	local start = love.timer.getTime()
	if truequeue[1] then
		while truequeue[1] and love.timer.getTime() < start+0.25 do
			truequeue[1]()
			table.remove(truequeue,1)
		end
		if truequeue[1] then return end
	end
	postloading = true
	ip.Update(dt)
	if not paused and not mainmenu then
		local scene = recorddata.scene
		local anim = recorddata.animation
		dtime = dtime + dt
		if dtime > (level and .2 or delay) then
			if recording then
				for i=1, #anim.ticks, 2 do
					local value = anim.ticks[i]
					local transition = anim.ticks[i+1]
					if value == overallcount then
						local camvalue = anim.camera and tostring(anim.camera[i+2])
						local length = 0
						recorddata.current = i
						anim.ltime = 0
						if transition == "->" or (transition or ""):match("^%-%d*%.?%d+>$") then
							local number = tonumber(transition:match("^%-(%d*%.?%d+)>$"))
							delay = number or anim.defaultspeed
							tpu = 1
							anim.lerptotal = anim.ticks[i+2] - value
						elseif transition == ">>" or (transition or ""):match("^>%d*%.?%d+>$") then
							local number = tonumber(transition:match("^>(%d*%.?%d+)>$"))
							delay = number or anim.defaultspeed
							tpu = anim.ticks[i+2] - value
							anim.lerptotal = 1
						else
							delay = 0.2
							tpu = 1
							LoadWorld(scene.level)
							recording = false
							love.resize()
							goto notick
						end
						anim.lerpstart = value + 1
						recorddata.next = recorddata.timer + length
						if camvalue and (camvalue:match("^[%+%-]?i$") or camvalue:match("^[%+%-]?%d*%.?%d+i?$") or camvalue:match("^[%+%-]?%d*%.?%d+[%+%-]%d*%.?%d*i$")) then
							if not anim.trackplayer and anim.tocam then
								cam.x = anim.fromcam.x + anim.tocam.x
								cam.y = anim.fromcam.y + anim.tocam.y
							elseif anim.tocam then
								anim.trackplayer.offx = anim.fromcam.x + anim.tocam.x
								anim.trackplayer.offy = anim.fromcam.y + anim.tocam.y
							end
							local x, y = camvalue:match("^([%+%-]?%d*%.?%d+)([%+%-]%d*%.?%d*)i$")
							x = x or camvalue:match("^([%+%-]?%d*%.?%d+)$")
							y = y or camvalue:match("^([%+%-]?%d*%.?%d+)i$") or camvalue:match("^([%+%-]?)i$")
							if y == "+" or y == "-" then y = y.."1" end
							anim.fromcam = not anim.trackplayer and {x = cam.x, y = cam.y} or {x = anim.trackplayer.offx, y = anim.trackplayer.offy}
							anim.tocam = {x = (tonumber(x) or 0) * scene.cellsize, y = (tonumber(y) or 0) * scene.cellsize}
						end
					end
				end
			end
			for i=1,(level and 1 or tpu) do
				DoTick(i==1)
			end
			::notick::
		end
		if recording and anim.fromcam and anim.tocam then
			anim.ltime = anim.ltime + dt
			local lerp = math.min(1, anim.ltime / (anim.lerptotal * delay))
			anim.lerpdebug = lerp
			if not anim.trackplayer then
				cam.x = anim.fromcam.x + anim.tocam.x * lerp
				cam.y = anim.fromcam.y + anim.tocam.y * lerp
			else
				anim.trackplayer.offx = anim.fromcam.x + anim.tocam.x * lerp
				anim.trackplayer.offy = anim.fromcam.y + anim.tocam.y * lerp
			end
		end
	end
	hoveredbutton = nil
	for i=1,#buttonorder do
		local b = buttons[buttonorder[i]]
		if b.updatefunc then b.updatefunc(x,y,b) end
		b.currentenabled = get(b.isenabled)
		if b.currentenabled then
			local x,y,x2,y2
			b.cx,b.cy,b.cw,b.ch = get(b.x),get(b.y),get(b.w),get(b.h)
			if b.halign == -1 then
				x = b.cx*uiscale
				x2 = x+b.cw*uiscale
			elseif b.halign == 1 then
				x2 = love.graphics.getWidth()-b.cx*uiscale
				x = x2-b.cw*uiscale
			else
				x = b.cx*uiscale+centerx-b.cw*.5*uiscale
				x2 = x+b.cw*uiscale
			end
			if b.valign == -1 then
				y = b.cy*uiscale
				y2 = y+b.ch*uiscale
			elseif b.valign == 1 then
				y2 = love.graphics.getHeight()-b.cy*uiscale
				y = y2-b.ch*uiscale
			else
				y = b.cy*uiscale+centery-b.ch*.5*uiscale
				y2 = y+b.ch*uiscale
			end
			if love.mouse.getX() >= x and love.mouse.getX() <= x2 and love.mouse.getY() >= y and love.mouse.getY() <= y2 then
				hoveredbutton = b
				if love.mouse.isDown(1) or love.mouse.isDown(2) or love.mouse.isDown(3) then placecells = false end
			end
		end
	end
	jx,jy = 0,0
	if (love.mouse.isDown(1) or love.mouse.isDown(2) or love.mouse.isDown(3)) and hoveredbutton and hoveredbutton.ishold then
		hoveredbutton.onclick(hoveredbutton)
	end
	if love.mouse.isDown(1) and chosen.id ~= 0 and not hoveredbutton and not puzzle and placecells then
		local x = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
		local y = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
		for cy=y-math.ceil(chosen.size*.5)+(chosen.shape == "Square" and 1 or 0),y+math.floor(chosen.size*.5) do
			for cx=x-math.ceil(chosen.size*.5)+(chosen.shape == "Square" and 1 or 0),x+math.floor(chosen.size*.5) do
				if (chosen.shape == "Square" or math.distSqr(cx-x,cy-y) <= chosen.size*chosen.size/4) and (IsTool(chosen.id) or (chosen.mode ~= "Or" or GetCell(cx,cy).id == 0) and (chosen.mode ~= "And" or GetCell(cx,cy).id ~= 0)) then
					if chosen.randrot then hudrot = chosen.rot chosen.rot = math.random(0,3) end
					if GetLayer(chosen.id) == -1 or chosen.id == 0 and lockedz == true then
						SetPlaceable(cx,cy,chosen.id)
					else
						if IsTool(chosen.id) and chosen.id ~= "paint" and chosen.id ~= "invertpaint" and chosen.id ~= "invertcolorpaint"
						and chosen.id ~= "hsvpaint" and chosen.id ~= "inverthsvpaint" and chosen.id ~= "invispaint" and chosen.id ~= "shadowpaint" and chosen.id ~= "blendmode" then lockedz = 0 end
						if not undocells.topush and width*height < 40000 then
							undocells.topush = table.copy(layers)
							undocells.topush.background = table.copy(placeables)
							undocells.topush.chunks = table.copy(chunks)
							undocells.topush.isinitial = isinitial
							undocells.topush.width = width
							undocells.topush.height = height
						end
						if IsTool(chosen.id) then
							if type(lockedz) == "number" then
								HandleTool(cx,cy,lockedz,GetCell(cx,cy,lockedz,true))
							end
						else
							PlaceCell(cx,cy,{id=chosen.id,rot=chosen.rot,lastvars={cx,cy,0}},GetLayer(chosen.id))
						end 
					end
				end
			end
		end	
	elseif love.mouse.isDown(1) and not hoveredbutton and not puzzle and selection.on then
		local x = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
		local y = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
		selection.x = math.min(x,selection.ox)
		selection.y = math.min(y,selection.oy)
		selection.w = math.max(selection.ox-selection.x + 1,x-selection.x + 1)
		selection.h = math.max(selection.oy-selection.y + 1,y-selection.y + 1)
	elseif (love.mouse.isDown(2) or love.mouse.isDown(1) and chosen.id == 0) and not hoveredbutton and not puzzle and placecells then
		local x = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
		local y = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
		for cy=y-math.ceil(chosen.size*.5)+(chosen.shape == "Square" and 1 or 0),y+math.floor(chosen.size*.5) do
			for cx=x-math.ceil(chosen.size*.5)+(chosen.shape == "Square" and 1 or 0),x+math.floor(chosen.size*.5) do
				if (chosen.shape == "Square" or math.distSqr(cx-x,cy-y) <= chosen.size*chosen.size/4) then
					if lockedz == true then
						SetPlaceable(cx,cy)
					else
						if not undocells.topush and width*height < 40000 then
							undocells.topush = table.copy(layers)
							undocells.topush.background = table.copy(placeables)
							undocells.topush.chunks = table.copy(chunks)
							undocells.topush.isinitial = isinitial
							undocells.topush.width = width
							undocells.topush.height = height
						end
						local c = GetCell(cx,cy,lockedz)
						if (chosen.id == "paint" or chosen.id == "invertpaint" or chosen.id == "invertcolorpaint"
						or chosen.id == "hsvpaint" or chosen.id == "inverthsvpaint" or chosen.id == "invispaint" or chosen.id == "shadowpaint") then
							c.vars.paint = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "blendmode" then
							c.vars.blending = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "timerep_tool" then
							lockedz = 0
							c.vars.timerepulseright=nil
							c.vars.timerepulsedown=nil
							c.vars.timerepulseleft=nil
							c.vars.timerepulseup=nil
							c.vars.timeimpulseright=nil
							c.vars.timeimpulsedown=nil
							c.vars.timeimpulseleft=nil
							c.vars.timeimpulseup=nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "grav_tool" then
							lockedz = 0
							c.vars.gravdir = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "prot_tool" then
							lockedz = 0
							c.vars.perpetualrot = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "tag_tool" then
							lockedz = 0
							c.vars.tag = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "spikes_tool" then
							lockedz = 0
							c.vars.spiked = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "armor_tool" then
							lockedz = 0
							c.vars.armored = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "bolt_tool" then
							lockedz = 0
							c.vars.bolted = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "petrify_tool" then
							lockedz = 0
							c.vars.petrified = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "goo_tool" then
							lockedz = 0
							c.vars.gooey = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "compel_tool" then
							lockedz = 0
							c.vars.compelled = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "entangle_tool" then
							lockedz = 0
							c.vars.entangled = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "permaclamp_tool" then
							lockedz = 0
							if chosen.data[1] == 1 then
								c.vars.pushpermaclamped = nil
							elseif chosen.data[1] == 2 then
								c.vars.pullpermaclamped = nil
							elseif chosen.data[1] == 3 then
								c.vars.grabpermaclamped = nil
							elseif chosen.data[1] == 4 then
								c.vars.swappermaclamped = nil
							elseif chosen.data[1] == 5 then
								c.vars.scissorpermaclamped = nil
							elseif chosen.data[1] == 6 then
								c.vars.tunnelpermaclamped = nil
							end
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "ghost_tool" then
							lockedz = 0
							c.vars.ghostified = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "coin_tool" then
							lockedz = 0
							c.vars.coins = nil
							PlaceCell(cx,cy,c,lockedz)
						elseif chosen.id == "input_tool" then
							lockedz = 0
							c.vars.input = nil
							PlaceCell(cx,cy,c,lockedz)
						else
							PlaceCell(cx,cy,getempty(),lockedz)
						end
					end
				end
			end
		end	
	end
	if love.mouse.isDown(3) and not inmenu and not mainmenu and not winscreen then
		local x,y = love.mouse.getX(),love.mouse.getY()
		cam.x = cam.x + mx - x
		cam.y = cam.y + my - y
		cam.tarx = cam.tarx + mx - x
		cam.tary = cam.tary + my - y
		mx,my = x,y
	else
		mx,my = love.mouse.getX(),love.mouse.getY()
	end
	freezecam = freezecam and not paused
	if not freezecam and not typing and not mainmenu and not recording then
		if ctrl() then
			if love.keyboard.isDown("w") or love.keyboard.isDown("up") then cam.tary = cam.tary - math.min(dt*1200,100) end
			if love.keyboard.isDown("s") or love.keyboard.isDown("down") then cam.tary = cam.tary + math.min(dt*1200,100) end
			if love.keyboard.isDown("a") or love.keyboard.isDown("left") then cam.tarx = cam.tarx - math.min(dt*1200,100) end
			if love.keyboard.isDown("d") or love.keyboard.isDown("right") then cam.tarx = cam.tarx + math.min(dt*1200,100) end
		else
			if love.keyboard.isDown("w") or love.keyboard.isDown("up") then cam.tary = cam.tary - math.min(dt*600,50) end
			if love.keyboard.isDown("s") or love.keyboard.isDown("down") then cam.tary = cam.tary + math.min(dt*600,50) end
			if love.keyboard.isDown("a") or love.keyboard.isDown("left") then cam.tarx = cam.tarx - math.min(dt*600,50) end
			if love.keyboard.isDown("d") or love.keyboard.isDown("right") then cam.tarx = cam.tarx + math.min(dt*600,50) end
		end
	end
	if not recording then
		cam.tarx = math.max(math.min(cam.tarx,width*cam.tarzoom-100+400*winxm),100-400*winxm)
		cam.tary = math.max(math.min(cam.tary,height*cam.tarzoom-100+300*winym),100-300*winym)
		cam.x = math.lerp(cam.x,cam.tarx,1-.9^(dt*100))
		cam.y = math.lerp(cam.y,cam.tary,1-.9^(dt*100))
		cam.zoom = math.lerp(cam.zoom,cam.tarzoom,1-.9^(dt*100))
		cam.x = math.abs(cam.x-cam.tarx) < .01 and cam.tarx or cam.x
		cam.y = math.abs(cam.y-cam.tary) < .01 and cam.tary or cam.y
		cam.zoom = math.abs(cam.zoom-cam.tarzoom) < .01 and cam.tarzoom or cam.zoom
	elseif recording and recorddata.animation.trackplayer then
		local tp = recorddata.animation.trackplayer
		local width, height = recorddata.scene.capture[1] * cam.zoom, recorddata.scene.capture[2] * cam.zoom
		local winxm, winym = width / 800, height / 600
		local minx, maxx, miny, maxy
		if type(tp[1]) == "number" then minx, maxx = tp[1], tp[1] else minx, maxx = tp[1]:match("(%d+)%-(%d+)") end
		if type(tp[2]) == "number" then miny, maxy = tp[2], tp[2] else miny, maxy = tp[2]:match("(%d+)%-(%d+)") end
		cam.tarx = math.max(math.min(cam.tarx,width*cam.zoom-100+400*winxm),100-400*winxm)
		cam.tary = math.max(math.min(cam.tary,height*cam.zoom-100+300*winym),100-300*winym)
		cam.x = tp.origx or cam.x
		cam.y = tp.origy or cam.y
		cam.x = math.lerp(cam.x,cam.tarx,1-.9^(dt*100))
		cam.y = math.lerp(cam.y,cam.tary,1-.9^(dt*100))
		cam.x = math.abs(cam.x-cam.tarx) < .01 and cam.tarx or cam.x
		cam.y = math.abs(cam.y-cam.tary) < .01 and cam.tary or cam.y
		tp.origx = cam.x
		tp.origy = cam.y
		cam.x = math.min(math.max(cam.x + (tp.offx or 0) - width/2, minx*cam.zoom), maxx*cam.zoom)
		cam.y = math.min(math.max(cam.y + (tp.offy or 0) - height/2, miny*cam.zoom), maxy*cam.zoom)
	end
	itime = math.min(itime + dt,delay)
	hudlerp = math.min(hudlerp + dt*10,1)
	for k,v in pairs(particles) do
		v:update(dt)
	end
	menuparticles:emit(dt*1000)
	menuparticles:update(dt)
	for i=#fireworkparticles,1,-1 do
		local p = fireworkparticles[i]
		p.x, p.y = p.x + p.vx, p.y + p.vy
		p.vx, p.vy = p.vx*0.95,p.vy*0.95
		p.life = p.life - dt
		if p.life <= 0 then
			table.remove(fireworkparticles,i)
		end
	end
	if typing then
		love.keyboard.setTextInput(true)
	else
		love.keyboard.setTextInput(false)
	end
end

MergeIntoInfo("texture", {
	[236]="particle_neutral",
	[685] = 1,
	[687] = 41,
	[689] = 12,
	[691] = 205,
	[693] = 4,
	[488] = "rotatordiverger0",
	[500] = "confetti1",
	[1116] = "sawblade0",
	[1163] = "dashblock0",
	[1180] = "keycollectable1",
	[1181] = "keydoor1",
})

function GetCellTexture(id)
	return GetAttribute(id, "texture", id) or id
end

MergeIntoInfo("drawtexture", {
	[1133]="particle_red",[1134]="particle_red",
	[1135]="particle_cyan",[1136]="particle_cyan",
	[1137]="particle_yellow",[1138]="particle_yellow",
	[1139]="particle_orange",[1140]="particle_orange",
	[1141]="particle_purple",[1142]="particle_purple",
	[1143]="particle_green",[1144]="particle_green",
	[1145]="particle_blue",[1146]="particle_blue",
	[1147]="particle_lime",[1148]="particle_lime",
	[1149]="particle_neutral",
	[206] = function(c) return "lluea"..c.vars[1] end,
	[351] = function(c) return fancy and "omnicellbase" or 351 end,
	[488] = function(c) return "rotatordiverger"..c.vars[1] end,
	[500] = function(c) return "confetti"..c.vars[1] end,
	[552] = function(c) return fancy and (c.vars[26] == 1 and "omnicellcontrolledbase" or "omnicellmovebase") or 552 end,
	[563] = function(c) return switches[c.vars[1]] and "switch_on" or 563 end,
	[564] = function(c) return switches[c.vars[1]] and 565 or 564 end,
	[565] = function(c) return switches[c.vars[1]] and 564 or 565 end,
	[566] = function(c) return c.vars[2] == 0 and 566 or "brokenstaller" end,
	[818] = function(c) return c.vars[1] == 1 and "laser_charge" or c.vars[1] == 2 and "laser_on" or 818 end,
	[819] = function(c) return "laser"..(type(c.vars.paint) == "number" and (c.vars.paint < 0 and "_invertcolorable" or "_colorable") or "")..(c.crossed and "_cross" or "") end,
	[846] = function(c,...) return c.vars[1] and c.vars[1] ~= 846 and GetDrawTexture({id=c.vars[1],rot=c.rot,vars=DefaultVars(c.vars[1],true)},...) or 846 end,
	[908] = function(c) return c.vars[2] and "victoryswitch_on" or 908 end,
	[909] = function(c) return c.vars[2] and "failureswitch_on" or 909 end,
	[1116] = function() return not paused and "sawblade"..math.floor(love.timer.getTime()*20%2) end,
	[1163] = function() return not paused and "dashblock"..math.floor(love.timer.getTime()*50%10) end,
	[1180] = function(c) return "keycollectable"..c.vars[1] end,
	[1181] = function(c) return "keydoor"..c.vars[1] end,
	bgspace = function(c,x,y,r,fancy)
		if fancy then
			local r,g,b,a = love.graphics.getColor()
			shaders.space:send("alpha", a)
			shaders.space:send("time", love.timer.getTime())
			love.graphics.setShader(shaders.space)
		end
		return "bgspace"
	end,
	bgmatrix = function(c,x,y,r,fancy)
		if fancy then
			local r,g,b,a = love.graphics.getColor()
			shaders.matrix:send("alpha", a)
			shaders.matrix:send("time", love.timer.getTime())
			love.graphics.setShader(shaders.matrix)
		end
		return "bgmatrix"
	end,
})

function GetDrawTexture(cell,...)
	return GetAttribute(cell.id, "drawtexture", cell, ...) or GetCellTexture(cell.id)
end

MergeIntoInfo("overlaytexture", {
})
function GetOverlay(cell)
	return GetAttribute(cell, "overlaytexture", cell) or cell.."_overlay"
end

MergeIntoInfo("drawrot", {
})
function DrawRot(cell,cx,cy,crot,...)
	return GetAttribute(cell.id, "drawrot", cell,cx,cy,crot,...) or crot
end

MergeIntoInfo("xscalemult", {
})
function xScaleMult(cell,...)
	return GetAttribute(cell.id, "xscalemult", cell, ...) or 1
end

function flipforlighting(c)
	return (c.rot > .5 and c.rot < 2.5) and -1 or 1
end
MergeIntoInfo("yscalemult", {
	[735]=flipforlighting,[815]=flipforlighting,[817]=flipforlighting,[1155]=flipforlighting,
})
function yScaleMult(cell,...)
	return GetAttribute(cell.id, "yscalemult", cell, ...) or 1
end

function DrawStoredCell(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] then
		UpdateShader(cell,cx,cy,crot,fancy,scale)
		DrawBasic(GetTex(cell.vars[1]),cx,cy,cell.vars[2]*math.halfpi,fancy,scale*storagemult)
		love.graphics.setShader()
	end
end

function DrawStoredMemory(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] then
		UpdateShader(cell,cx,cy,crot,fancy,scale)
		DrawBasic(GetTex(cell.vars[1]),cx,cy,cell.vars[2]*math.halfpi,fancy,scale*memorymult)
		love.graphics.setShader()
	end
end

function DrawStoredMaker(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] then
		UpdateShader(cell,cx,cy,crot,fancy,scale)
		DrawBasic(GetTex(cell.vars[1]),cx,cy,cell.vars[2]*math.halfpi,fancy,scale*makermult)
		love.graphics.setShader()
	end
end

function DrawStoredFilter(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] then
		UpdateShader(cell,cx,cy,crot,fancy,scale)
		DrawBasic(GetTex(cell.vars[1]),cx,cy,0,fancy,scale*memorymult)
		love.graphics.setShader()
	end
end

function DrawSmallNumber(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and cell.vars[1] ~= 0 and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.575*cam.zoom,cy+.225*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.6*cam.zoom,cy+.2*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and cell.vars[1] ~= 0 and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.575*20*scale,cy+.225*20*scale,40,"right",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.6*20*scale,cy+.2*20*scale,40,"right",0,20*scale/40,20*scale/40)
	end
end

function DrawSmallNumberWithZero(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.575*cam.zoom,cy+.225*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.6*cam.zoom,cy+.2*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.575*20*scale,cy+.225*20*scale,40,"right",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.6*20*scale,cy+.2*20*scale,40,"right",0,20*scale/40,20*scale/40)
	end
end

function DrawBigNumber(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and cell.vars[1] ~= 0 and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.475*cam.zoom,cy-.1*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.5*cam.zoom,cy-.125*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and cell.vars[1] ~= 0 and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.475*20*scale,cy-.1*20*scale,40,"center",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.5*20*scale,cy-.125*20*scale,40,"center",0,20*scale/40,20*scale/40)
	end
end

function DrawBigNumberWithZero(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.475*cam.zoom,cy-.1*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.5*cam.zoom,cy-.125*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1],cx-.475*20*scale,cy-.1*20*scale,40,"center",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1],cx-.5*20*scale,cy-.125*20*scale,40,"center",0,20*scale/40,20*scale/40)
	end
end

function DrawStoredCellWithNumber(cell,cx,cy,crot,fancy,scale)
	if cell.vars[3] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[3],cx-.575*cam.zoom,cy+.225*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[3],cx-.6*cam.zoom,cy+.2*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[3] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[3],cx-.575*20*scale,cy+.225*20*scale,40,"right",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[3],cx-.6*20*scale,cy+.2*20*scale,40,"right",0,20*scale/40,20*scale/40)
	end
	DrawStoredCell(cell,cx,cy,crot,fancy,scale)
end

function DrawPortalIDs(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and cell.vars[2] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1].."\n"..cell.vars[2],cx-.225*cam.zoom,cy-.225*cam.zoom,20,"center",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1].."\n"..cell.vars[2],cx-.25*cam.zoom,cy-.25*cam.zoom,20,"center",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and cell.vars[2] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars[1].."\n"..cell.vars[2],cx-.225*20*scale,cy-.225*20*scale,20,"center",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(cell.vars[1].."\n"..cell.vars[2],cx-.25*20*scale,cy-.25*20*scale,20,"center",0,20*scale/40,20*scale/40)
	end
end

function DrawFraction(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and cell.vars[2] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1].."/"..cell.vars[2]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.475*cam.zoom,cy-.1*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.5*cam.zoom,cy-.125*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and cell.vars[2] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1].."/"..cell.vars[2]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.475*20*scale,cy-.1*20*scale,40,"center",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.5*20*scale,cy-.125*20*scale,40,"center",0,20*scale/40,20*scale/40)
	end
end

function DrawComma(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and cell.vars[2] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1]..", "..cell.vars[2]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.475*cam.zoom,cy-.1*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.5*cam.zoom,cy-.125*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and cell.vars[2] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1]..", "..cell.vars[2]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.475*20*scale,cy-.1*20*scale,40,"center",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.5*20*scale,cy-.125*20*scale,40,"center",0,20*scale/40,20*scale/40)
	end
end

function DrawSmallFraction(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and cell.vars[2] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1].."/"..cell.vars[2]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.575*cam.zoom,cy+.225*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.6*cam.zoom,cy+.2*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and cell.vars[2] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1].."/"..cell.vars[2]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.575*20*scale,cy+.225*20*scale,40,"right",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.6*20*scale,cy+.2*20*scale,40,"right",0,20*scale/40,20*scale/40)
	end
end

function DrawAdjustableMover(cell,cx,cy,crot,fancy,scale)
	if cell.vars[1] and cell.vars[2] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1].."/"..cell.vars[2]..(cell.vars[4] and cell.vars[4] ~= 0 and (" M"..cell.vars[4]) or "")
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.475*cam.zoom,cy-.1*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.5*cam.zoom,cy-.125*cam.zoom,40,"center",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[1] and cell.vars[2] and fancy and absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = cell.vars[1].."/"..cell.vars[2]..(cell.vars[4] and cell.vars[4] ~= 0 and (" M"..cell.vars[4]) or "")
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.475*20*scale,cy-.1*20*scale,40,"center",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.5*20*scale,cy-.125*20*scale,40,"center",0,20*scale/40,20*scale/40)
	end
end

function DrawPartialConverter(cell,cx,cy,crot,fancy,scale)
	DrawStoredCell(cell,cx,cy,crot,fancy,scale)
	if cell.vars[3] and cell.vars[4] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = (cell.vars[4]-1).."/"..cell.vars[3]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.575*cam.zoom,cy+.225*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.6*cam.zoom,cy+.2*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
	elseif cell.vars[3] and cell.vars[4] and fancy and scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		local text = (cell.vars[4]-1).."/"..cell.vars[3]
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(text,cx-.575*20*scale,cy+.225*20*scale,40,"right",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.printf(text,cx-.6*20*scale,cy+.2*20*scale,40,"right",0,20*scale/40,20*scale/40)
	end
end

function DrawParticleIcon(cell,cx,cy,crot,fancy,scale)
	DrawBasic(GetTex(cell.id),cx,cy,0,fancy,scale)
end

MergeIntoInfo("afterdraw", {
	[165]=DrawStoredCell,[175]=DrawStoredCell,[198]=DrawStoredCell,[211]=DrawStoredCell,[212]=DrawStoredCell,
	[235]=DrawStoredCell,[362]=DrawStoredCell,[425]=DrawStoredCell,[426]=DrawStoredCell,[427]=DrawStoredCell,
	[737]=DrawStoredCell,[738]=DrawStoredCell,[739]=DrawStoredCell,[740]=DrawStoredCell,[742]=DrawStoredCell,
	[743]=DrawStoredCell,[744]=DrawStoredCell,[704]=DrawStoredCell,[821]=DrawStoredCell,[822]=DrawStoredCell,
	[823]=DrawStoredCell,[831]=DrawStoredCell,[905]=DrawStoredCell,[918]=DrawStoredCell,[1043]=DrawStoredCell,
	[1150]=DrawStoredCell,[1151]=DrawStoredCell,
	[166]=DrawStoredMemory,[341]=DrawStoredMemory,[652]=DrawStoredMemory,[653]=DrawStoredMemory,[761]=DrawStoredMemory,
	[762]=DrawStoredMemory,[1088]=DrawStoredMemory,
	[526]=DrawStoredMaker,[527]=DrawStoredMaker,[528]=DrawStoredMaker,[529]=DrawStoredMaker,[530]=DrawStoredMaker,
	[531]=DrawStoredMaker,[532]=DrawStoredMaker,[533]=DrawStoredMaker,[534]=DrawStoredMaker,
	[1050]=DrawStoredMaker,[1051]=DrawStoredMaker,[1052]=DrawStoredMaker,[1053]=DrawStoredMaker,[1054]=DrawStoredMaker,
	[1055]=DrawStoredMaker,[1056]=DrawStoredMaker,[1057]=DrawStoredMaker,[1058]=DrawStoredMaker,
	[1059]=DrawStoredMaker,[1060]=DrawStoredMaker,[1061]=DrawStoredMaker,[1062]=DrawStoredMaker,[1063]=DrawStoredMaker,
	[1064]=DrawStoredMaker,[1065]=DrawStoredMaker,[1066]=DrawStoredMaker,[1067]=DrawStoredMaker,
	[1068]=DrawStoredMaker,[1069]=DrawStoredMaker,[1070]=DrawStoredMaker,[1071]=DrawStoredMaker,[1072]=DrawStoredMaker,
	[1073]=DrawStoredMaker,[1074]=DrawStoredMaker,[1075]=DrawStoredMaker,[1076]=DrawStoredMaker,
	[233]=DrawStoredFilter,[601]=DrawStoredFilter,
	[222]=DrawSmallNumber,[224]=DrawSmallNumber,[318]=DrawSmallNumber,[320]=DrawSmallNumber,[453]=DrawSmallNumber,[455]=DrawSmallNumber,
	[589]=DrawSmallNumber,[590]=DrawSmallNumber,[591]=DrawSmallNumber,[592]=DrawSmallNumber,[593]=DrawSmallNumber,[594]=DrawSmallNumber,
	[595]=DrawSmallNumber,[596]=DrawSmallNumber,[614]=DrawSmallNumber,[644]=DrawSmallNumber,[796]=DrawSmallNumber,[797]=DrawSmallNumber,
	[798]=DrawSmallNumber,[799]=DrawSmallNumber,[804]=DrawSmallNumber,[805]=DrawSmallNumber,[806]=DrawSmallNumber,[807]=DrawSmallNumber,
	[1084]=DrawSmallNumber,[1100]=DrawSmallNumber,[1101]=DrawSmallNumber,[1102]=DrawSmallNumber,[1103]=DrawSmallNumber,
	[1104]=DrawSmallNumber,[1105]=DrawSmallNumber,[1106]=DrawSmallNumber,[1107]=DrawSmallNumber,[1108]=DrawSmallNumber,
	[1155]=DrawSmallNumber,[1157]=DrawSmallNumber,[1158]=DrawSmallNumber,[1159]=DrawSmallNumber,[1163]=DrawSmallNumber,
	[299]=DrawSmallNumberWithZero,[402]=DrawSmallNumberWithZero,[412]=DrawSmallNumberWithZero,[563]=DrawSmallNumberWithZero,
	[564]=DrawSmallNumberWithZero,[565]=DrawSmallNumberWithZero,[566]=DrawSmallNumberWithZero,[583]=DrawSmallNumberWithZero,
	[908]=DrawSmallNumberWithZero,[909]=DrawSmallNumberWithZero,
	[1167]=DrawBigNumber,[1168]=DrawBigNumber,[1169]=DrawBigNumber,[1170]=DrawBigNumber,
	[1187]=DrawBigNumberWithZero,[1189]=DrawBigNumberWithZero,[1197]=DrawBigNumberWithZero,
	[645]=DrawStoredCellWithNumber,[1154]=DrawStoredCellWithNumber,
	[221]=DrawPortalIDs,
	[668]=DrawFraction,[669]=DrawFraction,[1188]=DrawFraction,[1190]=DrawFraction,[1193]=DrawFraction,[1198]=DrawFraction,
	[1091]=DrawComma,[1092]=DrawComma,[1093]=DrawComma,[1094]=DrawComma,[1095]=DrawComma,
	[1096]=DrawComma,[1097]=DrawComma,[1098]=DrawComma,[1099]=DrawComma,
	[352]=DrawAdjustableMover,[353]=DrawAdjustableMover,[354]=DrawAdjustableMover,[355]=DrawAdjustableMover,[356]=DrawAdjustableMover,[357]=DrawAdjustableMover,
	[1083]=DrawPartialConverter,
	[1085]=DrawSmallFraction,
	[1133]=DrawParticleIcon,[1134]=DrawParticleIcon,[1135]=DrawParticleIcon,[1136]=DrawParticleIcon,[1137]=DrawParticleIcon,[1138]=DrawParticleIcon,
	[1139]=DrawParticleIcon,[1140]=DrawParticleIcon,[1141]=DrawParticleIcon,[1142]=DrawParticleIcon,[1143]=DrawParticleIcon,[1144]=DrawParticleIcon,
	[1145]=DrawParticleIcon,[1146]=DrawParticleIcon,[1147]=DrawParticleIcon,[1148]=DrawParticleIcon,[1149]=DrawParticleIcon,
	[206]=function(cell,cx,cy,crot,fancy,scale)
		if fancy then
			UpdateShader(cell,cx,cy,crot,fancy,scale)
			local texture=GetTex("lluea"..cell.vars[2].."l").normal
			local texsize=GetTex("lluea"..cell.vars[2].."l").size
			love.graphics.draw(texture,cx,cy,crot,cam.zoom/texsize.w*scale,cam.zoom/texsize.h*scale,texsize.w2,texsize.h2)
			texture = GetTex("lluea"..cell.vars[3].."r").normal
			texsize = GetTex("lluea"..cell.vars[3].."r").size
			love.graphics.draw(texture,cx,cy,crot,cam.zoom/texsize.w*scale,cam.zoom/texsize.h*scale,texsize.w2,texsize.h2)
			love.graphics.setShader()
		end
	end,
	[351]=function(cell,cx,cy,crot,fancy,scale)
		if fancy and #cell.vars >= 5 then
			UpdateShader(cell,cx,cy,crot,fancy,scale)
			local texture = GetTex("omnicell_r"..cell.vars[1])
			local texsize = texture.size
			DrawBasic(GetTex("omnicell_r"..cell.vars[1]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_d"..cell.vars[2]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_l"..cell.vars[3]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_u"..cell.vars[4]),cx,cy,crot,fancy,scale)
			love.graphics.setShader()
			if scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
				love.graphics.printf(cell.vars[5],cx-.475*cam.zoom,cy-.225*cam.zoom,20,"center",0,cam.zoom/20,cam.zoom/20)
			elseif absolutedraw and rendercelltext then
				love.graphics.printf(cell.vars[5],cx-.475*20*scale,cy-.225*20*scale,20,"center",0,20*scale/20,20*scale/20)
			end
		end
	end,
	[552]=function(cell,cx,cy,crot,fancy,scale)
		if fancy and #cell.vars >= 27 then
			UpdateShader(cell,cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_r"..cell.vars[1]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_d"..cell.vars[2]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_l"..cell.vars[3]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_u"..cell.vars[4]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_dr"..cell.vars[17]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_dl"..cell.vars[18]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_ul"..cell.vars[19]),cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("omnicell_ur"..cell.vars[20]),cx,cy,crot,fancy,scale)
			if cell.vars[21] == 1 then
				DrawBasic(GetTex("omnicell_move_r1"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[22] == 1 then
				DrawBasic(GetTex("omnicell_move_d1"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[23] == 1 then
				DrawBasic(GetTex("omnicell_move_l1"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[24] == 1 then
				DrawBasic(GetTex("omnicell_move_u1"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[6] == 1 then
				DrawBasic(GetTex("omnicell_push"),cx,cy,crot,fancy,scale)
			elseif cell.vars[6] == 2 then
				DrawBasic(GetTex("omnicell_nudge"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[7] == 1 then
				DrawBasic(GetTex("omnicell_pull"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[8] == 1 then
				DrawBasic(GetTex("omnicell_grab"),cx,cy,crot,fancy,scale)
			elseif cell.vars[8] == 2 then
				DrawBasic(GetTex("omnicell_shove"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[9] == 1 then
				DrawBasic(GetTex("omnicell_drill"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[10] == 1 then
				DrawBasic(GetTex("omnicell_slice"),cx,cy,crot,fancy,scale)
			end
			if cell.vars[25] ~= 0 then
				DrawBasic(GetTex("omnicell_rot"..cell.vars[25]),cx,cy,crot,fancy,scale)
			end
			love.graphics.setShader()
			if scale == 1 and cell.vars.paint ~= "s" and rendercelltext then
				love.graphics.printf((cell.vars[11] == 0 and "inf" or cell.vars[11])..(cell.vars[27] == 0 and "" or "+"..cell.vars[27]).."/"..cell.vars[12],cx-.2885*cam.zoom,cy+.1885*cam.zoom,50,"left",0,cam.zoom/80,cam.zoom/80)
				if cell.vars[6] ~= 0 or cell.vars[7] == 1 or cell.vars[8] ~= 0 or cell.vars[9] == 1 or cell.vars[10] == 1 then
					love.graphics.printf("M"..(cell.vars[13] == 0 and "" or cell.vars[13]).."/"..(cell.vars[14] == 0 and "" or cell.vars[14]).."/"..(cell.vars[15] == 0 and "" or cell.vars[15]),cx-.2885*cam.zoom,cy-.3*cam.zoom,80,"left",0,cam.zoom/80,cam.zoom/80)
					love.graphics.printf(cell.vars[5],cx-.0125*cam.zoom,cy+.1885*cam.zoom,25,"right",0,cam.zoom/80,cam.zoom/80)
				else
					love.graphics.printf(cell.vars[5],cx-.475*cam.zoom,cy-.225*cam.zoom,20,"center",0,cam.zoom/20,cam.zoom/20)
				end
			elseif absolutedraw and cell.vars.paint ~= "s" and rendercelltext then
				love.graphics.printf((cell.vars[11] == 0 and "inf" or cell.vars[11])..(cell.vars[27] == 0 and "" or "+"..cell.vars[27]).."/"..cell.vars[12],cx-.2885*20*scale,cy+.1885*20*scale,50,"left",0,20*scale/80,20*scale/80)
				if cell.vars[6] ~= 0 or cell.vars[7] == 1 or cell.vars[8] ~= 0 or cell.vars[9] == 1 or cell.vars[10] == 1 then
					love.graphics.printf("M"..(cell.vars[13] == 0 and "" or cell.vars[13]).."/"..(cell.vars[14] == 0 and "" or cell.vars[14]).."/"..(cell.vars[15] == 0 and "" or cell.vars[15]),cx-.2885*20*scale,cy-.3*20*scale,80,"left",0,20*scale/80,20*scale/80)
					love.graphics.printf(cell.vars[5],cx-.0125*20*scale,cy+.1885*20*scale,25,"right",0,20*scale/80,20*scale/80)
				else
					love.graphics.printf(cell.vars[5],cx-.475*20*scale,cy-.225*20*scale,20,"center",0,20*scale/20,20*scale/20)
				end
			end
		end
	end,
	[819] = function(cell,cx,cy,crot,fancy,scale)
		if type(cell.vars.paint) == "number" and cell.vars.paint > 0 then
			local r,g,b,a = love.graphics.getColor()
			love.graphics.setColor(1,1,1,a)
			local texture = GetTex("laser_white"..(cell.crossed and "_cross" or ""))
			local texsize = texture.size
			love.graphics.draw(texture.normal,cx,cy,crot,cam.zoom/texsize.w*scale,cam.zoom/texsize.h*scale,texsize.w2,texsize.h2)
			love.graphics.setColor(r,g,b,a)
		elseif type(cell.vars.paint) == "number" and cell.vars.paint < 0  then
			local r,g,b,a = love.graphics.getColor()
			love.graphics.setColor(0,0,0,a)
			local texture = GetTex("laser_white"..(cell.crossed and "_cross" or ""))
			local texsize = texture.size
			love.graphics.draw(texture.normal,cx,cy,crot,cam.zoom/texsize.w*scale,cam.zoom/texsize.h*scale,texsize.w2,texsize.h2)
			love.graphics.setColor(r,g,b,a)
		end
	end,
	[846] = function(cell,cx,cy,crot,fancy,scale)
		if cell.vars[1] then
			UpdateShader(cell,cx,cy,crot,fancy,scale)
			DrawBasic(GetTex("spyoverlay"),cx,cy,crot,fancy,scale)
			love.graphics.setShader()
		end
	end,
})
function AfterDraw(cell,cx,cy,crot,fancy,scale)
	return GetAttribute(cell.id,"afterdraw",cell,cx,cy,crot,fancy,scale)
end

function DrawBasic(texture,cx,cy,crot,fancy,scale,xmult,ymult)
	if not absolutedraw and rendercelltext then 
		local texsize = texture.size
		love.graphics.draw(texture.normal,cx,cy,crot,cam.zoom/texsize.w*scale*(xmult or 1),cam.zoom/texsize.h*scale*(ymult or 1),texsize.w2,texsize.h2)
	else
		local texsize = texture.size
		love.graphics.draw(texture.normal,cx,cy,crot,scale,scale,texsize.w2,texsize.h2)
	end
end

function DrawEffects(cell,cx,cy,crot,fancy,scale)
	if cell.vars.spiked then DrawBasic(GetTex("spiked"),cx,cy,crot,fancy,scale) end
	if cell.vars.gooey then DrawBasic(GetTex("gooey"),cx,cy,crot,fancy,scale) end
	if cell.vars.petrified then DrawBasic(GetTex("petrified"),cx,cy,crot,fancy,scale) end
	if cell.vars.input and cell.clicked then DrawBasic(GetTex("inputclicked"),cx,cy,0,fancy,scale)
	elseif cell.vars.input then DrawBasic(GetTex("inputfrozen"),cx,cy,0,fancy,scale)
	elseif cell.frozen then DrawBasic(GetTex("frozen"),cx,cy,0,fancy,scale) end
	if cell.thawed then DrawBasic(GetTex("thawed"),cx,cy,0,fancy,scale) end
	if cell.vars.armored then DrawBasic(GetTex("armored"),cx,cy,0,fancy,scale)
	elseif cell.protected then DrawBasic(GetTex("protected"),cx,cy,0,fancy,scale) end
	if cell.vars.bolted then DrawBasic(GetTex("bolted"),cx,cy,0,fancy,scale)
	elseif cell.locked then DrawBasic(GetTex("locked"),cx,cy,0,fancy,scale) end
	if cell.vars.pushpermaclamped then DrawBasic(GetTex("permaclamp-push"),cx,cy,0,fancy,scale)
	elseif cell.pushclamped then DrawBasic(GetTex("clamp-push"),cx,cy,0,fancy,scale) end
	if cell.vars.pullpermaclamped then DrawBasic(GetTex("permaclamp-pull"),cx,cy,0,fancy,scale)
	elseif cell.pullclamped then DrawBasic(GetTex("clamp-pull"),cx,cy,0,fancy,scale) end
	if cell.vars.grabpermaclamped then DrawBasic(GetTex("permaclamp-grab"),cx,cy,0,fancy,scale)
	elseif cell.grabclamped then DrawBasic(GetTex("clamp-grab"),cx,cy,0,fancy,scale) end
	if cell.vars.swappermaclamped then DrawBasic(GetTex("permaclamp-swap"),cx,cy,0,fancy,scale)
	elseif cell.swapclamped then DrawBasic(GetTex("clamp-swap"),cx,cy,0,fancy,scale) end
	if cell.vars.scissorpermaclamped then DrawBasic(GetTex("permaclamp-scissor"),cx,cy,0,fancy,scale)
	elseif cell.scissorclamped then DrawBasic(GetTex("clamp-scissor"),cx,cy,0,fancy,scale) end
	if cell.vars.tunnelpermaclamped then DrawBasic(GetTex("permaclamp-tunnel"),cx,cy,0,fancy,scale)
	elseif cell.tunnelclamped then DrawBasic(GetTex("clamp-tunnel"),cx,cy,0,fancy,scale) end
	if cell.sticky == 1 then DrawBasic(GetTex("sticky"),cx,cy,0,fancy,scale)
	elseif cell.sticky == 2 then DrawBasic(GetTex("viscous"),cx,cy,0,fancy,scale) end
	if cell.vars.gravdir then DrawBasic(GetTex("grav"..cell.vars.gravdir),cx,cy,0,fancy,scale) end
	if cell.vars.timeimpulseright then DrawBasic(GetTex("timeimp_r"),cx,cy,0,fancy,scale) end
	if cell.vars.timeimpulseleft then DrawBasic(GetTex("timeimp_l"),cx,cy,0,fancy,scale) end
	if cell.vars.timeimpulseup then DrawBasic(GetTex("timeimp_u"),cx,cy,0,fancy,scale) end
	if cell.vars.timeimpulsedown then DrawBasic(GetTex("timeimp_d"),cx,cy,0,fancy,scale) end
	if cell.vars.timerepulseright then DrawBasic(GetTex("timerep_r"),cx,cy,0,fancy,scale) end
	if cell.vars.timerepulseleft then DrawBasic(GetTex("timerep_l"),cx,cy,0,fancy,scale) end
	if cell.vars.timerepulseup then DrawBasic(GetTex("timerep_u"),cx,cy,0,fancy,scale) end
	if cell.vars.timerepulsedown then DrawBasic(GetTex("timerep_d"),cx,cy,0,fancy,scale) end
	if cell.vars.perpetualrot then DrawBasic(GetTex("perpetualrot"..cell.vars.perpetualrot),cx,cy,0,fancy,scale) end
	if cell.vars.compelled then DrawBasic(GetTex("compelled"..cell.vars.compelled),cx,cy,crot,fancy,scale) end
	if cell.vars.tag == 1 then DrawBasic(GetTex("tag_enemy"),cx,cy,crot,fancy,scale)
	elseif cell.vars.tag == 2 then DrawBasic(GetTex("tag_ally"),cx,cy,crot,fancy,scale)
	elseif cell.vars.tag == 3 then DrawBasic(GetTex("tag_player"),cx,cy,crot,fancy,scale) end
	if cell.vars.ghostified == 1 then DrawBasic(GetTex("ghostified"),cx,cy,crot,fancy,scale)
	elseif cell.vars.ghostified == 2 then DrawBasic(GetTex("ungeneratable"),cx,cy,crot,fancy,scale) end
	if cell.vars.coins and scale == 1 and rendercelltext then
		DrawBasic(GetTex("coins"),cx,cy,0,fancy,scale)
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.print(cell.vars.coins,cx-.175*cam.zoom,cy-.1125*cam.zoom,0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.print(cell.vars.coins,cx-.2*cam.zoom,cy-.1375*cam.zoom,0,cam.zoom/40,cam.zoom/40)
	end
	if cell.vars.coins and absolutedraw and rendercelltext then
		DrawBasic(GetTex("coins"),cx,cy,0,fancy,scale)
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.print(cell.vars.coins,cx-.175*20*scale,cy-.1125*20*scale,0,20*scale/40,20*scale/40)
		love.graphics.setColor(r,g,b,a)
		love.graphics.print(cell.vars.coins,cx-.2*20*scale,cy-.1375*20*scale,0,20*scale/40,20*scale/40)
	end
	if cell.vars.entangled and scale == 1 and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars.entangled,cx-.575*cam.zoom,cy-.375*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
		love.graphics.setColor(r*.75,g*.25,b,1)
		love.graphics.printf(cell.vars.entangled,cx-.6*cam.zoom,cy-.4*cam.zoom,40,"right",0,cam.zoom/40,cam.zoom/40)
	end
	if cell.vars.entangled and scale == 1 and rendercelltext then
		local r,g,b,a = love.graphics.getColor()
		love.graphics.setColor(0,0,0,a)
		love.graphics.printf(cell.vars.entangled,cx-.575*20*scale,cy-.375*20*scale,40,"right",0,20*scale/40,20*scale/40)
		love.graphics.setColor(r*.75,g*.25,b,1)
		love.graphics.printf(cell.vars.entangled,cx-.6*20*scale,cy-.4*20*scale,40,"right",0,20*scale/40,20*scale/40)
	end
	if cell.id ~= 0 and cell.rot ~= 0 and cell.rot ~= 1 and cell.rot ~= 2 and cell.rot ~= 3 then DrawBasic(GetTex("invalidrot"),cx,cy,0,fancy,scale) end
end

function TransformScreenPos(cx,cy,cell,x,y,interpolate,alpha,scale,meta)
	return cx,cy
end

function UpdateShader(cell,cx,cy,crot,fancy,scale)
	local r,g,b,alpha = love.graphics.getColor()
	if not cell.vars.paint or not fancy then
		love.graphics.setShader()
	elseif type(cell.vars.paint) == "number" then
		local shader = cell.vars.paint < 0 and shaders.invertcolor or shaders.color
		shader:send("red",math.floor(math.abs(cell.vars.paint)/65536)/255)
		shader:send("green",math.floor(math.abs(cell.vars.paint)%65536/256)/255)
		shader:send("blue",math.abs(cell.vars.paint)%256/255)
		shader:send("alpha",alpha)
		love.graphics.setShader(cell.vars.paint < 0 and shaders.invertcolor or shaders.color)
	elseif cell.vars.paint == "i" then
		shaders.invert:send("alpha",alpha)
		love.graphics.setShader(shaders.invert)
	elseif cell.vars.paint:sub(1,1) == "H" then
		shaders.hsv:send("hue",tonumber(cell.vars.paint:sub(2,string.find(cell.vars.paint,"S")-1)))
		shaders.hsv:send("sat",tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"S")+1,string.find(cell.vars.paint,"V")-1))/100)
		shaders.hsv:send("val",tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"V")+1,#cell.vars.paint))/100)
		shaders.hsv:send("invert",0)
		shaders.hsv:send("alpha",alpha)
		love.graphics.setShader(shaders.hsv)
	elseif cell.vars.paint:sub(1,1) == "h" then
		shaders.hsv:send("hue",tonumber(cell.vars.paint:sub(2,string.find(cell.vars.paint,"s")-1)))
		shaders.hsv:send("sat",tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"s")+1,string.find(cell.vars.paint,"v")-1))/100)
		shaders.hsv:send("val",tonumber(cell.vars.paint:sub(string.find(cell.vars.paint,"v")+1,#cell.vars.paint))/100)
		shaders.hsv:send("invert",1)
		shaders.hsv:send("alpha",alpha)
		love.graphics.setShader(shaders.hsv)
	elseif cell.vars.paint:sub(1,1) == "s" then
		shaders.shadow:send("alpha",alpha)
		love.graphics.setShader(shaders.shadow)
	end
end

function UpdateBlending(cell,cx,cy,crot,fancy,scale)
	if not cell.vars.blending or not fancy then
		love.graphics.setBlendMode("alpha","alphamultiply")
	elseif cell.vars.blending == 1 then
		love.graphics.setCanvas()
		love.graphics.setBlendMode("add")
	elseif cell.vars.blending == 2 then
		love.graphics.setCanvas()
		love.graphics.setBlendMode("subtract")
	elseif cell.vars.blending == 3 then
		love.graphics.setCanvas()
		love.graphics.setBlendMode("multiply","premultiplied")
	elseif cell.vars.blending == 4 then
		love.graphics.setCanvas()
		love.graphics.setBlendMode("screen")
	elseif cell.vars.blending == 5 then
		love.graphics.setCanvas()
		love.graphics.setBlendMode("lighten","premultiplied")
	elseif cell.vars.blending == 6 then
		love.graphics.setCanvas()
		love.graphics.setBlendMode("darken","premultiplied")
	end
end

function DrawCell(cell,x,y,interpolate,alpha,scale,meta)
	local cx,cy,crot
	local lerp = itime/delay
	interpolate = interpolate
	if not forcespread[cell.vars.forceinterp] then cell.vars.forceinterp = nil end
	if cell.vars.forceinterp then
		local force = forcespread[cell.vars.forceinterp]
		cx,cy,crot = math.floor(force.x*cam.zoom-cam.x+cam.zoom*.5+400*winxm),math.floor(force.y*cam.zoom-cam.y+cam.zoom*.5+300*winym),force.rot*math.halfpi
	elseif interpolate then
		cx,cy,crot = math.floor(math.graphiclerp(cell.lastvars[1],x,lerp)*cam.zoom-cam.x+cam.zoom*.5+400*winxm),math.floor(math.graphiclerp(cell.lastvars[2],y,lerp)*cam.zoom-cam.y+cam.zoom*.5+300*winym),math.graphiclerp(cell.rot-cell.lastvars[3],cell.rot,lerp)*math.halfpi%(math.pi*2)
	else
		cx,cy,crot = math.floor(x*cam.zoom-cam.x+cam.zoom*.5+400*winxm),math.floor(y*cam.zoom-cam.y+cam.zoom*.5+300*winym),cell.rot*math.halfpi
	end
	local canv = love.graphics.getCanvas()
	scale,alpha = scale or 1,alpha or 1
	cx,cy = TransformScreenPos(cx,cy,cell,x,y,interpolate,alpha,scale,meta)
	if currentsst == cell then
		drawsst = {x=cx,y=cy}
		anysst = true
	end
	if cell.id ~= 0 and cell.vars.paint ~= "I" then 
		local fancy = fancy
		if x == math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom) and y == math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom) then
			fancy = true
		end
		love.graphics.setColor(1,1,1,alpha)
		UpdateShader(cell,cx,cy,crot,fancy,scale)
		UpdateBlending(cell,cx,cy,crot,fancy,scale)
		local texname = GetDrawTexture(cell,cx,cy,crot,fancy,scale)
		if cell.id == 708 and richtexts[x+y*width] then
			love.graphics.setBlendMode("alpha","alphamultiply")
			love.graphics.setShader()
			richtexts[x+y*width].update()
			love.graphics.draw(richtexts[x+y*width].text,cx,cy,crot,cam.zoom/20,cam.zoom/20,4,5,richtexts[x+y*width].italic and -0.25 or 0)
			love.graphics.setCanvas(canv)
			return
		end
		local xmult = xScaleMult(cell,cx,cy,crot,fancy,scale)
		local ymult = yScaleMult(cell,cx,cy,crot,fancy,scale)
		crot = DrawRot(cell,cx,cy,crot,fancy,scale)
		DrawBasic(GetTex(texname),cx,cy,crot,fancy,scale,xmult,ymult)
		love.graphics.setShader()
		AfterDraw(cell,cx,cy,crot,fancy,scale)
		if fancy and cell.vars.paint ~= "s" then DrawEffects(cell,cx,cy,crot,fancy,scale) end
		if interpolate and isinitial and x and GetLayer(cell.id) == 0 then
			if GetPlaceable(x,y) and tex[GetOverlay(GetPlaceable(x,y))] then
				local texture = tex[GetOverlay(GetPlaceable(x,y))]
				if texture then
					local texsize = texture.size
					love.graphics.draw(texture.normal,cx,cy,0,cam.zoom/texsize.w,cam.zoom/texsize.h,texsize.w2,texsize.h2)
				end
			end
		end
	end
	if meta ~= 10 and fancy and interpolate and lerp < 1 then
		for i=1,#(cell.eatencells or {}) do
			local ecell = cell.eatencells[i]
			if ecell.id ~= 0 and ecell ~= cell then 
				DrawCell(ecell,cell.id == 0 and x or 
				math.lerp(cell.lastvars[1],x,lerp),cell.id == 0 and y or 
				math.lerp(cell.lastvars[2],y,lerp),true,alpha,
				math.lerp(scale,0,lerp),(meta or 0) + 1)
			end
		end
	end
	love.graphics.setCanvas(canv)
	love.graphics.setBlendMode("alpha","alphamultiply")
	love.graphics.setShader()
	if dodebug and cell.testvar then
		love.graphics.print(tostring(cell.testvar),cx,cy)
	end
end

function DrawAbsoluteCell(cell,x,y,interpolate,alpha,scale)
    local cx, cy = math.floor(x), math.floor(y)
    local crot = cell.rot * math.halfpi

    scale, alpha = scale or 1, alpha or 1

    local canv = love.graphics.getCanvas()
	local before = absolutedraw
	absolutedraw = true

    if cell.id ~= 0 and cell.vars.paint ~= "I" then
        love.graphics.setColor(1, 1, 1, alpha)

        UpdateShader(cell,cx,cy,crot,fancy,drawWidth)
        UpdateBlending(cell,cx,cy,crot,fancy,drawWidth)

        local texname = GetDrawTexture(cell,cx,cy,crot,fancy,drawWidth)

        if cell.id == 708 and richtexts[x + y * width] then
            love.graphics.setBlendMode("alpha", "alphamultiply")
            love.graphics.setShader()
            richtexts[x + y * width].update()
            love.graphics.draw(richtexts[x + y * width].text,cx,cy,crot,drawWidth,drawHeight,4,5,richtexts[x + y * width].italic and -0.25 or 0)
            love.graphics.setCanvas(canv)
            return
        end

        crot = DrawRot(cell,cx,cy,crot,fancy,scale)
        DrawBasic(GetTex(texname),cx,cy,crot,fancy,scale)

        love.graphics.setShader()
        AfterDraw(cell,cx,cy,crot,fancy,scale)
        if cell.vars.paint ~= "s" then DrawEffects(cell,cx,cy,crot,fancy,scale) end
    end

    love.graphics.setCanvas(canv)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setShader()
	absolutedraw = before
end

function GetDrawBounds(off, bg)
	if not recording then
		return math.max(math.floor((cam.x-400*winxm)/cam.zoom),off),
		math.min(math.floor((cam.x+400*winxm)/cam.zoom)+1,width-1-off),
		math.max(math.floor((cam.y-300*winym)/cam.zoom),off),
		math.min(math.floor((cam.y+300*winym)/cam.zoom)+1,height-1-off),
		"rightdown"
	else
		return math.max(math.floor((cam.x-cam.zoom)/cam.zoom),off),
		math.min(math.floor((cam.x+recorddata.canvas:getWidth()+cam.zoom)/cam.zoom)+1,width-1-off),
		math.max(math.floor((cam.y-cam.zoom)/cam.zoom),off),
		math.min(math.floor((cam.y+recorddata.canvas:getHeight()+cam.zoom)/cam.zoom)+1,height-1-off),
		"rightdown"
	end
end

	
CELLCOL = {1,1,1}
function DrawGrid()
	if love.graphics.getWidth() ~= cellcanv:getWidth() or love.graphics.getHeight() ~= cellcanv:getHeight() then
		cellcanv:release()
		cellcanv = love.graphics.newCanvas(love.graphics.getWidth(),love.graphics.getHeight())
	end
	local texture
	local texsize
	if cam.zoom <= 8 then
		bgcolor[4] = bgcolor[4] or 1
		love.graphics.setColor(bgcolor[1] * CELLCOL[1], bgcolor[2] * CELLCOL[2], bgcolor[3] * CELLCOL[3], bgcolor[4])
		love.graphics.rectangle("fill",math.floor(cam.zoom-cam.x+400*winxm)+.49,math.floor(cam.zoom-cam.y+300*winym)+.49,(width-2)*cam.zoom,(height-2)*cam.zoom)
	end
	love.graphics.setColor(CELLCOL)
	local startx,endx,starty,endy = GetDrawBounds(1, true)
	local gcanvas = recording and recorddata.canvas or nil
	love.graphics.setCanvas(gcanvas)
	if recording then love.graphics.clear(voidcolor) end
	for y=starty,endy do
		for x=startx,endx do
			local p = GetPlaceable(x,y) or 0
			love.graphics.setShader()
			love.graphics.setBlendMode("alpha", "alphamultiply")
			if p == "bgvoid" then
				if cam.zoom <= 8 then
					love.graphics.setColor(voidcolor)
					local cx,cy = math.floor(x*cam.zoom-cam.x+400*winxm)+.49,math.floor(y*cam.zoom-cam.y+300*winym)+.49
					love.graphics.rectangle("fill",cx,cy,cam.zoom,cam.zoom)
				end
			elseif (cam.zoom > 8 or p ~= 0) then
				love.graphics.setColor(CELLCOL)
				local cx,cy = math.floor(x*cam.zoom-cam.x+cam.zoom*.5+400*winxm)+.49,math.floor(y*cam.zoom-cam.y+cam.zoom*.5+300*winym)+.49
				local pt = {id=p}
				texture = GetTex(GetDrawTexture(pt,x,y,0,fancy,1),"Xbg")
				texsize = texture.size
				love.graphics.draw(texture.normal,cx,cy,DrawRot(pt,x,y,0),
				math.ceil(cam.zoom)/texsize.w*xScaleMult(pt,x,y,0),
				math.ceil(cam.zoom)/texsize.h*yScaleMult(pt,x,y,0),texsize.w2,texsize.h2)
			end
		end
	end
	love.graphics.setCanvas(cellcanv)
	love.graphics.setShader()
	if not persistentcanv then love.graphics.clear() end
	for z=0,depth-1 do
		local startx,endx,starty,endy,drawdir = GetDrawBounds(z == 0 and 0 or 1)
		anysst = false
		RunOn(function(c) return c.id ~= 0 end,
			function(x,y,c)
				DrawCell(c,x,y,true)
			end
			,drawdir,"all",z,startx,endx,starty,endy,z == 0)()
		if anysst then
			love.graphics.setColor(1, 1, 1)
			love.graphics.rectangle("line", drawsst.x-cam.zoom/2, drawsst.y-cam.zoom/2, cam.zoom, cam.zoom)
		end
		for i,force in ipairs(forcespread) do -- edge case crappery
			if overallcount >= force.revealtick and force.forcetype == "push" then
				DrawCell(force.drawcell,force.x,force.y,false)
			end
		end
		for i,force in ipairs(forcespread) do
			local x,y,rot = force.x, force.y, force.rot
			local cx,cy,crot
			local lerp = itime/delay
			if true then
				cx,cy,crot = math.floor(math.graphiclerp(force.lx,force.x,lerp)*cam.zoom-cam.x+cam.zoom*.5+400*winxm),math.floor(math.graphiclerp(force.ly,force.y,lerp)*cam.zoom-cam.y+cam.zoom*.5+300*winym),math.graphiclerp(force.ldir,force.dir,lerp)*math.halfpi%(math.pi*2)
			else
				cx,cy,crot = math.floor(force.x*cam.zoom-cam.x+cam.zoom*.5+400*winxm),math.floor(force.y*cam.zoom-cam.y+cam.zoom*.5+300*winym),force.dir*math.halfpi
			end
			DrawBasic(GetTex("force"..force.forcetype),cx,cy,crot,fancy,1,1,1)
		end
	end
	love.graphics.setCanvas(gcanvas)
	love.graphics.setShader()
	if fancy then
		love.graphics.setColor(0,0,0,.25)
		love.graphics.draw(cellcanv,shadowdist*cam.zoom,shadowdist*cam.zoom)
	end
	love.graphics.setColor(1,1,1,1)
	love.graphics.draw(cellcanv,.49,.49)
	if fancy then
		for k,v in pairs(particles) do
			love.graphics.draw(v,math.floor(cam.zoom-cam.x+cam.zoom*.5)+400*winxm,math.floor(cam.zoom-cam.y+cam.zoom*.5)+300*winym,0,cam.zoom/cellsize,cam.zoom/cellsize,cellsize/2,cellsize/2)
		end
		for i=1,#fireworkparticles do
			local p = fireworkparticles[i]
			local cx,cy = math.floor(p.x*cam.zoom-cam.x+cam.zoom*.5+400*winxm)+.49,math.floor(p.y*cam.zoom-cam.y+cam.zoom*.5+300*winym)+.49
			local scale = math.sqrt(p.life)/3
			love.graphics.setColor(p.color)
			texture = GetTex("firework_glow")
			texsize = texture.size
			love.graphics.setBlendMode("add")
			love.graphics.draw(texture.normal,cx,cy,0,cam.zoom/texsize.w*scale,cam.zoom/texsize.h*scale,texsize.w2,texsize.h2)
			love.graphics.setColor(1,1,1,1)
			texture = GetTex("firework_white")
			texsize = texture.size
			love.graphics.draw(texture.normal,cx,cy,0,cam.zoom/texsize.w*scale*3/7,cam.zoom/texsize.h*scale*3/7,texsize.w2,texsize.h2)
			love.graphics.setBlendMode("alpha","alphamultiply")
		end
	end
	if draggedcell then
		local mx = (love.mouse.getX()+cam.x-400*winxm)/cam.zoom-.5
		local my = (love.mouse.getY()+cam.y-300*winym)/cam.zoom-.5
		DrawCell(draggedcell,mx,my,false)
	elseif pasting then
		love.graphics.setColor(1,1,1,.5)
		local mx = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
		local my = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
		for z=0,#copied do
			for y=0,#copied[0] do
				for x=0,#copied[0][0] do
					DrawCell(copied[z][y][x],x+mx,y+my,false,.5)
					if z == 0 and copied[-1][y][x] then
						local cx,cy = math.floor((mx+x)*cam.zoom-cam.x+cam.zoom*.5+400*winxm)+.49,math.floor((my+y)*cam.zoom-cam.y+cam.zoom*.5+300*winym)+.49
						local pt = {id=copied[-1][y][x]}
						texture = GetTex(GetDrawTexture(pt,x,y,0,fancy,1),"Xbg")
						texsize = texture.size
						love.graphics.draw(texture.normal,cx,cy,0,cam.zoom/texsize.w,cam.zoom/texsize.h,texsize.w2,texsize.h2)
					end
				end
			end
		end
		love.graphics.setColor(1,1,1,.25)
		love.graphics.rectangle("fill",(mx-.5)*cam.zoom-cam.x+cam.zoom*.5+400*winxm,(my-.5)*cam.zoom-cam.y+cam.zoom*.5+300*winym,#copied[0][0]*cam.zoom+cam.zoom,#copied[0]*cam.zoom+cam.zoom)
	elseif selection.on then
		love.graphics.setColor(1,1,1,.25)
		local cx,cy = math.floor((selection.x-.5)*cam.zoom-cam.x+cam.zoom*.5+400*winxm),math.floor((selection.y-.5)*cam.zoom-cam.y+cam.zoom*.5+300*winym)
		love.graphics.rectangle("fill",cx,cy,selection.w*cam.zoom,selection.h*cam.zoom)
	elseif not hoveredbutton and not puzzle then
		local mx = math.floor((love.mouse.getX()+cam.x-400*winxm)/cam.zoom)
		local my = math.floor((love.mouse.getY()+cam.y-300*winym)/cam.zoom)
		local cell = GetPlacedCell({id=chosen.id,rot=chosen.rot,lastvars={0,0,0}},true)
		for y=my-math.ceil(chosen.size*.5)+(chosen.shape == "Square" and 1 or 0),my+math.floor(chosen.size*.5) do
			for x=mx-math.ceil(chosen.size*.5)+(chosen.shape == "Square" and 1 or 0),mx+math.floor(chosen.size*.5) do
				if (chosen.shape == "Square" or math.distSqr(x-mx,y-my) <= chosen.size*chosen.size/4) and (chosen.mode ~= "Or" or GetCell(x,y).id == 0) and (chosen.mode ~= "And" or GetCell(x,y).id ~= 0) then
					DrawCell(cell,x,y,false,.25)
				end
			end
		end
	end
	if dodebug then
		love.graphics.setLineWidth(.5)
		love.graphics.setColor(1,0,0,.1)
		for i=1,maxchunksize do
			local size,invsize = 2^i,1/2^i
			for y=0,(height-1)*invsize do
				for x=0,(width-1)*invsize do
					if chunks[0][i][y][x].all then
						love.graphics.rectangle("fill",math.floor((x*size-.5)*cam.zoom-cam.x+cam.zoom*.5+400*winxm)+.5,math.floor((y*size-.5)*cam.zoom-cam.y+cam.zoom*.5+300*winym)+.5,1/invsize*cam.zoom,1/invsize*cam.zoom)
					end
				end
			end
		end
	end
	love.graphics.setColor(1,1,1,1)
	local y = moreui and 120 or 70
	for i=1,8 do
		if collectedkeys[i] then
			local t = GetTex("keycollectable"..i)
			local ts = t.size
			love.graphics.draw(t.normal,800*winxm-30*uiscale,y*uiscale,0,20/ts.w*uiscale,20/ts.h*uiscale,ts.w2,ts.h2)
			y = y + 11
		end
	end
end

function DrawMainMenu()
	if not mainmenu then
		DrawGrid()
		love.graphics.setColor(1,1,1,1)
		if recording then
			if recorddata.animation.usinginput then
				local keysize = math.ceil(math.min(recorddata.canvas:getWidth() / 10, recorddata.canvas:getHeight() / 10))
				local padding = keysize/4
				local kx, ky = keysize/2, recorddata.canvas:getHeight()-keysize*2.5-padding
				local curkey = tonumber(recorddata.animation.input:sub(overallcount+1, overallcount+1), 16) or 0
				love.graphics.setColor(0.7, 0.7, 0.7, curkey % 2 == 1 and 1 or 0.2)
				love.graphics.rectangle("fill", kx+keysize*2+padding*2, ky+keysize+padding, keysize, keysize) -- d
				love.graphics.setColor(0.3, 0.3, 0.3, curkey % 2 == 1 and 1 or 0.8)
				love.graphics.rectangle("line", kx+keysize*2+padding*2, ky+keysize+padding, keysize, keysize) -- d
				love.graphics.setColor(0.7, 0.7, 0.7, curkey % 4 >= 2 and 1 or 0.2)
				love.graphics.rectangle("fill", kx, ky+keysize+padding, keysize, keysize) -- a
				love.graphics.setColor(0.3, 0.3, 0.3, curkey % 4 >= 2 and 1 or 0.8)
				love.graphics.rectangle("line", kx, ky+keysize+padding, keysize, keysize) -- a
				love.graphics.setColor(0.7, 0.7, 0.7, curkey % 8 >= 4 and 1 or 0.2)
				love.graphics.rectangle("fill", kx+keysize+padding, ky, keysize, keysize) -- w
				love.graphics.setColor(0.3, 0.3, 0.3, curkey % 8 >= 4 and 1 or 0.8)
				love.graphics.rectangle("line", kx+keysize+padding, ky, keysize, keysize) -- w
				love.graphics.setColor(0.7, 0.7, 0.7, curkey >= 8 and 1 or 0.2)
				love.graphics.rectangle("fill", kx+keysize+padding, ky+keysize+padding, keysize, keysize) -- s
				love.graphics.setColor(0.3, 0.3, 0.3, curkey >= 8 and 1 or 0.8)
				love.graphics.rectangle("line", kx+keysize+padding, ky+keysize+padding, keysize, keysize) -- s
			end
			love.graphics.setColor(1,1,1,1)
			love.graphics.setCanvas()
			love.graphics.rectangle("line", 50, 50, recorddata.canvas:getWidth(), recorddata.canvas:getHeight())
			love.graphics.draw(recorddata.canvas, 50, 50)
			--love.graphics.print(quanta.dump(recorddata))
			local i = recorddata.animation.input or ""
			local ts, tm, te = "", "", ""
			local cs, cm, ce = "", "", ""
			for i,v in ipairs(recorddata.animation.ticks) do
				if i < recorddata.current then
					ts = ts..v.." "
				elseif i > recorddata.current + 2 then
					te = te..v.." "
				else
					tm = tm..v.." "
				end
			end
			for i,v in ipairs(recorddata.animation.camera) do
				if i < recorddata.current then
					cs = cs..v.." "
				elseif i > recorddata.current + 2 then
					ce = ce..v.." "
				else
					cm = cm..v.." "
				end
			end
			if overallcount > 0 then
				recorddata.canvas:newImageData():encode("png", "recording/"..recorddata.frame..".png")
				recorddata.frame = recorddata.frame + 1
				love.graphics.printf({
					{1, 1, 1}, "Frame "..recorddata.frame.." ("..string.format("%.02f", recorddata.timer).."s)"
							 .."\nGlobal tick ("..overallcount.."): "..ts, {0, 1, 1}, tm, {1, 1, 1}, te
							 .."\nCamera {"..string.format("%.02f", cam.x)..", "..string.format("%.02f", cam.y).."}: "..cs, {0, 1, 1}, cm, {1, 1, 1}, ce
							 .."\nController: "..i:sub(0, overallcount), {0, 1, 1}, i:sub(overallcount+1, overallcount+1), {1, 1, 1}, i:sub(overallcount+2, -1)
							 .."\n"..string.format("%.02f%%", (recorddata.animation.lerpdebug or 0) * 100)
							 .."\n"..(recorddata.debug or "")
				}, 50, 50 + recorddata.canvas:getHeight(), settings.window_width - 100, "left")
			else
				love.graphics.print("Waiting...", 50, 50 + recorddata.canvas:getHeight())
			end
			if love.keyboard.isDown("tab") then love.timer.sleep(0.5) end
		end
		lvltitle.update()
		lvldesc.update()
		if title ~= "" then love.graphics.draw(lvltitle.text,centerx,10*uiscale,0,2*uiscale,2*uiscale,500,0,lvltitle.italic and -0.25 or 0) end
		if subtitle ~= "" then love.graphics.draw(lvldesc.text,centerx,30*uiscale,0,uiscale,uiscale,150,0,lvldesc.italic and -0.25 or 0) end
	elseif mainmenu == "title" then
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(menuparticles,centerx,centery)
		local logosize = GetTex("logo").size
		love.graphics.draw(GetTex("logo").normal,centerx,centery-100*uiscale,math.sin(love.timer.getTime())/20,uiscale*450/logosize.w,uiscale*111/logosize.h,logosize.w2,logosize.h2)
		love.graphics.setColor(0,0,0,1)
		splash.update()
		version.update()
		if versiontxt ~= version.rawtext then SetRichText(version,versiontxt,400,"center") end
		local s = (math.sin(love.timer.getTime()*.777)/5+1.5)*uiscale
		love.graphics.draw(version.text,centerx-200*uiscale+uiscale,centery-math.sin(love.timer.getTime()/2)*5*uiscale+uiscale*11,0,uiscale,uiscale,btntitle.italic and -0.25 or 0,0)
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(version.text,centerx-200*uiscale,centery-math.sin(love.timer.getTime()/2)*5*uiscale+uiscale*10,0,uiscale,uiscale,btntitle.italic and -0.25 or 0,0)
		love.graphics.draw(splash.text,centerx+uiscale*150,centery-50,math.sin(love.timer.getTime()*.666)/15-.2,s,s,75,0,splash.italic and -0.25 or 0)
		--love.graphics.printf(splash,centerx+uiscale*150,centery-50,150,"center",math.sin(love.timer.getTime()*.666)/15-.2,s,s,75)
	else
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(menuparticles,centerx,centery)
	end
end

function DrawButtons()
	stallbtn = nil
	for i=1,#buttonorder do
		local b = buttons[buttonorder[i]]
		if b.currentenabled then
			if b == hoveredbutton then
				if love.mouse.isDown(1) then
					love.graphics.setColor(b.clickcolor)
				else
					love.graphics.setColor(b.hovercolor)
				end
			else	
				love.graphics.setColor(b.color)
			end
			local x,y
			local t = GetTex(get(b.icon))
			local ts = t.size
			if b.halign == -1 then
				x = b.cx*uiscale+ts.w2*b.cw*uiscale/ts.w
			elseif b.halign == 1 then
				x = love.graphics.getWidth()-b.cx*uiscale-ts.w2*b.cw*uiscale/ts.w
			else
				x = b.cx*uiscale+centerx
			end
			if b.valign == -1 then
				y = b.cy*uiscale+ts.h2*b.ch*uiscale/ts.h
			elseif b.valign == 1 then
				y = love.graphics.getHeight()-b.cy*uiscale-ts.h2*b.ch*uiscale/ts.h
			else
				y = b.cy*uiscale+centery
			end
			x,y = math.round(x),math.round(y)
			if b.predrawfunc then b.predrawfunc(x,y,b) end
			love.graphics.draw(t.normal,x,y,get(b.rot) or 0,b.cw/ts.w*uiscale,b.ch/ts.h*uiscale,ts.w2,ts.h2)
			if hoveredbutton == b and b.name then
				stallbtn = b
			end
			if b.drawfunc then b.drawfunc(x,y,b) end
		end
	end
end

function DrawPauseMenu()
	if inmenu == true and not winscreen and not mainmenu and not wikimenu then
		local skew = math.sin(love.timer.getTime()*1.3)/8
		love.graphics.setColor(rainbow(.25))
		local scale = math.lerp(2,2.1,math.sin(love.timer.getTime())+1)*uiscale
		love.graphics.printf("CelLua Machine Wiki Mod",centerx,centery-147*uiscale,100,"center",0,scale,2*uiscale,50,8,skew)
		love.graphics.setColor(rainbow(.5))
		local scale = math.lerp(2,2.075,math.sin(love.timer.getTime()-.2)+1)*uiscale
		love.graphics.printf("CelLua Machine Wiki Mod",centerx,centery-147*uiscale,100,"center",0,scale,2*uiscale,50,8,skew)
		love.graphics.setColor(rainbow(.75))
		local scale = math.lerp(2,2.05,math.sin(love.timer.getTime()-.4)+1)*uiscale
		love.graphics.printf("CelLua Machine Wiki Mod",centerx,centery-147*uiscale,100,"center",0,scale,2*uiscale,50,8,skew)
		love.graphics.setColor(1,1,1,.5)
		local scale = math.lerp(2,2.025,math.sin(love.timer.getTime()-.6)+1)*uiscale
		love.graphics.printf("CelLua Machine Wiki Mod",centerx,centery-147*uiscale,100,"center",0,scale,2*uiscale,50,8,skew)
		love.graphics.setColor(1,1,1,.75)
		local scale = math.lerp(2,2.01,math.sin(love.timer.getTime()-.6)+1)*uiscale
		love.graphics.printf("CelLua Machine Wiki Mod",centerx,centery-147*uiscale,100,"center",0,scale,2*uiscale,50,8,skew)
		love.graphics.setColor(1,1,1,1)
		love.graphics.printf("CelLua Machine Wiki Mod",centerx,centery-147*uiscale,100,"center",0,2*uiscale,2*uiscale,50,8,skew)
		love.graphics.setColor(0.5,0.5,0.5,1)
		if not level then
			love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,delay),centery-131.5*uiscale,4*uiscale,10*uiscale)
			love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,(tpu-1)/9),centery-109.5*uiscale,4*uiscale,10*uiscale)
		end
		if not puzzle then love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,(border-1)/(#bordercells-1)),centery-87.5*uiscale,4*uiscale,10*uiscale) end
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,volume),centery-65.5*uiscale,4*uiscale,10*uiscale)
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,sfxvolume),centery-43.5*uiscale,4*uiscale,10*uiscale)
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,(musicspeed-.5)*.66666),centery-21.5*uiscale,4*uiscale,10*uiscale)
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,(newuiscale-.5)*.66666),centery+.5,4*uiscale,10*uiscale)
		love.graphics.setColor(textcolor[1],textcolor[2],textcolor[3],1)
		if not level then
			love.graphics.print("Update delay: "..math.round(delay*100)/100 .."s",centerx-150*uiscale,300*winym-142*uiscale,0,uiscale,uiscale)
			love.graphics.print("Ticks per update: "..tpu,centerx-150*uiscale,300*winym-120*uiscale,0,uiscale,uiscale)
		end
		love.graphics.print("Music Volume: "..volume*100 .."%",centerx-150*uiscale,300*winym-76*uiscale,0,uiscale,uiscale)
		love.graphics.print("SFX Volume: "..sfxvolume*100 .."%",centerx-150*uiscale,300*winym-54*uiscale,0,uiscale,uiscale)
		love.graphics.print("Music Speed: "..musicspeed*100 .."%",centerx-150*uiscale,300*winym-32*uiscale,0,uiscale,uiscale)
		if not puzzle then
			love.graphics.print("Border: "..border.." ("..tostring(GetAttribute(bordercells[border],"name"))..")",centerx-150*uiscale,centery-98*uiscale,0,uiscale,uiscale)
			love.graphics.print("Width",centerx-100*uiscale,centery+38*uiscale,0,uiscale,uiscale)
			love.graphics.print("Height",centerx+50*uiscale,centery+38*uiscale,0,uiscale,uiscale)
			love.graphics.print(newwidth..(typing == "width" and "_" or ""),centerx-95*uiscale,centery+52*uiscale,0,2*uiscale,2*uiscale) 
			love.graphics.print(newheight..(typing == "height" and "_" or ""),centerx+55*uiscale,centery+52*uiscale,0,2*uiscale,2*uiscale) 
		end
		love.graphics.print("UI Scale: "..newuiscale*100 .."%",centerx-150*uiscale,300*winym-10*uiscale,0,uiscale,uiscale)
	elseif not inmenu and not winscreen and not mainmenu and wikimenu == "export" then
		love.graphics.setColor(1,1,1,1)
		love.graphics.printf("Export Picture",centerx,centery-147*uiscale,100,"center",0,2*uiscale,2*uiscale,50,8,skew)
		love.graphics.setColor(textcolor[1],textcolor[2],textcolor[3],1)
		love.graphics.print("Size",centerx-100*uiscale,centery-38*uiscale,0,uiscale,uiscale)
		love.graphics.print("Padding",centerx+50*uiscale,centery-38*uiscale,0,uiscale,uiscale)
		love.graphics.print(newcellsize..(typing == "cellsize" and "_" or "px"),centerx-95*uiscale,centery+52*uiscale,0,2*uiscale,2*uiscale) 
		love.graphics.print(newpadding..(typing == "padding" and "_" or "%"),centerx+55*uiscale,centery+52*uiscale,0,2*uiscale,2*uiscale)
	elseif winscreen == 1 then
		local text = "Victory!"
		local skew = math.sin(love.timer.getTime()*1.3)/8
		local s = 4*uiscale
		love.graphics.setColor(rainbow(.25))
		local scale = math.lerp(4,4.2,math.sin(love.timer.getTime())+1)*uiscale
		love.graphics.printf(text,centerx,centery-75*uiscale,100,"center",0,scale,s,50,8,skew)
		love.graphics.setColor(rainbow(.5))
		local scale = math.lerp(4,4.15,math.sin(love.timer.getTime()-.2)+1)*uiscale
		love.graphics.printf(text,centerx,centery-75*uiscale,100,"center",0,scale,s,50,8,skew)
		love.graphics.setColor(rainbow(.75))
		local scale = math.lerp(4,4.1,math.sin(love.timer.getTime()-.4)+1)*uiscale
		love.graphics.printf(text,centerx,centery-75*uiscale,100,"center",0,scale,s,50,8,skew)
		love.graphics.setColor(1,1,1,.5)
		local scale = math.lerp(4,4.05,math.sin(love.timer.getTime()-.6)+1)*uiscale
		love.graphics.printf(text,centerx,centery-75*uiscale,100,"center",0,scale,s,50,8,skew)
		love.graphics.setColor(1,1,1,.75)
		local scale = math.lerp(4,4.02,math.sin(love.timer.getTime()-.6)+1)*uiscale
		love.graphics.printf(text,centerx,centery-75*uiscale,100,"center",0,scale,s,50,8,skew)
		love.graphics.setColor(1,1,1,1)
		love.graphics.printf(text,centerx,centery-75*uiscale,100,"center",0,s,s,50,8,skew)
	elseif winscreen == -1 then
		local text = "Failure..."
		local skew = math.sin(love.timer.getTime()*1.3)/8
		local s = 4*uiscale
		love.graphics.setColor(.75,0,0,1)
		love.graphics.printf(text,centerx,centery-71*uiscale,100,"center",0,s,s,50,8,skew)
		love.graphics.setColor(.9,0,0,1)
		love.graphics.printf(text,centerx,centery-73*uiscale,100,"center",0,s,s,50,8,skew)
		love.graphics.setColor(1,.5,.5,1)
		love.graphics.printf(text,centerx,centery-75*uiscale,100,"center",0,s,s,50,8,skew)
	elseif mainmenu == "options" then
		love.graphics.setColor(0.5,0.5,0.5,1)
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,volume),centery-65.5*uiscale,4*uiscale,10*uiscale)
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,sfxvolume),centery-43.5*uiscale,4*uiscale,10*uiscale)
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,(musicspeed-.5)*.66666),centery-21.5*uiscale,4*uiscale,10*uiscale)
		love.graphics.rectangle("fill",math.lerp(centerx-152*uiscale,centerx+148*uiscale,(newuiscale-.5)*.66666),centery+.5,4*uiscale,10*uiscale)
		love.graphics.setColor(textcolor[1],textcolor[2],textcolor[3],1)
		love.graphics.print("Music Volume: "..volume*100 .."%",centerx-150*uiscale,300*winym-76*uiscale,0,uiscale,uiscale)
		love.graphics.print("SFX Volume: "..sfxvolume*100 .."%",centerx-150*uiscale,300*winym-54*uiscale,0,uiscale,uiscale)
		love.graphics.print("Music Speed: "..musicspeed*100 .."%",centerx-150*uiscale,300*winym-32*uiscale,0,uiscale,uiscale)
		love.graphics.print("UI Scale: "..newuiscale*100 .."%",centerx-150*uiscale,300*winym-10*uiscale,0,uiscale,uiscale)
	end
end

function DrawButtonInfo()
	if stallbtn and popups then
		local name = get(stallbtn.name)
		local desc = get(stallbtn.desc)
		if name ~= btntitle.rawtext then
			SetRichText(btntitle,name)
		end
		local w = math.max(300,btntitle.text:getWidth()*2+20)
		if desc ~= btndesc.rawtext then
			SetRichText(btndesc,desc,w-20)
		end
		w = math.min(math.max(desc and btndesc.text:getWidth()+20 or 0,btntitle.text:getWidth()*2+20),w)*uiscale
		local h = (desc and btndesc.text:getHeight()*uiscale or 0)+40*uiscale
		local x = math.max(math.min(love.mouse.getX(),love.graphics.getWidth()-w),0)
		local y = math.max(math.min(love.mouse.getY(),love.graphics.getHeight()-h),0)
		btntitle.update()
		love.graphics.setColor(0.5,0.5,0.5,1)
		love.graphics.rectangle("fill",x,y,w,h)
		love.graphics.setColor(0.25,0.25,0.25,1)
		love.graphics.rectangle("fill",x+2*uiscale,y+2*uiscale,w-4*uiscale,h-4*uiscale)
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(btntitle.text,x+10*uiscale,y+10*uiscale,0,2*uiscale,2*uiscale,0,0,btntitle.italic and -0.25 or 0)
		if desc then
			btndesc.update()
			love.graphics.draw(btndesc.text,x+10*uiscale,y+30*uiscale,0,uiscale,uiscale,0,0,btndesc.italic and -0.25 or 0)
		end
	end
end

versiontxt = [[Version #r2.0.2#55aaff_ff00ffw1.2.1
#xCelLua Machine Wiki Mod created by #ff0000_00ff00aadenboy
#xOriginal CelLua Machine created by#00ff00_80ff80 KyYay
#xOriginal Cell Machine by #40a0ff-80c0ffSam Hogan]]

cellcanv = love.graphics.newCanvas(love.graphics.getWidth(),love.graphics.getHeight())
function love.draw()
	love.graphics.setShader()
	if truequeue[1] then
		love.graphics.setColor(textcolor[1],textcolor[2],textcolor[3],1)
		love.graphics.printf("Loading...",centerx,centery-20,100,"center",0,3,3,50)
		love.graphics.printf(#truequeue,centerx,centery+20,100,"center",0,2,2,50)
		return
	end
	if recording then
		DrawMainMenu()
	else
		DrawMainMenu()
		DrawButtons()
		DrawPauseMenu()
		DrawButtonInfo()
		love.graphics.setColor(textcolor[1],textcolor[2],textcolor[3],.5)
		love.graphics.print("FPS: ".. 1/delta,2,2) 
		love.graphics.print("Tick: ".. tickcount,2,12) 
		if subticking > 0 and not level then
			love.graphics.print("Subtick: "..subtick.."/"..#subticks,2,22) 
		end
		--love.graphics.print("updK: ".. updatekey,2,subticking and 32 or 22) 
		--love.graphics.print("supdK: ".. supdatekey,2,subticking and 42 or 32) 
		if dodebug and debugger.rawtext ~= "" then
			love.graphics.setColor(0,0,0,.5)
			love.graphics.rectangle("fill",love.graphics.getWidth()-300,0,300,150)
			love.graphics.setColor(0,1,0,1)
			love.graphics.print("Debugger (F3 to clear)",love.graphics.getWidth()-295,5)
			love.graphics.setColor(1,1,1,1)
			debugger.update()
			love.graphics.draw(debugger.text,love.graphics.getWidth()-295,16)
		end
	end
end

function SetRichText(rt,s,w,a)
	if not rt then
		rt = {text=love.graphics.newText(font),rawtext=s or "",italic=false,bold=false,update = function() end}
	elseif rt.getHeight then
		rt = {text=rt,rawtext=s or "",italic=false,bold=false,update = function() end}
	end
	if not s then return rt end
	rt.formattext = {textcolor}
	local ns = ""
	local i = 0
	local backslash = false
	rt.italic = false
	local ru = {}
	while i < #s do
		i = i + 1
		if s:sub(i,i) == "#" and not backslash then
			table.insert(rt.formattext,ns)
			if s:sub(i+1,i+1) == "r" then
				table.insert(ru,#rt.formattext+1)
				table.insert(ru,rainbow)
				table.insert(rt.formattext,rainbow())
				i = i + 1
			elseif s:sub(i+1,i+1) == "R" then
				table.insert(ru,#rt.formattext+1)
				table.insert(ru,fastrainbow)
				table.insert(rt.formattext,fastrainbow())
				i = i + 1
			elseif s:sub(i+1,i+1) == "m" then
				table.insert(ru,#rt.formattext+1)
				table.insert(ru,monochrome)
				table.insert(rt.formattext,monochrome())
				i = i + 1
			elseif s:sub(i+1,i+1) == "M" then
				table.insert(ru,#rt.formattext+1)
				table.insert(ru,fastmonochrome)
				table.insert(rt.formattext,fastmonochrome())
				i = i + 1
			elseif s:sub(i+1,i+1) == "x" then
				table.insert(rt.formattext,textcolor)
				i = i + 1
			else
				table.insert(rt.formattext,{(tonumber("0x"..s:sub(i+1,i+2)) or 255)/255,(tonumber("0x"..s:sub(i+3,i+4)) or 255)/255,(tonumber("0x"..s:sub(i+5,i+6)) or 255)/255})
				i = i + 6
			end
			ns = ""
		elseif (s:sub(i,i) == "-" or s:sub(i,i) == "_") and not backslash and ns == "" then
			if #ru == 0 or ru[#ru-1] ~= #rt.formattext then
				table.insert(ru,#rt.formattext)
				table.insert(ru,rt.formattext[#rt.formattext])
			end
			local lerp = s:sub(i,i) == "_" and fastlerpcolor or lerpcolor
			if s:sub(i+1,i+1) == "r" then
				ru[#ru] = lerp(ru[#ru],rainbow)
				i = i + 1
			elseif s:sub(i+1,i+1) == "R" then
				ru[#ru] = lerp(ru[#ru],fastrainbow)
				i = i + 1
			elseif s:sub(i+1,i+1) == "m" then
				ru[#ru] = lerp(ru[#ru],monochrome)
				i = i + 1
			elseif s:sub(i+1,i+1) == "M" then
				ru[#ru] = lerp(ru[#ru],fastmonochrome)
				i = i + 1
			elseif s:sub(i+1,i+1) == "x" then
				ru[#ru] = lerp(ru[#ru],textcolor)
				i = i + 1
			else
				ru[#ru] = lerp(ru[#ru],{(tonumber("0x"..s:sub(i+1,i+2)) or 255)/255,(tonumber("0x"..s:sub(i+3,i+4)) or 255)/255,(tonumber("0x"..s:sub(i+5,i+6)) or 255)/255})
				i = i + 6
			end
		elseif s:sub(i,i) == "n" and backslash then
			ns = ns.."\n"
			backslash = false
		elseif s:sub(i,i) == "i" and backslash then
			rt.italic = true
			backslash = false
		elseif s:sub(i,i) == "o" and backslash then
			table.insert(rt.formattext,ns)
			table.insert(rt.formattext,rt.formattext[#rt.formattext-1])
			table.insert(ru,#rt.formattext)
			table.insert(ru,getobfuscated(cheatsheet[s:sub(i+1,i+1)] or 1))
			table.insert(rt.formattext,"")
			table.insert(rt.formattext,rt.formattext[#rt.formattext-1])
			ns = ""
			i = i + 1
			backslash = false
		elseif s:sub(i,i) == "\\" and not backslash then
			backslash = true
		else
			ns = ns..s:sub(i,i)
			backslash = false
		end 
	end
	rt.update = #ru == 0 and function() end or function()
		for j=1,#ru,2 do
			rt.formattext[ru[j]] = ru[j+1]()
		end
		rt.text:setf(rt.formattext,w or math.huge,a or "left")
	end
	table.insert(rt.formattext,ns)
	rt.text:setf(rt.formattext,w or math.huge,a or "left")
	rt.rawtext = s
	return rt
end
splash = SetRichText()
lvltitle = SetRichText()
lvldesc = SetRichText()
btntitle = SetRichText()
btndesc = SetRichText()
debugger = SetRichText()
version = SetRichText()

function Resplash()
	SetRichText(splash,"#ffff00"..getsplash(),150,"center")
end
Resplash()

function DEBUG(str) --heehee CYF referenc
	local dtext = debugger.rawtext.."#00ff00"..tostring(str).."\n"
	SetRichText(debugger,dtext,390,"left")
	while debugger.text:getHeight() > 140 do
		SetRichText(debugger,string.sub(debugger.rawtext,2,#debugger.rawtext),390,"left")
	end
end

function love.textinput(key)
	if not postloading then
		return
	end
	if typing == "width" then
		if tonumber(key) then
			newwidth = tonumber(string.sub(tostring(newwidth)..key,1,3))
		end
	elseif typing == "height" then
		if tonumber(key) then
			newheight = tonumber(string.sub(tostring(newheight)..key,1,3))
		end
	elseif typing == "cellsize" then
		if tonumber(key) then
			newcellsize = tonumber(string.sub(tostring(newcellsize)..key,1,3))
		end
	elseif typing == "padding" then
		if tonumber(key) then
			newpadding = tonumber(string.sub(tostring(newpadding)..key,1,3))
		end
	elseif type(typing) == "number" then
		chosen.data[typing] = chosen.data[typing]..key
	elseif typing then
		typing(key)
	end
end

function love.keypressed(key,code,repeated)
	if not postloading then
		return
	end
	if key == "f3" then
		SetRichText(debugger,"",390,"left")
	elseif typing then
		if key == "v" and ctrl() then
			love.textinput(love.system.getClipboardText())
		elseif key == "backspace" then
			if typing == "width" then
				newwidth = tonumber(string.sub(tostring(newwidth),1,(utf8.offset(tostring(newwidth),-1) or 1)-1)) or 0
			elseif typing == "height" then
				newheight = tonumber(string.sub(tostring(newheight),1,(utf8.offset(tostring(newheight),-1) or 1)-1)) or 0
			elseif typing == "cellsize" then
				newcellsize = tonumber(string.sub(tostring(newcellsize),1,(utf8.offset(tostring(newcellsize),-1) or 1)-1)) or 0
			elseif typing == "padding" then
				newpadding = tonumber(string.sub(tostring(newpadding),1,(utf8.offset(tostring(newpadding),-1) or 1)-1)) or 0
			elseif type(typing) == "number" then
				chosen.data[typing] = string.sub(chosen.data[typing],1,(utf8.offset(chosen.data[typing],-1) or 1)-1)
			else
				typing(key)
			end
		end
	elseif not repeated then
		if key == "q" and ctrl() then
			FlipH()
		elseif key == "e" and ctrl() then
			FlipV()
		elseif key == "q" then
			RotateCCW()
		elseif key == "e" then
			RotateCW()
		elseif key == "space" then
			TogglePause(not paused)
		elseif key == "f" and not level then
			if ctrl() and not mainmenu then
				if mainmenu == "search" then ToMenu("back")
				elseif not mainmenu and not puzzle then ToMenu("search") end
			else
				DoTick(true)
				TogglePause(true)
			end
		elseif key == "escape" and not winscreen then
			if mainmenu and mainmenu ~= "title" then
				ToMenu("back")
			else
				if wikimenu then inmenu = true end
				inmenu = not inmenu
				wikimenu = nil
			end
		elseif key == "r" and ctrl() and not mainmenu then
			RefreshWorld()
		elseif key == "tab" and not puzzle and not mainmenu then
			ToggleSelection()
		elseif key == "c" and ctrl() and selection.on and not mainmenu then
			CopySelection()
		elseif key == "x" and ctrl() and selection.on and not mainmenu then
			CutSelection()
		elseif key == "backspace" and selection.on and not mainmenu then
			DeleteSelection()
		elseif key == "v" and ctrl() and not mainmenu then
			if not pasting then TogglePasting() end
		elseif key == "z" and ctrl() and not puzzle then
			Undo()
		elseif key == "k" then
			if ctrl() and not mainmenu then
				CreateStamp()
			else
				if mainmenu == "stamps" then ToMenu("back")
				elseif not mainmenu and not puzzle then StampMenu() end
			end
		elseif (key == "d" or key == "right") and freezecam then
			held = 0
			heldhori = 0
		elseif (key == "a" or key == "left") and freezecam then
			held = 2
			heldhori = 2
		elseif (key == "w" or key == "up") and freezecam then
			held = 3
			heldvert = 3
		elseif (key == "s" or key == "down") and freezecam then
			held = 1
			heldvert = 1
		elseif key == "z" or key == "return" then
			actionpressed = true
		elseif key == "f11" then
			love.window.setFullscreen(not love.window.getFullscreen())
			love.resize() --zoom fucks up if i dont
		end
	end
end

function DoFill(x,y,z,origid,toid)
	if chosen.randrot then hudrot = chosen.rot chosen.rot = math.random(0,3) end
	if x > 0 and x < width-1 and y > 0 and y < height-1 then
		if GetCell(x,y,z).id == origid then
			PlaceCell(x,y,{id=toid,rot=chosen.rot,lastvars={x,y,0}},z)
			local neighbors = GetNeighbors(x,y)
			for k,v in pairs(neighbors) do
				Queue("fill", function() DoFill(v[1],v[2],z,origid,toid) end)
			end
		end
	end
end

function SetDraggedCell(x,y)
	draggedcell = GetCell(x,y)
	PlaceCell(x,y,getempty())
end
MergeIntoInfo("handleplaceable",{
	placeable=SetDraggedCell,placeableR=SetDraggedCell,placeableO=SetDraggedCell,placeableY=SetDraggedCell,
	placeableG=SetDraggedCell,placeableC=SetDraggedCell,placeableB=SetDraggedCell,placeableP=SetDraggedCell,
	rotatable=function(x,y)
		RotateCellRaw(layers[0][y][x],1)
		PlaceCell(x,y,layers[0][y][x])
	end,
	rotatable180=function(x,y)
		RotateCellRaw(layers[0][y][x],2)
		PlaceCell(x,y,layers[0][y][x])
	end,
	hflippable=function(x,y)
		FlipCellRaw(layers[0][y][x],0)
		PlaceCell(x,y,layers[0][y][x])
	end,
	vflippable=function(x,y)
		FlipCellRaw(layers[0][y][x],1)
		PlaceCell(x,y,layers[0][y][x])
	end,
	ddflippable=function(x,y)
		FlipCellRaw(layers[0][y][x],.5)
		PlaceCell(x,y,layers[0][y][x])
	end,
	duflippable=function(x,y)
		FlipCellRaw(layers[0][y][x],1.5)
		PlaceCell(x,y,layers[0][y][x])
	end,
})

function HandlePlaceable(x,y)
	GetAttribute(GetPlaceable(x,y),"handleplaceable",x,y)
end

function love.mousepressed(x, y, btn) 
	typing = false
	if not postloading or mainmenu then
		return
	end
	newwidth = math.max(newwidth,1)
	newheight = math.max(newheight,1)
	newcellsize = math.max(newcellsize,1)
	newpadding = math.min(math.max(newpadding,0),99)
	if btn == 1 and not hoveredbutton and (chosen.id ~= 0 or puzzle or selection.on or pasting) then
		local cx = math.floor((x+cam.x-400*winxm)/cam.zoom)
		local cy = math.floor((y+cam.y-300*winym)/cam.zoom)
		if puzzle then
			if isinitial and GetCell(cx,cy).id ~= 0 then
				HandlePlaceable(cx,cy)
			elseif not isinitial then
				local cell,cz
				for z=depth-1,0,-1 do
					cell = GetCell(cx,cy,z,true)
					if cell.id ~= 0 then cz = z break end
				end
				OnClick(cell,1,cx,cy)
			end
		elseif pasting then
			undocells.topush = table.copy(layers)
			undocells.topush.background = table.copy(placeables)
			undocells.topush.chunks = table.copy(chunks)
			undocells.topush.isinitial = isinitial
			undocells.topush.width = width
			undocells.topush.height = height
			for z=0,#copied do
				for y=0,#copied[0] do
					for x=0,#copied[0][0] do
						if (chosen.mode ~= "Or" or GetCell(x+cx,y+cy).id == 0) and (chosen.mode ~= "And" or GetCell(x+cx,y+cy).id ~= 0) then
							copied[z][y][x].lastvars = {x+cx,y+cy,0}
							PlaceCell(x+cx,y+cy,table.copy(copied[z][y][x]),z)
						end
					end
				end
			end
			for y=0,#copied[0] do
				for x=0,#copied[0][0] do
					if (chosen.mode ~= "Or" or not GetPlaceable(x+cx,y+cy)) and (chosen.mode ~= "And" or GetPlaceable(x+cx,y+cy)) then
						SetPlaceable(x+cx,y+cy,copied[-1][y][x])
					end
				end
			end
			placecells = false
			TogglePasting()
		elseif filling and not IsTool(chosen.id) and GetLayer(chosen.id) ~= -1 then
			undocells.topush = table.copy(layers)
			undocells.topush.background = table.copy(placeables)
			undocells.topush.chunks = table.copy(chunks)
			undocells.topush.isinitial = isinitial
			undocells.topush.width = width
			undocells.topush.height = height
			local cz,cell = GetLayer(chosen.id),GetCell(cx,cy,GetLayer(chosen.id))
			if chosen.id == 0 then
				for z=depth-1,0,-1 do
					cell = GetCell(cx,cy,z,true)
					if cell.id ~= 0 then cz = z break end
				end
			end
			if cell.id ~= chosen.id then
				DoFill(cx,cy,cz,cell.id,chosen.id)
				ExecuteQueue("fill")
			end
			ToggleFill()
			placecells = false
		else
			local cell,cz
			for z=depth-1,0,-1 do
				cell = GetCell(cx,cy,z,true)
				if cell.id ~= 0 then cz = z break end
			end
			if selection.on then
				placecells = false
				selection.x,selection.y,selection.w,selection.h,selection.ox,selection.oy = cx,cy,1,1,cx,cy
			elseif (not IsTool(chosen.id) or cz ~= 0) and OnClick(cell,1,cx,cy) then
				placecells = false
			elseif (not IsTool(chosen.id) or cz ~= 0) and IsCellHolder(cell.id) then
				if chosen.id == 0 then
					if cell.vars[1] then
						cell.vars[1] = nil
						cell.vars[2] = nil
						if isinitial then initiallayers[cz][cy][cx].vars[1] = nil initiallayers[cz][cy][cx].vars[2] = nil end
						placecells = false
					end
				elseif GetLayer(chosen.id) == 0 then
					cell.vars[1] = chosen.id
					cell.vars[2] = chosen.rot
					if isinitial then initiallayers[cz][cy][cx].vars[1] = chosen.id initiallayers[cz][cy][cx].vars[2] = chosen.rot end
					placecells = false
				end
			elseif cell.id == 0 and chosen.id == 0 and GetPlaceable(cx,cy) then
				lockedz = true
			else
				lockedz = cz
			end
		end
	elseif (btn == 2 or btn == 1 and chosen.id == 0) and not hoveredbutton then
		local cx = math.floor((x+cam.x-400*winxm)/cam.zoom)
		local cy = math.floor((y+cam.y-300*winym)/cam.zoom)
		if puzzle then
			if not isinitial then
				local cell,cz
				for z=depth-1,0,-1 do
					cell = GetCell(cx,cy,z,true)
					if cell.id ~= 0 then cz = z break end
				end
				OnClick(cell,2,cx,cy)
			end
		elseif pasting then
			TogglePasting()
		elseif filling and not IsTool(chosen.id) then
			undocells.topush = table.copy(layers)
			undocells.topush.background = table.copy(placeables)
			undocells.topush.chunks = table.copy(chunks)
			undocells.topush.isinitial = isinitial
			undocells.topush.width = width
			undocells.topush.height = height
			local cz,cell = 0,GetCell(cx,cy,0)
			for z=depth-1,0,-1 do
				cell = GetCell(cx,cy,z,true)
				if cell.id ~= 0 then cz = z break end
			end
			if cell.id ~= 0 then
				DoFill(cx,cy,cz,cell.id,0)
				ExecuteQueue("fill")
			end
			ToggleFill()
			placecells = false
		else
			local cx = math.floor((x+cam.x-400*winxm)/cam.zoom)
			local cy = math.floor((y+cam.y-300*winym)/cam.zoom)
			local cell,cz
			for z=depth-1,0,-1 do
				cell = GetCell(cx,cy,z,true)
				if cell.id ~= 0 then cz = z break end
			end
			if not IsTool(chosen.id) and OnClick(cell,2,cx,cy) then
				placecells = false
			elseif not IsTool(chosen.id) and IsCellHolder(cell.id) and cell.vars[1] then
				cell.vars[1] = nil
				cell.vars[2] = nil
				if isinitial then initiallayers[cz][cy][cx].vars[1] = nil initiallayers[cz][cy][cx].vars[2] = nil end
				placecells = false
			elseif (cell.id == 0) and GetPlaceable(cx,cy) then
				lockedz = true
			else
				lockedz = cz
			end
		end
	elseif btn == 3 and not hoveredbutton and not puzzle then
		pickx,picky = x,y
	end
end

function love.mousereleased(x, y, btn)
	if not postloading then
		return
	end
	if undocells.topush then
		table.insert(undocells,1,undocells.topush)
		if #undocells > maxundo then
			undocells[maxundo+1] = nil
		end
		undocells.topush = nil
	end
	if draggedcell then
		local cx = math.floor((x+cam.x-400*winxm)/cam.zoom)
		local cy = math.floor((y+cam.y-300*winym)/cam.zoom)
		if GetPlaceable(cx,cy) == GetPlaceable(draggedcell.lastvars[1],draggedcell.lastvars[2]) then
			PlaceCell(draggedcell.lastvars[1],draggedcell.lastvars[2],GetCell(cx,cy))
			PlaceCell(cx,cy,draggedcell)
		else
			PlaceCell(draggedcell.lastvars[1],draggedcell.lastvars[2],draggedcell)
		end
	elseif hoveredbutton and get(hoveredbutton.isenabled) then
		hoveredbutton.onclick(hoveredbutton)
	elseif btn == 3 and pickx and not mainmenu and not puzzle and math.abs(pickx-x)+math.abs(picky-y) < 10 then
		local cx = math.floor((x+cam.x-400*winxm)/cam.zoom)
		local cy = math.floor((y+cam.y-300*winym)/cam.zoom)
		local cell
		for cz=depth-1,0,-1 do
			cell = GetCell(cx,cy,cz,true)
			if cell.id ~= 0 then break end
		end
		if not HandleCopy(cell) then
			SetSelectedCell(cell.id == 0 and GetPlaceable(cx,cy) or cell.id)
			hudlerp = 0
			hudrot = chosen.rot 
			chosen.rot = cell.rot
		end
	end
	placecells = true
	lockedz = false
	draggedx = nil
	draggedy = nil
	draggedcell = nil
	settings.uiscale = uiscale ~= newuiscale and newuiscale or uiscale
	uiscale = settings.uiscale
end

function love.wheelmoved(x,y)
	if not postloading then
		return
	end
	if mainmenu == "packs" then
		packscroll = math.max(math.min(packscroll-y*15, maxpackscroll), 0)
	elseif ctrl() then
		chosen.size = math.max(chosen.size+y,1)
	else
		ChangeZoom(y)
	end
end

function love.quit()
	WriteSavedVars()
end

encryptstr = "0123456789ABCDEFGHIJKLMNOPQRSTUVXWYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()`~-_=+[]{}<>,./?;:\'\"|	\\ "
function EncryptWithKey(str,key)
	local result = ""
	key = love.data.encode("string","base64",love.data.hash("sha512",key))
	for i=1,#str do
		local j = (i-1)%#key+1
		local strchar = str:sub(i,i)
		local keychar = key:sub(j,j)
		local n = string.find(encryptstr,strchar,1,true)
		local k = string.find(encryptstr,keychar,1,true)
		if n and k then
			n = (n+k-1)%#encryptstr+1
			result = result..encryptstr:sub(n,n)
		else
			result = result..strchar
		end
	end
	return result
end

function DecryptWithKey(str,key)
	local result = ""
	key = love.data.encode("string","base64",love.data.hash("sha512",key))
	for i=1,#str do
		local j = (i-1)%#key+1
		local strchar = str:sub(i,i)
		local keychar = key:sub(j,j)
		local n = string.find(encryptstr,strchar,1,true)
		local k = string.find(encryptstr,keychar,1,true)
		if n and k then
			n = (n-k-1)%#encryptstr+1
			result = result..encryptstr:sub(n,n)
		else
			result = result..strchar
		end
	end
	return result
end

--love.system.setClipboardText(EncryptWithKey(love.filesystem.read("secrets/0.txt"),"nopeeking"))

function HandleSecret(str)
	if str:len() == 0 then return end
	if postloading and GetSaved("secrets")[str] then return end
	local success
	local f = function()
		local files = love.filesystem.getDirectoryItems("secrets")
		for i=1,#files do
			local file = love.filesystem.read("secrets/"..files[i])
			local loaded = pcall(loadstring(DecryptWithKey(file,str)))
			if loaded then
				if postloading then GetSaved("secrets")[str] = true end
				success = true
				break
			end
		end
	end
	if postloading then f()
	else table.insert(truequeue,f) end
	do return success end
end