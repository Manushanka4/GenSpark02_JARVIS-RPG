import json;
import random;

walker Stage10V1 {
  has seed: int = 1234;          # starting seed for run 0
  has seed_step: int = 1;        # add this per run
  has runs: int = 50;            # how many runs to do
  has out_jsonl: str = "stage10_v1.jsonl";  # output file (append)
  has echo_stdout: bool = False; # also print to console if true

  has base_level: int = 2;       # next level after this is 3
  has base_diff: int = 1;        # starting difficulty

  # formatting helpers
  def fmt_pos(p: dict) -> str {
    return "Position(x=" + str(p["x"]) + ", y=" + str(p["y"]) + ")";
  }

  def fmt_wall(seg: dict) -> str {
    return "Wall(start_pos=" + self.fmt_pos(seg["start_pos"]) + ", end_pos=" + self.fmt_pos(seg["end_pos"]) + ")";
  }

  def fmt_level_text(level: dict) -> str {
    txt = "Level(name=" + str(level["name"]);
    txt = txt + ", difficulty=" + str(level["difficulty"]);
    txt = txt + ", time=" + str(level["time"]);
    txt = txt + ", width=" + str(level["width"]);
    txt = txt + ", height=" + str(level["height"]);
    txt = txt + ", num_wall=" + str(level["num_wall"]);
    txt = txt + ", num_enemies=" + str(level["num_enemies"]);
    txt = txt + ")";
    return txt;
  }

  def fmt_map_tiles_text(level_txt: str, walls: list, small_obstacles: list, enemies: list, player_pos: dict) -> str {
    # build walls text
    wtxt = ""; i = 0;
    while i < len(walls) { if i > 0 { wtxt = wtxt + ", "; } wtxt = wtxt + self.fmt_wall(walls[i]); i = i + 1; }
    # small obstacles text
    sotxt = ""; j = 0;
    while j < len(small_obstacles) { if j > 0 { sotxt = sotxt + ", "; } sotxt = sotxt + self.fmt_pos(small_obstacles[j]); j = j + 1; }
    # enemies text
    etxt = ""; k = 0;
    while k < len(enemies) { if k > 0 { etxt = etxt + ", "; } etxt = etxt + self.fmt_pos(enemies[k]); k = k + 1; }

    return "Map_tiles(level=" + level_txt
         + ", walls=[" + wtxt + "]"
         + ", small_obstacles=[" + sotxt + "]"
         + ", enemies=[" + etxt + "]"
         + ", player_pos=" + self.fmt_pos(player_pos) + ")";
  }

  def write_jsonl_line(line: str) -> None {
    # write as UTF-8 (keeps the em dash in the system string)
    f = open(self.out_jsonl, "a", encoding="utf-8");
    f.write(line + "\n");
    f.close();
    if self.echo_stdout { print(line); }
  }

  # dataset rules
  def time_for_diff(d: int) -> int {
    if d == 1 { return 300; }
    elif d == 2 { return 7; }
    elif d == 3 { return 8; }
    elif d == 4 { return 15; }
    elif d == 5 { return 12; }
    else { return 20 + d; }
  }

  def small_obstacle_count(d: int) -> int {
    if d == 1 { return 4; }
    elif d == 2 { return 3; }
    elif d == 3 { return 4; }
    elif d == 4 { return 5; }
    elif d == 5 { return 6; }
    else { return 6; }
  }

  # geometry
  def bounds_segments(w: int, h: int) -> list {
    segs = [];
    segs.append({"start_pos": {"x": 0, "y": 0},       "end_pos": {"x": 0, "y": h - 1}});
    segs.append({"start_pos": {"x": 0, "y": 0},       "end_pos": {"x": w - 1, "y": 0}});
    segs.append({"start_pos": {"x": w - 1, "y": 0},   "end_pos": {"x": w - 1, "y": h - 1}});
    segs.append({"start_pos": {"x": 0, "y": h - 1},   "end_pos": {"x": w - 1, "y": h - 1}});
    return segs;
  }

  # quick sampler (allows overlaps; that’s fine here)
  def sample_positions(n: int, w: int, h: int) -> list {
    out = [];
    c = 0;
    while c < n {
      rx = random.randint(1, w - 2);
      ry = random.randint(1, h - 2);
      out.append({"x": rx, "y": ry});
      c = c + 1;
    }
    return out;
  }

  # level/mapping
  def make_level(prev_level_name: int, diff: int) -> dict {
    w = 10 + 2 * (diff - 1);
    h = 10 + 2 * (diff - 1);
    return {
      "name": prev_level_name + 1,
      "difficulty": diff,
      "time": self.time_for_diff(diff),
      "width": w,
      "height": h,
      "num_wall": 4 + diff,
      "num_enemies": 1 + diff
    };
  }

  def gen_map_for(level: dict) -> dict {
    w = int(level["width"]); h = int(level["height"]);
    diff = int(level["difficulty"]);

    # start with borders, then add diff short segments
    walls = self.bounds_segments(w, h);
    extra = diff;
    idx = 0;
    while idx < extra {
      vx = random.randint(1, w - 2);
      vy = random.randint(1, h - 2);
      if random.randint(0, 1) == 0 {
        a = {"x": vx, "y": vy};
        b = {"x": vx, "y": min(h - 2, vy + random.randint(1, 2))};
      } else {
        a = {"x": vx, "y": vy};
        b = {"x": min(w - 2, vx + random.randint(1, 2)), "y": vy};
      }
      walls.append({"start_pos": a, "end_pos": b});
      idx = idx + 1;
    }

    # player stays at (1,1)
    player_pos = {"x": 1, "y": 1};

    # small obstacles count depends on diff
    so_cnt = self.small_obstacle_count(diff);
    small_obstacles = self.sample_positions(so_cnt, w, h);

    # enemies sampled like obstacles
    enemies = self.sample_positions(int(level["num_enemies"]), w, h);

    return {
      "level": level,
      "walls": walls,
      "small_obstacles": small_obstacles,
      "enemies": enemies,
      "player_pos": player_pos
    };
  }

  # prev window for Stage-2
  # keep levels in [max(3,N-3) .. N], and maps up to N-1
  def window_prev_levels_text(all_levels: list, all_maps_text: list, N: int) -> tuple {
    start_name = N - 3;
    if start_name < 3 { start_name = 3; }

    pl_txt = "";
    pm_txt = "";

    # levels
    i = 0;
    while i < len(all_levels) {
      L = all_levels[i];
      name_i = int(L["name"]);
      if (name_i >= start_name) and (name_i <= N) {
        if len(pl_txt) > 0 { pl_txt = pl_txt + ", "; }
        pl_txt = pl_txt + self.fmt_level_text(L);
      }
      i = i + 1;
    }

    # maps (<= N-1)
    k = 0;
    while k < len(all_maps_text) {
      mtxt = all_maps_text[k];
      lvl_name = 0;
      idx = mtxt.find("Level(name=");
      if idx >= 0 {
        idx2 = mtxt.find(",", idx + 11);
        if idx2 > idx { lvl_name = int(mtxt[idx + 11:idx2].strip()); }
      }
      if (lvl_name >= start_name) and (lvl_name <= (N - 1)) {
        if len(pm_txt) > 0 { pm_txt = pm_txt + ", "; }
        pm_txt = pm_txt + mtxt;
      }
      k = k + 1;
    }

    return (pl_txt, pm_txt);
  }

  # one run (makes 10 JSONL lines)
  def do_one_run(run_idx: int) -> None {
    # new seed per run
    random.seed(self.seed + (run_idx * self.seed_step));

    system = "This is a task you must complete by returning only the output.\nDo not include explanations, code, or extra text—only the result.\n";

    levels = [];
    maps_text = [];

    # Level 3
    cur_level = self.base_level;   # 2
    diff = self.base_diff;         # 1
    stage1_input = "create_next_level\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[], prev_level_maps=[])\n"
                 + "last_levels = []\n"
                 + "difficulty = " + str(diff);

    L3 = self.make_level(cur_level, diff);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage1_input, "output": json.dumps(L3, ensure_ascii=False)}, ensure_ascii=False));
    levels.append(L3);

    # L3 map
    cur_level = int(L3["name"] - 1);   # 2
    stage2_input = "create_next_map\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[" + self.fmt_level_text(L3) + "], prev_level_maps=[])\n"
                 + "level = " + self.fmt_level_text(L3);

    map3 = self.gen_map_for(L3);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage2_input, "output": json.dumps(map3, ensure_ascii=False)}, ensure_ascii=False));
    maps_text.append(self.fmt_map_tiles_text(self.fmt_level_text(L3), map3["walls"], map3["small_obstacles"], map3["enemies"], map3["player_pos"]));

    # Level 4
    cur_level = int(L3["name"]);   # 3
    diff = self.base_diff + 1;     # 2
    stage1_input = "create_next_level\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[" + self.fmt_level_text(L3) + "], prev_level_maps=[" + maps_text[0] + "])\n"
                 + "last_levels = [" + self.fmt_level_text(L3) + "]\n"
                 + "difficulty = " + str(diff);

    L4 = self.make_level(cur_level, diff);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage1_input, "output": json.dumps(L4, ensure_ascii=False)}, ensure_ascii=False));
    levels.append(L4);

    # L4 map
    cur_level = int(L4["name"] - 1);   # 3
    (pl_txt, pm_txt) = self.window_prev_levels_text(levels, maps_text, int(L4["name"]));
    stage2_input = "create_next_map\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[" + pl_txt + "], prev_level_maps=[" + pm_txt + "])\n"
                 + "level = " + self.fmt_level_text(L4);

    map4 = self.gen_map_for(L4);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage2_input, "output": json.dumps(map4, ensure_ascii=False)}, ensure_ascii=False));
    maps_text.append(self.fmt_map_tiles_text(self.fmt_level_text(L4), map4["walls"], map4["small_obstacles"], map4["enemies"], map4["player_pos"]));

    # Level 5
    cur_level = int(L4["name"]);   # 4
    diff = self.base_diff + 2;     # 3
    stage1_input = "create_next_level\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[" + self.fmt_level_text(L3) + ", " + self.fmt_level_text(L4) + "], prev_level_maps=[" + maps_text[0] + ", " + maps_text[1] + "])\n"
                 + "last_levels = [" + self.fmt_level_text(L3) + ", " + self.fmt_level_text(L4) + "]\n"
                 + "difficulty = " + str(diff);

    L5 = self.make_level(cur_level, diff);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage1_input, "output": json.dumps(L5, ensure_ascii=False)}, ensure_ascii=False));
    levels.append(L5);

    # L5 map
    cur_level = int(L5["name"] - 1);   # 4
    (pl_txt, pm_txt) = self.window_prev_levels_text(levels, maps_text, int(L5["name"]));
    stage2_input = "create_next_map\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[" + pl_txt + "], prev_level_maps=[" + pm_txt + "])\n"
                 + "level = " + self.fmt_level_text(L5);

    map5 = self.gen_map_for(L5);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage2_input, "output": json.dumps(map5, ensure_ascii=False)}, ensure_ascii=False));
    maps_text.append(self.fmt_map_tiles_text(self.fmt_level_text(L5), map5["walls"], map5["small_obstacles"], map5["enemies"], map5["player_pos"]));

    # Level 6
    cur_level = int(L5["name"]);   # 5
    diff = self.base_diff + 3;     # 4
    stage1_input = "create_next_level\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[" + self.fmt_level_text(L4) + ", " + self.fmt_level_text(L5) + "], prev_level_maps=[" + maps_text[1] + ", " + maps_text[2] + "])\n"
                 + "last_levels = [" + self.fmt_level_text(L4) + ", " + self.fmt_level_text(L5) + "]\n"
                 + "difficulty = " + str(diff);

    L6 = self.make_level(cur_level, diff);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage1_input, "output": json.dumps(L6, ensure_ascii=False)}, ensure_ascii=False));
    levels.append(L6);

    # L6 map
    cur_level = int(L6["name"] - 1);   # 5
    (pl_txt, pm_txt) = self.window_prev_levels_text(levels, maps_text, int(L6["name"]));
    stage2_input = "create_next_map\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(diff)
                 + ", prev_levels=[" + pl_txt + "], prev_level_maps=[" + pm_txt + "])\n"
                 + "level = " + self.fmt_level_text(L6);

    map6 = self.gen_map_for(L6);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage2_input, "output": json.dumps(map6, ensure_ascii=False)}, ensure_ascii=False));
    maps_text.append(self.fmt_map_tiles_text(self.fmt_level_text(L6), map6["walls"], map6["small_obstacles"], map6["enemies"], map6["player_pos"]));

    # Level 7 
    cur_level = int(L6["name"]);   # 6
    diff = self.base_diff + 4;     # 5
    stage1_input = "create_next_level\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(self.base_diff + 2)
                 + ", prev_levels=[" + self.fmt_level_text(L5) + ", " + self.fmt_level_text(L6) + "], prev_level_maps=[" + maps_text[2] + ", " + maps_text[3] + "])\n"
                 + "last_levels = [" + self.fmt_level_text(L5) + ", " + self.fmt_level_text(L6) + "]\n"
                 + "difficulty = " + str(diff);

    L7 = self.make_level(cur_level, diff);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage1_input, "output": json.dumps(L7, ensure_ascii=False)}, ensure_ascii=False));
    levels.append(L7);

    # L7 map (window 4..7)
    cur_level = int(L7["name"] - 1);   # 6
    (pl_txt, pm_txt) = self.window_prev_levels_text(levels, maps_text, int(L7["name"]));
    stage2_input = "create_next_map\n\n"
                 + "self = LevelManager(current_level=" + str(cur_level)
                 + ", current_difficulty=" + str(self.base_diff + 2)
                 + ", prev_levels=[" + pl_txt + "], prev_level_maps=[" + pm_txt + "])\n"
                 + "level = " + self.fmt_level_text(L7);

    map7 = self.gen_map_for(L7);
    self.write_jsonl_line(json.dumps({"system": system, "input": stage2_input, "output": json.dumps(map7, ensure_ascii=False)}, ensure_ascii=False));
  }

  # entry: run many times and append
  can start with `root entry {
    # loop `runs` times
    run_idx = 0;
    while run_idx < self.runs {
      self.do_one_run(run_idx);
      run_idx = run_idx + 1;
    }
  }
}

with entry:__main__ {
  # start once; the walker handles the loop
  root spawn Stage10V1(
    seed=20250817,
    seed_step=1,
    runs=50,
    out_jsonl="stage10_v1.jsonl",
    echo_stdout=False,
    base_level=2,
    base_diff=1
  );
}
