#! /usr/bin/env pike

// to record final scores over 10 games in D1/scores.txt
//pike othello_gtp.pike -f ./player1 -s ./player2 -o D1 -n 10 -v 1

// to record games in player1-vs-player2-XXX.sgf
//pike othello_gtp.pike -f ./player1 -s ./player2 -n 1 -v 1 -l 1

float player_game_time = 320.0;


#define DUMP_GTP_PIPES		0

class othellotp_server {
  int server_is_up;
  private Stdio.File file_out;
  private Stdio.FILE file_in;
  string command_line;
  string full_engine_name;

  void create(string _command_line) {
    file_out = Stdio.File();
    file_in = Stdio.FILE();
    command_line = _command_line;
    array error = catch { 
	Process.create_process(command_line / " ",
			       ([ "stdin" : file_out->pipe(),
				  "stdout" : file_in->pipe() ])); };
    if (error) {
      werror(error[0]); werror("Command line was `%s'.\n", command_line);
      destruct(this_object());
    } else {
      array error = catch {
	  full_engine_name = get_full_engine_name(); server_is_up = 1; };
      if (error) {
	werror("Engine `%s' crashed at startup.\nPerhaps command line is wrong.\n",
	       command_line);
	destruct(this_object());
      }
    }
  }
  
  array send_command(string command) {
#if DUMP_GTP_PIPES
    werror("[%s%s] %s\n", full_engine_name ? full_engine_name + ", " : "", command);
#endif
    command = String.trim_all_whites(command);
    sscanf(command, "%[0-9]", string id);
    if (command[0] == '#' || command == id) return ({ 0, "" });
    file_out->write("%s\n", command);
    string response = file_in->gets();
    if (!response) {
      server_is_up = 0;
      error("Engine `%s' playing crashed!", command_line);
    }
#if DUMP_GTP_PIPES
    werror("%s\n", response);
#endif
    array result;
    int id_length = strlen(id);
    if (response && response[..id_length] == "=" + id)
      result = ({ 0, response[id_length + 1 ..] });
    else if (response && response[..id_length] == "?" + id)
      result = ({ 1, response[id_length + 1 ..] });
    else
      result = ({ -1, response });
    result[1] = String.trim_all_whites(result[1]);
    while (1) {
      response = file_in->gets();
#if DUMP_GTP_PIPES
      werror("%s\n", response);
#endif
      if (response == "") {
	if (result[0] < 0) {
	  werror("Warning, unrecognized response to command `%s':\n", command);
	  werror("%s\n", result[1]);
	}
	return result;
      }
      result[1] += "\n" + response;
    }
  }
  string get_full_engine_name() {
    return send_command("name")[1] + " " + send_command("version")[1];
  }
  string generate_move(int _first_player) {
    if(_first_player == 1) return send_command("genmove black ")[1];
    return send_command("genmove white ")[1];
  }
  void newgame() {
    send_command("clear_board ");
  }
  void move(string _movestr, int _first) {
    if(_first == 1) send_command("play black " +_movestr);
    else send_command("play white " +_movestr);
  }
  void quit() {
    send_command("quit");
  }
};


class othellotp_game {
  private othellotp_server p0;
  private othellotp_server p1;
  private int verbose;

  public int log_games;
  int nb_moves_records = 0;
  public array(string) moves_records = allocate(100);

  public int nb_games;

  public string p0_name;
  public int p0_score;
  public int p0_new_win;
  public int p0_wins;

  public string p1_name;
  public int p1_score;
  public int p1_new_win;
  public int p1_wins;


  public int nb_turn;
  public int board_w = 10;
  public int board_h = 10;
  bool board_alloc = false;
  public string board;

  float p0_remaining_time;
  float p1_remaining_time;

  int cap_start;
  int cap_player_color;
  int cap_opponent_color;
  array(int) cap_pos = allocate(100);
  int cap_size;

  public string output_dir = "data";

  void create(string command_line_player0, string command_line_player1,
	      string new_output_dir, int _verbose, int _log) {
    verbose = _verbose;
    log_games = _log;
    p0 = othellotp_server(command_line_player0);
    if (p0) p1 = othellotp_server(command_line_player1);
    if (!p0 || !p1) {
      werror("!p0 || !p1"); finalize(); exit(0);
    }
    
    nb_games = 0; 
    p0_name = command_line_player0; p0_new_win = 0; p0_wins = 0;
    p1_name = command_line_player1; p1_new_win = 0; p1_wins = 0;
    
    if(new_output_dir != "") {
      output_dir = new_output_dir;
    }
  }

