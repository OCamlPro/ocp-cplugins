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

type arg =
| ARG_STRING of string
| ARG_INT of int
| ARG_NULL
| ARG_ENDMSG


let get_posint s pos =
  let rec iter s pos i offset =
    let n = int_of_char s.[pos] in
    let pos = pos + 1 in
    if n land 0x80 <> 0 then
      (i lor ((n land 0x7f) lsl offset)), pos
    else
      iter s pos (i lor (n lsl offset)) (offset+7)

  in
  iter s pos 0 0

let get s pos =
  let arg = int_of_char s.[pos] in
  let pos = pos + 1 in
  match arg with
  | 0 -> ARG_ENDMSG, pos
  | 1 ->
    let n,pos = get_posint s pos in
    let s = String.sub s pos n in
    ARG_STRING s, pos + n + 1
  | 2 ->
    let n,pos = get_posint s pos in
    ARG_INT n, pos
  | 3 ->
    let n,pos = get_posint s pos in
    ARG_INT (-n), pos
  | 4 ->
    ARG_NULL, pos
  | _ -> assert false

let get_int s pos =
  let arg, pos = get s pos in
  match arg with
  | ARG_INT n -> n, pos
  | _ -> assert false

let get_string s pos =
  let arg, pos = get s pos in
  match arg with
  | ARG_STRING s -> s, pos
  | _ -> assert false

