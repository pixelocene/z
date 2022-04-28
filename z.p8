pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
-- z
-- by damien & florent

function _init()
	-- debug related
	freemove=true -- count movement as action
	debug_enabled=true
	debug_stack={}

	init_main_title()
end

-->8
-- main title

function init_main_title()
	_update=update_title_screen
	_draw=draw_title_screen
end

function update_title_screen()
	if btnp(❎) or btnp(🅾️) then
		init_game()
	end
end

function draw_title_screen()
	cls(2)
	-- z
	line(20,20,107,20,1)
	line(20,21,107,21,1)
	line(20,22,107,22,1)
	line(20,23,107,23,1)
	line(20,24,107,24,1)
	
	line(107,24,28,70,1)
	line(106,24,27,70,1)
	line(105,24,26,70,1)
	line(104,24,25,70,1)
	line(103,24,24,70,1)
	line(102,24,23,70,1)
	line(101,24,22,70,1)
	line(100,24,21,70,1)
	
	line(20,70,107,70,1)
	line(20,71,107,71,1)
	line(20,72,107,72,1)
	line(20,73,107,73,1)
	line(20,74,107,74,1)
	-- players
	palt(0,false)
	palt(14,true)
	spr(1,25,80)
	spr(3,35,80)
	spr(5,45,80)
	spr(7,55,80)
	spr(9,65,80)
	spr(17,75,80)
	spr(19,85,80)
	spr(33,95,80)
	palt(0,true)
	palt(14,false)
	-- instructions
	print("press ❎ or 🅾️ to start",15,110)
end

-->8
-- game

