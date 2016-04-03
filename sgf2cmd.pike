#! /usr/bin/env pike

// to convert sgf to cmd file

int main(int argc, array(string) argv) {
  
  if(sizeof(argv) != 2) {
    werror("usage: %s SGF_FILE\n");
    exit(0);
  }
  string infile = argv[1];
  string outfile = replace(infile, ".sgf", ".cmd");
  // werror("-->%s\n", infile);
  // werror("-->%s\n", outfile);

  Stdio.File out = Stdio.File();
  if(!out->open(outfile,"wc")) {
    write("Failed to open file %s.\n", outfile);
    return 0;
  }
  out->write("clear_board\n");

  string incontent = Stdio.File(infile)->read();
  int insize = sizeof(incontent);
  //  werror("-->%d\n", insize);

  for(int i = 0; i < insize; i++) {
    if(incontent[i] == ';') {
      if(i+1 == insize) break;
      if(incontent[i+1] == 'B') {
	//werror("black move\n");
	if(incontent[i+3] == 't' && incontent[i+4] == 't') {
	  out->write("play black PASS\n");
	} else {
	  int col = incontent[i+3]-'a';
	  int lig = incontent[i+4];
	  out->write("play black %c%c\n", lig, '1'+col);
	}
      }
      if(incontent[i+1] == 'W') {
	if(incontent[i+3] == 't' && incontent[i+4] == 't') {
	  out->write("play white PASS\n");
	} else {
	  //werror("white move\n");
	  int col = incontent[i+3]-'a';
	  int lig = incontent[i+4];
	  out->write("play white %c%c\n", lig, '1'+col);
	}
      }
    }
  }
  out->write("quit\n");
  out->close();

  return 0;
}
