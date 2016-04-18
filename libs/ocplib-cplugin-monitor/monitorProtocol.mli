(**************************************************************************)
(*                                                                        *)
(*                        OCamlPro Typerex                                *)
(*                                                                        *)
(*   Copyright OCamlPro 2011-2016. All rights reserved.                   *)
(*   This file is distributed under the terms of the GPL v3.0             *)
(*   (GNU General Public Licence version 3.0).                            *)
(*                                                                        *)
(*     Contact: <typerex@ocamlpro.com> (http://www.ocamlpro.com/)         *)
(*                                                                        *)
(*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       *)
(*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES       *)
(*  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND              *)
(*  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS   *)
(*  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    *)
(*  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN     *)
(*  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE      *)
(*  SOFTWARE.                                                             *)
(**************************************************************************)

module MSG_C2S_INIT : sig
  type t = {
           protocol_version : int;
           synchronous_mode : int;
           exe_name : string;
           args : string list;
           pid : int;
           ppid : int;
           curdir : string;
  }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_EXIT : sig
  type t = { retcode : int }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_OPEN : sig
  type t = {
           filename : string;
           flags : int;
           perm : int;
           ret : int;
         }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_CLOSE : sig
  type t = { fd : int; ret : int; }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_STAT : sig
  type t =  { filename : string; ret : int; }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_UNLINK : sig
  type t =  { filename : string; ret : int; }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_RENAME : sig
  type t = {
           old_filename : string;
           new_filename : string;
           ret : int;
         }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_CHDIR : sig
  type t = { dirname : string; ret : int; }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_GETENV : sig
  type t =  { var : string; ret : string option; }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_SYSTEM : sig
  type t = { command : string; ret : int; }
  val parse : string -> t
  val to_string : t -> string
end
module MSG_C2S_READ_DIRECTORY : sig
  type t = { dirname : string; ret : int; }
  val parse : string -> t
  val to_string : t -> string
end



type msg =
| MSG_C2S_INIT of MSG_C2S_INIT.t
| MSG_C2S_EXIT of MSG_C2S_EXIT.t
| MSG_C2S_OPEN of MSG_C2S_OPEN.t
| MSG_C2S_CLOSE of MSG_C2S_CLOSE.t
| MSG_C2S_STAT of MSG_C2S_STAT.t
| MSG_C2S_UNLINK of MSG_C2S_UNLINK.t
| MSG_C2S_RENAME of MSG_C2S_RENAME.t
| MSG_C2S_CHDIR of MSG_C2S_CHDIR.t
| MSG_C2S_GETENV of MSG_C2S_GETENV.t
| MSG_C2S_SYSTEM of MSG_C2S_SYSTEM.t
| MSG_C2S_READ_DIRECTORY of MSG_C2S_READ_DIRECTORY.t

val msg_to_string : msg -> string
val parse_msg : string -> msg