  void sgf_log_init() {
    nb_moves_records = 0;
  }
  // a8 -> 8a -> ha
  void sgf_add_move(string str) {
    int c0 = -1;
    int c1 = -1;
    if(str[0] >= 'a' && str[0] <= 'h') c0 = (str[0]-'a');
    if(str[1] >= '1' && str[1] <= '8') c1 = (str[1]-'1');
    if(c0 == -1 && c1 == -1) {
      moves_records[nb_moves_records] = "tt";
    } else {
      moves_records[nb_moves_records] = sprintf("%c%c", 'a'+c1, 'a'+c0);
    }
    nb_moves_records ++;
  }
  // http://www.red-bean.com/sgf/
  void sgf_log_end() {
    string n0 = p0_name - "./";
    string n1 = p1_name - "./";
    string log_filename = sprintf("%s-vs-%s-%03d.sgf", n0, n1, nb_games);
    Stdio.File o = Stdio.File();
    if(!o->open(log_filename,"wc")) {
      write("Failed to open file %s.\n", log_filename);
      return;
    }
    o->write("(;GM[2]FF[4]\nCA[UTF-8]\nAP[othello_gtp.pike]\nSZ[8]\nPB[%s]\nPW[%s]\n", n0, n1);
    if(p0_new_win == 1) {
      o->write("RE[B+%d]\n", p0_score-p1_score);
    } else if(p1_new_win == 1) {
      o->write("RE[W+%d]\n", p1_score-p0_score);
    }
    for(int i = 0; i < nb_moves_records; i++) {
      if(i>0 && i%10==0) o->write("\n");
      if(i%2 == 0) o->write(";B[%s]", moves_records[i]);
      else o->write(";W[%s]", moves_records[i]);
    }
    o->write("\n)");
    o->close();
  }

  void printScore(string file_name) {
    Stdio.File o = Stdio.File();
    if(!o->open(file_name,"wac")) {
        write("Failed to open file.\n");
        return;
    }
    o->write(" (%s %d %.2f) (%s %d %.2f) ",
	     p0_name, p0_score, p0_remaining_time,
	     p1_name, p1_score, p1_remaining_time);
    if(p0_new_win == 1) {
      o->write("=> "+p0_name+" win\n");
    } else if(p1_new_win == 1) {
      o->write("=> "+p1_name+" win\n");
    } else {
      o->write("=> draw game\n");
    }
    o->close();
  }

  void init_board() {
    nb_turn = 0;
    p0_remaining_time = player_game_time;
    p1_remaining_time = player_game_time;
    
    if(board_alloc == false) {
      for(int i = 0; i < board_w*board_h; i++)
    	board = board+".";
      board_alloc = true;
    } else {
      for(int i = 0; i < board_w*board_h; i++)
	board[i] = '.';
    }
    for(int i = 0; i < board_w; i++) {
      board[i] = '#';  board[i+(board_w*(board_h-1))] = '#';
    }
    for(int i = 0; i < board_h; i++) {
      board[i*board_w] = '#';  board[i*board_w+(board_w-1)] = '#';
    }
    board[44] = 'o'; board[45] = '@';
    board[54] = '@'; board[55] = 'o';
  }
  void print_board() {
    bool color_print = true;
    if(color_print) {
      werror("nb_turn: %d   timers : \x1b[31m%.2f\x1b[0m : %.2f\n", 
	     nb_turn, p0_remaining_time, p1_remaining_time);
    } else {
      werror("nb_turn: %d   timers : %.2f : %.2f\n", 
	     nb_turn, p0_remaining_time, p1_remaining_time);
    }
    for(int i = 1; i < 9; i++) {
      werror(""+i+" ");
      for(int j = 1; j < 9; j++) {
	if(color_print) {
	  if(board[i*10+j] == '@') {
	    werror("\x1b[31m%c\x1b[0m ", board[i*10+j]);
	  } else {
	    werror("%c ",board[i*10+j]);
	  }
	} else {
	  werror("%c ",board[i*10+j]);
	}
      }
      werror("\n");
    }
    werror("  ");
    for(int j = 0; j < 8; j++) 
      werror("%c ", 'a'+j);
    werror("\n");
  }
  bool play_move(string move) {
    if(move == "PASS") { 
      for(int i = 1; i < 9; i++) {
	for(int j = 1; j < 9; j++) {
	  if(board[i*10+j] == '.') {
	    cap_start = -1; cap_size = 0;
	    if(make_cap(i*10+j) == true) {
	      return false;
	    }
	  }
	}
      }
      cap_player_color = '@';
      cap_opponent_color = 'o';
      if(nb_turn%2 == 1) {
        cap_player_color = 'o';
        cap_opponent_color = '@';
      }
      nb_turn ++; return true; 
    }
    int strpos = 0;
    if(move[0] >= 'a' && move[0] <= 'h') strpos += 1+(move[0]-'a');
    if(move[1] >= '1' && move[1] <= '8') strpos += board_w*(1+move[1]-'1');
    if(strpos >= 0 && strpos <= 142) {
      if(board[strpos] != '.') return false;
      cap_start = -1; cap_size = 0;
      if(make_cap(strpos) == false) return false;
      board[strpos] = cap_player_color;
      for(int i = 0; i < cap_size; i++)
	board[cap_pos[i]] = cap_player_color;
      nb_turn ++;
      return true;
    }
    return false;
  }
  void set_result() {
    p0_score = 0; // always black player
    p1_score = 0;
    for(int i = 1; i < 9; i++) {
      for(int j = 1; j < 9; j++) {
	if(board[i*10+j] == '@') p0_score++;
	else if(board[i*10+j] == 'o') p1_score++;
      }
    }
    p0_new_win = 0; p1_new_win = 0;
    if(p0_score > p1_score) { p0_new_win = 1; p1_new_win = 0; }
    if(p1_score > p0_score) { p0_new_win = 0; p1_new_win = 1; }
  }