function init_game()
	turn=1
	game_state="action_selection"

	areas={}
	game_special_buildings={}
	
	info_message = {
		message=nil,
		anim=0
	}

	error_message = {
		message=nil,
		anim=0
	}

	players={}
	current_player=1

	target={
		x=0,
		y=0,
		anim=0
	}
	
	current_action=actions[1]
	current_inventory_selection=nil
	inventory_actions={}
	current_inventory_action=1

	-- init areas
	repeat
		local area=layouts[ceil(rnd(#layouts))]
		-- todo check area not already used before adding it
		local exists=false
		for a in all(areas) do
			if (a==area) exists=true
		end
		if not exists then
			-- init buildings for the area
			for b in all(area.buildings) do
				local building=nil
				if b.is=="normal" then
					building=normal_building
				elseif b.is=="graveyard" then
					building=graveyard
				else
					-- special buildings are picked randomly
					repeat
						local exists=false
						local spe=special_buildings[ceil(rnd(#special_buildings))]
						for special_building in all(game_special_buildings) do
							if special_building.name==b.name then
								exists=true
							end
						end
						building=spe
					until not exists
				end
				b.name=building.name
				b.objects=building.objects
			end
			-- add the area to the map areas
			add(areas,area)
		end
	until #areas==4

	-- init players
	for i=1,4 do
		local x,y = rnd_start_location()
		local job = get_a_job()
		add(players, {
			hp=6,
			actions=4,
			x=x,		-- pos x on the grid
			y=y,		-- pos y on the grid
			ox=x, -- offset (for animation)
			oy=y,	-- offset (for animation)
			job=job,
			anim=0,
			mirror=false, -- if true, look to the left
			building=nil, -- building data
			inventory={},
			max_inventory_size=6,
		})
	end

	_update=update_game
	_draw=draw_game
end

function update_game()
	local p=players[current_player]
	-- update animations
	update_target()
	update_player()
	-- update messages
	if info_message.message~=nil then
		info_message.anim-=0.1
		if info_message.anim <= 0 then info_message.message=nil end
	end
	if error_message.message~=nil then
		error_message.anim-=0.1
		if error_message.anim <= 0 then error_message.message=nil end
	end
	-- handle user interaction
	if game_state=="action_selection" then
		if (btnp(⬅️)) current_player-=1
		if (btnp(➡️)) current_player+=1	
		if (btnp(⬇️)) move_to_next_action(1)
		if (btnp(⬆️)) move_to_next_action(-1)
		if (btnp(🅾️)) do_action()
		-- check user selection cycling
		if (current_player>#players) current_player=1
		if (current_player<1) current_player=#players
	end

	if game_state=="move" then
		local newx,newy=p.x,p.y

		if btnp(❎) or p.actions==0 then
			game_state="action_selection"
			return
		end

		if btnp(⬅️) then
			newx-=1
			p.mirror=true
		end
		if btnp(➡️) then
			newx+=1
			p.mirror=false
		end
		if (btnp(⬇️)) newy+=1
		if (btnp(⬆️)) newy-=1
		
		-- check the new coordinates before applying them
		if ((p.x~=newx or p.y~=newy) and current_player_can_go_to(newx,newy)) then
			p.x=newx
			p.y=newy
			if (not freemove) p.actions-=1
		end
		
		-- retrieve the builder the player is in (if any)
		get_building_for_player()
	end
	
	if game_state=="inventory" then
		if #p.inventory>0 then
			if btnp(⬅️) or btnp(➡️) then

				if btnp(⬅️) then current_inventory_selection-=1 end
				if btnp(➡️) then current_inventory_selection+=1 end

				if current_inventory_selection > #p.inventory then
					current_inventory_selection=1
				end

				if current_inventory_selection < 1 then
					current_inventory_selection=#p.inventory
				end

				-- update object actions
				local actions={}
				if p.inventory[current_inventory_selection].use~=nil then
					add(actions,"use")
				end
				add(actions,"throw")
				inventory_actions=actions
				current_inventory_action=1
				
			elseif btnp(⬇️) or btnp(⬆️) then

				if btnp(⬇️) then current_inventory_action+=1 end
				if btnp(⬆️) then current_inventory_action-=1 end

				if current_inventory_action > #inventory_actions then
					current_inventory_action=1
				end
				if current_inventory_action < 1 then
					current_inventory_action=#current_inventory_action
				end

				printh(inventory_actions[current_inventory_action])

			elseif btnp(🅾️) then
				if inventory_actions[current_inventory_action]=="throw" then
					deli(p.inventory,current_inventory_selection)
				end
			end
		end

		if btnp(❎) then
			current_inventory_selection=1
			game_state="action_selection"
		end

	end

	if game_state=="enter_building" then update_game_enter_building() end
end

-- navigate between the current player actions
function move_to_next_action(direction)
	local keys=get_table_keys(actions)
	local index=nil
	for i,v in ipairs(actions) do
		if v.name==current_action.name then
			index=i
		end
	end
	-- go to next index
	index+=direction
	-- check new index is in boundaries
	if (index>#actions) index=1
	if (index<1) index=#actions
	-- modify current action
	current_action=actions[keys[index]]
end

-- execute the selected action for the current player
function do_action()
	local p=players[current_player]
	-- switch to move state
	if (current_action.name=="move") game_state="move"
	-- pickup an object from the current building
	if current_action.name=="search" then
		if p.building==nil then
			error_message={
				message="you are not in a building",
				anim=4
			}
			return
		end
		if #p.inventory>=p.max_inventory_size then
			error_message={
				message="your inventory is full",
				anim=4
			}
			return
		end
		local o=p.building.objects[ceil(rnd(#p.building.objects))]
		info_message={
			message="you found "..o.name,
			anim=4
		}
		-- Run the action if it has one
		if o.action~=nil then o.action() end
		-- Add the object to the inventory if set
		if o.autoremove==nil or o.autoremove==false then
			add(p.inventory,o)
		end
	end
	if current_action.name=="inventory" then
		current_inventory_selection=1
		game_state="inventory"
	end
end

function draw_game()
	local p=players[current_player]

	draw_map()
	draw_players()
	
	if game_state=="action_selection" then
		if current_action.name=="special" then
			name=p.job.action.name
			description=p.job.action.description
		else
			name=current_action.name
			description=current_action.description
		end
		
		rectfill(22,93,20+#name*4+4,91+8,1)
		rectfill(20,91,20+#name*4+2,91+6,2)
		
		rectfill(22,102,117,122,1)
		if p.actions>0 then
			rectfill(20,100,115,120,2)
		else
			rectfill(20,100,115,120,8)
		end
		
		print(name,22,92,7)
		if p.actions>0 then
			print(description,22,102,7)
		else
			print("no actions remaining",22,102,7)
		end
	end
	
	if game_state=="inventory" then
		rectfill(8,8,127,127,2)
		rectfill(8,8,127,18,1)
		
		print(
			"inventory ("..#p.inventory.."/"..p.max_inventory_size..")",
			38,11,7
		)
		
		for i=1,p.max_inventory_size do
			local x=19+(i-1)*11
			local y=27
			if i==current_inventory_selection and p.inventory[i]~=nil then
				rect(x,y,x+9,y+9,7)
			else
				rect(x,y,x+9,y+9,13)
			end
			if p.inventory[i]~=nil then
				spr(
					p.inventory[i].sprite,
					x+1,y+1
				)
			end
		end

		local o=p.inventory[current_inventory_selection]

		if o~=nil then

			print(o.name,21,46,0)
			print(o.name,20,45,7)

			print(o.description,21,61,0)
			print(o.description,20,60,7)

			local box_x=82
			local box_y=127-8-#inventory_actions*9
			local box_w=42
			local box_h=#inventory_actions*8+12 --@todo fix the height

			line(box_x+1,box_y,box_x+box_w-1,box_y,1)
			line(box_x+1,box_y+box_h,box_x+box_w-1,box_y+box_h,1)
			line(box_x,box_y+1,box_x,box_y+box_h-1,1)
			line(box_x+box_w,box_y+1,box_x+box_w,box_y+box_h-1,1)

			for i,action in ipairs(inventory_actions) do
				local c=6
				if inventory_actions[current_inventory_action]==action then c=7 end
				print(action,box_x+6,box_y+6+(i-1)*8,1)
				print(action,box_x+5,box_y+5+(i-1)*8,c)
			end

		end
	end

	if info_message.message~=nil then
		local place=info_message.message
		rectfill(17,66,122,74,1)
		rectfill(15,64,120,72,2)
		print(
			place,
			(122-17-#place*4)/2+17+1,
			67,
			1
		)
		print(
			place,
			(122-17-#place*4)/2+17,
			66,
			7
		)
	end

	if error_message.message~=nil then
		local message=error_message.message
		rectfill(17,66,122,74,1)
		rectfill(15,64,120,72,8)
		print(
			message,
			(122-17-#message*4)/2+17+1,
			67,
			1
		)
		print(
			message,
			(122-17-#message*4)/2+17,
			66,
			7
		)
	end
	
	draw_ui()
	draw_debug()
end

-->8
-- tools and debug

function debug(value)
	add(debug_stack,value)
end

function draw_debug()
	if debug_enabled then
		local y=127-6
		for message in all(debug_stack) do
			printh(message, "debug")
			rectfill(0,y,128,y+6,8)
			print("!"..message,1,y+1,7)
			y-=8
		end
	end
end

function get_table_keys(table)
  local keyset = {}
  for k,v in pairs(table) do
    keyset[#keyset + 1] = k
  end
  return keyset
end

-->8
-- map and buildings

function draw_map()
	cls()
	map(0,0,8,8)
	-- draw areas
	for i=1,4 do
		local area=areas[i]
		
		local srcx=area.mapping.x
		local srcy=area.mapping.y
		if i==1 then
			destx=1 desty=1
		elseif i==2 then
			destx=8 desty=1
		elseif i==3 then
			destx=1 desty=8
		else
			destx=8 desty=8
		end
		
		for x=0,5 do
			for y=0,5 do
				mset(
					destx+x,desty+y,
					mget(srcx+x,srcy+y)
				)
			end
		end
	end
	
end

function current_player_can_go_to(x,y)
	-- check out of boundaries
	if x<1 or x>15 or y<1 or y>15 then
		return false
	end
	-- check non traversable sprits
	-- (map is 0,0 and player is 1,1)
	if (fget(mget(x-1,y-1),0)) then
		return false
	end
	-- all is right
	return true
end

-->8❎
-- players

function get_building_for_player()
	local p=players[current_player]
	local a=nil
	local relx=0 local rely=0
	local previous_building_id=nil
	if p.building~=nil then
		previous_building_id=p.building.id
	end
	-- determine which area we are in
	-- and calculate the player position relative to the area
	if p.x>1 and p.x<8 and p.y>1 and p.y<8 then
		a=areas[1]
		relx=p.x-1 rely=p.y-1
	elseif p.x>8 and p.x<15 and p.y>1 and p.y<8 then
		a=areas[2]
		relx=p.x-8 rely=p.y-1
	elseif p.x>1 and p.x<8 and p.y>8 and p.y<15 then	
		a=areas[3]
		relx=p.x-1 rely=p.y-8
	elseif p.x>8 and p.x<15 and p.y>8 and p.y<15 then
		a=areas[4]
		relx=p.x-8 rely=p.y-8
	else
		p.building=nil
		return
	end
	-- check the building in the area
	for b in all(a.buildings) do
		for r in all(b.rects) do
			if relx>=r[1] and relx<=r[3]
				and rely>=r[2] and rely<=r[4] then
				p.building=b
				if previous_building_id~=b.id then
					info_message = {
						message=p.building.name,
						anim=3
					}
				end
				return
			end
		end
	end
end

function update_player()
	local p=players[current_player]
	p.anim+=0.1
	if p.anim>2 then p.anim=0 end
end

function draw_players()
	for p in all(players) do
		draw_player(p)
	end
end

function draw_player(p,x,y,menu)
	local x=x or p.x*8
	local y=y or p.y*8
	local menu=menu or false
	local sprite=nil
	
	if players[current_player]==p and menu==false then
		draw_target(x,y)
	end
	
	palt(0,false)
	palt(14,true)
	
	if fget(mget(p.x-1,p.y-1),1) and menu==false then
		-- when in building, player is shadowed
		sprite=27
	else
		sprite=p.job.sprite
	end
	
	if menu==false then
		-- @todo check if walking
		sprite+=p.anim
	end
	
	if menu then
			spr(sprite,x,y)
		else
			spr(sprite,x,y,1,1,p.mirror)
		end
	
	palt(0,true)
	palt(14,false)
end

function get_a_job()
	local jobs_names = get_table_keys(jobs)
	-- remove already taken jobs
	for p in all(players) do
		del(jobs_names, p.job)	
	end
	-- pick a job and return it
	return jobs[
		jobs_names[
			ceil(rnd(#jobs_names))
		]
	]
end

function rnd_start_location()
	repeat
		-- get a location around the gamefield
		exists=false
		local pos=ceil(rnd(56))
		if pos>=1 and pos<16 then
			-- top border
			col=pos
			row=1
		end
		if pos>15 and pos<29 then
			-- right border
			col=15
			row=pos-15+1
		end
		if pos>28 and pos<44 then
			-- bottom border
			col=43-pos+1
			row=15
		end
		if pos>43 and pos<=56 then
			-- left border
			col=1
			row=56-pos+1
		end
		-- if a player is already there we relaunch
		for p in all(players) do
			if p.x==col and p.y==row then
				exists=true
			end
		end
	until not exists
	return col, row	
end

-->8
-- ui
function draw_ui()
	draw_player_status()
	draw_actions()
	draw_turn()
end

function draw_player_status()
	local p=players[current_player]
	rectfill(0,0,127,7,2)
	draw_player(p,0,0,true)
	for i=1,p.hp do
		spr(11,1+i*8,0)
	end
	for i=1,p.actions do
		spr(12,1+p.hp*8+2+i*6,0)
	end
end

function draw_turn()
	local x=(turn>9) and 86 or 90
	print("tURN "..turn.."/12",x+1,2,0)
	print("tURN "..turn.."/12",x,1,7)
end

function draw_actions()
	local p=players[current_player]
	
	rectfill(0,8,7,127,1)
	
	if current_action.name=="move" then
		rectfill(0,10,7,18,14)
	end
	
	if current_action.name=="search" then
		rectfill(0,20,7,28,14)
	end

	if current_action.name=="inventory" then
		rectfill(0,30,7,38,14)
	end

	if current_action.name=="fight" then
		rectfill(0,40,7,48,14)
	end
	
	if current_action.name=="exchange" then
		rectfill(0,50,7,58,14)
	end

	if current_action.name=="special" then
		rectfill(0,60,7,68,14)
	end
		
	if current_action.name=="turn end" then
		rectfill(0,120,7,128,14)
	end
	
	spr(48,0,10) -- move
	spr(50,0,20) -- search
	spr(43,0,30) -- inventory
	spr(51,0,40) -- fight
	spr(49,0,50) -- exchange
	spr(p.job.action.sprite,0,60) -- player special action
	
	spr(59,0,120) -- turn end
end
-->8
-- target

function update_target()
	target.anim+=0.125
	if target.anim >= 2 then
		target.anim=0
	end
end

function draw_target(x,y)
	if target.anim <= 1 then
		spr(16,x,y)
	else
		spr(32,x,y)
	end
end
-->8
-- game data

-- objects
-- nb: descriptions must no be more than 24 caraters per line
objects = {
	-- simple building
	trap={
		name="trap",
		description="it’s a trap! you lose 1♥",
		action=function()
			local p=players[current_player]
			p.hp-=1
		end,
		autoremove=true,
	},
	kitchen_knife={
		sprite=64,
		name="kitchen knife",
		description="+1 damage in melee",
	},
	bandage={
		sprite=96,
		name="bandage",
		description="recover 1♥",
		use=function()
			local p=players[current_player]
			p.hp+=1
		end
	},
	survival_book={
		sprite=81,
		name="survival book",
		description="add 1 max ♥",
	},
	toothpaste={
		sprite=0,
		name="toothpaste",
		description="your breath left a\nlittle to be desired\nlately.",
	},
	brick={
		sprite=65,
		name="brick",
		description="+1 damage in ranged",
	},
	-- sanitarium
	hungry_patient={
		name="hungry patient",
		description="he looks pretty dead",
	},
	oxygen_bomb={
		sprite=66,
		name="oxygen bomb",
		description="make it explodes baby",
	},
	straitjacket={
		sprite=0,
		name="straitjacket",
		description="this is precisely your\nsize, coincidence?"
	},
	care_kit={
		sprite=97,
		name="care kit",
		description="recover 2♥",
	},
	stethoscope={
		sprite=80,
		name="stethoscope",
		description="???",
	},
	antibiotics={
		sprite=112,
		name="antibiotics",
		description="???",
	},
	-- police station
	cell_door={
		sprite=0,
		name="cell door",
		description="???",
	},
	gun={
		sprite=67,
		name="a gun with 3 ammo",
		description="???",
	},
	stale_donuts={
		sprite=0,
		name="stale donuts",
		description="the appearance is\nsuspicious, but you are\nso hungry...",
	},
	cocain_bag={
		sprite=98,
		name="cocain bag",
		description="???",
	},
	bulletproof_vest={
		sprite=82,
		name="bulletproof vest",
		description="???",
	},
	cb_radio={
		sprite=113,
		name="cb-radio",
		description="???",
	},
	-- graveyard
	embittered_deceased={
		sprite=0,
		name="embittered deceased",
		description="not so dead after all…",
	},
	gravedigger_shovel={
		sprite=68,
		name="gravedigger shovel",
		description="???",
	},
	flower_wreath={
		sprite=0,
		name="flower wreath",
		description="we will all go to\nheaven...\nbut in fact no",
	},
	matches={
		sprite=100,
		name="matches",
		description="???",
	},
	old_military_helmet={
		sprite=83,
		name="old military helmet",
		description="???",
	},
	bag_of_nails={
		sprite=114,
		name="bag of nails",
		description="???",
	},
	-- garage
	dangerous_material={
		sprite=0,
		name="dangerous material",
		description="???",
	},
	rifle={
		sprite=69,
		name="rifle with 6 ammo",
		description="???",
	},
	pinup_calendar={
		sprite=0,
		name="pinup calendar",
		description="miss december has\ndefinitely changed a\nlot since",
	},
	energy_drink={
		sprite=0,
		name="energy drink",
		description="???",
	},
	tool_bag={
		sprite=84,
		name="tool bag",
		description="???",
	},
	gasoline={
		sprite=115,
		name="gasoline",
		description="???"
	}
}

-- buildings

-- every simple building
normal_building = {
	name="simple building",
	objects={
		objects.trap,
		objects.kitchen_knife,
		objects.toothpaste,
		objects.bandage,
		objects.survival_book,
		objects.brick,
	}
}

-- graveyard is a special area
-- and cannot be selected randomly
graveyard = {
	name="graveyard",
	objects={
		objects.embittered_deceased,
		objects.gravedigger_shovel,
		objects.flower_wreath,
		objects.matches,
		objects.old_military_helmet,
		objects.bag_of_nails,
	}
}

-- those buildings can be picked randomly
special_buildings = {
	{
		name="sanitarium",
		objects={
			objects.hungry_patient,
			objects.oxygen_bomb,
			objects.straitjacket,
			objects.care_kit,
			objects.stethoscope,
			objects.antibiotics,
		}
	},
	{
		name="police station",
		objects={
			objects.cell_door,
			objects.gun,
			objects.stale_donuts,
			objects.cocain_bag,
			objects.bulletproof_vest,
			objects.cb_radio,
		}
	},
	{
		name="garage",
		objects={
			objects.dangerous_material,
			objects.rifle,
			objects.pinup_calendar,
			objects.energy_drink,
			objects.tool_bag,
			objects.gasoline,
		}
	}
}

-- squares layouts
layouts = {
	{
		mapping={x=15,y=0},
		buildings={
			{
				id="1-1",
				is="special",
				rects={{1,1,3,3}}
			},
			{
				id="1-2",
				is="normal",
				rects={{1,5,2,6}}
			},
			{
				id="1-3",
				is="normal",
				rects={
					{5,3,6,6},
					{4,5,6,6}
				}
			},
		}
	},
	{
		mapping={x=21,y=0},
		buildings={
			{
				id="2-1",
				is="special",
				rects={
					{1,1,2,6},
					{3,3,4,4},
					{5,1,6,6}
				}
			},
		}
	},
	{
		mapping={x=27,y=0},
		buildings={
			{
				id="3-1",
				is="graveyard",
				rects={{1,1,6,6}}
			}
		}
	},
	{
		mapping={x=15,y=6},
		buildings={
			{
				id="4-1",
				is="special",
				rects={{1,1,4,2}}
			},
			{
				id="4-2",
				is="normal",
				rects={{5,1,6,6}}
			},
			{
				id="4-3",
				is="normal",
				rects={
					{1,4,3,5},
					{2,6,3,6}
				}
			}
		}
	},
	{
		mapping={x=21,y=6},
		buildings={
			{
				id="5-1",
				is="normal",
				rects={{1,1,2,3}}
			},
			{
				id="5-2",
				is="special",
				rects={
					{4,1,6,4},
					{1,5,6,6}
				}
			}
		}
	},
}

-- players jobs
jobs = {
	builder={
		name="builder",
		sprite=1,
		action={
			name="barricade",
			description="build a barricade",
			sprite=54,
		},
	},
	thief={
		name="thief",
		sprite=3,
		action={
			name="steal",
			description="pick the item you want\nwhen you search a\nbuilding",
			sprite=58,
		},
	},
	doctor={
		name="doctor",
		sprite=5,
		action={
			name="heal",
			description="heal an another player",
			sprite=52,
		},
	},
	actor={
		name="actor",
		sprite=7,
		action={
			name="act",
			description="act like a zombie to\navoid fight",
			sprite=55,
		},
	},
	trader={
		name="trader",
		sprite=9,
		action={
			name="hide",
			description="hide in a building to\navoid fight",
			sprite=56,
		},
	},
	minesweeper={
		name="minesweeper",
		sprite=17,
		action={
			name="bomb",
			description="build a bomb that will\nexplode zombies",
			sprite=53,
		},
	},
	priest={
		name="priest",
		sprite=19,
		action={
			name="pray",
			description="pray to randomly heal\nyourself or kill\nzombies",
			sprite=57,
		},
	},
}
	
actions = {
	{
		name="move",
		description="move the player",
	},
	{
		name="search",
		description="search for items in a\nbuilding",
	},
	{
		name="inventory",
		description="watch your inventory",
	},
	{
		name="fight",
		description="fight zombies",
	},
	{
		name="exchange",
		description="exchange items with an\nanother player",
	},
	{
		name="special",
		description="job special action",
	},
	{
		name="turn end",
		description="end the current turn",
	},
}

__gfx__
00000000eeaaa1eeeeaaa1eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000555555555555555555555555
00000000eeffff1eeeffff1eee00001eee00001eeeffff1eeeffff1eeeffff1eeeffff1eeeffff1eeeffff1e0770770007770000555555555555555555566555
00700700eef1f11eeef1f11eee01f11eee01f11eeef1f11eeef1f11eeef1f11eeef1f11eeef1f11eeef1f11e7887887079997000555555555555555555566555
00077000eeffff1eeeffff1eee00001eee00001eeecccc1eeecccc1eeeffff1eeeffff1eeeffff1eeeffff1e7e88887079797000555555555666666555566555
00077000eec9c1eeeec9c1eeee0001eeee0001eeee7771eeee7771eeeeaaa1eeeeaaa1eeee0091eeee0091ee7888887079997000555555555666666555566555
00700700eccccc1eeeccc1eee000001eee0001eeef777f1eee7771eeefaaaf1eeeaaa1eeef009f1eee0091ee0788870079797000555555555555555555566555
00000000eeccc1eeeeccc1eeee0001eeee0001eeee6661eeee6661eeeeccc1eeeeccc1eeeeddd1eeeeddd1ee0078700079797000555555555555555555566555
00000000eec1c1eeeeec1eeeee0101eeeee01eeeee6161eeeee61eeeeec1c1eeeeec1eeeeed1d1eeeeed1eee0007000077077000555555555555555555555555
88800888ee33331eee33331eeeeeeeeeeeeeeeee000000000000000000000000000000000000000000000000eeeeeeeeeeeeeeee555555555555555555555555
80000008e3c7cc31e3c7cc31eeffff1eeeffff1e000000000000000000000000000000000000000000000000eedddd1eeedddd1e555555555555555555555555
80000008e371c131e371c131eef1f11eeef1f11e000000000000000000000000000000000000000000000000eedddd1eeedddd1e555555555555555555555555
00000000e3ccc731e3ccc731eeffff1eeeffff1e000000000000000000000000000000000000000000000000eedddd1eeedddd1e555666655666666556666555
00000000ee3331eeee3331eeee0071eeee0071ee000000000000000000000000000000000000000000000000eeddd1eeeeddd1ee555666655666666556666555
80000008e333331eee3331eeef000f1eee0001ee000000000000000000000000000000000000000000000000eddddd1eeeddd1ee555665555556655555566555
80000008ee3331eeee3331eeee0001eeee0001ee000000000000000000000000000000000000000000000000eeddd1eeeeddd1ee555665555556655555566555
88800888ee3131eeeee311eeee0101eeeee01eee000000000000000000000000000000000000000000000000eed1d1eeeee1d1ee555555555555555555555555
88000088eeeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000eeeeeeee555555555555555555555555
80000008ee33331eee33331e000000000000000000000000000000000000000000000000000000000000000000077000eeeeeeee555665555556655555566555
00000000ee3a3a1eee3a3a1e00000000000000000000000000000000000000000000000000000000000000000000000099599599555665555556655555566555
00000000ee33331eee33331e00000000000000000000000000000000000000000000000000000000000000000007700095995995555666655666666556666555
00000000ee3831eeee3831ee00000000000000000000000000000000000000000000000000000000000000000007700059959959555666655666666556666555
00000000e333331eee3331ee00000000000000000000000000000000000000000000000000000000000000000007700019111191555665555556655555566555
80000008ee3381eeee3381ee000000000000000000000000000000000000000000000000000000000000000000077070e9eeee9e555665555556655555566555
88000088ee3131eeeee31eee000000000000000000000000000000000000000000000000000000000000000000000000919ee919555555555555555555555555
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eeeeeeee555555555555555555555555
000070000070000000770000007777000777777000000070000000000777777000700700000770000077770007770000eeeeeeea555665555556655555566555
000077000777777007007000007000000770077000777500070770700777777000700700007777000000700000700770eeeeee41555665555556655555566555
077777700070000007007000007000000700007007007700007707700705705000700700007777000007700000700700eee0041e555666655666666556666555
077777700000070000775000007700000700007007777700077077700777777000777700000770000077770000700770ee06001e555666655666666556666555
000077000777777000000700007000000770077007777700007007000777777000700700000770000777777000700700ee00001e555555555555555555555555
000070000000070000000070007007000777777000777000007007000070070000700700000770000777777000000770ee1001ee555555555555555555555555
000000000000000000000000000000000000000000000000000000000007700000000000000000000000000000000000eee11eee555555555555555555555555
00000000000000000000000000000000440000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000404000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000054445500000000000000006044000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000
7777744409888940cccccc6066666460000400600006000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0077700008889850cccccc6700060440000046666066000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001111115000006440000065660446000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000440000566664400000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000055554400000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600600044444700500005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0000c0044444700510055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0000c0044844700551155000066600000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0000c0048884700155555000766650008008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c00c00044844700151155006666550888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000cc000044444700155555000500500666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060006044444700151155000050500868888680000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006660044444600111111000005000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000060000066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00776660000770000000606000dddd10000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777660007007000006050000ddd910008048000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777660777777770060006000ddad10004849000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777660666666660600000600daa910004949000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777660767887670677777600ddad10004949000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777660778888770577777500dadd10004949000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00776660777887770055555000ddd110004909000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000005500000066660088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000056650666006006800800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077eee00055556650055506008888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
777eeee0500005500065006008e88e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
066888000500000000650000088e8880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0077ccc055555555000560500888e880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777cccc565656650666655008e88e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0066ddd0555555550000605008888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55666666666666666666665555999999999999999999995555cccccccccccccccccccc5555888888888888888888885500000000000000000000000000000000
5766666666666666666666755a99999999999999999999a557cccccccccccccccccccc755e88888888888888888888e500000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666660000000066666677aa99999900000000999999aa77cccccc00000000cccccc77ee88888800000000888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
776666666666666666666677aa99999999999999999999aa77cccccccccccccccccccc77ee88888888888888888888ee00000000000000000000000000000000
77dddddddddddddddddddd77aa44444444444444444444aa771111111111111111111177ee22222222222222222222ee00000000000000000000000000000000
7dddddddddddddddddddddd7a4444444444444444444444a711111111111111111111117e2222222222222222222222e00000000000000000000000000000000
dddddddddddddddddddddddd44444444444444444444444411111111111111111111111122222222222222222222222200000000000000000000000000000000
5553355555533555b333333344454444454444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5533b33555333b35b33b333b45444544446664540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
533333b5533b3333333b333b44444445466166440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
53b33355333333333b333b3345445444561116440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
553335553b3333333b333b3344444444466166450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55545555553333b5b333333b54445445466166440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5554555555544555b3b3333b44544444466666540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
555455555554455533b33b3344444544436336340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
88822888222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
82ffff18227727722277277222772772227727722277277222772772227772227772227772227772222222222277722222222222222222772222727722777222
82f1f118278878872788788727887887278878872788788727887887279997279997279997279997222222222227007272772277222222270227202702207022
22ffff1227e8888727e8888727e8888727e8888727e8888727e88887279797279797279797279797222222222227027070707270722222270227022702777022
22007122278888872788888727888887278888872788888727888887279997279997279997279997222222222227027070772070702222270227022702700022
8f000f18227888722278887222788872227888722278887222788872279797279797279797279797222222222227022770707270702222777272027772777222
82000128222787222227872222278722222787222227872222278722279797279797279797279797222222222222022200202020202222200020222000200022
70000000888802222222722222227222222272222222722222227222277277277277277277277277222222222222222222222222222222222222222222222222
07000000888808885555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
0070000088880f185555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555ffff15
07000000888801185555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555f1f115
7000000088880f155666666556666665566666655666666556666665566666655666666556666665566666655666666556666665566666655666666556ffff15
00000000000001655666666556666665566666655666666556666665566666655666666556666665566666655666666556666665566666655666666556aaa155
177777718f000f18555555555555555555555555555555555555555555555555555665555555555555555555555555555555555555555555555555555faaaf15
17777771850001585555555555555555555555555555555555555555555555555556655555555555555555555555555555555555555555555555555555ccc155
11117711880101885555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555c1c155
11117111555555555566666666666666666666555555555555533555555335555555555555999999999999555553355555533555559999999999995555555555
1111111155566555576666666666666666666675555555555533b33555333b35555665555a999999999999a555333b355533b3355a999999999999a555566555
111111115556655577666666666666666666667755555555533333b5533b333355566555aa999999999999aa533b3333533333b5aa999999999999aa55566555
11111111555665557766666666666666666666775555555553b333553333333355566555aa999999999999aa3333333353b33355aa999999999999aa55566555
111111115556655577666666666666666666667755555555553335553b33333355566555aa999999999999aa3b33333355333555aa999999999999aa55566555
11771111555665557766666666666666666666775555555555545555553333b555566555aa999999999999aa553333b555545555aa999999999999aa55566555
171171115556655577666666666666666666667755555555555455555554455555566555aa999999999999aa5554455555545555aa999999999999aa55566555
171171115555555577666666666666666666667755555555555455555554455555555555aa999999999999aa5554455555545555aa999999999999aa55555555
117751115555555577666666666666666666667755555555555335555553355555555555aa999999999999aa5553355555533555aa999999999999aa55555555
1111171155566555776666666666666666666677555555555533b3355533b33555566555aa999999999999aa5533b33555333b35aa999999999999aa55ffff15
111111715556655577666666666666666666667755555555533333b5533333b555566555aa999999999999aa533333b5533b3333aa999999999999aa55f1f115
11111111555665557766666666666666666666775555555553b3335553b3335555566555aa999999999999aa53b3335533333333aa999999999999aa55ffff15
111111115556655577666666666666666666667755555555553335555533355555566555aa999999999999aa553335553b333333aa999999999999aa55009155
111111115556655577666666666666666666667755555555555455555554555555566555aa999999999999aa55545555553333b5aa999999999999aa5f009f15
111111115556655577666666666666666666667755555555555455555554555555566555aa999999999999aa5554555555544555aa999999999999aa55ddd155
117777115555555577666666666666666666667755555555555455555554555555555555aa999999999999aa5554555555544555aa999999999999aa55d1d155
117111115555555577666666666666666666667755555555556666666666665555555555aa99999999999999999999999999999999999999999999aa55555555
117111115556655577666666666666666666667755555555576666666666667555566555aa99999999999999999999999999999999999999999999aa55566555
117711115556655577666666666666666666667755555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
117111115556655577666666666666666666667755555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
117117115556655577666666666666666666667755555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
111111115556655577dddddddddddddddddddd7755555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
11111111555665557dddddddddddddddddddddd755555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
1111111155555555dddddddddddddddddddddddd55555555776666666666667755555555aa99999999999999999999999999999999999999999999aa55555555
111111115555555555555555555555555555555555555555776666666666667755555555aa99999999999999999999999999999999999999999999aa55555555
117111115556655555555555555555555555555555555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
177777715556655555555555555555555555555555555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
117111115556655555555555555555555555555555555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
111117115556655555555555555555555555555555555555776666666666667755566555aa99999999999999999999999999999999999999999999aa55566555
177777715556655555555555555555555555555555555555776666666666667755566555aa99999999999999444444444444444499999999999999aa55566555
111117115556655555555555555555555555555555555555776666666666667755566555aa99999999999999444444444444444499999999999999aa55566555
111111115555555555555555555555555555555555555555776666666666667755555555aa99999999999999444444444444444499999999999999aa55555555
111111115555555555666666666666555555555555666666666666666666667755555555aa999999999999aa5553355555533555aa999999999999aa55555555
111111115556655557666666666666755555555557666666666666666666667755566555aa999999999999aa55333b355533b335aa999999999999aa55566555
eeeeeeee5556655577666666666666775555555577666666666666666666667755566555aa999999999999aa533b3333533333b5aa999999999999aa55566555
eee77eee5556655577666666666666775555555577666666666666666666667755566555aa999999999999aa3333333353b33355aa999999999999aa55566555
ee7777ee5556655577666666666666775555555577666666666666666666667755566555aa999999999999aa3b33333355333555aa999999999999aa55566555
ee7777ee5556655577666666666666775555555577666666666666666666667755566555aa999999999999aa553333b555545555aa999999999999aa55566555
eee77eee5556655577666666666666775555555577666666666666666666667755566555aa999999999999aa5554455555545555aa999999999999aa55566555
eee77eee5555555577666666666666775555555577666666666666666666667755555555aa999999999999aa5554455555545555aa999999999999aa55555555
eee77eee5555555577666666666666775555555577666666666666666666667755555555aa999999999999aa5553355555533555aa999999999999aa55555555
eeeeeeee5556655577666666666666775555555577666666666666666666667755566555aa999999999999aa5533b3355533b335aa999999999999aa55566555
eeeeeeee5556655577666666666666775555555577666666666666666666667755566555aa999999999999aa533333b5533333b5aa999999999999aa55566555
111111115556655577666666666666775555555577666666666666666666667755566555aa999999999999aa53b3335553b33355aa999999999999aa55566555
111111115556655577666666666666775555555577666666666666666666667755566555aa999999999999aa5533355555333555aa999999999999aa55566555
111111115556655577dddddddddddd775555555577dddddddddddddddddddd7755566555aa444444444444aa5554555555545555aa444444444444aa55566555
11111111555665557dddddddddddddd7555555557dddddddddddddddddddddd755566555a44444444444444a5554555555545555a44444444444444a55566555
1111111155555555dddddddddddddddd55555555dddddddddddddddddddddddd5555555544444444444444445554555555545555444444444444444455555555
11111111555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
11111111555665555555555555555555555555555555555555555555555555555556655555555555555555555555555555555555555555555555555555566555
11111111555665555555555555555555555555555555555555555555555555555556655555555555555555555555555555555555555555555555555555566555
11111111555666655666666556666665566666655666666556666665566666655666666556666665566666655666666556666665566666655666666556666555
11111111555666655666666556666665566666655666666556666665566666655666666556666665566666655666666556666665566666655666666556666555
11111111555665555555555555555555555555555555555555555555555555555556655555555555555555555555555555555555555555555555555555566555
11111111555665555555555555555555555555555555555555555555555555555556655555555555555555555555555555555555555555555555555555566555
11111111555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
11111111555555555566666666666666666666555555555555533555555335555555555555666666666666666666665555555555555335555553355555555555
1111111155566555576666666666666666666675555555555533b33555333b3555566555576666666666666666666675555555555533b33555333b3555566555
111111115556655577666666666666666666667755555555533333b5533b33335556655577666666666666666666667755555555533333b5533b333355566555
11111111555665557766666666666666666666775555555553b3335533333333555665557766666666666666666666775555555553b333553333333355566555
111111115556655577666666666666666666667755555555553335553b3333335556655577666666666666666666667755555555553335553b33333355566555
11111111555665557766666666666666666666775555555555545555553333b5555665557766666666666666666666775555555555545555553333b555566555
11111111555665557766666666666666666666775555555555545555555445555556655577666666666666666666667755555555555455555554455555566555
11111111555555557766666666666666666666775555555555545555555445555555555577666666666666666666667755555555555455555554455555555555
11111111555555557766666666666666666666775555555555533555555335555555555577666666666666666666667755555555555335555553355555555555
1111111155566555776666666666666666666677555555555533b3355533b33555566555776666666666666666666677555555555533b3355533b33555566555
111111115556655577666666666666666666667755555555533333b5533333b55556655577666666666666666666667755555555533333b5533333b555566555
11111111555665557766666666666666666666775555555553b3335553b33355555665557766666666666666666666775555555553b3335553b3335555566555
11111111555665557766666666666666666666775555555555333555553335555556655577666666666666666666667755555555553335555533355555566555
11111111555665557766666666666666666666775555555555545555555455555556655577666666666666666666667755555555555455555554555555566555
11111111555665557766666666666666666666775555555555545555555455555556655577666666666666666666667755555555555455555554555555566555
11111111555555557766666666666666666666775555555555545555555455555555555577666666666666666666667755555555555455555554555555555555
11111111555555557766666666666666666666775555555555666666666666555555555577666666666666666666667755555555556666666666665555555555
11111111555665557766666666666666666666775555555557666666666666755556655577666666666666666666667755555555576666666666667555566555
11111111555665557766666666666666666666775555555577666666666666775556655577666666666666666666667755555555776666666666667755566555
11111111555665557766222222222222222222275555555577666666666666775556655577666666666666666666667755555555776666666666667755566555
11111111555665557766227772777277727272275555555577666666666666775556655577666666666666666666667755555555776666666666667755566555
111111115556655577dd227272727272727272211555555577666666666666775556655577dddddddddddddddddddd7755555555776666666666667755566555
11111111555665557ddd22777277227772777221155555557766666666666677555665557dddddddddddddddddddddd755555555776666666666667755566555
1111111155555555dddd2272227272727222722115555555776666666666667755555555dddddddddddddddddddddddd55555555776666666666667755555555
11111111555555555555227222727272727772211555555577666666666666775555555555555555555555555555555555555555776666666666667755555555
11111111555665555555222222222222222222211555555577666666666666775556655555555555555555555555555555555555776666666666667755566555
11111111555665555555551111111111111111111555555577666666666666775556655555555555555555555555555555555555776666666666667755566555
11111111555665555555551111111111111111111555555577666666666666775556655555555555555555555555555555555555776666666666667755566555
11111111555665555555222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222667755566555
11111111555665555555222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222667755566555
11111111555665555555227772777277727272222277722772222277727772772277222772777272227272222272727772777272222222222222117755566555
11111111555555555555227272727272727272222227227272222272727272727272727272777272227272222272727222727272222222222222117755555555
11111111555555555566227772772277727772222227227272222277227772727272727272727272227772222277727722777272222222222222117755555555
11111111555665555766227222727272722272222227227272222272727272727272727272727272222272222272727222727272222222222222117755566555
11111111555665557766227222727272727772222227227722222272727272727277727722727277727772222272727772727277722222222222117755566555
11111111555665557766222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222117755566555
11111111555665557766227272277272727772277277727222777222222772777222227272777272227222222222222222222222222222222222117755566555
11111111555665557766227272727272727272722272227222722222227272727222227272272272227222222222222222222222222222222222117755566555
11111111555665557766227772727272727722777277227222772222227272772222227722272272227222222222222222222222222222222222117755566555
11111111555555557766222272727272727272227272227222722222227272727222227272272272227222222222222222222222222222222222117755555555
11111111555555557766227772772227727272772277727772722222227722727222227272777277727772222222222222222222222222222222117755555555
11111111555665557766222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222117755566555
11111111555665557766227772277277727772777277722772222222222222222222222222222222222222222222222222222222222222222222117755566555
11111111555665557766222272727277727272272272227222222222222222222222222222222222222222222222222222222222222222222222117755566555
11111111555665557766222722727272727722272277227772222222222222222222222222222222222222222222222222222222222222222222117755566555
111111115556655577dd227222727272727272272272222272222222222222222222222222222222222222222222222222222222222222222222117755566555
11111111555665557ddd22777277227272777277727772772222222222222222222222222222222222222222222222222222222222222222222211d755566555
1111111155555555dddd22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222211dd55555555
11111111555555555555222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222115555555555
17771111555665555555551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111115555ffff15
11711771555665555555551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111115555f1f115
11711711555666655666666556666665566666655666666556666665566666655666666556666665566666655666666556666665566666655666666556cccc15
11711771555666655666666556666665566666655666666556666665566666655666666556666665566666655666666556666665566666655666666556777155
1111171155555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555f777f15
11111771555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555666155
11111111555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555616155

__gff__
0000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202020202020202020000000002000202000202000202000200000000020202020202020202020202000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1d0e0e0e0e0e0e1e0e0e0e0e0e0e1f8687880fb0b18385b1b08385b2b2b2b2b2b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f9687980fb1b09395b0b19395b2b4b4b4b4b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0fa6a7a80f8082938484848495b2b4b4b4b4b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f0e0e1e3f90929384a4a48495b2b4b4b4b4b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f80820f8081929395b1b09395b2b4b4b4b4b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0fa0a20fa0a1a2a3a5b0b1a3a5b2b2b2b2b2b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f898a8a8b808280820f8687880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2d0e0e0e0e0e0e2e0e0e0e0e0e0e2fa9aaaaab909290920f9687980000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f0e0e0e1f9092a0a20f9687980000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f8081820f90920e0e3f9687980000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0fa081920f90928687878787980000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0fb0a0a20fa0a2a6a7a7a7a7a80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0d0d0d0d0d0d0f0d0d0d0d0d0d0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3d0e0e0e0e0e0e3e0e0e0e0e0e0e3f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
