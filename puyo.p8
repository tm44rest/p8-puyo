pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- pico-puyo
-- by rest

-- test comment

-- globals --
-------------
_upd=nil
_drw=nil

debug={}
dirx={-1,1,0,0,1,-1,-1,1}
diry={0,0,-1,1,-1,-1,1,1}
diropp={1,0,3,2}
rotcw={2,3,1,0}
rotccw={3,2,0,1}
pool={}
board={}
falling={}
to_pop={}
chain_cnt=0 -- used for counting chains
btn_hld=nil
btn_dur=8	-- delay until repeat
double_tap=0 --used for rotation

-- falling puyo
init_vel=1 -- 1 pixel/frame
term_vel=8
gravity=.1875
f_off=0
f_vel=0

-- player --
------------
p_x=3
p_y=1
p_m=nil				--master puyo
p_s=nil				--slave puyo
p_sm=nil			--master sprite
p_ss=nil 		--slave sprite
p_sdir=nil --slave direction
p_t=0
p_grace=32
p_num=1
p_wait=false
p_ani=0


-- main functions --
--------------------

function _init()
 
 for i=1,6 do
 	board[i]={}
 end
 
 for i=0,255 do
 	pool[i+1]=i%4
 end
 shuffle(pool)
 
 p_m=pool[p_num]
 p_s=pool[p_num+1]
 p_sdir=2
 p_sm=p_m*16+1
 p_ss=p_s*16+1
 
 _upd=upd_plyr_ctrl
end

function _update60()
	_upd()
end

function _draw()
	cls()
	map()
 if _upd==upd_plyr_ctrl then
		o_spr(p_sm,p_x*8,p_y*8)
		spr(p_ss,(p_x+dirx[p_sdir+1])*8,(p_y+diry[p_sdir+1])*8)
 end
	for i=1,6 do
		for j=1,13 do
			local sp=board[i][j]
			if (sp) spr(sp,i*8,j*8)
		end
	end
	
	local off=0
	if (f_off>=8) off=4
	for p in all(falling) do
		spr(p.n,p.x*8,(p.y-1)*8+off)
	end
	
	for s in all(debug) do
		print(s)
	end
end
-->8
-- updates

function upd_plyr_ctrl()
	local btn_dir = get_btn_dir()

	if btn_dir==⬇️ then
		p_t+=8
	else
		p_t+=1
	end
	if p_t>=16 then
		if try_move(⬇️) then p_t=0
		else 
			if p_grace<=0 or btn_dir==⬇️ then
				place_ctrld()
			else
				p_grace-=1
			end
		end
	end
	if (btn_dir==⬅️) try_move(⬅️)
	if (btn_dir==➡️) try_move(➡️)
	if (btnp(🅾️)) rotate(false)
	if (btnp(❎)) rotate(true)
end

function upd_fall()
	--todo: split and chain falling
	-- have different frame data.
	-- seperate these into two fns
	if count(falling)==0 then
		_upd=upd_wait
		return
	end

	f_off+=f_vel
	f_vel+=gravity
	if (f_vel>=term_vel) f_vel=term_vel
	
	if f_off>=16 then
		f_off=0
		for p in all(falling) do
			if is_unobstructed(0,p.x,p.y+1) then
				p.y+=1
			else 
				place(p)
				del(falling,p)
			end
		end
	end
end

function upd_wait()
	if p_ani<=32 then
		p_ani+=1
	else
		p_ani=0
		find_pop()
		if count(to_pop)==0 then
			_upd=upd_plyr_ctrl
		else
			_upd=upd_pop
		end
	end
end

function mem(t,v)
	for u in all(t) do
		if (u==v) return true
	end
	return false
end

function upd_pop()
	--todo: not tsu accurate
	if count(to_pop)~=0 then
		local to_fall = {}
		for c in all(to_pop) do
			for p in all(c) do
				board[p.x][p.y]=nil
				if not mem(to_fall,p.x) then
					-- is there an easier way
					-- to add each column once?
					add(to_fall,p.x)
					add_fall(p.x)
				end
			end
		end
	end
	
	start_chainfall()
