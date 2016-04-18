/*
gcc -Wall -o plugin.so -shared -fPIC byterun/watcher.c
*/


// #include "caml/mlintnats.h"
#include "caml/misc.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* For Sys V RPCs */
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <errno.h>

static int mq_c2s = -1;
static int mq_s2c = -1;

#define ARG_STRING 1
#define ARG_POSINT 2
#define ARG_NEGINT 3



int buf_string(char* buf, int pos, char* s, int slen)
{
  if( pos + slen > 7000 ) return -1;
  
  buf[pos++] = ARG_STRING;
  buf[pos++] = (slen & 0xff);
  buf[pos++] = (slen >> 8) & 0xff;
  strncpy(buf+pos, s, slen);
  return pos + slen;
}

int buf_int(char* buf, int pos, int i)
{
  if( i < 0 ){
    buf[pos++] = ARG_NEGINT;
    i = -i;
  } else {
    buf[pos++] = ARG_POSINT;
  }
  while(i > 0x7f){
    buf[pos++] = i & 0x7f;
    i = i >> 7;
  }
  buf[pos++] = i | 0x80;
  return pos;
}

static intnat caml_cplugins_watcher(int prim, intnat arg1, intnat arg2, intnat arg3)
{
  switch(prim){
  case CAML_CPLUGINS_EXIT: {
    fprintf(stderr, "exit(%d)\n",arg1);
    exit(arg1);
  }
  case CAML_CPLUGINS_OPEN: {
    int ret = open((char*)arg1,arg2,arg3);
    fprintf(stderr, "%d = open(%s,%d,%d)\n",ret, (char*)arg1,arg2,arg3);
    return ret;
  }
  case CAML_CPLUGINS_CLOSE: {
    int ret = close(arg1);
    fprintf(stderr, "%d = close(%d)\n",ret, arg1);
    return ret;
  }
  case CAML_CPLUGINS_STAT: {
    int ret = stat((char*)arg1,arg2);
    fprintf(stderr, "%d = stat(%s,_)\n",ret, (char*)arg1);
    return ret;
  }
  case CAML_CPLUGINS_UNLINK: {
    int ret = unlink((char*)arg1);
    fprintf(stderr, "%d = unlink(%s)\n",ret, (char*)arg1);
    return ret;
  }
  case CAML_CPLUGINS_RENAME: {
    int ret = rename((char*)arg1,(char*)arg2);
    fprintf(stderr, "%d = rename(%s,%s)\n",ret, (char*)arg1, (char*)arg2);
    return ret;
  }
  case CAML_CPLUGINS_CHDIR: {
    int ret = chdir(arg1);
    fprintf(stderr, "%d = chdir(%s)\n",ret, (char*)arg1);
    return ret;
  }
  case CAML_CPLUGINS_GETENV: {
    char* ret = getenv((char*)arg1);
    fprintf(stderr, "%s = getenv(%s)\n",(char*)ret, (char*)arg1);
    return (intnat) ret;
  }
  case CAML_CPLUGINS_SYSTEM: {
    int ret = system((char*)arg1);
    fprintf(stderr, "%d = system(%s)\n",ret, (char*)arg1);
    return ret;
  }
  case CAML_CPLUGINS_READ_DIRECTORY: {
    int ret = caml_read_directory((char*)arg1,arg2);
    fprintf(stderr, "%d = read_directory(%s)\n",ret, (char*)arg1);
    return ret;
  }
  default:
    fprintf(stderr, "Unknown primitive %d\n", prim);
    exit(2);
  }

}

static char bufmsg[8000];
static int bufpos = 0;

void caml_cplugin_init(char* exe_name, char** argv)
{
  char *s = getenv("CAML_WATCHER_MQ");
  if( s != NULL ){

    int mq_c2s = atoi(s) - 1;
    int mq_s2c = msgget(IPC_PRIVATE, 0600);
    if( mq_s2c < 0 || mq_c2s < 0) return;

    int msg_res = msgsnd(mq_c2s, bufmsg, bufpos, 0);
    bufpos = 0;
    if( msg_res < 0 ) {
      fprintf(stderr, "watcher: msgsnd failed.\n");
      return;
    }
    fprintf(stderr, "Plugin connected for %s\n", exe_name);
    
    caml_cplugins_prim = caml_cplugins_watcher;
  }
}

/* What we want: 

 * CAML_WATCHER_FILE should be the name of a socket
   server on the local file-system.
 * The plugin connects to that file, reads some configuration,
   and then outputs all the informations it should.
 * If synchronous mode is chosen, the plugin waits for a response
   from the server every time a request is sent. In asynchronous
   mode, it does not wait (faster).
 */
