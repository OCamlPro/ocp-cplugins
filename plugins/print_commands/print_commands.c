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

typedef value (*caml_cplugins_query)(int);

void caml_cplugin_init(char* exe_name,
                       char** argv,
                       caml_cplugins_query* query)
{
  char *watcher_log = getenv("CAML_PRINT_COMMANDS_LOG");
  if(watcher_log == NULL) watcher_log = "print_commands.log";

  char *dir = malloc(5000);
  char* curdir = getcwd(dir, 5000);
  if(curdir == NULL){
    free(dir);
    dir = malloc(50000);
    curdir = getcwd(dir, 50000);
  }
  FILE *f = fopen(watcher_log, "a");
  fprintf(f, "In %s:\n\t", curdir);
  while(*argv != NULL){
    fprintf(f, "%s ", *argv);
    argv++;
  }
  fprintf(f, "\n");
  fflush(f);
  fclose(f);
  free(dir);
}