end
-->8
-- draws
-->8
-- helper functions --

function o_spr(s,x,y)
	for i=1,15 do
		pal(i,7)
	end
	for i=1,8 do
		spr(s,x+dirx[i],y+diry[i])
	end
	for i=1,15 do
		pal(i,i)
	end
	spr(s,x,y)
end

function shuffle(pool)
	for i=1,256 do
		local j=flr(rnd(255)+1)
		swap(pool,i,j)
	end
end

function swap(t,i,j)
	local temp=t[i]
	t[i]=t[j]
	t[j]=temp
end

-- begins the falling state
-- after split
function start_fall()
	f_off=0
	f_vel=init_vel
	_upd=upd_fall
end

-- begins the falling state
-- after chain
function start_chainfall()
	f_off=0
	f_vel=term_vel
	_upd=upd_fall
end

-- adds all puyos in column to
-- the falling list.
-- only call once per column
-- or you get duplicates
function add_fall(column)
	for row=2,12 do
		local n=board[column][row]
		if n~=nil then
			add(falling,{x=column,y=row,n=n})
		end
	end
end
-->8
-- controls --
--------------

-- rotate function using tsu
-- frame data taken from
-- https://puyonexus.com/wiki/puyo_puyo_tsu/rotation,_collision_and_push_back
function rotate(clockwise)
 -- target cell coords
 local trgt_dir=-1
	if clockwise then
		trgt_dir=rotcw[p_sdir+1]
	else
	 trgt_dir=rotccw[p_sdir+1]
	end
	local trgt_x=p_x+dirx[trgt_dir+1]
	local trgt_y=p_y+diry[trgt_dir+1]
	
	-- target cell check
	if not is_unobstructed(0,trgt_x,trgt_y) then
		-- current row check (ghost cells)
	 if p_y<2 then
	 	if trgt_dir==2 or trgt_dir==3 then
	 		return
	 	end
	 end
	 
	 -- 0pposite cell check
	 local opp_dir=diropp[trgt_dir+1]
	 local opp_x=p_x+dirx[opp_dir+1]
		local opp_y=p_y+diry[opp_dir+1]
		local opp_free=is_unobstructed(0,opp_x,opp_y)
		local double_rotation=false
		if not opp_free then
			-- double rotation check
			double_tap+=1
			if double_tap%2==0 then
				double_rotation=true
				p_t=7
			else
				return
			end
		end
		-- push back
		if opp_free then
			p_x,p_y=opp_x,opp_y
		else
			if double_rotation then
				p_y+=diry[p_sdir+1]
				trgt_dir=diropp[p_sdir+1]
			end	
		end
	end
	
	-- rotation acknowledgement
	double_tap=0
	p_sdir=trgt_dir
end


function try_move(d)
	local destx_mast,desty_mast=p_x+dirx[d+1],p_y+diry[d+1]
	local destx_slav,desty_slav=destx_mast+dirx[p_sdir+1],desty_mast+diry[p_sdir+1]
	
	if is_unobstructed(0,destx_mast,desty_mast)
	and is_unobstructed(0,destx_slav,desty_slav)
	then
		p_x+=dirx[d+1]
		p_y+=diry[d+1]
		if (d==0 or d==1) sfx(0)
		return true
	end
	return false
end

function get_btn_dir()
	local b=nil
	i=0
	while b==nil and i<=3 do
		if btn(i) then b=i end
		i+=1
	end
	
	
	if (b==0 or b==1) and btn_hld==b then
		btn_dur-=1
		if btn_dur<=0 then
			btn_dur=2
			return b
		else
			return nil
		end
	else
		btn_dur=8
		btn_hld=b
		return b
	end
	
end

-->8
-- board --
-----------

function place(puyo)
	board[puyo.x][puyo.y]=puyo.n
end