  bool make_cap(int _pos) {
    bool ret = false;
    cap_player_color = '@';
    cap_opponent_color = 'o';
    if(nb_turn%2 == 1) {
      cap_player_color = 'o';
      cap_opponent_color = '@';
    }
    if(dir_str_opp(_pos, -board_w)) ret = true; 
    if(dir_str_opp(_pos, board_w)) ret = true;
    if(dir_str_opp(_pos, -1)) ret = true;
    if(dir_str_opp(_pos, 1)) ret = true;
    if(dir_str_opp(_pos, board_w+1)) ret = true;
    if(dir_str_opp(_pos, -board_w-1)) ret = true;
    if(dir_str_opp(_pos, board_w-1)) ret = true;
    if(dir_str_opp(_pos, -board_w+1)) ret = true;
    return ret;
  }
  bool dir_str_opp(int _pos, int _dir) {
    if(dir_is_opp(_pos, _dir) == false) return false;
    if(cap_start == -1) cap_start = _pos;
    int cap_size_copy = cap_size;
    cap_pos[cap_size] = _pos+_dir; cap_size++;
    int npos = _pos+2*_dir;
    while(board[npos] == cap_opponent_color) {
      cap_pos[cap_size] = npos; 
      cap_size++; npos+=_dir;
    }
    if(board[npos] == cap_player_color) return true;
    cap_size = cap_size_copy;
    return false;
  }
  bool dir_is_opp(int _pos, int _dir) {
    if(board[_pos] == '#') return false;
    if(board[_pos+_dir] == cap_opponent_color) return true;
    return false;
  }

  void play() {
    if (verbose) werror("\nBeginning a new game.\n");

    p0_new_win = 0;
    p1_new_win = 0;
    p0_score = 0; 
    p1_score = 0;
    p0->newgame();
    p1->newgame();

    init_board();
    if(verbose) print_board();

    // perform a match
    string p0_move = "";
    string p1_move = "";
    while(true) {      

      array(int) Ti = System.gettimeofday();
      p0_move = p0->generate_move(1);
      if(log_games) sgf_add_move(p0_move);
      array(int) Tf = System.gettimeofday();
      float ms = (float)((Tf[0] - Ti[0]))+(float)(Tf[1] - Ti[1])/1000000;
      p0_remaining_time -= ms;
      if(p0_remaining_time < 0.0) {
	p0_new_win = 0; p1_new_win = 1;
	werror(" ===> "+p0_name+" time exceeded\n");
	print_board();
	werror(" ===> "+p1_name+" WIN\n");
	break;
      }
      if(play_move(p0_move) == false) {
	p0_new_win = 0; p1_new_win = 1;
	werror(" ===> "+p0_name+" try to play "+p0_move+"\n");
	print_board();
	werror(" ===> "+p1_name+" WIN\n");
	break;
      } else {
	if(verbose) {
	  string msg = sprintf("\n === player %c at %s\n", cap_player_color, p0_move);
	  werror(msg);
	  print_board();
	}
      }
      p1->move(p0_move, 1);
      if(p0_move == "PASS" && p1_move == "PASS") {
	set_result(); break;
      }

      Ti = System.gettimeofday();
      p1_move = p1->generate_move(0);
      if(log_games) sgf_add_move(p1_move);
      Tf = System.gettimeofday();
      ms = (float)((Tf[0] - Ti[0]))+(float)(Tf[1] - Ti[1])/1000000;
      p1_remaining_time -= ms;

      if(p1_remaining_time < 0.0) {
	p1_new_win = 0; p0_new_win = 1;
	werror(" ===> "+p1_name+" time exceeded\n");
	print_board();
	werror(" ===> "+p0_name+" WIN\n");
	break;
      }
      if(play_move(p1_move) == false) {
	p1_new_win = 0; p0_new_win = 1;
	werror(" ===> "+p1_name+"try to play "+p1_move+"\n");
	print_board();
	werror(" ===> "+p0_name+" WIN\n");
	break;
      } else {
	if(verbose) {
	  string msg = sprintf("\n === player %c at %s\n", cap_player_color, p1_move);
	  werror(msg);
	  print_board();
	}
      }
      p0->move(p1_move, 0);
      //sleep(1);
      if(p0_move == "PASS" && p1_move == "PASS") {
	set_result(); break;	
      }
    }
  }

