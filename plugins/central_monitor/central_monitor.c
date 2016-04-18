/**************************************************************************/
/*                                                                        */
/*                              OCamlPro TypeRex                          */
/*                                                                        */
/*   Copyright OCamlPro 2011-2016. All rights reserved.                   */
/*   This file is distributed under the terms of the GPL v3.0             */
/*      (GNU Public Licence version 3.0).                                 */
/*                                                                        */
/*     Contact: <typerex@ocamlpro.com> (http://www.ocamlpro.com/)         */
/*                                                                        */
/*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES       */
/*  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND              */
/*  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS   */
/*  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    */
/*  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN     */
/*  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE      */
/*  SOFTWARE.                                                             */
/**************************************************************************/


#include "caml/mlvalues.h"
#include "caml/misc.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define PROTOCOL_VERSION 1

#define ARG_ENDMSG 0
#define ARG_STRING 1
#define ARG_POSINT 2
#define ARG_NEGINT 3
#define ARG_NULL   4

#define MSG_C2S_INIT   1
#define MSG_C2S_EXIT   2
#define MSG_C2S_OPEN   3
#define MSG_C2S_CLOSE  4
#define MSG_C2S_STAT   5
#define MSG_C2S_UNLINK 6
#define MSG_C2S_RENAME  7
#define MSG_C2S_CHDIR   8
#define MSG_C2S_GETENV  9
#define MSG_C2S_SYSTEM 10
#define MSG_C2S_READ_DIRECTORY 11


#define MSG_S2C_INIT 1
#define MSG_S2C_OK   2

static int sockfd = -1;
static int synchronous_mode = 0;

#define BUF_LEN 65500
static char buf[BUF_LEN];
static int pos = 0;

static void buf_posint(int i)
{
  while(i > 0x7f){
    buf[pos++] = i & 0x7f;
    i = i >> 7;
  }
  buf[pos++] = i | 0x80;
}

static void buf_null()
{
  buf[pos++] = ARG_NULL;
}

static void buf_int(int i)
{
  if( pos + 20 > BUF_LEN ) { sockfd = -1; pos = 0; return; }
  if( i < 0 ){
    buf[pos++] = ARG_NEGINT;
    i = -i;
  } else {
    buf[pos++] = ARG_POSINT;
  }
  buf_posint(i);
}

static void buf_string(char* s, int slen)
{
  if( pos + slen + 20 > BUF_LEN ) { sockfd = -1; pos = 0; return; }
  
  buf[pos++] = ARG_STRING;
  buf_posint(slen);
  strncpy(buf+pos, s, slen);
  pos += slen;
  buf[pos++] = 0;
}

static void buf_string0(char *s)
{ buf_string(s, strlen(s)); }

static void use_message(int msg, int nargs, intnat *args)
{
  
}

static int parse_message()
{
  int np = pos;
  unsigned char *s = (unsigned char*) buf;
  int nargs = 0;
  int sign = 1;
  intnat args[20];
  int msg = *s++;  np--;
  while( np > 0 ){
    int arg_kind = *s++;
    np--;
    switch( arg_kind ){
    case ARG_ENDMSG:{
      use_message(msg, nargs, args);
      pos = 0;
      return 1;
    }
    case ARG_NULL:{
      args[nargs++] = (intnat)NULL;
      break;
    }
    case ARG_NEGINT:{
      sign = -1;
    } /* fall-through */
    case ARG_STRING:
    case ARG_POSINT:
      {      
      intnat i = 0;
      int offset = 0;
      if( np == 0 ) return 0;
      intnat c = *s++; np--;
      while( (c & 0x80) == 0 ){
        i |= c << offset;
        offset += 7;
        if( np == 0 ) return 0;
        c = *s++; np--;
      }
      i |= (c & 0x7f) << offset;
      i *= sign;
      if( arg_kind == ARG_STRING ){
        if( np > i ){
          i = (intnat) s;
          np -= (i+1);
          s += (i+1);
        } else {
          return 0;
        }
      }
      args[nargs++] = i;
      sign = 1;
      break;
    }
    default:{
      pos = 0;
      sockfd = -1;
      return 1;
    }
    }
  }
  pos = 0;
  return 1;
}

#define SET_INT(buf,pos,msg_len)                \
  buf[pos] = (msg_len) & 0xff;                  \
  buf[(pos)+1] = ((msg_len) >> 8) & 0xff;       \
  buf[(pos)+2] = ((msg_len) >> 16) & 0xff;      \
  buf[(pos)+3] = ((msg_len) >> 24) & 0xff;      \

static int msg_id = 0;

static int buf_send()
{
  char *s = buf;
  int msg_len = pos - 8;
  SET_INT(buf,0,msg_len);
  msg_id++;
  SET_INT(buf,4,msg_id);
/*  fprintf(stderr, "Message send %d %d\n", msg_id,msg_len); */
  if(sockfd >= 0){
    while(pos > 0){
      int nw = write(sockfd, s, pos);
      if( nw <= 0 ){ sockfd = -1; pos = 0; return -1; }
      /*      fprintf(stderr, "written %d\n", nw); */
      s += nw;
      pos -= nw;
    }
  }
  pos = 0;
  return msg_id;
}

static void buf_end_msg()
{
  if( sockfd >= 0 ){
/*    fprintf(stderr, "buf_end_msg\n"); */
    buf[pos++] = ARG_ENDMSG;
    int id = buf_send();
    if( id > 0 && synchronous_mode ){
      /* For now, we suppose server messages are short... */
      int msg_read = 0;
      char * s = buf;
      while( !msg_read ){
        int nr = read(sockfd, s, BUF_LEN - pos);
        if( nr <= 0 ){ sockfd = -1; pos = 0; return; }
        s += nr;
        pos += nr;
        msg_read = parse_message();
      }
      pos = 0;
    }
  }
}


