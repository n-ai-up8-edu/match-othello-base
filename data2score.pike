#! /usr/bin/env pike

// to read data/scores.txt 

int main(int argc, array(string) argv) {
  
  string infile = "data/scores.txt";
  // werror("-->%s\n", infile);
  Stdio.File o=Stdio.File();
  if(!o->open(infile,"r")) {
    write("Failed to open file.\n");
    return 0;
  }
  string file_contents = o->read();
  o->close();

  mapping(string:string) players = ([ ]);
  mapping(string:int) wins = ([ ]);
  mapping(string:int) scores = ([ ]);

  string line;
  foreach(file_contents/"\n",line) {
    array(string) AA = line / " ";
    if(sizeof(AA) == 10) {
      string prg0 = AA[1] - "(./";
      int score0; sscanf(AA[2], "%d", score0);
      float time0; sscanf(AA[3], "%f)", time0);
      string prg1 = AA[4] - "(./";
      int score1; sscanf(AA[5], "%d", score1);
      float time1; sscanf(AA[6], "%f)", time1);
      if(score0 > score1) {
	players[prg0] = prg0;
	wins[prg0] = wins[prg0] + 1;
	scores[prg0] = scores[prg0] + score0;
      }
      if(score1 > score0) {
	players[prg1] = prg1;
	wins[prg1] = wins[prg1] + 1;
	scores[prg1] = scores[prg1] + score1;
      }
    }
  }
  array(string) pl = values(players);
  for(int i = 0; i < sizeof(pl); i++) {
    int sum_wins = wins[pl[i]];
    int sum_scores = scores[pl[i]];
    string pp = sprintf("  %s %d wins [%d]\n", pl[i], sum_wins, sum_scores);
    werror(pp);
  }

  return 0;
}