function place_ctrld()
	local p_sx,p_sy=p_x+dirx[p_sdir+1],p_y+diry[p_sdir+1]
	
	if is_unobstructed(0,p_x,p_y+1) and p_y==p_sy then
		add(falling,{x=p_x,y=p_y+1,n=p_sm})
		board[p_sx][p_sy]=p_ss
	elseif is_unobstructed(0,p_sx,p_sy+1) and p_sy==p_y then
		add(falling,{x=p_sx,y=p_sy+1,n=p_ss})
		board[p_x][p_y]=p_sm
	else
		board[p_x][p_y]=p_sm
		board[p_sx][p_sy]=p_ss
	end
	
	p_num=(p_num+2)%256+1
	p_x=3
 p_y=1
 p_m=pool[p_num]
 p_s=pool[p_num+1]
 p_sdir=2
 p_sm=p_m*16+1
 p_ss=p_s*16+1
 p_grace=32
 p_t=0
 double_tap=0
 
 sfx(2)
 start_fall()
end

function find_pop()
	local checked={}
	for i=1,6 do
		checked[i]={}
		for j=2,13 do
			checked[i][j]=false
		end
	end
	
	for i=1,6 do
		for j=2,13 do
			chain_cnt=0
			local chain=dfs(checked,{},1,i,j)
			if chain~=nil then
				add(to_pop,chain)
			end
		end
	end
end

function dfs(checked,chain,cnt,x,y)
	--if (board[x][y]~=nil) print(x..","..y)
	checked[x][y]=true
	add(chain,{x=x,y=y})
	chain_cnt+=1
	
	for p in all(neighbors(x,y)) do
		if not checked[p.x][p.y] then
			--print("--"..p.x .. "," .. p.y)
			dfs(checked,chain,cnt,p.x,p.y)
		end
	end
	
	if chain_cnt>=4 then
		return chain
	else
		return nil
	end
end

function neighbors(x,y)
	local adj={}
	for d=0,3 do
		local tx,ty=x+dirx[d+1],y+diry[d+1]
		if in_board(0,tx,ty)
		and board[tx][ty]~=nil
		and board[x][y]==board[tx][ty] then
			add(adj,{x=tx,y=ty})
		end
	end
	for p in all(adj) do
		--print("-"..p.x..","..p.y)
	end
	return adj
end 

function in_ghost_board(plyr,x,y)
	if plyr==0 then
		return x>=1 and x<=6 and y<=13
	else
		return true
	end
end

function in_board(plyr,x,y)
	if plyr==0 then
		return in_ghost_board(0,x,y) and y>=2
	else
		return true
	end
end

function is_unoccupied(x,y)
	return board[x][y]==nil
end

function is_unobstructed(plyr,x,y)
 return in_ghost_board(plyr,x,y) and is_unoccupied(x,y)
end

__gfx__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31011110000
000000000888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31011111001
007007008288822000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31011111101
000770008722272000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31011111001
000770008712172000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31011110100
007007008778772000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31000101111
000000008888882000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31010011111
000000000222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013b7b31001001110
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666600000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100100000000
6666665000aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110100000000
67767750071a17000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100111111001
67161750a17a71900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010011110100
67161750a77a77900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100101111
66666650aaaaaa900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111110011111
05555500099999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111001001110
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000ccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000cccccc500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c55c55500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001001
00000000571c17500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100
00000000c71c17500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111
000000000cccc5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111
00000000005555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000bbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b71b17300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b71b17300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000b77b77300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbb300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbb300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000033333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e2f1f1f1f1f1f0e0e2f1f1f1f1f1f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e00000020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e1e0f0f0f0f0f0e0e1e0f0f0f0f0f0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
__sfx__
000100003072030720307203072030720367001670013700117000e70014500155001050000000000000000012700147001570016700177001570012700167001670000000000000000000000000000000000000
00010000016200262004620076200f6201d2001d20016000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001732012320103200d3200d2200d2200d2200d2200d22012320153201b32022320283202130028300293000c4000000000000000000000000000000000000000000000000000000000000000000000000
000500000000033050380503a0503b0503c0503a05038050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