  void finalize() {
    p0->quit(); p1->quit(); 
  }
}

void run_many_games(othellotp_game game, int _nb_games_to_play) {

  game->nb_games = 0;
  for (int k = 0; k < _nb_games_to_play; k++) {
    if(game->log_games == 1) { game->sgf_log_init(); }
    game->play();
    if(game->p0_new_win == 1) {
      werror("================= player1 (%s) WIN\n", game->p0_name);
      game->p0_wins ++;
    } 
    if(game->p1_new_win == 1) {
      werror("================= player2 (%s) WIN\n", game->p1_name);
      game->p1_wins ++;
    } 
    if(game->p0_new_win == 0 && game->p1_new_win == 0) {
      werror("================= DRAW game\n");
    }
    game->nb_games ++;
    game->printScore(game->output_dir+"/scores.txt");
    if(game->log_games == 1) { game->sgf_log_end(); }
    sleep(2);
  }
  game->finalize();
}

string help_message =
  "Usage: %s [OPTION]... [FILE]...\n\n"
  "Runs either a match or endgame contest between two GTP engines.\n"
  "`--white' and `--black' options are mandatory.\n\n"
  "Options:\n"
  "  -n, --number=NB_GAMES         the number of games to play\n"
  "  -f, --first=COMMAND_LINE\n"
  "  -s, --second=COMMAND_LINE     command lines to run the two engines with.\n\n"
  "  -o, --outputdir=OUTPUT_DIRECTORY (default ouput is data)\n"
  "      --help                    display this help and exit.\n"
  "  -v, --verbose=LEVEL           1 - print moves, 2 and higher - draw boards.\n"
  "  -l, --log=ON/OFF           1 - activate log files.\n";

int main(int argc, array(string) argv) {
  string hint = sprintf("Try `%s --help' for more information.\n",
			basename(argv[0]));
  if (Getopt.find_option(argv, UNDEFINED, "help")) {
    write(help_message, basename(argv[0]));
    return 0;
  }
  string str_nb_games = Getopt.find_option(argv, "n", "games", UNDEFINED, "");
  int nb_games = 1;
  if (str_nb_games != "") {
    sscanf(str_nb_games, "%d", nb_games);
    if(nb_games <= 0) nb_games = 1;
  }
  string str_p0 = Getopt.find_option(argv, "f", "first", UNDEFINED, "");
  if (str_p0 == "") {
    werror("First player is not specified.\n" + hint);
    return 1;
  }
  string str_p1 = Getopt.find_option(argv, "s", "second", UNDEFINED, "");
  if (str_p1 == "") {
    werror("Second player is not specified.\n" + hint);
    return 1;
  }
  string str_output_dir = Getopt.find_option(argv, "o", "outputdir", UNDEFINED, "");
  int verbose = (int) Getopt.find_option(argv, "v", "verbose", UNDEFINED, "0");
  int loggames = (int) Getopt.find_option(argv, "l", "log", UNDEFINED, "0");
  
  othellotp_game game = othellotp_game(str_p0, str_p1, str_output_dir, verbose, loggames);
  if (game) {
    run_many_games(game, nb_games);
  }
  return 0;
}
