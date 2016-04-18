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

/*
gcc -I `ocamlc -where` -Wall -o plugin.so -shared -fPIC byterun/watcher.c
*/


#include "caml/mlvalues.h"
#include "caml/misc.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

static int (*my_caml_read_directory)(char * dirname, struct ext_table * contents);

static intnat caml_cplugins_watcher(int prim, intnat arg1, intnat arg2, intnat arg3)
{
  switch(prim){
  case CAML_CPLUGINS_EXIT: {
    fprintf(stderr, "exit(%ld)\n",arg1);
    exit(arg1);
  }
  case CAML_CPLUGINS_OPEN: {
    int ret = open((char*)arg1,arg2,arg3);
    fprintf(stderr, "%d = open(%s,%ld,%ld)\n",ret, (char*)arg1,arg2,arg3);
    return ret;
  }
  case CAML_CPLUGINS_CLOSE: {
    int ret = close(arg1);
    fprintf(stderr, "%d = close(%ld)\n",ret, arg1);
    return ret;
  }
  case CAML_CPLUGINS_STAT: {
    int ret = stat((char*)arg1,(struct stat *)arg2);
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
    int ret = chdir((char*)arg1);
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
    int ret = my_caml_read_directory((char*)arg1,(struct ext_table * )arg2);
    fprintf(stderr, "%d = read_directory(%s)\n",ret, (char*)arg1);
    return ret;
  }
  default:
    fprintf(stderr, "Unknown primitive %d\n", prim);
    exit(2);
  }

}

typedef value (*caml_cplugins_prim_type)(int,value,value,value);

void caml_cplugin_init(char* exe_name, char** argv, caml_cplugins_prim_type* watcher, void* read_dir)
{
  fprintf(stderr, "Plugin initialized for %s\n", exe_name);
  
  *watcher = caml_cplugins_watcher;
  my_caml_read_directory = read_dir;
}