module C2S = struct

  module MSG_INIT = struct
    type t = {
      protocol_version : int;
      synchronous_mode : int;
      exe_name : string;
      args : string list;
      pid : int;
      ppid : int;
      curdir : string;
    }
    let parse msg pos =

      let protocol_version, pos = get_int msg pos in
      let synchronous_mode, pos = get_int msg pos in
      let exe_name, pos = get_string msg pos in
      let rec iter pos list =
        let v, pos = get msg pos in
        match v with
        | ARG_STRING s ->
          iter pos (s:: list)
        | ARG_NULL ->
          (List.rev list, pos)
        | _ -> assert false
      in
      let args, pos = iter pos [] in
      let pid, pos = get_int msg pos in
      let ppid, pos = get_int msg pos in
      let curdir, pos = get_string msg pos in
      { protocol_version;
        synchronous_mode;
        exe_name;
        args;
        pid;
        ppid;
        curdir;
      }
    let to_string t =
      Printf.sprintf "MSG_INIT { exe_name = %S; args = %s;curdir = %S }"
        t.exe_name (String.concat " " t.args) t.curdir
  end

  module MSG_EXIT = struct
    type t = { retcode : int }
    let parse msg pos =

      let retcode, pos = get_int msg pos in
      { retcode }
    let to_string t = Printf.sprintf "MSG_EXIT { retcode = %d }" t.retcode
  end

  module MSG_OPEN = struct
    type t = {
      filename : string;
      flags : int;
      perm : int;
      ret : int;
    }
    let parse msg pos =

      let filename, pos = get_string msg pos in
      let flags, pos = get_int msg pos in
      let perm, pos = get_int msg pos in
      let ret, pos = get_int msg pos in
      { filename; flags; perm; ret }
    let to_string t =
      Printf.sprintf "MSG_OPEN { filename = %S ret = %d}"
        t.filename t.ret
  end

  module MSG_CLOSE = struct
    type t = { fd : int; ret : int }
    let parse msg pos =

      let fd, pos = get_int msg pos in
      let ret, pos = get_int msg pos in
      { fd; ret }

    let to_string t = Printf.sprintf "MSG_CLOSE { fd = %d ret = %d }" t.fd t.ret
  end

  module MSG_STAT = struct
    type t = { filename : string; ret : int; }
    let parse msg pos =

      let filename, pos = get_string msg pos in
      let ret, pos = get_int msg pos in
      { filename; ret }
    let to_string t = Printf.sprintf "MSG_STAT { filename = %S ret = %d }" t.filename t.ret
  end

  module MSG_UNLINK = struct
    type t = { filename : string; ret : int; }
    let parse msg pos =

      let filename, pos = get_string msg pos in
      let ret, pos = get_int msg pos in
      { filename; ret }
    let to_string t = Printf.sprintf "MSG_UNLINK { filename = %S ret = %d }" t.filename t.ret
  end

  module MSG_RENAME = struct
    type t = { old_filename : string; new_filename : string; ret : int }
    let parse msg pos =

      let old_filename, pos = get_string msg pos in
      let new_filename, pos = get_string msg pos in
      let ret, pos = get_int msg pos in
      { old_filename; new_filename; ret }
    let to_string t = Printf.sprintf "MSG_RENAME"
  end

  module MSG_CHDIR = struct
    type t = { dirname : string; ret : int }
    let parse msg pos =

      let dirname, pos = get_string msg pos in
      let ret, pos = get_int msg pos in
      { dirname; ret }
    let to_string t = Printf.sprintf "MSG_CHDIR"
  end

  module MSG_GETENV = struct
    type t = { var : string; ret : string option }
    let parse msg pos =

      let var, pos = get_string msg pos in
      let ret, pos = get msg pos in
      let ret = match ret with
          ARG_STRING s -> Some s
        | ARG_NULL -> None
        | _ -> assert false
      in
      { var; ret }
    let to_string t =
      Printf.sprintf "MSG_GETENV { var = %S ret = %s }"
        t.var (match t.ret with None -> "None"
        | Some v -> Printf.sprintf "Some %S" v)
  end

  module MSG_SYSTEM = struct
    type t = { command : string; ret : int }
    let parse msg pos =

      let command, pos = get_string msg pos in
      let ret, pos = get_int msg pos in
      { command; ret }
    let to_string t =
      Printf.sprintf "MSG_SYSTEM { command = %S ret = %d }" t.command t.ret
  end

  module MSG_READ_DIRECTORY = struct
    type t = { dirname : string; ret : int }
    let parse msg pos =

      let dirname, pos = get_string msg pos in
      let ret, pos = get_int msg pos in
      { dirname; ret }
    let to_string t = Printf.sprintf "MSG_READ_DIRECTORY { dirname = %S ret = %d }" t.dirname t.ret
  end

  type msg =
  | MSG_INIT of MSG_INIT.t
  | MSG_EXIT of MSG_EXIT.t
  | MSG_OPEN of MSG_OPEN.t
  | MSG_CLOSE of MSG_CLOSE.t
  | MSG_STAT of MSG_STAT.t
  | MSG_UNLINK of MSG_UNLINK.t
  | MSG_RENAME of MSG_RENAME.t
  | MSG_CHDIR of MSG_CHDIR.t
  | MSG_GETENV of MSG_GETENV.t
  | MSG_SYSTEM of MSG_SYSTEM.t
  | MSG_READ_DIRECTORY of MSG_READ_DIRECTORY.t

  let msg_to_string msg =
    match msg with
    | MSG_INIT t -> MSG_INIT.to_string t
    | MSG_EXIT t -> MSG_EXIT.to_string t
    | MSG_OPEN t -> MSG_OPEN.to_string t
    | MSG_CLOSE t -> MSG_CLOSE.to_string t
    | MSG_STAT t -> MSG_STAT.to_string t
    | MSG_UNLINK t -> MSG_UNLINK.to_string t
    | MSG_RENAME t -> MSG_RENAME.to_string t
    | MSG_CHDIR t -> MSG_CHDIR.to_string t
    | MSG_GETENV t -> MSG_GETENV.to_string t
    | MSG_SYSTEM t -> MSG_SYSTEM.to_string t
    | MSG_READ_DIRECTORY t -> MSG_READ_DIRECTORY.to_string t

  let parse_msg msg =
    let msg_kind = int_of_char msg.[0] in
    let pos = 1 in
    let msg =
      match msg_kind with
      | 1 -> MSG_INIT (MSG_INIT.parse msg pos)
      | 2 -> MSG_EXIT (MSG_EXIT.parse msg pos)
      | 3 -> MSG_OPEN (MSG_OPEN.parse msg pos)
      | 4 -> MSG_CLOSE (MSG_CLOSE.parse msg pos)
      | 5 -> MSG_STAT (MSG_STAT.parse msg pos)
      | 6 -> MSG_UNLINK (MSG_UNLINK.parse msg pos)
      | 7 -> MSG_RENAME (MSG_RENAME.parse msg pos)
      | 8 -> MSG_CHDIR (MSG_CHDIR.parse msg pos)
      | 9 -> MSG_GETENV (MSG_GETENV.parse msg pos)
      | 10 -> MSG_SYSTEM (MSG_SYSTEM.parse msg pos)
      | 11 -> MSG_READ_DIRECTORY (MSG_READ_DIRECTORY.parse msg pos)
      | _ -> assert false
    in
    msg

end

module S2C = struct
  type msg =
  | MSG_ACK

  let marshal msg =
    match msg with
    | MSG_ACK -> "\001"

end