static int buf_begin_msg(int msg)
{
  if( sockfd >= 0 ){
    
    pos = 8;
    buf[pos++] = msg;
    return 1;
  }
  return 0;
}

static void send_initial_message(char* exe_name, char** argv)
{
  buf_begin_msg(MSG_C2S_INIT);
  buf_int(PROTOCOL_VERSION);
  buf_int(synchronous_mode);
  buf_string0(exe_name);
  while( *argv != NULL){
    buf_string0(*argv++);
  }
  buf_null();
  buf_int(getpid());
  buf_int(getppid());
  {
    char *curdir = malloc(50000);
    getcwd(curdir, 50000);
    buf_string0(curdir);
    free(curdir);
  }
  buf_end_msg();
}






static int (*my_caml_read_directory)(char * dirname, struct ext_table * contents);

static intnat caml_cplugins_watcher(int prim, intnat arg1, intnat arg2, intnat arg3)
{
  switch(prim){
  case CAML_CPLUGINS_EXIT: {
    if( buf_begin_msg(MSG_C2S_EXIT) ){
      buf_int(arg1);
      buf_end_msg();
      if( !synchronous_mode ){ /* on exit, flush the socket */
        /*        fprintf(stderr, "waiting for shutdown\n"); */
        shutdown(sockfd, SHUT_RDWR);
      }
    }
    exit(arg1);
  }
  case CAML_CPLUGINS_OPEN: {
    int ret = open((char*)arg1,arg2,arg3);
    if( buf_begin_msg(MSG_C2S_OPEN) ){
      buf_string0((char*)arg1);
      buf_int(arg2);
      buf_int(arg3);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  case CAML_CPLUGINS_CLOSE: {
    int ret = close(arg1);
    if( buf_begin_msg(MSG_C2S_CLOSE) ){
      buf_int(arg1);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  case CAML_CPLUGINS_STAT: {
    int ret = stat((char*)arg1,(struct stat *)arg2);
    if( buf_begin_msg(MSG_C2S_STAT) ){
      buf_string0((char*)arg1);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  case CAML_CPLUGINS_UNLINK: {
    int ret = unlink((char*)arg1);
    if( buf_begin_msg(MSG_C2S_UNLINK ) ) {
      buf_string0((char*)arg1);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  case CAML_CPLUGINS_RENAME: {
    int ret = rename((char*)arg1,(char*)arg2);
    if( buf_begin_msg(MSG_C2S_RENAME) ){
      buf_string0((char*)arg1);
      buf_string0((char*)arg2);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  case CAML_CPLUGINS_CHDIR: {
    int ret = chdir((char*)arg1);
    if( buf_begin_msg(MSG_C2S_CHDIR) ){
      buf_string0((char*)arg1);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  case CAML_CPLUGINS_GETENV: {
    char* ret = getenv((char*)arg1);
    if( buf_begin_msg(MSG_C2S_GETENV) ){
      buf_string0((char*)arg1);
      if( ret != NULL ){
        buf_string0((char*)ret);
      } else {
        buf_null();
      }
      buf_end_msg();
    }
    return (intnat) ret;
  }
  case CAML_CPLUGINS_SYSTEM: {
    int ret = system((char*)arg1);
    if( buf_begin_msg(MSG_C2S_SYSTEM) ){
      buf_string0((char*)arg1);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  case CAML_CPLUGINS_READ_DIRECTORY: {
    int ret = my_caml_read_directory((char*)arg1,(struct ext_table * )arg2);
    if( buf_begin_msg(MSG_C2S_READ_DIRECTORY) ){
      buf_string0((char*)arg1);
      buf_int(ret);
      buf_end_msg();
    }
    return ret;
  }
  default:
    fprintf(stderr, "cplugin: unknown primitive %d\n", prim);
    exit(2);
  }

}

typedef value (*caml_cplugins_prim_type)(int,value,value,value);

void caml_cplugin_init(char* exe_name, char** argv, caml_cplugins_prim_type* watcher, void* read_dir)
{
  char *s = getenv("OCP_WATCHER_PORT");
  /*  fprintf(stderr, "port = %s\n", s); */
    
  if( s != NULL ){

    int port = atoi(s);
    /*    fprintf(stderr, "port = %d\n", port);     */
    if( port < 1024 ) return;
    /* fprintf(stderr, "port = %d\n", port);     */
    while(*s != 0){
      if(*s++ == 's') synchronous_mode = 1;
    }
    
    sockfd = socket(PF_INET, SOCK_STREAM, 0);
    struct sockaddr_in s_addr;

    memset(&s_addr, 0, sizeof(struct sockaddr_in));
    s_addr.sin_family = AF_INET;
    inet_aton("127.0.0.1", & s_addr.sin_addr);
    s_addr.sin_port = htons(port);
#ifdef SIN6_LEN
    s_addr->s_inet.sin_len = sizeof(struct sockaddr_in);
#endif
    int sock_len = sizeof(struct sockaddr_in);
    /* fprintf(stderr, "connecting to %d...\n", port); */

    int ret = connect(sockfd, (const struct sockaddr*)&s_addr, sock_len);
    
    if( ret >= 0 ){
      /* fprintf(stderr, "connected...\n"); */
      send_initial_message(exe_name, argv);

      *watcher = caml_cplugins_watcher;
      my_caml_read_directory = read_dir;
    } else {
      fprintf(stderr, "cplugin: could not connect to port %d\n", port);
    }
  } 
}

